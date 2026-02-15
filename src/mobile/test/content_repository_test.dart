import 'package:flutter_test/flutter_test.dart';
import 'package:betelsas/data/repositories/content_repository.dart';
import 'package:flutter/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ContentRepository loads and parses lessons.json', (WidgetTester tester) async {
    final repository = ContentRepository();
    final lessons = await repository.loadLessons();
    
    expect(lessons, isNotEmpty);
    expect(lessons.first.title, 'Quem é Deus?');
    expect(lessons.length, greaterThanOrEqualTo(5)); // Based on the file content I saw
  });
}
