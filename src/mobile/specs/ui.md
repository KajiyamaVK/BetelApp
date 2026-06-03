---
layer: ui
project: mobile
last_reviewed: 2026-06-03
---

## Propósito

Governa decisões de interface do usuário no app mobile — navegação, componentes visuais, comportamento de telas, e padrões de interação.

## Decisões

### Navegação

- **Navigator 1.0 imperativo** — sem GoRouter, sem Navigator 2.0, sem named routes. Toda navegação via `Navigator.push` / `pushReplacement` com `MaterialPageRoute`.
  - **Por quê:** App pequeno com poucas telas e fluxo linear. A complexidade de rotas declarativas não se justifica ainda.

- **BottomNavigationBar com IndexedStack** — 4 tabs fixos: Lições (index 0), Músicas (index 1), Revisões (index 2), Favoritos (index 3). `IndexedStack` mantém todas as telas montadas simultaneamente.
  - **Por quê:** Preserva scroll position e estado local ao trocar de tab sem reconstruir widgets.

- **Splash → MainScaffold (one-way)** — `SplashScreen` usa `pushReplacement` para `MainScaffold` após sync. Não há como voltar ao splash.

- **Audio stop on tab change** — sair do tab Músicas (index 1) para qualquer outro tab chama `audioNotifier.stop()`, parando a reprodução inteiramente.
- **Review toggle no LessonDetailScreen** — ícone `Icons.style_rounded` no AppBar, visível apenas se `lesson.questionCount > 0`. Amarelo quando ativo, branco54 quando inativo. Toggle via `ReviewRepositoryImpl.setReviewActive()` e refresha `ReviewViewModel`.
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

- **Cards:** Border radius 20px, elevation 4 — padrão definido no `CardTheme`.

### Componentes compartilhados

- **`BetelHeader`** — widget de cabeçalho usado em HomeScreen, MusicScreen, FavoritesScreen. Exibe logo SVG, versão do app (via `package_info_plus`), e banner de atualização in-app (via `in_app_update`).

- **`AudioPlayerWidget`** — player de áudio reutilizável no bottom das telas. Aceita parâmetros de configuração:
  - `showShuffle: true/false` — shuffle só aparece na tela de músicas, não no detalhe da lição.
  - `showPrevNext: true/false` — prev/next buttons só na tela de músicas.
  - Subwidgets privados: `_CircleButton`, `_RepeatButton`, `_ToggleButton`.

### Padrões de widget

- **`ConsumerWidget`** para telas stateless que leem providers (HomeScreen, MusicScreen, FavoritesScreen).
- **`ConsumerStatefulWidget`** para telas que precisam de Riverpod + estado local (SplashScreen, MainScaffold, LessonDetailScreen, AudioPlayerWidget).
- **`StatefulWidget` puro** para widgets com apenas estado local Flutter (BetelHeader).
- **Inner widgets privados** (prefixo `_`) dentro do mesmo arquivo para encapsulamento.

### Telas

| Tela | Arquivo | Função |
|------|---------|--------|
| SplashScreen | `screens/splash_screen.dart` | Entry point: sync, progress bar, aviso de dados móveis |
| MainScaffold | `widgets/main_scaffold.dart` | Shell com 4 tabs + IndexedStack |
| HomeScreen | `screens/home/home_screen.dart` | Lista lições do SQLite, pull-to-refresh, offline warning |
| LessonDetailScreen | `screens/lesson/lesson_detail_screen.dart` | PDF inline (pdfrx) + audio player condicional + favorito toggle + toggle de revisão |
| MusicScreen | `screens/music/music_screen.dart` | Lista músicas, play/pause por item, floating AudioPlayerWidget |
| FavoritesScreen | `screens/favorites/favorites_screen.dart` | Lista favoritos (lições + músicas), navega para detalhe |
| ReviewsScreen | `screens/reviews/reviews_screen.dart` | Tab Revisões: banner de revisão diária + lista de lições ativas |
| ReviewSessionScreen | `screens/reviews/review_session_screen.dart` | Sessão de flashcard: progress bar, revelar resposta, Acertei/Errei, resumo |

### Splash screen

- `flutter_native_splash` com background preto + imagem.
- `flutter_launcher_icons` para ícone do app.

## O que NÃO fazer

- **Não usar GoRouter ou rotas declarativas** sem necessidade comprovada (a complexidade atual não justifica).
- **Não criar cores/estilos inline** — sempre usar `AppTheme` como fonte única.
- **Não usar fontes fora do Poppins** — a tipografia do app é consistente com uma única família.
- **Não instalar APKs debug para teste manual em dispositivo** — builds debug no Samsung ativam otimizador JIT (`dex2oat`) que causa tela preta permanente. Sempre usar `flutter build apk --release` + `adb install`.
- **Não usar GoRouter ou rotas declarativas** sem necessidade comprovada (a complexidade atual não justifica).
- **ReviewsScreen** mostra lista de lições ativas — não exibir lista de cards individuais nessa tela (isso é responsabilidade da `ReviewSessionScreen`).
