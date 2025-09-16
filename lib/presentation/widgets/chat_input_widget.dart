import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../core/models/chat_models.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/theme/app_theme.dart';

class ChatInputWidget extends ConsumerStatefulWidget {
  final Function(String) onSendText;
  final Function(String type, String data, String filename) onSendMedia;
  final ChatMessage? replyingTo;

  const ChatInputWidget({
    super.key,
    required this.onSendText,
    required this.onSendMedia,
    this.replyingTo,
  });

  @override
  ConsumerState<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends ConsumerState<ChatInputWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showAttachmentOptions = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Clear input immediately for better UX
    _textController.clear();
    setState(() {
      _showAttachmentOptions = false;
    });

    // Send message
    final chatNotifier = ref.read(chatProvider.notifier);
    chatNotifier.sendTextMessage(
      text,
      replyId: widget.replyingTo?.id,
    );
    
    // Show sending feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending message...'),
        duration: Duration(seconds: 2),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Data = base64Encode(bytes);
        
        // Show sending feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sending image...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        final chatNotifier = ref.read(chatProvider.notifier);
        await chatNotifier.sendMediaMessage(
          type: '3', // Image type
          filename: image.name,
          base64Data: base64Data,
          replyId: widget.replyingTo?.id,
        );
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
    
    setState(() {
      _showAttachmentOptions = false;
    });
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final base64Data = base64Encode(bytes);
        
        // Show sending feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sending document...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        final chatNotifier = ref.read(chatProvider.notifier);
        await chatNotifier.sendMediaMessage(
          type: '5', // Document type
          filename: result.files.single.name,
          base64Data: base64Data,
          replyId: widget.replyingTo?.id,
        );
      }
    } catch (e) {
      _showError('Failed to pick document: $e');
    }
    
    setState(() {
      _showAttachmentOptions = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Attachment options
        if (_showAttachmentOptions)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _AttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                _AttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  onTap: _pickDocument,
                ),
                _AttachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  onTap: () {
                    // TODO: Implement location picker
                  },
                ),
              ],
            ),
          ),
        
        // Input area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Attachment button
              IconButton(
                icon: Icon(
                  _showAttachmentOptions ? Icons.close : Icons.attach_file,
                  color: AppTheme.primaryColor,
                ),
                onPressed: () {
                  setState(() {
                    _showAttachmentOptions = !_showAttachmentOptions;
                  });
                },
              ),
              
              // Text input
              Expanded(
                child: TextFormField(
                  controller: _textController,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Color(0xFFF1F5F9),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  maxLines: 5,
                  minLines: 1,
                  onFieldSubmitted: (_) => _sendTextMessage(),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Send button
              Container(
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                  onPressed: _sendTextMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}