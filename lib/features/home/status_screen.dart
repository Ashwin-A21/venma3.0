import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final TextEditingController _textController = TextEditingController();
  File? _selectedMedia;
  String _mediaType = 'text'; // text, image, video
  bool _isUploading = false;

  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);

    if (file != null) {
      setState(() {
        _selectedMedia = File(file.path);
        _mediaType = isVideo ? 'video' : 'image';
      });
    }
  }

  Future<void> _postStatus() async {
    if (_textController.text.isEmpty && _selectedMedia == null) return;

    setState(() => _isUploading = true);

    try {
      await SupabaseService.postStatusWithMedia(
        _textController.text.isEmpty ? null : _textController.text,
        _selectedMedia,
        _mediaType,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Status posted!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error posting status: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Create Status"),
        actions: [
          if (_isUploading)
            const Center(child: Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ))
          else
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.primary),
              onPressed: _postStatus,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _selectedMedia != null
                  ? _mediaType == 'image'
                      ? Image.file(_selectedMedia!)
                      : const Icon(Icons.videocam, size: 100, color: Colors.white) // Placeholder for video preview
                  : TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                      textAlign: TextAlign.center,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: "Type a status...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
            ),
          ),
          if (_selectedMedia != null)
             Padding(
               padding: const EdgeInsets.all(8.0),
               child: TextField(
                 controller: _textController,
                 style: const TextStyle(color: Colors.white),
                 decoration: const InputDecoration(
                   hintText: "Add a caption...",
                   hintStyle: TextStyle(color: Colors.grey),
                   border: OutlineInputBorder(),
                   filled: true,
                   fillColor: Colors.white10,
                 ),
               ),
             ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: () => _pickMedia(ImageSource.camera, false),
                ),
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.white),
                  onPressed: () => _pickMedia(ImageSource.gallery, false),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  onPressed: () => _pickMedia(ImageSource.gallery, true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
