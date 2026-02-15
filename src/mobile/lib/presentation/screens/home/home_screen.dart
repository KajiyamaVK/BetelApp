import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/presentation/screens/home/home_view_model.dart';
import 'package:betelsas/presentation/widgets/betel_header.dart';
import 'package:betelsas/presentation/screens/lesson/lesson_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsState = ref.watch(homeViewModelProvider);

    return Scaffold(
      body: CustomScrollView(
          slivers: [
             SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const BetelHeader(),
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
    
                        Text(
                          'Lições',
                          style: AppTheme.heading1,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Eu & minha Casa Serviremos a Deus',
                          style: AppTheme.bodyText.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            lessonsState.when(
              data: (lessons) {
                if (lessons.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('Nenhuma lição encontrada.')),
                  );
                }

                return SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 10),
                    // List of Lessons
                    ...lessons.map((lesson) => _buildLessonTile(context, lesson)).toList(),
                    const SizedBox(height: 20),
                  ]),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(child: Text('Erro ao carregar lições: $err')),
              ),
            ),
          ],
        ),
      );
  }



  Widget _buildLessonTile(BuildContext context, dynamic lesson) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
              '${lesson.id}',
              style: AppTheme.heading2.copyWith(color: Colors.black),
            ),
          ),
        ),
        title: Text(lesson.title, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),

        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonDetailScreen(lesson: lesson),
            ),
          );
        },
      ),
    );
  }
}
