import 'package:json_annotation/json_annotation.dart';

part 'instagram_account.g.dart';

@JsonSerializable()
class InstagramAccount {
  final int? id;
  final String username;
  final String? password; // Encrypted
  final String? sessionId;
  final String? csrfToken;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime? lastSync;
  final DateTime createdAt;
  final DateTime updatedAt;

  InstagramAccount({
    this.id,
    required this.username,
    this.password,
    this.sessionId,
    this.csrfToken,
    this.isActive = true,
    this.lastLogin,
    this.lastSync,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InstagramAccount.fromJson(Map<String, dynamic> json) => _$InstagramAccountFromJson(json);
  Map<String, dynamic> toJson() => _$InstagramAccountToJson(this);

  InstagramAccount copyWith({
    int? id,
    String? username,
    String? password,
    String? sessionId,
    String? csrfToken,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? lastSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InstagramAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      sessionId: sessionId ?? this.sessionId,
      csrfToken: csrfToken ?? this.csrfToken,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      lastSync: lastSync ?? this.lastSync,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
