---
layer: ui
project: mobile
last_reviewed: 2026-06-13
---

## Propósito

Governa decisões de interface do usuário no app mobile — navegação, componentes visuais, comportamento de telas, e padrões de interação.

## Decisões

### Navegação

- **Navigator 1.0 imperativo** — sem GoRouter, sem Navigator 2.0, sem named routes. Toda navegação via `Navigator.push` / `pushReplacement` com `MaterialPageRoute`.
  - **Por quê:** App pequeno com poucas telas e fluxo linear. A complexidade de rotas declarativas não se justifica ainda.

- **BottomNavigationBar com IndexedStack** — 4 tabs fixos: Lições (index 0), Músicas (index 1), Revisões (index 2), Favoritos (index 3). `IndexedStack` mantém todas as telas montadas simultaneamente.
  - **Por quê:** Preserva scroll position e estado local ao trocar de tab sem reconstruir widgets.

- **Splash → MainScaffold (one-way)** — `SplashScreen` usa `pushReplacement` para `MainScaffold(syncResult: result)` após o sync. Não há como voltar ao splash.
  - `MainScaffold` recebe `SyncResult?` como parâmetro e o repassa para `HomeScreen(syncResult: widget.syncResult)` na inicialização dos tabs.
  - `HomeScreen` usa o `SyncResult` para:
    - Exibir banner laranja "Você está offline" quando `offlineWithData`.
    - Exibir estado vazio com ícone `Icons.wifi_off` quando `offlineFirstBoot` e a lista de lições estiver vazia.

- **Review toggle no LessonDetailScreen** — ícone `Icons.style_rounded` no AppBar, visível em todos os casos:
  - `questionCount == 0`: cor `Colors.white24`, botão desabilitado (onPressed null), tooltip "Sem perguntas disponíveis".
  - `questionCount > 0`, revisão ativa: cor `Colors.white` (branco cheio), tooltip "Revisão ativa".
  - `questionCount > 0`, revisão inativa: cor `Colors.white54`, tooltip "Ativar revisão".
  - Toggle via `ReviewRepositoryImpl.setReviewActive()` e refresha `ReviewViewModel`.
  - **Por quê:** Decisão de UX para evitar áudio tocando "fantasma" enquanto o usuário navega lições/favoritos. O audio player só é visível na tela de músicas e no detalhe da lição.

### Design System / Theme

- **Arquivo central:** `lib/core/theme/app_theme.dart` — todas as cores e tipografia definidas como `static const` / `static TextStyle get`.

- **Paleta de cores:**
  | Token | Valor | Uso |
  |-------|-------|-----|
  | Primary | `#FFBD00` (golden yellow) | AppBar, destaques, botões primários |
  | White | `#FFFFFF` | Backgrounds, texto sobre cor primária |
  | Light Grey | `#F5F5F5` | Backgrounds secundários, cards |
  | Dark Grey | `#333333` | Texto principal |
  | Error | `#E57373` | Estados de erro |
  | Success | `#81C784` | Estados de sucesso |

- **Tipografia:** Google Fonts **Poppins** exclusivamente.
  | Style | Size | Weight |
  |-------|------|--------|
  | heading1 | 24 | bold |
  | heading2 | 20 | w600 |
  | bodyText | 16 | normal |
  | caption | 14 | w400 (grey) |

- **Material 3** ativado (`useMaterial3: true`).

- **Cards:** Border radius 20px, elevation 4 — padrão definido no `CardTheme`. Telas individuais **não devem sobrescrever `shape` localmente** sem razão visual explícita. A divergência atual em `FavoritesScreen` (16px via `BorderRadius.circular(16)`) é inconsistência não intencional — novas telas devem seguir os 20px do tema.

### Componentes compartilhados

