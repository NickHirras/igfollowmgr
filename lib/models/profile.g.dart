// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
  id: (json['id'] as num?)?.toInt(),
  username: json['username'] as String,
  displayName: json['displayName'] as String?,
  profilePictureUrl: json['profilePictureUrl'] as String?,
  bio: json['bio'] as String?,
  followersCount: (json['followersCount'] as num?)?.toInt(),
  followingCount: (json['followingCount'] as num?)?.toInt(),
  postsCount: (json['postsCount'] as num?)?.toInt(),
  isVerified: json['isVerified'] as bool? ?? false,
  isPrivate: json['isPrivate'] as bool? ?? false,
  lastSync: json['lastSync'] == null
      ? null
      : DateTime.parse(json['lastSync'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'displayName': instance.displayName,
  'profilePictureUrl': instance.profilePictureUrl,
  'bio': instance.bio,
  'followersCount': instance.followersCount,
  'followingCount': instance.followingCount,
  'postsCount': instance.postsCount,
  'isVerified': instance.isVerified,
  'isPrivate': instance.isPrivate,
  'lastSync': instance.lastSync?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
