class LoginRequest {
  final String username;
  final String password;

  LoginRequest({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

class LoginResponse {
  final String? token;
  final String? error;
  final bool isSuccess;

  LoginResponse({
    this.token,
    this.error,
    required this.isSuccess,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'],
      error: json['error'],
      isSuccess: json['token'] != null,
    );
  }
}

class UserData {
  final int userId;
  final String displayName;
  final String? userImage;
  final int tenantId;
  final List<ChannelData> channels;

  UserData({
    required this.userId,
    required this.displayName,
    this.userImage,
    required this.tenantId,
    required this.channels,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      userId: json['UserId'] ?? 0,
      displayName: json['DisplayName'] ?? '',
      userImage: json['UserImage'],
      tenantId: json['TenantId'] ?? 0,
      channels: (json['Channels'] as List?)
          ?.map((c) => ChannelData.fromJson(c))
          .toList() ?? [],
    );
  }
}

class ChannelData {
  final int data;
  final String level;

  ChannelData({
    required this.data,
    required this.level,
  });

  factory ChannelData.fromJson(Map<String, dynamic> json) {
    return ChannelData(
      data: json['Data'] ?? 0,
      level: json['Level'] ?? '',
    );
  }
}