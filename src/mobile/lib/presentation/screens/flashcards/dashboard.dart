import 'dart:async';
import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/data/models/flashcard.dart';
import 'package:betelsas/presentation/screens/flashcards/dashboard_view_model.dart';
import 'package:betelsas/presentation/screens/flashcards/study_session.dart';
import 'package:betelsas/presentation/widgets/betel_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlashcardDashboard extends ConsumerStatefulWidget {
  const FlashcardDashboard({super.key});

  @override
  ConsumerState<FlashcardDashboard> createState() => _FlashcardDashboardState();
}

class _FlashcardDashboardState extends ConsumerState<FlashcardDashboard> {
  Timer? _longPressTimer;

  void _startTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(seconds: 10), () {
      _showResetDialog();
    });
  }

  void _cancelTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  Future<void> _showResetDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetar Progresso?'),
        content: const Text(
          'Deseja resetar TODOS os cards para o estado "Novo"? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Resetar Tudo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(flashcardDashboardProvider.notifier).resetAllCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos os cards foram resetados!')),
        );
      }
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateMsg = ref.watch(flashcardDashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: stateMsg.when(
        data: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BetelHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text('Flashcards', style: AppTheme.heading1),
              ),
              // Filters
              _buildFilters(context, ref, state.filter),
              
              const SizedBox(height: 20),
              
              // Start Session Button Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 200, // Fixed height for better visual
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(24),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/flashcardsScreen.png'), 
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                       // Yellow Mask (0.4 opacity)
                       Positioned.fill(
                         child: Container(
                           decoration: BoxDecoration(
                             color: AppTheme.primaryColor.withOpacity(0.4),
                             borderRadius: BorderRadius.circular(24),
                           ),
                         ),
                       ),
                       // Black Fade (Bottom to Top)
                       Positioned.fill(
                         child: Container(
                           decoration: BoxDecoration(
                             borderRadius: BorderRadius.circular(24),
                             gradient: LinearGradient(
                               begin: Alignment.bottomCenter,
                               end: Alignment.topCenter,
                               colors: [
                                 Colors.black.withOpacity(0.8),
                                 Colors.transparent,
                               ],
                             ),
                           ),
                         ),
                       ),
                       // Content
                       Center(
                         child: Padding(
                           padding: const EdgeInsets.all(24),
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                      Text(
                        'Vamos praticar?',
                        style: AppTheme.heading2.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${state.filteredCards.length} cards selecionados',
                        style: AppTheme.bodyText.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Listener(
                        onPointerDown: (_) => _startTimer(),
                        onPointerUp: (_) => _cancelTimer(),
                        onPointerCancel: (_) => _cancelTimer(),
                        child: ElevatedButton.icon(
                          onPressed: state.filteredCards.isEmpty
                              ? null
                              : () {
                                  _cancelTimer(); // Cancel timer just in case
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StudySession(
                                        flashcards: state.filteredCards.map((c) => c.flashcard).toList(),
                                        onSessionComplete: () {
                                          ref.invalidate(flashcardDashboardProvider);
                                          Navigator.pop(context); // Pop back to dashboard after session
                                        },
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Começar Sessão'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.textColor,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                           ],
                           ),
                         ),
                       ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Lista de Cards', style: AppTheme.heading2),
              ),
              const SizedBox(height: 10),

              // Card List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: state.filteredCards.length,
                  itemBuilder: (context, index) {
                    final item = state.filteredCards[index];
                    // Use the index from the ORIGINAL list + 1
                    final originalIndex = state.allCards.indexOf(item) + 1;
                    return _buildCardItem(item, originalIndex);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, WidgetRef ref, FlashcardStatus? currentFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildFilterChip(
            context,
            ref,
            label: 'Todos',
            isSelected: currentFilter == null,
            onSelected: () => ref.read(flashcardDashboardProvider.notifier).setFilter(null),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            ref,
            label: 'Novos',
            isSelected: currentFilter == FlashcardStatus.newCard,
            onSelected: () => ref.read(flashcardDashboardProvider.notifier).setFilter(FlashcardStatus.newCard),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            ref,
            label: 'Revisar',
            isSelected: currentFilter == FlashcardStatus.review,
            onSelected: () => ref.read(flashcardDashboardProvider.notifier).setFilter(FlashcardStatus.review),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            ref,
            label: 'Aprendidos',
            isSelected: currentFilter == FlashcardStatus.learned,
            onSelected: () => ref.read(flashcardDashboardProvider.notifier).setFilter(FlashcardStatus.learned),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.textColor : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildCardItem(FlashcardWithStatus item, int index) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (item.status) {
      case FlashcardStatus.newCard:
        statusColor = Colors.grey;
        statusText = 'Novo';
        statusIcon = Icons.circle_outlined;
        break;
      case FlashcardStatus.review:
        statusColor = Colors.orange;
        statusText = 'Revisar';
        statusIcon = Icons.access_time_rounded;
        break;
      case FlashcardStatus.learned:
        statusColor = Colors.green;
        statusText = 'Aprendido';
        statusIcon = Icons.check_circle_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudySession(
                flashcards: [item.flashcard], // Start session with only this card
                onSessionComplete: () {
                  ref.invalidate(flashcardDashboardProvider);
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '$index'.padLeft(2, '0'),
              style: AppTheme.heading2.copyWith(color: Colors.black),
            ),
          ),
        ),
        title: Text(item.flashcard.question, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Text(statusText, style: AppTheme.caption.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
