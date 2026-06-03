import 'package:betelapp/core/providers.dart';
import 'package:betelapp/core/theme/app_theme.dart';
import 'package:betelapp/data/models/flashcard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewSessionScreen extends ConsumerStatefulWidget {
  const ReviewSessionScreen({super.key});

  @override
  ConsumerState<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends ConsumerState<ReviewSessionScreen> {
  List<CardProgress> _cards = [];
  int _currentIndex = 0;
  bool _revealed = false;
  int _correctCount = 0;
  int _incorrectCount = 0;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final repo = ref.read(reviewRepositoryProvider);
    final activeIds = await repo.getActiveLessonIds();
    final dueCards = await repo.getDueCards(lessonIds: activeIds);
    if (!mounted) return;
    setState(() {
      _cards = dueCards;
      _loading = false;
      _finished = dueCards.isEmpty;
    });
  }

  Future<void> _answer(bool correct) async {
    final repo = ref.read(reviewRepositoryProvider);
    await repo.recordAnswer(
      questionId: _cards[_currentIndex].questionId,
      correct: correct,
    );

    if (correct) {
      _correctCount++;
    } else {
      _incorrectCount++;
    }

    if (_currentIndex + 1 >= _cards.length) {
      await ref.read(reviewViewModelProvider.notifier).loadState();
      setState(() => _finished = true);
    } else {
      setState(() {
        _currentIndex++;
        _revealed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Revisão do dia', style: AppTheme.caption),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _finished
              ? _buildFinishedView()
              : _buildCardView(),
    );
  }

  Widget _buildCardView() {
    final card = _cards[_currentIndex];
    final progress = (_currentIndex + 1) / _cards.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PROGRESSO', style: AppTheme.caption),
              Text(
                'Card ${_currentIndex + 1} de ${_cards.length}',
                style: AppTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              color: AppTheme.primaryColor,
              minHeight: 6,
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PERGUNTA', style: AppTheme.caption),
                const SizedBox(height: 12),
                Text(
                  card.questionText ?? '',
                  style: AppTheme.heading2,
                ),
                if (_revealed) ...[
                  const Divider(color: AppTheme.primaryColor, thickness: 2),
                  const SizedBox(height: 8),
                  Text('RESPOSTA', style: AppTheme.caption),
                  const SizedBox(height: 6),
                  Text(card.answerText ?? '', style: AppTheme.bodyText),
                ] else ...[
                  const SizedBox(height: 8),
                  const Divider(color: AppTheme.primaryColor, thickness: 2),
                ],
              ],
            ),
          ),
          const Spacer(),
          if (!_revealed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _revealed = true),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('REVELAR RESPOSTA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _answer(false),
                    icon: const Icon(Icons.close_rounded, color: Colors.red),
                    label: const Text('ERREI',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _answer(true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('ACERTEI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFinishedView() {
    final total = _correctCount + _incorrectCount;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text('Sessão concluída!', style: AppTheme.heading1),
            const SizedBox(height: 8),
            Text('$_correctCount de $total acertos', style: AppTheme.bodyText),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }
}
