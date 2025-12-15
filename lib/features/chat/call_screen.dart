import 'dart:async';
import '../../core/extensions/color_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';

class CallScreen extends StatefulWidget {
  final String friendName;
  final String friendAvatar;
  final bool isVideo;
  final String? callId; // For incoming
  final bool isIncoming;
  final String? friendId; // For outgoing

  const CallScreen({
    super.key,
    required this.friendName,
    required this.friendAvatar,
    this.isVideo = false,
    this.callId,
    this.isIncoming = false,
    this.friendId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  String _status = "Initializing...";
  String? _currentCallId;
  StreamSubscription? _callSubscription;
  StreamSubscription? _signalSubscription;
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  
  bool _micEnabled = true;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      // Request permissions first
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = "Camera/Microphone permissions denied";
            _status = "Permission Denied";
          });
        }
        return;
      }

      await _initWebRTC();
    } catch (e) {
      debugPrint("Call Init Error: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "Failed to initialize call: $e";
          _status = "Error";
        });
      }
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      if (widget.isVideo) {
        final cameraStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        return cameraStatus.isGranted && micStatus.isGranted;
      } else {
        final micStatus = await Permission.microphone.request();
        return micStatus.isGranted;
      }
    } catch (e) {
      debugPrint("Permission Error: $e");
      return false;
    }
  }

  Future<void> _initWebRTC() async {
    try {
      // Initialize renderers
      _localRenderer = RTCVideoRenderer();
      _remoteRenderer = RTCVideoRenderer();
      
      await _localRenderer!.initialize();
      await _remoteRenderer!.initialize();

      // Get Local Media with error handling
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': widget.isVideo ? {
            'facingMode': 'user',
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          } : false,
        });
        _localRenderer!.srcObject = _localStream;
      } catch (e) {
        debugPrint("GetUserMedia Error: $e");
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = "Could not access camera/microphone";
            _status = "Media Error";
          });
        }
        return;
      }

      // Create Peer Connection
      _peerConnection = await createPeerConnection(_configuration);
      
      // Add Local Tracks
      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });

      // Handle Remote Stream
      _peerConnection?.onTrack = (event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          _remoteRenderer!.srcObject = event.streams[0];
          if (mounted) setState(() {});
        }
      };
      
      _peerConnection?.onAddStream = (stream) {
        _remoteRenderer!.srcObject = stream;
        if (mounted) setState(() {});
      };

      // Handle ICE Candidates
      _peerConnection?.onIceCandidate = (candidate) {
        if (_currentCallId != null) {
          SupabaseService.sendSignal(_currentCallId!, {
            'type': 'ice-candidate',
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            }
          });
        }
      };

      // Handle connection state changes
      _peerConnection?.onConnectionState = (state) {
        debugPrint("Connection State: $state");
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          if (mounted) {
            setState(() => _status = "Connection Failed");
          }
        }
      };

      if (mounted) {
        setState(() => _isInitialized = true);
      }

      if (widget.isIncoming) {
        _currentCallId = widget.callId;
        if (mounted) setState(() => _status = "Connecting...");
        _listenToSignals();
      } else {
        _startOutgoingCall();
      }
    } catch (e) {
      debugPrint("WebRTC Init Error: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "WebRTC initialization failed: $e";
          _status = "Error";
        });
      }
    }
  }

  Future<void> _startOutgoingCall() async {
    if (widget.friendId == null || widget.friendId!.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = "Cannot call: Friend ID is missing";
        _status = "Error";
      });
      return;
    }
    
    try {
      setState(() => _status = "Calling...");
      _currentCallId = await SupabaseService.createCall(widget.friendId!, widget.isVideo);
      _listenToCallStatus();
      _listenToSignals();
      
      // Create Offer
      if (_peerConnection != null) {
        RTCSessionDescription offer = await _peerConnection!.createOffer();
        await _peerConnection!.setLocalDescription(offer);
        
        await SupabaseService.sendSignal(_currentCallId!, {
          'type': 'offer',
          'sdp': offer.sdp,
        });
      }
    } catch (e) {
      debugPrint("Start Call Error: $e");
      setState(() {
        _hasError = true;
        _errorMessage = "Failed to start call: $e";
        _status = "Call Failed";
      });
    }
  }

  void _listenToCallStatus() {
    if (_currentCallId == null) return;
    _callSubscription = SupabaseService.listenToCall(_currentCallId!).listen((data) {
      final status = data['status'];
      if (status == 'ended' || status == 'rejected') {
        setState(() => _status = "Call Ended");
        _closeCall();
      } else if (status == 'answering') {
        setState(() => _status = "Connected");
      }
    });
  }

  void _listenToSignals() {
    if (_currentCallId == null) return;
    
    _signalSubscription = SupabaseService.listenToSignals(_currentCallId!).listen((signals) async {
      for (var signal in signals) {
        // Ignore own signals
        if (signal['sender_id'] == SupabaseService.currentUser!.id) continue;
        
        final payload = signal['payload'];
        if (payload == null) continue;
        
        final type = payload['type'];
        
        try {
          if (type == 'offer' && widget.isIncoming) {
            // Handle Offer
            if (_peerConnection?.signalingState != RTCSignalingState.RTCSignalingStateStable) continue;
            
            await _peerConnection!.setRemoteDescription(
              RTCSessionDescription(payload['sdp'], 'offer')
            );
            
            // Create Answer
            final answer = await _peerConnection!.createAnswer();
            await _peerConnection!.setLocalDescription(answer);
            
            await SupabaseService.sendSignal(_currentCallId!, {
              'type': 'answer',
              'sdp': answer.sdp,
            });
            
            if (mounted) setState(() => _status = "Connected");

          } else if (type == 'answer' && !widget.isIncoming) {
            // Handle Answer
            var remoteDesc = await _peerConnection!.getRemoteDescription();
            if (remoteDesc == null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(payload['sdp'], 'answer')
              );
              if (mounted) setState(() => _status = "Connected");
            }

          } else if (type == 'ice-candidate') {
            // Add Candidate
            final candidateMap = payload['candidate'];
            if (candidateMap != null && _peerConnection != null) {
              await _peerConnection!.addCandidate(RTCIceCandidate(
                candidateMap['candidate'],
                candidateMap['sdpMid'],
                candidateMap['sdpMLineIndex'],
              ));
            }
          }
        } catch (e) {
          debugPrint("Signal Processing Error: $e");
        }
      }
    });
  }

  Future<void> _endCall() async {
    try {
      if (_currentCallId != null) {
        await SupabaseService.updateCallStatus(_currentCallId!, 'ended');
      }
    } catch (e) {
      debugPrint("End Call Error: $e");
    }
    _closeCall();
  }
  
  void _closeCall() {
    _cleanup();
    if (mounted) Navigator.pop(context);
  }

  void _cleanup() {
    _callSubscription?.cancel();
    _signalSubscription?.cancel();
    
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream?.dispose();
    
    _peerConnection?.close();
    _peerConnection?.dispose();
    
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
  }

  void _toggleMic() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        bool enabled = audioTracks.first.enabled;
        audioTracks.first.enabled = !enabled;
        setState(() => _micEnabled = !enabled);
      }
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background / Remote Video
          _buildBackground(),
          
          // Local Video (floating)
          if (widget.isVideo && _isInitialized && _localRenderer?.srcObject != null)
            Positioned(
              right: 20,
              top: 50,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(
                    _localRenderer!, 
                    mirror: true, 
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
                  ),
                ),
              ),
            ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                if (!widget.isVideo || _status != "Connected") ...[
                   const SizedBox(height: 50),
                   Text(
                    widget.isVideo ? "Video Call" : "Voice Call",
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                   ),
                   const SizedBox(height: 10),
                   Text(
                    _status,
                    style: TextStyle(
                      color: _hasError ? Colors.red : AppColors.primary, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                   ),
                   if (_hasError && _errorMessage != null) ...[
                     const SizedBox(height: 10),
                     Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 20),
                       child: Text(
                         _errorMessage!,
                         textAlign: TextAlign.center,
                         style: const TextStyle(color: Colors.red, fontSize: 14),
                       ),
                     ),
                   ],
                   const SizedBox(height: 20),
                   Text(
                    widget.friendName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                   ),
                ],
                
                if (!widget.isVideo && _status != "Connected")
                  Expanded(
                    child: Center(
                      child: _buildAvatarWithAnimation(),
                    ),
                  )
                else
                  const Spacer(),
                
                // Actions
                Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        _micEnabled ? Icons.mic : Icons.mic_off, 
                        _micEnabled ? Colors.white : Colors.black, 
                        _micEnabled ? Colors.white24 : Colors.white, 
                        _toggleMic
                      ),
                      _buildActionButton(Icons.call_end, Colors.white, Colors.red, _endCall),
                      _buildActionButton(Icons.volume_up, Colors.white, Colors.white24, () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (widget.isVideo && _status == "Connected" && _remoteRenderer != null) {
      return RTCVideoView(
        _remoteRenderer!, 
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
      );
    }
    
    // Show avatar image as background
    return Container(
      color: Colors.black,
      child: widget.friendAvatar.isNotEmpty && widget.friendAvatar.startsWith('http')
          ? Image.network(
              widget.friendAvatar,
              fit: BoxFit.cover,
              color: Colors.black.withOpacityValue(0.7),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.black54);
              },
            )
          : Container(color: Colors.black54),
    );
  }

  Widget _buildAvatarWithAnimation() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
        color: Colors.grey[800],
      ),
      child: ClipOval(
        child: widget.friendAvatar.isNotEmpty && widget.friendAvatar.startsWith('http')
            ? Image.network(
                widget.friendAvatar,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.person, size: 60, color: Colors.white54);
                },
              )
            : const Icon(Icons.person, size: 60, color: Colors.white54),
      ),
    ).animate(
      onPlay: (controller) => _status == "Calling..." ? controller.repeat() : controller.stop()
    ).shimmer(duration: 2000.ms, color: AppColors.primary.withOpacityValue(0.5));
  }

  Widget _buildActionButton(IconData icon, Color iconColor, Color bgColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 30),
      ),
    );
  }
}
