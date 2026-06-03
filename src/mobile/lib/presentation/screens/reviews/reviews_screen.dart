import 'package:betelapp/core/providers.dart';
import 'package:betelapp/core/theme/app_theme.dart';
import 'package:betelapp/presentation/screens/reviews/review_session_screen.dart';
import 'package:betelapp/presentation/screens/reviews/reviews_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewState = ref.watch(reviewViewModelProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: reviewState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
          data: (state) => _ReviewsContent(state: state),
        ),
      ),
    );
  }
}

class _ReviewsContent extends StatelessWidget {
  final ReviewState state;

  const _ReviewsContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Revisões', style: AppTheme.heading1),
                Text(
                  'MEMORIZAÇÃO DO CATECISMO',
                  style: AppTheme.caption.copyWith(letterSpacing: 1),
                ),
                const SizedBox(height: 16),
                if (state.totalDueToday > 0)
                  _DailyReviewBanner(dueCount: state.totalDueToday),
                const SizedBox(height: 20),
                Text(
                  'LIÇÕES ATIVAS',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (state.activeLessonIds.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nenhuma lição com revisão ativa.\nAbre uma lição e ativa a revisão.',
                  textAlign: TextAlign.center,
                  style: AppTheme.caption,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DailyReviewBanner extends StatelessWidget {
  final int dueCount;

  const _DailyReviewBanner({required this.dueCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REVISÃO DO DIA',
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text('Vamos praticar?', style: AppTheme.heading2),
          Text(
            '$dueCount ${dueCount == 1 ? 'card' : 'cards'} para revisar hoje',
            style: AppTheme.bodyText,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReviewSessionScreen(),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Começar Sessão'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
