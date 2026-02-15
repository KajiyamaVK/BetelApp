import 'package:json_annotation/json_annotation.dart';

part 'flashcard.g.dart';

@JsonSerializable()
class Flashcard {
  final String id;
  final String question;
  final String answer;

  Flashcard({
    required this.id,
    required this.question,
    required this.answer,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) => _$FlashcardFromJson(json);
  Map<String, dynamic> toJson() => _$FlashcardToJson(this);
}

enum FlashcardStatus {
  newCard,
  review,
  learned,
}

class FlashcardWithStatus {
  final Flashcard flashcard;
  final FlashcardStatus status;

  FlashcardWithStatus({
    required this.flashcard,
    required this.status,
  });
}
