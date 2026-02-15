
import 'package:betelsas/presentation/screens/favorites/favorites_screen.dart';
import 'package:betelsas/presentation/screens/favorites/favorites_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Fake Ref that does nothing
class FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestFavoritesViewModel extends FavoritesViewModel {
  // Pass a dummy value to satisfy non-nullable Ref
  // Using dynamic cast to bypass type check if needed, though strictly it expects Ref
  // Safe because we override loadFavorites and don't use _ref
  TestFavoritesViewModel() : super(FakeRef() as dynamic);

  @override
  Future<void> loadFavorites() async {
    // Return empty state for test immediately
    state = const AsyncValue.data([]);
  }
}

void main() {
  testWidgets('FavoritesScreen displays empty state centered', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesViewModelProvider.overrideWith((ref) => TestFavoritesViewModel()),
        ],
        child: const MaterialApp(
          home: FavoritesScreen(),
        ),
      ),
    );

    // Re-pump to allow async init (if any) and settling
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify empty state text is present
    expect(find.text('Você ainda não tem favoritos.'), findsOneWidget);

    // Verify Center widget wraps the content
    final columnFinder = find.ancestor(
      of: find.text('Você ainda não tem favoritos.'),
      matching: find.byType(Column),
    );
    expect(columnFinder, findsOneWidget);

    final centerFinder = find.ancestor(
      of: columnFinder,
      matching: find.byType(Center),
    );
    
    // This assertion should fail before fix
    expect(centerFinder, findsOneWidget, reason: "Empty state content should be centered");
  });
}