- **`BetelHeader`** — widget de cabeçalho usado em HomeScreen, MusicScreen, FavoritesScreen. Exibe:
  - Logo SVG (`assets/images/betel-topbar-logo.svg`), centralizado.
  - Versão do app (via `package_info_plus`) no canto inferior direito, em cinza claro (9px).
  - Badge `DEV` laranja (`#FF6B00`) imediatamente à esquerda da versão quando o app **não** foi instalado pela Play Store (`installerStore != 'com.android.vending'`). Detecta sideload e builds instalados via ADB.
  - Banner de atualização in-app azul (`#2a5298`) abaixo do logo quando `InAppUpdate` detecta atualização disponível. Botão "Atualizar" inicia `startFlexibleUpdate()` + `completeFlexibleUpdate()`.
  - **Ausência intencional:** `ReviewsScreen` e `ReviewSessionScreen` **não usam** `BetelHeader`. `ReviewsScreen` usa `SafeArea` + `Padding` com título manual ("Revisões" + subtítulo "MEMORIZAÇÃO DO CATECISMO" em `AppTheme.caption` com `letterSpacing: 1`). A ausência é intencional para dar identidade visual diferenciada ao tab de revisões.

- **`AudioPlayerWidget`** — player de áudio reutilizável no bottom das telas. Aceita parâmetros de configuração:
  - `showShuffle: bool` (default `true`) — botão shuffle. Passado como `false` no `LessonDetailScreen`.
  - `onPrevious: VoidCallback?` — callback do botão "anterior". Quando `null`, o botão não é renderizado.
  - `onNext: VoidCallback?` — callback do botão "próximo". Quando `null`, o botão não é renderizado.
  - Prev/next só são exibidos na tela de músicas (callbacks fornecidos). No `LessonDetailScreen`, ambos são `null`.
  - **Seek slider — drag state local:** `AudioPlayerWidget` é `ConsumerStatefulWidget` (não stateless) para manter `_isDragging: bool` e `_dragValue: double?` como estado local. Durante o drag do slider, a posição exibida vem de `_dragValue` (não de `audioState.position`) — evita que o provider sobrescreva a posição enquanto o usuário está arrastando. Ao soltar (`onChangeEnd`), `audioNotifier.seek()` é chamado e o estado local é limpo.
  - Subwidgets privados: `_CircleButton`, `_RepeatButton`, `_ToggleButton`.

