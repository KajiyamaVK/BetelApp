// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Lesson _$LessonFromJson(Map<String, dynamic> json) => Lesson(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  imageUrl: json['imageUrl'] as String,
  content: json['content'] as String,
  scriptureReference: json['scriptureReference'] as String,
  pdfUrl: json['pdfUrl'] as String?,
  song: json['song'] == null
      ? null
      : Song.fromJson(json['song'] as Map<String, dynamic>),
  flashcards: (json['flashcards'] as List<dynamic>)
      .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LessonToJson(Lesson instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'imageUrl': instance.imageUrl,
  'content': instance.content,
  'scriptureReference': instance.scriptureReference,
  'pdfUrl': instance.pdfUrl,
  'song': instance.song,
  'flashcards': instance.flashcards,
};
