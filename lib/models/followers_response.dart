import 'package:json_annotation/json_annotation.dart';
import 'instagram_user.dart';

part 'followers_response.g.dart';

@JsonSerializable()
class FollowersResponse {
  final List<InstagramUser> users;
  @JsonKey(name: 'next_max_id')
  final String? nextMaxId;

  FollowersResponse({required this.users, this.nextMaxId});

  factory FollowersResponse.fromJson(Map<String, dynamic> json) =>
      _$FollowersResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FollowersResponseToJson(this);
}
