import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:betelapp/data/models/content.dart';

void main() {
  test('creates Content from SQLite map for VIDEO type', () {
    final map = {
      'id': 1,
      'slug': 'welcome-video',
      'title': 'Bem-vindo',
      'type': 'VIDEO',
      'youtube_url': 'https://youtube.com/watch?v=abc',
      'html': null,
    };
    final content = Content.fromMap(map);
    expect(content.id, 1);
    expect(content.slug, 'welcome-video');
    expect(content.title, 'Bem-vindo');
    expect(content.type, 'VIDEO');
    expect(content.youtubeUrl, 'https://youtube.com/watch?v=abc');
    expect(content.html, isNull);
  });

  test('creates Content from SQLite map for TEXT type', () {
    final map = {
      'id': 2,
      'slug': 'about-course',
      'title': 'Sobre o curso',
      'type': 'TEXT',
      'youtube_url': null,
      'html': '<p>Conteúdo aqui</p>',
    };
    final content = Content.fromMap(map);
    expect(content.id, 2);
    expect(content.type, 'TEXT');
    expect(content.html, '<p>Conteúdo aqui</p>');
    expect(content.youtubeUrl, isNull);
  });

  test('creates Content with pagesHtml from JSON-encoded pages_html column', () {
    final pagesJson = jsonEncode(['<p>Page 1</p>', '<p>Page 2</p>']);
    final map = {
      'id': 3,
      'slug': 'multi-page',
      'title': 'Tutorial',
      'type': 'TEXT',
      'youtube_url': null,
      'html': null,
      'pages_html': pagesJson,
    };
    final content = Content.fromMap(map);
    expect(content.pagesHtml, isNotNull);
    expect(content.pagesHtml!.length, 2);
    expect(content.pagesHtml![0], '<p>Page 1</p>');
    expect(content.pagesHtml![1], '<p>Page 2</p>');
  });

  test('pagesHtml is null when pages_html column is null (single-page)', () {
    final map = {
      'id': 4,
      'slug': 'single',
      'title': 'Single',
      'type': 'TEXT',
      'youtube_url': null,
      'html': '<p>Only page</p>',
      'pages_html': null,
    };
    final content = Content.fromMap(map);
    expect(content.pagesHtml, isNull);
    expect(content.html, '<p>Only page</p>');
  });
}