- **`BetelDialog`** — dialog overlay centralizado, reutilizável em qualquer tela do app. Suporta paginação horizontal (swipe) e dois modos visuais. Arquivo: `lib/presentation/widgets/betel_dialog.dart`.
  - **Props:**
    - `pages: List<Widget>` — conteúdo de cada página. Se 1 item, sem paginação.
    - `showBackButton: bool` (default `false`) — botão ‹ no canto superior esquerdo. Comportamento duplo:
      - Na primeira página (index 0): fecha o dialog (`Navigator.of(context).pop()`).
      - Nas demais páginas: navega para a página anterior dentro do dialog (`PageController.previousPage()`, 300ms, `easeInOut`).
      - Útil em dialogs multi-página onde o usuário deve poder revisitar páginas anteriores sem fechar.
    - `showCloseButton: bool` (default `true`) — botão ✕ no canto superior direito.
    - `showPagination: bool?` (default `null` = auto) — dots de paginação. Auto = visível quando `pages.length > 1`.
    - `isVideoOnly: bool` (default `false`) — sem container branco, overlay escuro direto.
    - `barrierDismissible: bool` (default `true`) — fecha ao tocar fora.
  - **Modos visuais:**
    - `isVideoOnly: false` → container branco, border-radius 20px, fundo `Colors.white`.
    - `isVideoOnly: true` → sem container (transparente), para exibir vídeo diretamente.
  - **Paginação:** `PageView` horizontal, dots animados (`AnimatedContainer`). Dot ativo = `AppTheme.primaryColor` com largura 20px (pill). Dot inativo = grey 40%, 8x8px (círculo).
  - **Bottom padding:** 36px quando paginação não é exibida.
  - **Uso:** `BetelDialog.show(context, pages: [...])` — helper estático que chama `showDialog` com barrier escuro (60% alpha).
  - Subwidgets privados: `_TopBar`, `_CircleIconButton`, `_PaginationDots`, `_DotIndicator`, `_VideoContentPage`, `_TextContentPage`.
  - **Por quê:** O app não tinha dialog reutilizável — os usos anteriores eram `AlertDialog` cru. Este componente padroniza avisos, listas de ações, vídeos e onboarding multi-página.
  - **`showContent(context, Content content)`** — convenience method que recebe um `Content` e monta o dialog automaticamente:
    - **VIDEO:** `_VideoContentPage` com `youtube_player_iframe` (API iframe WebView). Extrai `videoId` e orientação da URL via `_parseVideoUrl()`:
      - `youtu.be/<id>` → horizontal
      - `?v=<id>` → horizontal
      - `/embed/<id>` → horizontal
      - `/shorts/<id>` → vertical (aspect ratio 9:16)
      - Usa `YoutubePlayerController.fromVideoId()` com `autoPlay: false`.
      - `EagerGestureRecognizer` garante que o WebView vence o `PageView` no reconhecimento de gestos horizontais (evita conflito com a barra de progresso do YouTube).
      - Botão "Abrir no YouTube" abaixo do player abre a URL no app nativo via `url_launcher` (`LaunchMode.externalApplication`).
    - **TEXT:** Dois sub-modos baseados nos campos do modelo `Content`:
      - **Multi-page** (`content.pagesHtml`: `List<String>` não vazio): cada elemento da lista vira uma `_TextContentPage` separada. O dialog exibe paginação horizontal (swipe + dots). Este é o modo principal para conteúdo criado no portal com múltiplas páginas.
      - **Single-page legacy** (`content.html`: `String`): cria um único `_TextContentPage`. Usado como fallback para conteúdos criados antes da introdução do campo `pagesHtml`.
      - `_TextContentPage` usa `flutter_widget_from_html_core` (`HtmlWidget`) com `SingleChildScrollView` e padding `horizontal: 16, vertical: 8`. Renderiza HTML do editor Tiptap como widgets nativos Flutter.
    - Se conteúdo não tem dados renderizáveis, `showContent` retorna silenciosamente.
  - **Uso pelo dev:** buscar conteúdo via `contentRepository.loadContentBySlug('slug')`, depois `BetelDialog.showContent(context, content)`. O **onde** cada conteúdo aparece é hardcoded pelo dev.

### Padrões de widget

- **`ConsumerWidget`** para telas stateless que leem providers (MusicScreen, FavoritesScreen).
- **`ConsumerStatefulWidget`** para telas que precisam de Riverpod + estado local (SplashScreen, MainScaffold, HomeScreen, LessonDetailScreen, AudioPlayerWidget).
  - HomeScreen usa estado local (`_contentDialogShown`) para garantir que o dialog de conteúdo de boas-vindas seja exibido apenas uma vez por montagem.
- **`StatefulWidget` puro** para widgets com apenas estado local Flutter (BetelHeader).
- **Inner widgets privados** (prefixo `_`) dentro do mesmo arquivo para encapsulamento.

### Telas

| Tela | Arquivo | Função |
|------|---------|--------|
| SplashScreen | `screens/splash_screen.dart` | Entry point: sync, spinner + mensagem de progresso ("Baixando lição X de Y…"), aviso de dados móveis |
| MainScaffold | `widgets/main_scaffold.dart` | Shell com 4 tabs + IndexedStack + banner de conectividade em tempo real |
| HomeScreen | `screens/home/home_screen.dart` | Lista lições do SQLite, pull-to-refresh, offline warning, dialog de conteúdo na primeira montagem |
| LessonDetailScreen | `screens/lesson/lesson_detail_screen.dart` | PDF inline (pdfrx) + audio player condicional + favorito toggle + toggle de revisão |
| MusicScreen | `screens/music/music_screen.dart` | Lista de músicas (lições com áudio), play/pause por item, `AudioPlayerWidget` flutuante |
| FavoritesScreen | `screens/favorites/favorites_screen.dart` | Lista favoritos (lições + músicas). Cabeçalho `BetelHeader` + título "Favoritos" em ambos os estados. **Estado vazio:** ícone `Icons.favorite_border_rounded` (80px, cinza) + "Você ainda não tem favoritos." **Estado carregado:** `ListView` com `Card`+`ListTile` — ícone de livro para lições (navega para `LessonDetailScreen`), ícone de nota musical para músicas (exibe Snackbar: "vá ao tab Músicas para ouvir"). |
| ReviewsScreen | `screens/reviews/reviews_screen.dart` | Tab Revisões: três estados — (1) nenhuma lição ativa (instrução ao usuário), (2) lições ativas mas sem cards devidos hoje ("volte amanhã"), (3) cards devidos → `_DailyReviewBanner` com contagem de perguntas e botão "Começar Sessão" → `ReviewSessionScreen`. **Não exibe lista de lições.** |
| ReviewSessionScreen | `screens/reviews/review_session_screen.dart` | Sessão de flashcard: progress bar "Card N de M", card branco com pergunta, botão "REVELAR RESPOSTA" exibe resposta inline, botões "ERREI" (OutlinedButton vermelho) e "ACERTEI" (ElevatedButton primário). Ao terminar: tela de resumo com "N de M acertos" e botão "Voltar". Ao sair, atualiza `reviewViewModelProvider`. |

