import 'package:betelsas/core/providers.dart';
import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/data/models/flashcard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

class StudySession extends ConsumerStatefulWidget {
  final List<Flashcard> flashcards;
  final VoidCallback? onSessionComplete;

  const StudySession({
    super.key,
    required this.flashcards,
    this.onSessionComplete,
  });

  @override
  ConsumerState<StudySession> createState() => _StudySessionState();
}

class _StudySessionState extends ConsumerState<StudySession> {
  final CardSwiperController _controller = CardSwiperController();
  

  // Track current card index to update progress bar
  int _currentIndex = 0;

  // Track pending database operations to prevent race conditions
  final List<Future<void>> _pendingOperations = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onSwipe(int showIndex, int? nextIndex, CardSwiperDirection direction) {
    // Record result
    final card = widget.flashcards[showIndex];
    String performance = 'good'; // Default

    if (direction == CardSwiperDirection.left) {
      performance = 'again';
    } else if (direction == CardSwiperDirection.right) {
      performance = 'easy';
    }

    // Call repository and track the future
    final future = ref.read(flashcardRepositoryProvider).recordReview(card.id, performance);
    _pendingOperations.add(future);
    
    // Clean up completed futures to avoid memory leaks (optional for short sessions but good practice)
    future.whenComplete(() => _pendingOperations.remove(future));

    setState(() {
      if (nextIndex != null) {
        _currentIndex = nextIndex;
      }
    });

    return true; // Return true to allow swipe
  }
  
  Future<void> _onEnd() async {
    try {
      // Wait for all pending database writes to complete
      if (_pendingOperations.isNotEmpty) {
        await Future.wait(_pendingOperations);
      }
    } catch (e) {
      // Log error but ensure we still close the session
      debugPrint('Error saving flashcard progress: $e');
    } finally {
      if (mounted && widget.onSessionComplete != null) {
        widget.onSessionComplete!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return const Center(child: Text('Sem cards para revisar!'));
    }

    // We keep Scaffold here to provide the AppBar. 
    // Since FlashcardDashboard also provides a Scaffold, this nested Scaffold provides the app bar for the session.
    // It is common practice for screens to return Scaffold even if nested in tabs.
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${_currentIndex + 1}/${widget.flashcards.length}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTheme.heading2.copyWith(color: AppTheme.textColor),
        automaticallyImplyLeading: false, // Don't show back button
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CardSwiper(
                controller: _controller,
                cardsCount: widget.flashcards.length,
                onSwipe: _onSwipe,
                onEnd: _onEnd,
                isLoop: false,
                allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true),
                numberOfCardsDisplayed: min(3, widget.flashcards.length),
                backCardOffset: const Offset(0, 40),
                padding: const EdgeInsets.all(24),
                cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                  return FlashcardView(
                    flashcard: widget.flashcards[index],
                    onFlip: () {}, // Optional callback
                  );
                },
              ),
            ),
            // Controls (optional, if we want buttons instead of swipes)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'fail_btn',
                    onPressed: () => _controller.swipe(CardSwiperDirection.left),
                    backgroundColor: AppTheme.errorColor,
                    label: const Text('Não sei'),
                    icon: const Icon(Icons.close),
                  ),
                  FloatingActionButton.extended(
                    heroTag: 'pass_btn',
                    onPressed: () => _controller.swipe(CardSwiperDirection.right),
                    backgroundColor: AppTheme.successColor,
                    label: const Text('Já sei'),
                    icon: const Icon(Icons.check),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FlashcardView extends StatefulWidget {
  final Flashcard flashcard;
  final VoidCallback onFlip;

  const FlashcardView({super.key, required this.flashcard, required this.onFlip});

  @override
  State<FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<FlashcardView> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showAnswer = !_showAnswer);
        widget.onFlip();
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.1),
               blurRadius: 20,
               offset: const Offset(0, 10),
             ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _showAnswer ? 'RESPOSTA' : 'PERGUNTA',
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 20),
              Text(
                _showAnswer ? widget.flashcard.answer : widget.flashcard.question,
                style: AppTheme.heading1.copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
               Text(
                _showAnswer ? 'Toque para esconder' : 'Toque para revelar',
                style: AppTheme.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
