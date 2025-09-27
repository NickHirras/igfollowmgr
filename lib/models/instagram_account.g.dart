// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instagram_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InstagramAccount _$InstagramAccountFromJson(Map<String, dynamic> json) =>
    InstagramAccount(
      id: (json['id'] as num?)?.toInt(),
      username: json['username'] as String,
      password: json['password'] as String?,
      sessionId: json['sessionId'] as String?,
      csrfToken: json['csrfToken'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      lastLogin: json['lastLogin'] == null
          ? null
          : DateTime.parse(json['lastLogin'] as String),
      lastSync: json['lastSync'] == null
          ? null
          : DateTime.parse(json['lastSync'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$InstagramAccountToJson(InstagramAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'password': instance.password,
      'sessionId': instance.sessionId,
      'csrfToken': instance.csrfToken,
      'isActive': instance.isActive,
      'lastLogin': instance.lastLogin?.toIso8601String(),
      'lastSync': instance.lastSync?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