### MusicScreen — detalhes de implementação

- **`MusicViewModel`** (`screens/music/music_view_model.dart`): carrega lições com `loadLessonsWithAudio()`, mapeia para `Song(id: lesson.id.toString(), title: lesson.title, artist: 'Betel', audioUrl: dir.path + '/' + localAudioPath)`. Exposto como `AsyncValue<List<Song>>` via `musicViewModelProvider`.
- **Ícone da track atual:** quando uma song é a `audioState.currentUrl`, o leading container exibe `Icons.graphic_eq_rounded` em vez do número da lição.
- **Tap no play button:** chama `setQueue(songs, startIndex: index)` — substitui a queue inteira e começa a tocar a partir da song selecionada.
- **`AudioPlayerWidget` flutuante:** visível apenas quando `audioState.currentUrl != null`. Bottom padding da lista muda para evitar sobreposição com o player.

### Audio lifecycle

- **Audio stop on tab change** — sair do tab Músicas (index 1) para qualquer outro tab chama `audioNotifier.stop()`, parando a reprodução inteiramente.
- **Audio stop ao sair do LessonDetailScreen** — `_LessonAudioPlayerState.dispose()` chama `audioNotifier.stop()` quando o usuário pressiona back na tela de detalhes da lição. O áudio da lição nunca continua tocando em background após o usuário sair da tela.
  - **Por quê:** O player da lição é um widget filho do `LessonDetailScreen`; não faz sentido manter áudio da lição tocando enquanto o usuário está em outra tela.

### Splash screen

- Fundo preto com `Image.asset('assets/images/splash_screen_image.jpg')` centralizada.
- `flutter_native_splash` com background preto + imagem para a tela de splash nativa do OS.
- `flutter_launcher_icons` para ícone do app.
- Durante o sync, exibe na parte inferior (bottom: 60px) um `CircularProgressIndicator` branco e uma mensagem de texto "Baixando lição X de Y…" — atualizada pelo callback `onProgress` do `ContentSyncService`.
- A mensagem só aparece enquanto há download em andamento; se o sync pular (sem mudanças), a splash some sem exibir indicador.
- Aviso de dados móveis: `AlertDialog` nativo (não `BetelDialog`) com `barrierDismissible: false`, botões "Agora não" e "Baixar".

### MainScaffold — banner de conectividade

- Observa `networkStatusProvider` (via `NetworkStatusNotifier`).
- Quando `NetworkStatus != ok`, exibe `_ConnectivityBanner` acima do `IndexedStack`, visível em todos os tabs:
  - `NetworkStatus.serverDown`: fundo `AppTheme.errorColor` (vermelho), texto "Servidor indisponível. Verificando…"
  - Demais estados offline: fundo `Colors.grey[700]`, texto "Sem conexão com a internet. Verificando…"
