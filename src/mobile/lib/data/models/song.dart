import 'package:json_annotation/json_annotation.dart';

part 'song.g.dart';

@JsonSerializable()
class Song {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final int durationIds; // Duration in seconds

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    required this.durationIds,
  });

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
  Map<String, dynamic> toJson() => _$SongToJson(this);
}
