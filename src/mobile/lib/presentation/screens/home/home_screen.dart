import 'package:betelapp/core/providers.dart';
import 'package:betelapp/core/theme/app_theme.dart';
import 'package:betelapp/data/models/lesson.dart';
import 'package:betelapp/data/services/content_sync_service.dart';
import 'package:betelapp/presentation/screens/home/home_view_model.dart';
import 'package:betelapp/presentation/widgets/betel_header.dart';
import 'package:betelapp/presentation/screens/lesson/lesson_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  final SyncResult? syncResult;
  const HomeScreen({super.key, this.syncResult});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsState = ref.watch(homeViewModelProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final syncService = ref.read(contentSyncServiceProvider);
          await syncService.sync();
          ref.invalidate(homeViewModelProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BetelHeader(),
                  if (syncResult == SyncResult.offlineWithData)
                    Container(
                      color: Colors.orange.shade100,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Você está offline — o conteúdo pode estar desatualizado',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lições', style: AppTheme.heading1),
                        const SizedBox(height: 5),
                        Text(
                          'Eu & minha Casa Serviremos a Deus',
                          style: AppTheme.bodyText
                              .copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            lessonsState.when(
              data: (lessons) {
                if (lessons.isEmpty &&
                    syncResult == SyncResult.offlineFirstBoot) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Sem conexão com a internet',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'É necessário conexão para fazer o download do conteúdo',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                if (lessons.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('Nenhuma lição encontrada.')),
                  );
                }
                return SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 10),
                    ...lessons.map((lesson) => _buildLessonTile(context, lesson)),
                    const SizedBox(height: 20),
                  ]),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Erro ao carregar lições: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonTile(BuildContext context, Lesson lesson) {
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
