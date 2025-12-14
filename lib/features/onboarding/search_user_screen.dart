import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../core/constants/app_colors.dart';

class SearchUserScreen extends StatefulWidget {
  const SearchUserScreen({super.key});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Contact>? _contacts;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);
      setState(() {
        _contacts = contacts;
      });
    }
  }

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.client
          .from('users')
          .select('id, username, display_name, avatar_url')
          .ilike('username', '%$query%')
          .neq('id', SupabaseService.currentUser!.id)
          .limit(10);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error searching: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest(String userId) async {
    try {
      await SupabaseService.sendFriendRequest(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Friend request sent!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  void _shareInviteLink() {
    final username = SupabaseService.currentUser?.userMetadata?['username'] ?? "me";
    Share.share("Join me on Venma! Use my handle @$username to find me. Download here: https://venma.app");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Find a Friend"),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Username"),
            Tab(text: "Contacts"),
            Tab(text: "Invite"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsernameSearch(),
          _buildContactsList(),
          _buildInviteSection(),
        ],
      ),
    );
  }

  Widget _buildUsernameSearch() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search by username...",
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: AppColors.primary),
                onPressed: _searchUser,
              ),
            ),
            onSubmitted: (_) => _searchUser(),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text((user['username'] as String)[0].toUpperCase()),
                    ),
                    title: Text(user['display_name'] ?? "Unknown",
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text("@${user['username']}",
                        style: const TextStyle(color: Colors.grey)),
                    trailing: ElevatedButton(
                      onPressed: () => _sendRequest(user['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text("Add"),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    if (_contacts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_contacts!.isEmpty) {
      return const Center(child: Text("No contacts found", style: TextStyle(color: Colors.white)));
    }
    return ListView.builder(
      itemCount: _contacts!.length,
      itemBuilder: (context, index) {
        final contact = _contacts![index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.surface,
            child: Text(contact.displayName.isNotEmpty ? contact.displayName[0] : "?"),
          ),
          title: Text(contact.displayName, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
              contact.phones.isNotEmpty ? contact.phones.first.number : "No number",
              style: const TextStyle(color: Colors.grey)),
          trailing: TextButton(
            onPressed: () {
              // Logic to invite via SMS or check if they are on Venma (requires phone matching backend)
              Share.share("Hey ${contact.displayName}, join me on Venma! https://venma.app");
            },
            child: const Text("Invite"),
          ),
        );
      },
    );
  }

  Widget _buildInviteSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.share, size: 80, color: AppColors.primary),
          const SizedBox(height: 20),
          const Text(
            "Invite your close friend",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          const Text(
            "Share your link to connect instantly.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _shareInviteLink,
            icon: const Icon(Icons.ios_share),
            label: const Text("Share Invite Link"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}
