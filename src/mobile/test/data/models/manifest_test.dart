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
}
