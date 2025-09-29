// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'followers_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FollowersResponse _$FollowersResponseFromJson(Map<String, dynamic> json) =>
    FollowersResponse(
      users: (json['users'] as List<dynamic>)
          .map((e) => InstagramUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextMaxId: json['next_max_id'] as String?,
    );

Map<String, dynamic> _$FollowersResponseToJson(FollowersResponse instance) =>
    <String, dynamic>{
      'users': instance.users,
      'next_max_id': instance.nextMaxId,
    };
