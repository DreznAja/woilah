import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/models/chat_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/app_config.dart';

class RoomListWidget extends ConsumerWidget {
  final List<Room> rooms;
  final bool isLoading;
  final String? selectedRoomId;
  final Function(Room)? onRoomTap;

  const RoomListWidget({
    super.key,
    required this.rooms,
    required this.isLoading,
    this.selectedRoomId,
    this.onRoomTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading && rooms.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (rooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: AppTheme.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No conversations found',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        final isSelected = room.id == selectedRoomId;
        
        return _RoomListItem(
          room: room,
          isSelected: isSelected,
          onTap: () {
            onRoomTap?.call(room);
          },
        );
      },
    );
  }
}

class _RoomListItem extends StatelessWidget {
  final Room room;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoomListItem({
    required this.room,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
      child: ListTile(
        onTap: onTap,
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: _isValidImageUrl(room.contactImage ?? room.linkImage)
                  ? NetworkImage(room.contactImage ?? room.linkImage!)
                  : null,
              backgroundColor: AppTheme.neutralLight,
              child: !_isValidImageUrl(room.contactImage ?? room.linkImage)
                  ? Icon(
                      room.isGroup ? Icons.group : Icons.person,
                      color: AppTheme.textSecondary,
                    )
                  : null,
            ),
            
            // Channel indicator
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: _getChannelIcon(room.channelId),
              ),
            ),
          ],
        ),
        
        title: Row(
          children: [
            Expanded(
              child: Text(
                room.name,
                style: TextStyle(
                  fontWeight: room.unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (room.isPinned)
              const Icon(
                Icons.push_pin,
                size: 16,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
        
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            
            Text(
              room.lastMessage ?? 'No messages',
              style: TextStyle(
                color: room.unreadCount > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: room.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            Row(
              children: [
                Text(
                  room.channelName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                if (room.lastMessageTime != null)
                  Text(
                    timeago.format(room.lastMessageTime!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 4),
            
            Row(
              children: [
                _getStatusChip(room.status),
                const Spacer(),
                if (room.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      room.unreadCount > 99 ? '99+' : room.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        isThreeLine: true,
      ),
    );
  }

  Widget _getChannelIcon(int channelId) {
    Color color;
    IconData icon;

    switch (channelId) {
      case 1: // WhatsApp
      case 1557:
        color = const Color(0xFF25D366);
        icon = Icons.chat;
        break;
      case 2: // Telegram
        color = const Color(0xFF0088CC);
        icon = Icons.send;
        break;
      case 3: // Instagram
        color = const Color(0xFFE4405F);
        icon = Icons.camera_alt;
        break;
      case 4: // Messenger
        color = const Color(0xFF0084FF);
        icon = Icons.messenger;
        break;
      case 19: // Email
        color = const Color(0xFFEA4335);
        icon = Icons.email;
        break;
      default:
        color = AppTheme.textSecondary;
        icon = Icons.chat_bubble;
    }

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 8,
        color: Colors.white,
      ),
    );
  }

  Widget _getStatusChip(int status) {
    String text;
    Color color;

    switch (status) {
      case 1:
        text = 'Unassigned';
        color = AppTheme.errorColor;
        break;
      case 2:
        text = 'Assigned';
        color = AppTheme.primaryColor;
        break;
      case 3:
        text = 'Resolved';
        color = AppTheme.successColor;
        break;
      default:
        text = 'Unknown';
        color = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file:///')) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }
}