- O banner desaparece automaticamente quando a conectividade é restaurada (reativo via provider).
- Diferente do aviso estático de `HomeScreen` (baseado no `SyncResult` do startup): esse banner reflete o estado de rede em tempo real durante toda a sessão.

### MainScaffold — gestos de desenvolvimento (Revisões tab)

Dois gestos ocultos na tab Revisões permitem testar o sistema de revisão sem manipular o banco de dados diretamente. Ambos estão ativos em todos os builds (sem guard de ambiente):

- **Reset de progresso (10 taps em 3s):** Tapping a tab Revisões 10 vezes em até 3 segundos chama `reviewRepository.resetAllProgress()`. Exibe SnackBar de confirmação. Não altera os toggles de lições ativas.
- **Avanço de 1 dia (long-press 10s):** Manter pressionado o ícone da tab Revisões por 10 segundos abre um `AlertDialog` de confirmação. Se confirmado, chama `reviewRepository.advanceOneDayForTesting()` — antecipa `next_review_at` de todos os cards em 1 dia sem alterar o relógio do sistema. Exibe SnackBar de confirmação.

Esses gestos existem para acelerar testes manuais do algoritmo Leitner sem aguardar os intervalos reais (1–16 dias).

### HomeScreen — dialog de conteúdo automático

- Na primeira montagem (via `addPostFrameCallback`), HomeScreen busca o conteúdo com slug `'conteudo-teste'` via `contentRepository.loadContentBySlug()`.
- Se encontrado, abre `BetelDialog.showContent()` automaticamente.
- Um flag local (`_contentDialogShown`) garante que o dialog é exibido no máximo uma vez por ciclo de vida do widget.
- O slug `'conteudo-teste'` é hardcoded — para alterar o conteúdo exibido, o admin publica no portal com esse slug.

### HomeScreen — layout da lista de lições

- Cabeçalho fixo: título "Lições" (`AppTheme.heading1`) + subtítulo "Eu & minha Casa Serviremos a Deus" (bodyText italic). Padding horizontal 20px, vertical 10px.
- Cada lição é renderizada como `ListTile` dentro de um `Container` branco com `borderRadius: 16px` e sombra leve. Margin: `horizontal: 20, vertical: 8`. (Nota: diverge do `CardTheme` do design system que define radius 20px.)
- Leading: quadrado 50x50px com `borderRadius: 12px` e fundo `AppTheme.primaryColor`, exibindo `lesson.id` (chave primária do DB) como texto em `AppTheme.heading2` preto — não um índice sequencial da lista.
- Trailing: `Icons.chevron_right_rounded` em cinza.
- Tap navega para `LessonDetailScreen(lesson: lesson)` via `Navigator.push` + `MaterialPageRoute`.

### Padrões de provider (ViewModel)

- **`StateNotifierProvider<VM, AsyncValue<T>>`** — padrão para view models de telas que carregam dados assíncronos (ex: `homeViewModelProvider`, `favoritesViewModelProvider`).
  - O `StateNotifier` inicia o carregamento no construtor.
  - `ref.invalidate(provider)` é usado para forçar recarga após eventos externos (ex: pull-to-refresh pós-sync em `HomeScreen`).
- View models de revisão e audio seguem padrões análogos — ver specs de business e data para detalhes.

## O que NÃO fazer

- **Não usar GoRouter ou rotas declarativas** sem necessidade comprovada (a complexidade atual não justifica).
- **Não criar cores/estilos inline** — sempre usar `AppTheme` como fonte única.
- **Não usar fontes fora do Poppins** — a tipografia do app é consistente com uma única família.
- **Não instalar APKs debug para teste manual em dispositivo** — builds debug no Samsung ativam otimizador JIT (`dex2oat`) que causa tela preta permanente. Sempre usar `flutter build apk --release` + `adb install`.
- **Não usar GoRouter ou rotas declarativas** sem necessidade comprovada (a complexidade atual não justifica).
- **ReviewsScreen** mostra apenas o banner de revisão diária com a contagem de cards devidos — não exibir lista de lições ativas nem lista de cards individuais nessa tela. A lista de cards é responsabilidade exclusiva da `ReviewSessionScreen`.
