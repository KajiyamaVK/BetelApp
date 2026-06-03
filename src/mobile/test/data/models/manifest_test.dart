import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:betelapp/data/models/manifest.dart';

const _sampleJson = '''
{
  "version": 1,
  "updated_at": "2026-05-27T12:00:00Z",
  "lessons": [
    {
      "id": 1,
      "title": "Qual o Fim principal?",
      "pdf": {"active": "lessons/1/lesson_v1.pdf", "checksum": "abc123", "history": []},
      "audio": {"active": "lessons/1/audio_v1.mp3", "ext": "mp3", "checksum": "def456", "history": []}
    },
    {
      "id": 2,
      "title": "Que regra deu Deus?",
      "pdf": {"active": "lessons/2/lesson_v1.pdf", "checksum": "ghi789", "history": []},
      "audio": null
    }
  ]
}
''';

void main() {
  test('parses manifest version and lesson count', () {
    final manifest = ContentManifest.fromJson(json.decode(_sampleJson));
    expect(manifest.version, 1);
    expect(manifest.lessons.length, 2);
  });

  test('parses lesson with audio', () {
    final manifest = ContentManifest.fromJson(json.decode(_sampleJson));
    final lesson = manifest.lessons[0];
    expect(lesson.id, 1);
    expect(lesson.title, 'Qual o Fim principal?');
    expect(lesson.pdf.active, 'lessons/1/lesson_v1.pdf');
    expect(lesson.pdf.checksum, 'abc123');
    expect(lesson.audio?.active, 'lessons/1/audio_v1.mp3');
    expect(lesson.audio?.ext, 'mp3');
  });

  test('parses lesson without audio', () {
    final manifest = ContentManifest.fromJson(json.decode(_sampleJson));
    expect(manifest.lessons[1].audio, isNull);
  });

  test('parses lesson with questions', () {
    final json2 = json.decode('''
    {
      "version": 1,
      "updated_at": "2026-05-27T12:00:00Z",
      "lessons": [
        {
          "id": 3,
          "title": "Lição com perguntas",
          "pdf": {"active": "lessons/3/lesson_v1.pdf", "checksum": "abc", "history": []},
          "audio": null,
          "questions": [
            {"id": 10, "q": "Pergunta 1?", "a": "Resposta 1."},
            {"id": 11, "q": "Pergunta 2?", "a": "Resposta 2."}
          ]
        }
      ]
    }
    ''');
    final manifest = ContentManifest.fromJson(json2);
    final lesson = manifest.lessons.first;
    expect(lesson.questions.length, 2);
    expect(lesson.questions[0].id, 10);
    expect(lesson.questions[0].question, 'Pergunta 1?');
    expect(lesson.questions[0].answer, 'Resposta 1.');
  });

  test('parses lesson with no questions field as empty list', () {
    // The _sampleJson has no questions field — should default to []
    final manifest = ContentManifest.fromJson(json.decode(_sampleJson));
    expect(manifest.lessons[0].questions, isEmpty);
    expect(manifest.lessons[1].questions, isEmpty);
  });

  test('parses lesson with empty questions array', () {
    final json3 = json.decode('''
    {
      "version": 1,
      "updated_at": "2026-05-27T12:00:00Z",
      "lessons": [
        {
          "id": 4,
          "title": "Lição sem perguntas",
          "pdf": {"active": "lessons/4/lesson_v1.pdf", "checksum": "abc", "history": []},
          "audio": null,
          "questions": []
        }
      ]
    }
    ''');
    final manifest = ContentManifest.fromJson(json3);
    expect(manifest.lessons.first.questions, isEmpty);
  });
}
