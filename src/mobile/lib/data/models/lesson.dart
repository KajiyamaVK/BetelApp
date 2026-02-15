import 'package:json_annotation/json_annotation.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:betelsas/data/models/flashcard.dart';

part 'lesson.g.dart';

@JsonSerializable()
class Lesson {
  final int id;
  final String title;

  final String imageUrl;
  final String content;
  final String scriptureReference;
  final String? pdfUrl;
  final Song? song;
  final List<Flashcard> flashcards;

  Lesson({
    required this.id,
    required this.title,

    required this.imageUrl,
    required this.content,
    required this.scriptureReference,
    this.pdfUrl,
    this.song,
    required this.flashcards,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => _$LessonFromJson(json);
  Map<String, dynamic> toJson() => _$LessonToJson(this);
}
