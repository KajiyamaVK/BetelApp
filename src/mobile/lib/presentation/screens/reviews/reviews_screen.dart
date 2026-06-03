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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revisões', style: AppTheme.heading1),
          Text(
            'MEMORIZAÇÃO DO CATECISMO',
            style: AppTheme.caption.copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: 24),
          if (state.activeLessonIds.isEmpty)
            _EmptyState(message:
              'Nenhuma lição com revisão ativa.\nAbra uma lição e ative a revisão.')
          else if (state.totalDueToday == 0)
            _EmptyState(message:
              'Nada para revisar hoje.\nVolte amanhã!')
          else
            _DailyReviewBanner(dueCount: state.totalDueToday),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTheme.caption,
        ),
      ),
    );
  }
}

class _DailyReviewBanner extends StatelessWidget {
  final int dueCount;

  const _DailyReviewBanner({required this.dueCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AppTheme.primaryColor, width: 5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REVISÃO DO DIA',
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text('Vamos praticar?', style: AppTheme.heading2),
          Text(
            '$dueCount ${dueCount == 1 ? 'pergunta' : 'perguntas'} para revisar hoje',
            style: AppTheme.bodyText,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
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
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
