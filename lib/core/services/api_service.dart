import 'dart:convert';
import 'package:dio/dio.dart';
import '../app_config.dart';
import '../models/auth_models.dart';
import '../models/chat_models.dart';
import 'storage_service.dart';

class ApiResponse<T> {
  final bool isError;
  final T? data;
  final String? error;
  final int statusCode;

  ApiResponse({
    required this.isError,
    this.data,
    this.error,
    this.statusCode = 200,
  });
}

class ApiService {
  static Dio? _dio;

  static Future<void> init() async {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptor for authentication
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  static Dio get dio {
    assert(_dio != null, 'ApiService not initialized');
    return _dio!;
  }

  // Authentication
  static Future<ApiResponse<String>> login(LoginRequest request) async {
    try {
      final response = await dio.post(
        AppConfig.generateTokenEndpoint,
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        if (token != null) {
          return ApiResponse(
            isError: false,
            data: token,
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['error'] ?? 'Login failed',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'Login failed with status: ${response.statusCode}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

 // Get room list
static Future<ApiResponse<List<Room>>> getRoomList({
  String? search,
  Map<String, dynamic>? filters,
  int take = 20,
  int skip = 0,
}) async {
  try {
    // Build the request data to match the backend format
    final requestData = {
      'Take': take,
      'Skip': skip,
      'Sort': ['IsPin DESC', 'TimeMsg DESC'],
      'IncludeColumns': [
        'Id', 'CtId', 'CtRealId', 'GrpId', 'CtRealNm', 'Ct', 'Grp',
        'LastMsg', 'TimeMsg', 'Uc', 'St', 'ChId', 'ChAcc', 'CtImg', 'LinkImg',
        'IsGrp', 'IsPin', 'CtIsBlock', 'IsMuteBot', 'Tags', 'Fn'
      ],
      'ColumnSelection': 1,
    };

    if (search != null && search.isNotEmpty) {
      requestData['ContainsText'] = search;
    }

    if (filters != null) {
      // Handle status filter properly
      if (filters.containsKey('St')) {
        requestData['EqualityFilter'] = {'St': filters['St']};
      } else {
        requestData['EqualityFilter'] = filters;
      }
    }

    final response = await dio.post(
      'Services/Chat/Chatrooms/List',
      data: requestData,
    );

    if (response.statusCode == 200) {
      // Safe null checking for IsError
      final isError = response.data['IsError'];
      final hasError = isError == true; // This handles null and false cases properly
      
      if (!hasError && response.data['Entities'] != null) {
        final entities = response.data['Entities'] as List;
        final rooms = entities.map((e) => Room.fromJson(e)).toList();
        
        return ApiResponse(
          isError: false,
          data: rooms,
          statusCode: response.statusCode!,
        );
      } else {
        return ApiResponse(
          isError: true,
          error: response.data['ErrorMessage'] ?? response.data['Error'] ?? 'Failed to load rooms',
          statusCode: response.statusCode!,
        );
      }
    } else {
      return ApiResponse(
        isError: true,
        error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
        statusCode: response.statusCode!,
      );
    }
  } catch (e) {
    print('Error in getRoomList: $e');
    return ApiResponse(
      isError: true,
      error: e.toString(),
      statusCode: 500,
    );
  }
}

  // Get messages for a room
static Future<ApiResponse<List<ChatMessage>>> getMessages({
  required String roomId,
  int take = 20,
  int skip = 0,
}) async {
  try {
    final requestData = {
      'Take': take,
      'Skip': skip,
      'EqualityFilter': {'RoomId': roomId},
      'Sort': ['In DESC', 'Type DESC'],
    };

    final response = await dio.post(
      'Services/Chat/Chatmessages/List',
      data: requestData,
    );

    if (response.statusCode == 200) {
      // Safe null checking for IsError
      final isError = response.data['IsError'];
      final hasError = isError == true; // This handles null and false cases properly
      
      if (!hasError && response.data['Entities'] != null) {
        final entities = response.data['Entities'] as List;
        final messages = entities.map((e) => ChatMessage.fromJson(e)).toList();
        
        return ApiResponse(
          isError: false,
          data: messages,
          statusCode: response.statusCode!,
        );
      } else {
        return ApiResponse(
          isError: true,
          error: response.data['ErrorMessage'] ?? response.data['Error'] ?? 'Failed to load messages',
          statusCode: response.statusCode!,
        );
      }
    } else {
      return ApiResponse(
        isError: true,
        error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
        statusCode: response.statusCode!,
      );
    }
  } catch (e) {
    return ApiResponse(
      isError: true,
      error: e.toString(),
      statusCode: 500,
    );
  }
}

  // Send message using Inbox API (the proper way to send messages)
  static Future<ApiResponse<String>> sendMessage(Map<String, dynamic> messageData) async {
    try {
      // Ensure proper data types for Inbox API
      final inboxData = {
        'LinkId': messageData['LinkId'] is int ? messageData['LinkId'] : int.tryParse(messageData['LinkId']?.toString() ?? '0') ?? 0,
        'ChannelId': messageData['ChannelId'] is int ? messageData['ChannelId'] : int.tryParse(messageData['ChannelId']?.toString() ?? '1') ?? 1,
        'AccountIds': messageData['AccountIds']?.toString() ?? messageData['IdAccount']?.toString() ?? '1',
        'BodyType': messageData['BodyType'] is int ? messageData['BodyType'] : int.tryParse(messageData['BodyType']?.toString() ?? messageData['Type']?.toString() ?? '1') ?? 1,
        'Body': messageData['Msg']?.toString() ?? '',
        'Attachment': messageData['Attachment']?.toString() ?? messageData['File']?.toString() ?? '',
      };

      // Ensure LinkId is not 0 (which causes the error)
      if (inboxData['LinkId'] == 0) {
        return ApiResponse(
          isError: true,
          error: 'Invalid LinkId: LinkId cannot be 0',
          statusCode: 400,
        );
      }

      print('Sending message via Inbox API: ${jsonEncode(inboxData)}');

      final response = await dio.post(
        AppConfig.inboxSendEndpoint,
        data: inboxData,
      );

      print('Inbox API response: ${response.data}');

      if (response.statusCode == 200) {
        // Handle both boolean and null cases for IsError
        final isError = response.data['IsError'];
        final hasError = isError == true; // This handles null and false cases properly
        
        if (!hasError) {
          return ApiResponse(
            isError: false,
            data: response.data['Data']?.toString() ?? 'Message sent successfully',
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['Error'] ?? response.data['ErrorMessage'] ?? 'Failed to send message',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      print('Error in sendMessage: $e');
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Upload base64 file
  static Future<ApiResponse<UploadedFile>> uploadBase64({
    required String filename,
    required String mimetype,
    required String base64Data,
  }) async {
    try {
      final requestData = {
        'filename': filename,
        'mimetype': mimetype,
        'data': base64Data,
      };

      final response = await dio.post(
        AppConfig.uploadBase64Endpoint,
        data: requestData,
      );

      if (response.statusCode == 200) {
        if (response.data['Error'] == null) {
          final data = response.data['Data'];
          final uploadedFile = UploadedFile.fromJson(data);
          
          return ApiResponse(
            isError: false,
            data: uploadedFile,
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['Error'],
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'Upload failed with status: ${response.statusCode}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Get contact list
  static Future<ApiResponse<List<Contact>>> getContactList({
    int take = 20,
    int skip = 0,
  }) async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name'],
        'ColumnSelection': 1,
        'Take': take,
        'Skip': skip,
      };

      final response = await dio.post(
        AppConfig.contactListEndpoint,
        data: requestData,
      );

      if (response.statusCode == 200 && !response.data['IsError']) {
        final entities = response.data['Entities'] as List;
        final contacts = entities.map((e) => Contact.fromJson(e)).toList();
        
        return ApiResponse(
          isError: false,
          data: contacts,
          statusCode: response.statusCode!,
        );
      } else {
        return ApiResponse(
          isError: true,
          error: response.data['ErrorMessage'] ?? 'Failed to load contacts',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Get channel list
  static Future<ApiResponse<List<Map<String, dynamic>>>> getChannelList() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Nm'],
        'ColumnSelection': 1,
      };

      final response = await dio.post(
        AppConfig.channelListEndpoint,
        data: requestData,
      );

      if (response.statusCode == 200 && !response.data['IsError']) {
        final entities = response.data['Entities'] as List;
        
        return ApiResponse(
          isError: false,
          data: entities.cast<Map<String, dynamic>>(),
          statusCode: response.statusCode!,
        );
      } else {
        return ApiResponse(
          isError: true,
          error: response.data['ErrorMessage'] ?? 'Failed to load channels',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Get account list
  static Future<ApiResponse<List<Map<String, dynamic>>>> getAccountList({
    int? channelId,
  }) async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'Channel'],
        'ColumnSelection': 1,
      };

      if (channelId != null) {
        requestData['EqualityFilter'] = {'Channel': channelId};
      }

      final response = await dio.post(
        AppConfig.accountListEndpoint,
        data: requestData,
      );

      if (response.statusCode == 200 && !response.data['IsError']) {
        final entities = response.data['Entities'] as List;
        
        return ApiResponse(
          isError: false,
          data: entities.cast<Map<String, dynamic>>(),
          statusCode: response.statusCode!,
        );
      } else {
        return ApiResponse(
          isError: true,
          error: response.data['ErrorMessage'] ?? 'Failed to load accounts',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }
}