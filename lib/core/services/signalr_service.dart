import 'dart:async';
import 'dart:convert';
import 'package:signalr_netcore/signalr_client.dart';
import '../app_config.dart';
import '../models/chat_models.dart';
import 'storage_service.dart';

class SignalRService {
  static HubConnection? _connection;
  static final StreamController<Room> _roomUpdateController = StreamController<Room>.broadcast();
  static final StreamController<ChatMessage> _messageController = StreamController<ChatMessage>.broadcast();
  static final StreamController<Map<String, dynamic>> _ackController = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<String> _connectionStatusController = StreamController<String>.broadcast();

  // Streams
  static Stream<Room> get roomUpdates => _roomUpdateController.stream;
  static Stream<ChatMessage> get messages => _messageController.stream;
  static Stream<Map<String, dynamic>> get messageAcks => _ackController.stream;
  static Stream<String> get connectionStatus => _connectionStatusController.stream;

  static Future<void> init() async {
    final token = StorageService.getToken();
    if (token == null) return;

    // Dispose existing connection if any
    if (_connection != null) {
      try {
        await _connection!.stop();
      } catch (e) {
        print('Error stopping existing connection: $e');
      }
    }

    _connection = HubConnectionBuilder()
        .withUrl(AppConfig.signalRUrl)
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
        .build();

    // Setup event handlers
    _setupEventHandlers();

    try {
      await _connection!.start()!.timeout(const Duration(seconds: 10));
      _connectionStatusController.add('connected');
      await _subscribeUser();
      print('SignalR connected successfully');
    } catch (e) {
      _connectionStatusController.add('disconnected');
      print('SignalR connection failed: $e');
      // Attempt to reconnect after a delay
      _attemptReconnect();
    }
  }

