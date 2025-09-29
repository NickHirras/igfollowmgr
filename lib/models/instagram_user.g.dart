// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instagram_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InstagramUser _$InstagramUserFromJson(Map<String, dynamic> json) =>
    InstagramUser(
      id: InstagramUser._idFromJson(json['pk']),
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      profilePictureUrl: json['profile_pic_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isPrivate: json['is_private'] as bool? ?? false,
      isBusiness: json['is_business_account'] as bool? ?? false,
      externalUrl: json['external_url'] as String?,
      followersCount: InstagramUser._extractCount(json['edge_followed_by']),
      followingCount: InstagramUser._extractCount(json['edge_follow']),
      postsCount: InstagramUser._extractCount(
        json['edge_owner_to_timeline_media'],
      ),
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
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$InstagramUserToJson(InstagramUser instance) =>
    <String, dynamic>{
      'pk': instance.id,
      'username': instance.username,
      'full_name': instance.fullName,
      'profile_pic_url': instance.profilePictureUrl,
      'is_verified': instance.isVerified,
      'is_private': instance.isPrivate,
      'is_business_account': instance.isBusiness,
      'external_url': instance.externalUrl,
      'edge_followed_by': instance.followersCount,
      'edge_follow': instance.followingCount,
      'edge_owner_to_timeline_media': instance.postsCount,
      'biography': instance.biography,
      'followedAt': instance.followedAt?.toIso8601String(),
      'followingAt': instance.followingAt?.toIso8601String(),
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
