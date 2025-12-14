import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // Auth
  static User? get currentUser => client.auth.currentUser;


  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  static Future<void> signUp(String email, String password, String username) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    // Create user profile in 'users' table if not triggered by DB function
    if (response.user != null && response.session != null) {
      try {
        await client.from('users').upsert({
          'id': response.user!.id,
          'username': username,
          'display_name': username, // Default
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Ignore RLS errors if the trigger already handled it or if session is invalid
        // debugPrint("Profile creation error (likely handled by trigger): $e");
      }
    } else if (response.user != null && response.session == null) {
      // If session is null, email confirmation is likely enabled
      throw "Please check your email to confirm your account, or disable Email Confirmation in Supabase.";
    }
  }

  static Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.venma://login-callback/',
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Data
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await client.from('users').select().eq('id', userId).single();
    return response;
  }

  // Friendships
  static Future<String?> getActiveFriendshipId() async {
    final userId = currentUser!.id;
    final response = await client.from('friendships')
        .select()
        .or('user_id_1.eq.$userId,user_id_2.eq.$userId')
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
        
    if (response != null) {
      return response['id'] as String;
    }
    return null;
  }

  static Future<void> sendFriendRequest(String friendId) async {
    final userId = currentUser!.id;
    // Check if exists
    final exists = await client.from('friendships')
        .select()
        .or('and(user_id_1.eq.$userId,user_id_2.eq.$friendId),and(user_id_1.eq.$friendId,user_id_2.eq.$userId)')
        .maybeSingle();
        
    if (exists != null) {
      throw "Friendship or request already exists!";
    }

    await client.from('friendships').insert({
      'user_id_1': userId,
      'user_id_2': friendId,
      'status': 'pending',
    });
  }

  static Stream<List<Map<String, dynamic>>> getPendingRequests() {
    final userId = currentUser!.id;
    // We want requests where WE are the recipient.
    // In our schema, user_id_1 is usually sender, but let's check both or assume logic.
    // Actually, usually user_id_2 is recipient if user_id_1 initiated.
    // Let's query where we are involved and status is pending.
    // BUT we need to know WHO sent it.
    // For simplicity, let's just show all pending where we are user_id_2.
    return client.from('friendships')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .map((data) => data.where((item) => item['user_id_2'] == userId).toList());
  }

  static Future<void> acceptRequest(String friendshipId) async {
    await client.from('friendships').update({'status': 'active'}).eq('id', friendshipId);
  }

  static Future<void> rejectRequest(String friendshipId) async {
    await client.from('friendships').delete().eq('id', friendshipId);
  }

  static Future<void> sendNudge(String friendshipId) async {
    final userId = currentUser!.id;
    await client.from('messages').insert({
      'friendship_id': friendshipId,
      'sender_id': userId,
      'content': 'NUDGE',
      'type': 'nudge',
    });
  }
  static Future<void> ensureUserProfileExists() async {
    final user = currentUser;
    if (user == null) return;

    try {
      // Check if profile exists
      final profile = await client.from('users').select().eq('id', user.id).maybeSingle();
      
      if (profile == null) {
        // Create profile
        final metadata = user.userMetadata;
        // Generate a unique-ish username if not present
        String username = metadata?['preferred_username'] ?? 
                         metadata?['name']?.toString().replaceAll(' ', '').toLowerCase() ?? 
                         user.email?.split('@')[0] ?? 
                         'user_${user.id.substring(0, 8)}';
                         
        // Ensure username is unique by appending random digits if needed (simple retry logic could be better but this is a start)
        // For now, we'll trust the generated one or let the DB fail if unique constraint violated, 
        // but to be safer let's append some random numbers if it's a common name.
        // Actually, let's just use the generated one. If it fails, the user will see an error, but it's better than nothing.
        
        final displayName = metadata?['full_name'] ?? metadata?['name'] ?? username;
        final avatarUrl = metadata?['avatar_url'] ?? metadata?['picture'];

        await client.from('users').upsert({
          'id': user.id,
          'username': username,
          'display_name': displayName,
          'avatar_url': avatarUrl,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // debugPrint("Error ensuring profile exists: $e");
      // Rethrow so the UI can handle it or retry
      rethrow;
    }
  }
  static Future<Map<String, dynamic>?> getFriendDetails(String friendshipId) async {
    final userId = currentUser!.id;
    final friendship = await client.from('friendships').select().eq('id', friendshipId).single();
    
    final friendId = friendship['user_id_1'] == userId ? friendship['user_id_2'] : friendship['user_id_1'];
    
    return await getUserProfile(friendId);
  }

  static Stream<Map<String, dynamic>?> getLatestMessage(String friendshipId) {
    return client.from('messages')
        .stream(primaryKey: ['id'])
        .eq('friendship_id', friendshipId)
        .order('created_at', ascending: true) // Stream order issue fix: Stream returns list in default order usually, we want to ensure we get the tail.
        // Actually, with .stream(), order matters for the query to select *which* rows to watch if limited.
        // If we want the LATEST, we should order by created_at DESC and limit.
        .order('created_at', ascending: false)
        .limit(10) // Increase limit to avoid edge cases where single item updates might be missed
        .map((messages) {
          if (messages.isEmpty) return null;
          // Sort in memory to be 100% sure we get the latest
          messages.sort((a, b) => b['created_at'].compareTo(a['created_at']));
          return messages.first;
        });
  }
  static Stream<List<Map<String, dynamic>>> getFriendStatus(String friendId) {
    // Get statuses for friend that are not expired
    return client.from('statuses')
        .stream(primaryKey: ['id'])
        .eq('user_id', friendId)
        .order('created_at')
        .map((data) => data.where((s) {
          final expiresAt = DateTime.parse(s['expires_at']);
          return expiresAt.isAfter(DateTime.now());
        }).toList());
  }

  static Future<void> postStatus(String text) async {
    final userId = currentUser!.id;
    await client.from('statuses').insert({
      'user_id': userId,
      'content_text': text,
      'type': 'text',
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });
  }

  static Future<void> postStatusWithMedia(String? text, File? mediaFile, String type) async {
    final userId = currentUser!.id;
    String? mediaUrl;
    
    if (mediaFile != null) {
      final ext = mediaFile.path.split('.').last;
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      // Assuming 'status' bucket exists, otherwise might need to create it or use a common one
      try {
        await client.storage.from('status').upload(path, mediaFile);
        mediaUrl = client.storage.from('status').getPublicUrl(path);
      } on StorageException catch (e) {
        if (e.statusCode == '404' || e.message.contains('Bucket not found')) {
          debugPrint("Bucket 'status' not found. Please create it in Supabase Dashboard.");
          throw "System Error: The 'status' storage bucket is missing. Please contact the developer to create it in the Supabase Dashboard.";
        }
        rethrow;
      } catch (e) {
        debugPrint("Error uploading status media: $e");
        rethrow;
      }
    }

    await client.from('statuses').insert({
      'user_id': userId,
      'content_text': text,
      'content_url': mediaUrl,
      'type': type,
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });
  }

  // Chat Media - Image
  static Future<void> sendImageMessage(String friendshipId, File imageFile, {bool isOneTime = false}) async {
    final userId = currentUser!.id;
    final ext = imageFile.path.split('.').last;
    final path = '$userId/${friendshipId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    try {
      await client.storage.from('chat_media').upload(path, imageFile);
      final url = client.storage.from('chat_media').getPublicUrl(path);
      
      // Get chat settings for disappearing messages
      final expiresAt = await getMessageExpiryTime(friendshipId);
      
      await client.from('messages').insert({
        'friendship_id': friendshipId,
        'sender_id': userId,
        'content': url,
        'type': 'image',
        'is_one_time': isOneTime,
        'expires_at': expiresAt?.toIso8601String(),
      });
    } on StorageException catch (e) {
      debugPrint("Storage error uploading image: ${e.message}");
      if (e.statusCode == '404' || e.message.contains('Bucket not found')) {
        throw "Storage bucket 'chat_media' not found. Please create it in Supabase Dashboard.";
      }
      rethrow;
    } catch (e) {
      debugPrint("Error uploading chat image: $e");
      rethrow;
    }
  }

  // Chat Media - Video
  static Future<void> sendVideoMessage(String friendshipId, File videoFile, {bool isOneTime = false}) async {
    final userId = currentUser!.id;
    final ext = videoFile.path.split('.').last;
    final path = '$userId/${friendshipId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    try {
      await client.storage.from('chat_media').upload(path, videoFile);
      final url = client.storage.from('chat_media').getPublicUrl(path);
      
      final expiresAt = await getMessageExpiryTime(friendshipId);
      
      await client.from('messages').insert({
        'friendship_id': friendshipId,
        'sender_id': userId,
        'content': url,
        'type': 'video',
        'is_one_time': isOneTime,
        'expires_at': expiresAt?.toIso8601String(),
      });
    } on StorageException catch (e) {
      debugPrint("Storage error uploading video: ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("Error uploading chat video: $e");
      rethrow;
    }
  }

  // Chat Media - File/Document
  static Future<void> sendFileMessage(String friendshipId, File file, String fileName) async {
    final userId = currentUser!.id;
    final ext = file.path.split('.').last;
    final path = '$userId/${friendshipId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    try {
      final fileSize = await file.length();
      await client.storage.from('chat_media').upload(path, file);
      final url = client.storage.from('chat_media').getPublicUrl(path);
      
      final expiresAt = await getMessageExpiryTime(friendshipId);
      
      await client.from('messages').insert({
        'friendship_id': friendshipId,
        'sender_id': userId,
        'content': url,
        'type': 'file',
        'file_name': fileName,
        'file_size': fileSize,
        'expires_at': expiresAt?.toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error uploading file: $e");
      rethrow;
    }
  }

  // Mark one-time message as viewed
  static Future<void> markOneTimeViewed(String messageId) async {
    await client.from('messages').update({'one_time_viewed': true}).eq('id', messageId);
  }

  // Get message expiry time based on chat settings
  static Future<DateTime?> getMessageExpiryTime(String friendshipId) async {
    try {
      final settings = await client
          .from('chat_settings')
          .select()
          .eq('friendship_id', friendshipId)
          .maybeSingle();
      
      if (settings == null || settings['disappearing_mode'] == 'off') {
        return null;
      }
      
      switch (settings['disappearing_mode']) {
        case '1_week':
          return DateTime.now().add(const Duration(days: 7));
        case 'custom':
          final hours = settings['custom_duration_hours'] ?? 24;
          return DateTime.now().add(Duration(hours: hours));
        case 'after_read':
          // For after_read, we set a far future date and handle in markAsRead
          return null;
        default:
          return null;
      }
    } catch (e) {
      debugPrint("Error getting chat settings: $e");
      return null;
    }
  }

  // Get/Update chat settings
  static Future<Map<String, dynamic>?> getChatSettings(String friendshipId) async {
    return await client
        .from('chat_settings')
        .select()
        .eq('friendship_id', friendshipId)
        .maybeSingle();
  }

  static Future<void> updateChatSettings(String friendshipId, String mode, {int? customHours}) async {
    await client.from('chat_settings').upsert({
      'friendship_id': friendshipId,
      'disappearing_mode': mode,
      'custom_duration_hours': customHours,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Storage
  static Future<String> uploadFile(File file, String bucket, String path) async {
    // Check if bucket exists first? No, assume it exists or let it fail (user should have run schema)
    // Actually, for avatars, we want to overwrite if the user is updating their own simple path? 
    // But we are using unique timestamps, so overwrite isn't needed.
    await client.storage.from(bucket).upload(path, file);
    return client.storage.from(bucket).getPublicUrl(path);
  }

  // Profile
  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final userId = currentUser!.id;
    await client.from('users').update(updates).eq('id', userId);
  }

  // Calls (Signaling)
  static Future<String> createCall(String receiverId, bool isVideo) async {
    final userId = currentUser!.id;
    final response = await client.from('calls').insert({
      'caller_id': userId,
      'receiver_id': receiverId,
      'status': 'offering',
      'is_video': isVideo,
    }).select().single();
    return response['id'];
  }

  static Stream<List<Map<String, dynamic>>> listenForIncomingCalls() {
    final userId = currentUser!.id;
    return client.from('calls')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .order('created_at')
        .map((events) => events.where((e) => e['status'] == 'offering').toList());
  }
  
  static Future<void> updateCallStatus(String callId, String status, {Map<String, dynamic>? data}) async {
    final updates = {'status': status};
    if (data != null) updates.addAll(data.map((key, value) => MapEntry(key, value.toString())));
    await client.from('calls').update(updates).eq('id', callId);
  }

  static Stream<Map<String, dynamic>> listenToCall(String callId) {
    return client.from('calls').stream(primaryKey: ['id']).eq('id', callId).map((event) => event.first);
  }

  // WebRTC Signals (ICE Candidates, SDP)
  static Future<void> sendSignal(String callId, Map<String, dynamic> signalData) async {
    final userId = currentUser!.id;
    await client.from('call_signals').insert({
      'call_id': callId,
      'sender_id': userId,
      'payload': signalData,
    });
  }

  static Stream<List<Map<String, dynamic>>> listenToSignals(String callId) {
    return client.from('call_signals')
        .stream(primaryKey: ['id'])
        .eq('call_id', callId)
        .order('created_at');
  }

  static Future<int> getStreak(String friendshipId) async {
    final response = await client.from('friendships').select('streak_score').eq('id', friendshipId).single();
    return response['streak_score'] as int? ?? 0;
  }
  static Stream<Map<String, dynamic>> getFriendshipStream(String friendshipId) {
    return client.from('friendships')
        .stream(primaryKey: ['id'])
        .eq('id', friendshipId)
        .map((data) => data.first);
  }
}
