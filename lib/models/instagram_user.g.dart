// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instagram_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InstagramUser _$InstagramUserFromJson(Map<String, dynamic> json) =>
    InstagramUser(
      id: (json['id'] as num?)?.toInt(),
      username: json['username'] as String,
      fullName: json['fullName'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      isPrivate: json['isPrivate'] as bool? ?? false,
      isBusiness: json['isBusiness'] as bool? ?? false,
      externalUrl: json['externalUrl'] as String?,
      followersCount: (json['followersCount'] as num?)?.toInt(),
      followingCount: (json['followingCount'] as num?)?.toInt(),
      postsCount: (json['postsCount'] as num?)?.toInt(),
      biography: json['biography'] as String?,
      followedAt: json['followedAt'] == null
          ? null
          : DateTime.parse(json['followedAt'] as String),
      followingAt: json['followingAt'] == null
          ? null
          : DateTime.parse(json['followingAt'] as String),
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$InstagramUserToJson(InstagramUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'fullName': instance.fullName,
      'profilePictureUrl': instance.profilePictureUrl,
      'isVerified': instance.isVerified,
      'isPrivate': instance.isPrivate,
      'isBusiness': instance.isBusiness,
      'externalUrl': instance.externalUrl,
      'followersCount': instance.followersCount,
      'followingCount': instance.followingCount,
      'postsCount': instance.postsCount,
      'biography': instance.biography,
      'followedAt': instance.followedAt?.toIso8601String(),
      'followingAt': instance.followingAt?.toIso8601String(),
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
