import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/models/chat_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/app_config.dart';

class MessageBubbleWidget extends StatelessWidget {
  final ChatMessage message;
  final bool showSenderInfo;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    this.showSenderInfo = true,
    this.onReply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = _isFromMe(message);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 32,
              child: showSenderInfo ? CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.neutralLight,
                child: const Icon(
                  Icons.person,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ) : null,
            ),
          ],
          
          if (!isMe && showSenderInfo)
            const SizedBox(width: 8)
          else if (!isMe)
            const SizedBox(width: 40),
          
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageActions(context),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Sender name for customer messages
                  if (!isMe && showSenderInfo)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        'Customer',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  
                  // Reply preview
                  if (message.replyId != null) _buildReplyPreview(),
                  
                  // Message content
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.myMessageColor : AppTheme.otherMessageColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: _buildMessageContent(),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Message info
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeago.format(message.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildAckIcon(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (isMe) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              child: showSenderInfo ? CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.white,
                ),
              ) : null,
            ),
          ] else if (isMe) ...[
            const SizedBox(width: 40),
          ],
        ],
      ),
    );
  }

  bool _isFromMe(ChatMessage message) {
    // Message is from me (agent/user) if agentId > 0
    // Message is from customer if agentId == 0
    return message.agentId > 0;
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: AppTheme.primaryColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Replying to',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            message.replyMessage ?? 'Media message',
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (message.type) {
      case 1: // Text
        return _buildTextMessage();
      case 2: // Audio
        return _buildAudioMessage();
      case 3: // Image
        return _buildImageMessage();
      case 4: // Video
        return _buildVideoMessage();
      case 5: // Document
        return _buildDocumentMessage();
      case 7: // Sticker
        return _buildStickerMessage();
      case 9: // Location
        return _buildLocationMessage();
      default:
        return _buildTextMessage();
    }
  }

  Widget _buildTextMessage() {
    final isMe = _isFromMe(message);
    
    // Clean the message text by removing the "Sent from NoBox.Ai trial account" suffix
    String cleanMessage = message.message ?? '';
    if (cleanMessage.contains('\n\nSent from NoBox.Ai trial account')) {
      cleanMessage = cleanMessage.split('\n\nSent from NoBox.Ai trial account')[0];
    }
    
    return Text(
      cleanMessage,
      style: TextStyle(
        color: isMe ? Colors.white : AppTheme.textPrimary,
        fontSize: 16,
      ),
    );
  }

Widget _buildImageMessage() {
  final imageUrl = _getFileUrl();
  if (imageUrl == null || imageUrl.isEmpty) {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Image not available', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 200,
            height: 200,
            color: Colors.grey.shade200,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 200,
            height: 200,
            color: Colors.grey.shade200,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('Failed to load image', 
                     style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ), // Added missing closing parenthesis and comma here
    ],
  );
} // Added missing closing parenthesis for the function

  Widget _buildVideoMessage() {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.play_circle_filled,
            size: 48,
            color: Colors.white,
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Icon(
              Icons.videocam,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioMessage() {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.play_arrow, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: 0.3,
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '0:30',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentMessage() {
    String fileName = 'Document';
    String fileSize = '';
    
    // Try to extract filename from file data
    if (message.file != null) {
      try {
        final fileData = message.file!;
        if (fileData.startsWith('[') || fileData.startsWith('{')) {
          final dynamic parsed = jsonDecode(fileData);
          if (parsed is List && parsed.isNotEmpty) {
            final fileInfo = parsed[0];
            if (fileInfo is Map<String, dynamic>) {
              fileName = fileInfo['OriginalName'] ?? fileInfo['originalName'] ?? fileName;
            }
          } else if (parsed is Map<String, dynamic>) {
            fileName = parsed['OriginalName'] ?? parsed['originalName'] ?? fileName;
          }
        }
      } catch (e) {
        print('Error parsing document data: $e');
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (fileSize.isNotEmpty)
                Text(
                  fileSize,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                )
              else
                const Text(
                  'Document',
                  style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickerMessage() {
    final stickerUrl = _getFileUrl();
    if (stickerUrl == null || stickerUrl.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_emotions, size: 32, color: Colors.grey),
            SizedBox(height: 4),
            Text('Sticker', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: stickerUrl,
      width: 120,
      height: 120,
      fit: BoxFit.contain,
      errorWidget: (context, url, error) => Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_emotions, size: 32, color: Colors.grey),
            SizedBox(height: 4),
            Text('Sticker', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationMessage() {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.map,
            size: 48,
            color: AppTheme.textSecondary,
          ),
          Positioned(
            bottom: 8,
            child: Text(
              'Location',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getFileUrl() {
    if (message.file != null) {
      try {
        final fileData = message.file!;
        
        // Check if it's a JSON string
        if (fileData.startsWith('[') || fileData.startsWith('{')) {
          final dynamic parsed = jsonDecode(fileData);
          if (parsed is List && parsed.isNotEmpty) {
            final fileInfo = parsed[0];
            if (fileInfo is Map<String, dynamic>) {
              final filename = fileInfo['Filename'] ?? fileInfo['filename'];
              if (filename != null) {
                // Construct proper URL
                return '${AppConfig.baseUrl}Inbox/DownloadFile/$filename';
              }
            }
          } else if (parsed is Map<String, dynamic>) {
            final filename = parsed['Filename'] ?? parsed['filename'];
            if (filename != null) {
              return '${AppConfig.baseUrl}Inbox/DownloadFile/$filename';
            }
          }
        }
        
        // If it's already a URL, validate it
        if (fileData.startsWith('http://') || fileData.startsWith('https://')) {
          return fileData;
        }
        
        // If it's just a filename, construct URL
        if (!fileData.contains('://') && !fileData.startsWith('file:///')) {
          return '${AppConfig.baseUrl}Inbox/DownloadFile/$fileData';
        }
        
        return null;
      } catch (e) {
        print('Error parsing file data: $e');
        return null;
      }
    }
    return null;
  }

  Widget _buildAckIcon() {
    IconData icon;
    Color color;

    switch (message.ack) {
      case 1: // Pending
        icon = Icons.access_time;
        color = AppTheme.textSecondary;
        break;
      case 2: // Sent
        icon = Icons.check;
        color = AppTheme.textSecondary;
        break;
      case 3: // Delivered
        icon = Icons.done_all;
        color = AppTheme.textSecondary;
        break;
      case 4: // Failed
        icon = Icons.error_outline;
        color = AppTheme.errorColor;
        break;
      case 5: // Read
        icon = Icons.done_all;
        color = AppTheme.primaryColor;
        break;
      default:
        icon = Icons.access_time;
        color = AppTheme.textSecondary;
    }

    return Icon(
      icon,
      size: 16,
      color: color,
    );
  }

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.errorColor),
              title: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}