import 'package:json_annotation/json_annotation.dart';

part 'instagram_user.g.dart';

@JsonSerializable()
class InstagramUser {
  @JsonKey(name: 'pk', fromJson: _idFromJson)
  final int? id;
  @JsonKey(name: 'username')
  final String username;
  @JsonKey(name: 'full_name')
  final String? fullName;
  @JsonKey(name: 'profile_pic_url')
  final String? profilePictureUrl;
  @JsonKey(name: 'is_verified')
  final bool isVerified;
  @JsonKey(name: 'is_private')
  final bool isPrivate;
  @JsonKey(name: 'is_business_account', defaultValue: false)
  final bool isBusiness;
  @JsonKey(name: 'external_url')
  final String? externalUrl;
  @JsonKey(name: 'edge_followed_by', fromJson: _extractCount)
  final int? followersCount;
  @JsonKey(name: 'edge_follow', fromJson: _extractCount)
  final int? followingCount;
  @JsonKey(name: 'edge_owner_to_timeline_media', fromJson: _extractCount)
  final int? postsCount;
  @JsonKey(name: 'biography')
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory InstagramUser.fromJson(Map<String, dynamic> json) => _$InstagramUserFromJson(json);
  Map<String, dynamic> toJson() {
    final json = _$InstagramUserToJson(this);
    // Ensure isBusiness is always included, even if it was missing from the original JSON
    json['is_business_account'] = isBusiness;
    return json;
  }

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

  static int? _idFromJson(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  static int? _extractCount(dynamic value) {
    if (value == null) return null;
    if (value is Map && value['count'] != null) {
      final count = value['count'];
      if (count is int) return count;
      if (count is String) return int.tryParse(count);
      if (count is num) return count.toInt();
      return null;
    }
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }
}
