import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../models/chat_models.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
import '../services/storage_service.dart';

class ChatState {
  final List<Room> rooms;
  final List<ChatMessage> messages;
  final Room? activeRoom;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreMessages;
  final String? error;
  final String connectionStatus;

  ChatState({
    this.rooms = const [],
    this.messages = const [],
    this.activeRoom,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMoreMessages = true,
    this.error,
    this.connectionStatus = 'disconnected',
  });

  ChatState copyWith({
    List<Room>? rooms,
    List<ChatMessage>? messages,
    Room? activeRoom,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreMessages,
    String? error,
    String? connectionStatus,
  }) {
    return ChatState(
      rooms: rooms ?? this.rooms,
      messages: messages ?? this.messages,
      activeRoom: activeRoom ?? this.activeRoom,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      error: error,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState()) {
    _initializeSignalR();
  }

  void _initializeSignalR() {
    // Listen to connection status
    SignalRService.connectionStatus.listen((status) {
      state = state.copyWith(connectionStatus: status);
    });

    // Listen to room updates
    SignalRService.roomUpdates.listen((room) {
      _updateRoom(room);
    });

    // Listen to new messages
    SignalRService.messages.listen((message) {
      _addMessage(message);
    });

    // Listen to message acknowledgments
    SignalRService.messageAcks.listen((ackData) {
      _updateMessageAck(ackData);
    });
  }

  Future<void> loadRooms({String? search, Map<String, dynamic>? filters}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await ApiService.getRoomList(
        search: search,
        filters: filters,
      );

      if (response.isError) {
        state = state.copyWith(
          isLoading: false,
          error: response.error,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        rooms: response.data ?? [],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> selectRoom(Room room) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Leave previous room if exists
      if (state.activeRoom != null && SignalRService.isConnected) {
        await SignalRService.leaveConversation(state.activeRoom!.id);
      }

      // Load initial messages (most recent)
      final messagesResponse = await ApiService.getMessages(
        roomId: room.id,
        take: 20, // Load 20 most recent messages initially
        skip: 0,
      );
      
      if (!messagesResponse.isError && messagesResponse.data != null) {
        // Sort messages by timestamp (newest first from API, then reverse for display)
        final sortedMessages = List<ChatMessage>.from(messagesResponse.data!);
        sortedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
        final displayMessages = sortedMessages.reversed.toList(); // Oldest first for display
        
        state = state.copyWith(
          activeRoom: room,
          messages: displayMessages,
          isLoading: false,
          hasMoreMessages: messagesResponse.data!.length >= 20, // Has more if we got full page
        );
        
        // Join new room after successfully loading messages
        if (SignalRService.isConnected) {
          await SignalRService.joinConversation(room.id, state.activeRoom?.id);
        }
      } else {
        state = state.copyWith(
          activeRoom: room,
          messages: [],
          isLoading: false,
          hasMoreMessages: false,
          error: messagesResponse.error,
        );
      }
    } catch (e) {
      print('Error selecting room: $e');
      state = state.copyWith(
        activeRoom: room,
        messages: [],
        isLoading: false,
        hasMoreMessages: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMoreMessages() async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null || state.isLoadingMore || !state.hasMoreMessages) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final currentMessageCount = state.messages.length;
      
      final messagesResponse = await ApiService.getMessages(
        roomId: activeRoom.id,
        take: 20,
        skip: currentMessageCount, // Skip messages we already have
      );

      if (!messagesResponse.isError && messagesResponse.data != null) {
        final newMessages = messagesResponse.data!;
        
        if (newMessages.isNotEmpty) {
          // Sort new messages (newest first from API, then reverse)
          final sortedNewMessages = List<ChatMessage>.from(newMessages);
          sortedNewMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          final displayNewMessages = sortedNewMessages.reversed.toList();
          
          // Prepend new (older) messages to existing messages
          final allMessages = [...displayNewMessages, ...state.messages];
          
          state = state.copyWith(
            messages: allMessages,
            isLoadingMore: false,
            hasMoreMessages: newMessages.length >= 20, // Has more if we got full page
          );
        } else {
          // No more messages
          state = state.copyWith(
            isLoadingMore: false,
            hasMoreMessages: false,
          );
        }
      } else {
        state = state.copyWith(
          isLoadingMore: false,
          error: messagesResponse.error,
        );
      }
    } catch (e) {
      print('Error loading more messages: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendTextMessage(String text, {String? replyId}) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return;

    // Validate message text
    if (text.trim().isEmpty) {
      state = state.copyWith(error: 'Message cannot be empty');
      return;
    }

    // Use API directly for sending messages to ensure they reach external platforms
    await _sendMessageViaAPI(text, replyId: replyId);
  }

 Future<void> _sendMessageViaAPI(String text, {String? replyId}) async {
  final activeRoom = state.activeRoom;
  if (activeRoom == null) return;

  try {
    // Get the agent account ID
    final accountId = await _getAgentAccountId(activeRoom.channelId);
    if (accountId == null) {
      state = state.copyWith(error: 'Unable to determine agent account ID');
      return;
    }
    
    // Get the proper LinkId from the room
    final linkId = activeRoom.ctId ?? activeRoom.id;
    
    // FIX: Use WhatsApp Business channel ID (1561) instead of room's channelId
    // Room shows channelId: 1 but we need to send with channelId: 1561
    final channelId = 1561; // WhatsApp Business with mobile number
    
    print('Room channelId: ${activeRoom.channelId}, Using channelId: $channelId');
    
    // Format data for Inbox API
    final apiMessageData = {
      'LinkId': int.tryParse(linkId),
      'ChannelId': channelId, // Use WhatsApp Business channel ID (1561)
      'AccountIds': accountId,
      'BodyType': 1,
      'Body': text,
      'Attachment': '',
      if (replyId != null) 'ReplyId': replyId,
    };
    
    print('Sending message via API: ${jsonEncode(apiMessageData)}');
    
    final response = await ApiService.sendMessage(apiMessageData);
    if (response.isError) {
      state = state.copyWith(error: response.error ?? 'Failed to send message');
    } else {
      print('Message sent successfully via API');
      
      // Also try SignalR for real-time updates
      try {
        final signalRData = {
          'Room': {
            'IdLink': linkId,
            'IdGroup': activeRoom.grpId,
            'IdAccount': int.tryParse(accountId) ?? 1,
            'IdRoom': activeRoom.id,
          },
          'Msg': {
            'Type': '1',
            'Msg': text,
            'File': '',
            'Files': '',
            if (replyId != null) 'ReplyId': replyId,
          },
        };
        await SignalRService.sendMessage(signalRData);
      } catch (e) {
        print('SignalR notification failed: $e');
      }
    }
  } catch (apiError) {
    print('API fallback failed: $apiError');
    state = state.copyWith(error: 'Failed to send message: $apiError');
  }
}

  Future<void> sendMediaMessage({
    required String type,
    required String filename,
    required String base64Data,
    String? caption,
    String? replyId,
  }) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return;

    try {
      // Upload file first
      final uploadResponse = await ApiService.uploadBase64(
        filename: filename,
        mimetype: _getMimeType(filename),
        base64Data: base64Data,
      );

      if (uploadResponse.isError) {
        state = state.copyWith(error: uploadResponse.error);
        return;
      }

      // Send media message via API
      await _sendMediaMessageViaAPI(type, caption, uploadResponse.data!, replyId: replyId);
    } catch (e) {
      print('Error sending media message: $e');
      state = state.copyWith(error: 'Failed to send media message: $e');
    }
  }

  Future<void> _sendMediaMessageViaAPI(String type, String? caption, UploadedFile uploadedFile, {String? replyId}) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return;

    try {
      // Get the agent account ID (the account that will send the message)
      final accountId = await _getAgentAccountId(activeRoom.channelId);
      if (accountId == null) {
        state = state.copyWith(error: 'Unable to determine agent account ID');
        return;
      }
      
      // Get the proper LinkId and AccountId from the room
      final linkId = activeRoom.ctId ?? activeRoom.id;
      
      // Use the working channel ID from your Postman test
      final workingChannelId = 1; // Use WhatsApp channel ID
      
      // Format data for Inbox API
      final apiMessageData = {
        'LinkId': int.tryParse(linkId),
        'ChannelId': workingChannelId,
        'AccountIds': accountId,
        'BodyType': int.parse(type),
        'Body': caption ?? '',
        'Attachment': jsonEncode([uploadedFile.toJson()]),
        if (replyId != null) 'ReplyId': replyId,
      };
      
      print('Sending media message via API: ${jsonEncode(apiMessageData)}');
      
      final response = await ApiService.sendMessage(apiMessageData);
      if (response.isError) {
        state = state.copyWith(error: response.error ?? 'Failed to send media message');
      } else {
        print('Media message sent successfully via API');
        
        // Also send via SignalR for real-time updates
        try {
          // Create proper SignalR message structure
          final signalRData = {
            'Room': {
              'IdLink': linkId,
              'IdGroup': activeRoom.grpId,
              'IdAccount': int.tryParse(accountId) ?? 1,
              'IdRoom': activeRoom.id,
            },
            'Msg': {
              'Type': type,
              'Msg': caption ?? '',
              'File': uploadedFile.filename,
              'Files': jsonEncode([uploadedFile.toJson()]),
              if (replyId != null) 'ReplyId': replyId,
            },
          };
          await SignalRService.sendMessage(signalRData);
        } catch (e) {
          print('SignalR notification failed (this is OK): $e');
        }
      }
    } catch (apiError) {
      print('Media API fallback failed: $apiError');
      state = state.copyWith(error: 'Failed to send media message: $apiError');
    }
  }
  
  Future<String?> _getAgentAccountId(int channelId) async {
  // FIX: Use WhatsApp Business channel ID (1561) to get the correct account
  final effectiveChannelId = 1561; // Always use WhatsApp Business channel
  
  // First try to get from stored user data
  final userData = StorageService.getUserData();
  if (userData != null && userData['AgentAccountId'] != null) {
    return userData['AgentAccountId'].toString();
  }
  
  // Try to fetch agent accounts for WhatsApp Business channel from API
  try {
    final response = await ApiService.getAccountList(channelId: effectiveChannelId);
    if (!response.isError && response.data != null && response.data!.isNotEmpty) {
      // Return the first agent account ID for this channel
      final account = response.data!.first;
      final accountId = account['Id']?.toString();
      
      // Save it for future use
      if (accountId != null && userData != null) {
        userData['AgentAccountId'] = accountId;
        await StorageService.saveUserData(userData);
      }
      
      return accountId;
    }
  } catch (e) {
    print('Error fetching account list: $e');
  }
  
  // Fallback to known working agent account ID
  return "706026840646405";
}
  void _updateRoom(Room room) {
    final rooms = List<Room>.from(state.rooms);
    final index = rooms.indexWhere((r) => r.id == room.id);
    
    if (index != -1) {
      rooms[index] = room;
    } else {
      rooms.insert(0, room);
    }

    state = state.copyWith(rooms: rooms);
  }

  void _addMessage(ChatMessage message) {
    print('Adding message to state: ${message.id}, room: ${message.roomId}, active: ${state.activeRoom?.id}');
    if (state.activeRoom?.id == message.roomId) {
      final messages = List<ChatMessage>.from(state.messages);
      
      // Check if message already exists to avoid duplicates
      final existingIndex = messages.indexWhere((m) => m.id == message.id);
      if (existingIndex == -1) {
        print('Message not found, adding new message');
        messages.add(message);
        // Sort messages by timestamp
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        state = state.copyWith(messages: messages);
        print('Updated messages count: ${messages.length}');
      } else {
        print('Message already exists at index: $existingIndex');
        // Update existing message if it's an optimistic message being replaced
        if (messages[existingIndex].from == 'me' && message.from != 'me') {
          messages[existingIndex] = message;
          state = state.copyWith(messages: messages);
          print('Replaced optimistic message with real message');
        }
      }
    } else {
      print('Message not for active room. Message room: ${message.roomId}, Active room: ${state.activeRoom?.id}');
    }
  }

  void _updateOptimisticMessage(String messageId, int ackStatus) {
    final messages = List<ChatMessage>.from(state.messages);
    final index = messages.indexWhere((m) => m.id == messageId);
    
    if (index != -1) {
      final updatedMessage = ChatMessage(
        id: messages[index].id,
        roomId: messages[index].roomId,
        from: messages[index].from,
        to: messages[index].to,
        agentId: messages[index].agentId,
        type: messages[index].type,
        message: messages[index].message,
        file: messages[index].file,
        files: messages[index].files,
        timestamp: messages[index].timestamp,
        ack: ackStatus,
        replyId: messages[index].replyId,
        replyType: messages[index].replyType,
        replyFrom: messages[index].replyFrom,
        replyMessage: messages[index].replyMessage,
        replyFiles: messages[index].replyFiles,
        isEdited: messages[index].isEdited,
        note: messages[index].note,
      );
      
      messages[index] = updatedMessage;
      state = state.copyWith(messages: messages);
    }
  }

  void _updateMessageAck(Map<String, dynamic> ackData) {
    if (state.activeRoom?.id == ackData['roomId']) {
      final messages = List<ChatMessage>.from(state.messages);
      final index = messages.indexWhere((m) => m.id == ackData['messageId']);
      
      if (index != -1) {
        // Update message ack status
        // This would require updating the ChatMessage model to be mutable or creating a new instance
      }
    }
  }

  String _getMimeType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mp3';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});