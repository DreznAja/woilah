import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/theme/app_theme.dart';

class ConnectionStatusWidget extends ConsumerWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: chatState.connectionStatus == 'connected' 
                ? AppTheme.successColor 
                : AppTheme.errorColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          chatState.connectionStatus == 'connected' ? 'Online' : 'Connecting...',
          style: TextStyle(
            fontSize: 12,
            color: chatState.connectionStatus == 'connected' 
                ? AppTheme.successColor 
                : AppTheme.errorColor,
          ),
        ),
      ],
    );
  }
}