  static void _setupEventHandlers() {
    // Connection closed
    _connection!.onclose(({error}) {
      _connectionStatusController.add('disconnected');
      print('SignalR connection closed: $error');
      _attemptReconnect();
    });

    // Receive room updates (Supervisor)
    _connection!.on('TerimaSubSpv', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 2) {
        final roomData = arguments[1] as String;
        final room = Room.fromJson(jsonDecode(roomData));
        _roomUpdateController.add(room);
      }
    });

    // Receive room updates (Agent)
    _connection!.on('TerimaSubAgent', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 2) {
        final roomData = arguments[1] as String;
        final room = Room.fromJson(jsonDecode(roomData));
        _roomUpdateController.add(room);
      }
    });

    // Receive new messages
    _connection!.on('TerimaPesan', (List<Object?>? arguments) {
      print('Received TerimaPesan event: $arguments');
      if (arguments != null && arguments.length >= 2) {
        try {
          final messageData = arguments[1] as String;
          print('Raw message data: $messageData');
          final parsedData = jsonDecode(messageData);
          print('Parsed message data: $parsedData');
          final message = ChatMessage.fromJson(parsedData);
          print('Created message object: ${message.id}, ${message.message}');
          _messageController.add(message);
        } catch (e) {
          print('Error parsing received message: $e');
        }
      } else {
        print('Invalid TerimaPesan arguments: $arguments');
      }
    });

    // Receive message acknowledgments
    _connection!.on('TerimaAck', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 3) {
        final roomId = arguments[0] as String;
        final messageId = arguments[1] as String;
        final status = arguments[2] as int;
        final error = arguments.length > 3 ? arguments[3] as String? : null;
        
        _ackController.add({
          'roomId': roomId,
          'messageId': messageId,
          'status': status,
          'error': error,
        });
      }
    });

    // Receive new room notifications
    _connection!.on('TerimaRoomBaru', (List<Object?>? arguments) {
     print('Received TerimaRoomBaru event: $arguments');
      if (arguments != null && arguments.length >= 2) {
       try {
         final roomData = arguments[1] as String;
         final room = Room.fromJson(jsonDecode(roomData));
         _roomUpdateController.add(room);
       } catch (e) {
         print('Error parsing new room: $e');
       }
      }
    });

   // Add more event listeners for debugging
   _connection!.on('KirimPesan', (List<Object?>? arguments) {
     print('Received KirimPesan event: $arguments');
   });

   _connection!.on('MessageSent', (List<Object?>? arguments) {
     print('Received MessageSent event: $arguments');
   });

   // Listen to all events for debugging
   _connection!.onreconnected(({connectionId}) {
     print('SignalR reconnected with ID: $connectionId');
     _connectionStatusController.add('connected');
   });

   _connection!.onreconnecting(({error}) {
     print('SignalR reconnecting: $error');
     _connectionStatusController.add('reconnecting');
   });
  }

  static Future<void> _subscribeUser() async {
    if (_connection == null || _connection!.state != HubConnectionState.Connected) {
      print('SignalR not connected, cannot subscribe user');
      return;
    }
    
    final userData = StorageService.getUserData();
    if (userData == null) return;

    try {
      final userId = userData['UserId']?.toString() ?? '1';
      final tenantId = userData['TenantId']?.toString() ?? '1';
      
      print('Subscribing user - UserId: $userId, TenantId: $tenantId');
      
      // Try both subscription methods to ensure compatibility
      await _connection!.invoke('SubscribeUserAgent', args: [userId, tenantId]);
      print('Subscribed as agent successfully');
      
      // Also try supervisor subscription as fallback
      try {
        await _connection!.invoke('SubscribeUserSpv', args: [tenantId]);
        print('Also subscribed as supervisor');
      } catch (e) {
        print('Supervisor subscription failed (this is normal): $e');
      }
    } catch (e) {
      print('Failed to subscribe user: $e');
    }
  }

  static Future<void> joinConversation(String roomId, String? previousRoomId) async {
    if (_connection == null || _connection!.state != HubConnectionState.Connected) {
      print('SignalR not connected, cannot join conversation');
      return;
    }
    
    try {
      await _connection!.invoke('JoinConversation', args: [roomId, previousRoomId ?? '']);
    } catch (e) {
      print('Failed to join conversation: $e');
    }
  }

  static Future<void> leaveConversation(String roomId) async {
    if (_connection == null || _connection!.state != HubConnectionState.Connected) {
      print('SignalR not connected, cannot leave conversation');
      return;
    }
    
    try {
      await _connection!.invoke('LeaveConversation', args: [roomId]);
    } catch (e) {
      print('Failed to leave conversation: $e');
    }
  }

  static Future<bool> sendMessage(Map<String, dynamic> messageData) async {
    try {
      // Ensure connection before sending
      await ensureConnection();
      
      // Clean and validate message data
      final cleanedData = _cleanMessageData(messageData);
      print('Sending message data: ${jsonEncode(cleanedData)}');
      
      await _connection!.invoke('KirimPesan', args: [jsonEncode(cleanedData)]).timeout(
        const Duration(seconds: 10),
      );
      print('Message sent successfully via SignalR');
      return true;
    } catch (e) {
      print('Failed to send message via SignalR: $e');
      return false;
    }
  }

  static Map<String, dynamic> _cleanMessageData(Map<String, dynamic> data) {
    // Ensure we have the correct structure for SignalR
    if (data.containsKey('Room') && data.containsKey('Msg')) {
      // Already in correct format, just clean it
      final cleaned = Map<String, dynamic>.from(data);
      
      // Ensure Room data is properly formatted
      if (cleaned['Room'] is Map<String, dynamic>) {
        final room = Map<String, dynamic>.from(cleaned['Room']);
        // Ensure proper data types
        room['IdLink'] = room['IdLink']?.toString();
        room['IdGroup'] = room['IdGroup']?.toString();
        room['IdAccount'] = int.tryParse(room['IdAccount']?.toString() ?? '1') ?? 1;
        room['IdRoom'] = room['IdRoom']?.toString();
        cleaned['Room'] = room;
      }
      
      // Ensure Msg data is properly formatted
      if (cleaned['Msg'] is Map<String, dynamic>) {
        final msg = Map<String, dynamic>.from(cleaned['Msg']);
        msg['Type'] = msg['Type']?.toString() ?? '1';
        msg['Msg'] = msg['Msg']?.toString() ?? '';
        msg['File'] = msg['File']?.toString() ?? '';
        msg['Files'] = msg['Files']?.toString() ?? '';
        if (msg['ReplyId'] != null) {
          msg['ReplyId'] = msg['ReplyId'].toString();
        }
        cleaned['Msg'] = msg;
      }
      
      return cleaned;
    }
    
    // Convert flat structure to Room + Msg structure
    return {
      'Room': {
        'IdLink': data['IdLink']?.toString() ?? data['LinkId']?.toString(),
        'IdGroup': data['IdGroup']?.toString() ?? data['GroupId']?.toString(),
        'IdAccount': int.tryParse(data['IdAccount']?.toString() ?? '1') ?? 1,
        'IdRoom': data['IdRoom']?.toString() ?? data['RoomId']?.toString(),
      },
      'Msg': {
        'Type': data['Type']?.toString() ?? '1',
        'Msg': data['Msg']?.toString() ?? '',
        'File': data['File']?.toString() ?? '',
        'Files': data['Files']?.toString() ?? '',
        if (data['ReplyId'] != null) 'ReplyId': data['ReplyId'].toString(),
      },
    };
  }

  static Future<void> markAsResolved(String roomId) async {
    if (_connection == null || _connection!.state != HubConnectionState.Connected) {
      print('SignalR not connected, cannot mark as resolved');
      return;
    }
    
    try {
      await _connection!.invoke('MarkResolved', args: [roomId]);
    } catch (e) {
      print('Failed to mark as resolved: $e');
    }
  }

  static Future<void> subscribe(List<String> roomIds) async {
    if (_connection == null || _connection!.state != HubConnectionState.Connected) {
      print('SignalR not connected, cannot subscribe');
      return;
    }
    
    try {
      await _connection!.invoke('Subscribe', args: [roomIds]);
    } catch (e) {
      print('Failed to subscribe to rooms: $e');
    }
  }

  static void _attemptReconnect() {
    Timer(const Duration(seconds: 5), () async {
      try {
        if (_connection != null && _connection!.state != HubConnectionState.Connected) {
          await _connection!.start();
          _connectionStatusController.add('connected');
          await _subscribeUser();
          print('SignalR reconnected successfully');
        }
      } catch (e) {
        print('Reconnection attempt failed: $e');
        // Try again after another delay
        Timer(const Duration(seconds: 10), () {
          _attemptReconnect();
        });
      }
    });
  }

  static Future<void> ensureConnection() async {
    final maxRetries = 3;
    var retryCount = 0;
    
    while ((_connection == null || _connection!.state != HubConnectionState.Connected) && retryCount < maxRetries) {
      print('SignalR not connected, attempting to reconnect...');
      try {
        if (_connection == null) {
          await init();
        } else {
          await _connection!.start()!.timeout(const Duration(seconds: 10));
          _connectionStatusController.add('connected');
          await _subscribeUser();
        }
        
        // If we reach here, connection is successful
        print('SignalR connection ensured successfully');
        return;
      } catch (e) {
        retryCount++;
        print('Failed to ensure SignalR connection: $e');
        _connectionStatusController.add('disconnected');
        
        if (retryCount < maxRetries) {
          print('Retrying connection... ($retryCount/$maxRetries)');
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    }
    
    if (_connection == null || _connection!.state != HubConnectionState.Connected) {
      throw Exception('SignalR connection failed after $maxRetries attempts');
    }
  }

  static void dispose() {
    _connection?.stop();
    _roomUpdateController.close();
    _messageController.close();
    _ackController.close();
    _connectionStatusController.close();
  }

  static bool get isConnected => _connection?.state == HubConnectionState.Connected;
}