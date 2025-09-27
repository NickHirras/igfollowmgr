import 'package:json_annotation/json_annotation.dart';

part 'profile.g.dart';

@JsonSerializable()
class Profile {
  final int? id;
  final String username;
  final String? displayName;
  final String? profilePictureUrl;
  final String? bio;
  final int? followersCount;
  final int? followingCount;
  final int? postsCount;
  final bool isVerified;
  final bool isPrivate;
  final DateTime? lastSync;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    this.id,
    required this.username,
    this.displayName,
    this.profilePictureUrl,
    this.bio,
    this.followersCount,
    this.followingCount,
    this.postsCount,
    this.isVerified = false,
    this.isPrivate = false,
    this.lastSync,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileToJson(this);

  Profile copyWith({
    int? id,
    String? username,
    String? displayName,
    String? profilePictureUrl,
    String? bio,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    bool? isVerified,
    bool? isPrivate,
    DateTime? lastSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      isVerified: isVerified ?? this.isVerified,
      isPrivate: isPrivate ?? this.isPrivate,
      lastSync: lastSync ?? this.lastSync,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
