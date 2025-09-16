import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/chat_models.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/message_bubble_widget.dart';
import '../../widgets/chat_input_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Room room;

  const ChatScreen({
    super.key,
    required this.room,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  ChatMessage? _replyingTo;
  bool _isNearTop = false;

  @override
  void initState() {
    super.initState();
    
    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
    
    // Select the room and load messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatProvider.notifier).selectRoom(widget.room);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      
      // Check if user is near the top (within 200 pixels)
      _isNearTop = currentScroll <= 200;
      
      // Load more messages when user scrolls to top
      if (currentScroll <= 100 && !ref.read(chatProvider).isLoadingMore) {
        ref.read(chatProvider.notifier).loadMoreMessages();
      }
    }
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only scroll to bottom when new messages arrive and user is not viewing old messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isNearTop) {
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleReply(ChatMessage message) {
    setState(() {
      _replyingTo = message;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    
    // Listen for errors and show them
    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ref.read(chatProvider.notifier).clearError();
              },
            ),
          ),
        );
      }
    });
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _isValidImageUrl(widget.room.contactImage ?? widget.room.linkImage)
                  ? NetworkImage(widget.room.contactImage ?? widget.room.linkImage!)
                  : null,
              backgroundColor: AppTheme.neutralLight,
              child: !_isValidImageUrl(widget.room.contactImage ?? widget.room.linkImage)
                  ? Icon(
                      widget.room.isGroup ? Icons.group : Icons.person,
                      color: AppTheme.textSecondary,
                      size: 20,
                    )
                  : null,
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  Row(
                    children: [
                      _getChannelIcon(widget.room.channelId),
                      const SizedBox(width: 6),
                      Text(
                        widget.room.channelName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'resolve':
                  _handleResolve();
                  break;
                case 'archive':
                  _handleArchive();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'resolve',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Mark as Resolved'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Archive'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: AppTheme.textSecondary,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              'Start the conversation!',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Load more indicator at top
                          if (!chatState.hasMoreMessages)
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'No more messages',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () async {
                                if (chatState.hasMoreMessages) {
                                  await ref.read(chatProvider.notifier).loadMoreMessages();
                                }
                              },
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: chatState.messages.length + (chatState.isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // Show loading indicator at the top when loading more
                                  if (index == 0 && chatState.isLoadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  
                                  // Adjust index if loading indicator is shown
                                  final messageIndex = chatState.isLoadingMore ? index - 1 : index;
                                  final message = chatState.messages[messageIndex];
                                  final previousMessage = messageIndex > 0 ? chatState.messages[messageIndex - 1] : null;
                                  final showSenderInfo = previousMessage == null || 
                                      previousMessage.agentId != message.agentId ||
                                      message.timestamp.difference(previousMessage.timestamp).inMinutes > 5;
                                  
                                  return MessageBubbleWidget(
                                    message: message,
                                    showSenderInfo: showSenderInfo,
                                    onReply: () => _handleReply(message),
                                    onDelete: () => _handleDelete(message),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
          
          // Reply preview
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.neutralLight,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: AppTheme.primaryColor, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Replying to',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          _replyingTo!.message ?? 'Media message',
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelReply,
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          
          // Input
          ChatInputWidget(
            onSendText: (text) => _handleSendText(text),
            onSendMedia: (type, data, filename) => _handleSendMedia(type, data, filename),
            replyingTo: _replyingTo,
          ),
        ],
      ),
    );
  }

  Widget _getChannelIcon(int channelId) {
    Color color;
    IconData icon;

    switch (channelId) {
      case 1:
        color = const Color(0xFF25D366);
        icon = Icons.chat;
        break;
      case 1557:
      case 1561:
        color = const Color(0xFF25D366);
        icon = Icons.business;
        break;
      case 2:
        color = const Color(0xFF0088CC);
        icon = Icons.send;
        break;
      case 3:
        color = const Color(0xFFE4405F);
        icon = Icons.camera_alt;
        break;
      case 4:
        color = const Color(0xFF0084FF);
        icon = Icons.messenger;
        break;
      case 19:
        color = const Color(0xFFEA4335);
        icon = Icons.email;
        break;
      default:
        color = AppTheme.textSecondary;
        icon = Icons.chat_bubble;
    }

    return Icon(icon, size: 12, color: color);
  }

  void _handleSendText(String text) {
    _cancelReply(); // Clear reply after sending
  }

  void _handleSendMedia(String type, String data, String filename) {
    _cancelReply(); // Clear reply after sending
  }

  void _handleResolve() {
    // Implement resolve functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conversation marked as resolved'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _handleArchive() {
    // Implement archive functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conversation archived'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _handleDelete(ChatMessage message) {
    // Implement delete functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement actual delete logic here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message deleted'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file:///')) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }
}