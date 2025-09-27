import 'package:json_annotation/json_annotation.dart';

part 'instagram_user.g.dart';

@JsonSerializable()
class InstagramUser {
  final int? id;
  final String username;
  final String? fullName;
  final String? profilePictureUrl;
  final bool isVerified;
  final bool isPrivate;
  final bool isBusiness;
  final String? externalUrl;
  final int? followersCount;
  final int? followingCount;
  final int? postsCount;
  final String? biography;
  final DateTime? followedAt; // When they started following me
  final DateTime? followingAt; // When I started following them
  final DateTime? lastSeen;
  final DateTime createdAt;
  final DateTime updatedAt;

  InstagramUser({
    this.id,
    required this.username,
    this.fullName,
    this.profilePictureUrl,
    this.isVerified = false,
    this.isPrivate = false,
    this.isBusiness = false,
    this.externalUrl,
    this.followersCount,
    this.followingCount,
    this.postsCount,
    this.biography,
    this.followedAt,
    this.followingAt,
    this.lastSeen,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InstagramUser.fromJson(Map<String, dynamic> json) => _$InstagramUserFromJson(json);
  Map<String, dynamic> toJson() => _$InstagramUserToJson(this);

  InstagramUser copyWith({
    int? id,
    String? username,
    String? fullName,
    String? profilePictureUrl,
    bool? isVerified,
    bool? isPrivate,
    bool? isBusiness,
    String? externalUrl,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    String? biography,
    DateTime? followedAt,
    DateTime? followingAt,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InstagramUser(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      isVerified: isVerified ?? this.isVerified,
      isPrivate: isPrivate ?? this.isPrivate,
      isBusiness: isBusiness ?? this.isBusiness,
      externalUrl: externalUrl ?? this.externalUrl,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      biography: biography ?? this.biography,
      followedAt: followedAt ?? this.followedAt,
      followingAt: followingAt ?? this.followingAt,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
