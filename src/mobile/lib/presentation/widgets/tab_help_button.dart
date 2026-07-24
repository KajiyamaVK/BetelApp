import 'package:betelapp/core/providers.dart';
import 'package:betelapp/presentation/widgets/betel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Circular ? button shown at the top-right of each tab header.
/// Loads content by [displayLocation] and opens BetelDialog.showContent().
/// Does nothing silently if no content is configured for this location.
class TabHelpButton extends ConsumerWidget {
  final String displayLocation;

  const TabHelpButton({super.key, required this.displayLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _onTap(context, ref),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade200,
        ),
        child: const Center(
          child: Text(
            '?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(contentRepositoryProvider);
    final content = await repository.loadContentByLocation(displayLocation);
    if (content != null && context.mounted) {
      BetelDialog.showContent(context, content);
    }
  }
}
