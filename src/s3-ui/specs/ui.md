---
layer: ui
project: s3-ui
last_reviewed: 2026-06-13
---

## Propósito

Governa decisões de interface do s3-ui — componentes, layouts, padrões visuais, e comportamento de telas do painel web.

## Decisões

### Framework e stack

- **Next.js 14 (App Router)** — sem Pages Router. Output mode `standalone` para deploy em Docker.
  - **Por quê:** App Router é o padrão atual do Next.js. Standalone simplifica o container.

- **Route groups:**
  - `app/(auth)/` — páginas públicas (login, change-password)
  - `app/(dashboard)/` — páginas autenticadas com layout compartilhado (sidebar)
  - `app/api/` — API route handlers REST

### Design system

- **Tailwind CSS v3 + shadcn/ui** (style: `base-nova`, ícones: `lucide`).

- **Paleta de cores** (tokens em `tailwind.config.ts`):
  | Token | Valor | Uso |
  |-------|-------|-----|
  | primary | `#FFBD00` (amarelo) | Botões, destaques, accents |
  | background | `#F5F5F5` | Background geral |
  | surface | `#FFFFFF` | Cards, áreas de conteúdo |
  | text-main | `#333333` | Texto principal |
  | delete-bg/delete-text | — | Botões de exclusão |
  | success | — | Estados de sucesso |
  | warning | — | Estados de alerta |

- **Tipografia:** Poppins (sans) + Geist fonts bundled localmente.

- **Componentes shadcn/ui em uso:** accordion, alert-dialog, badge, button, checkbox, dialog, drawer, input, label, table.

- **Tiptap (WYSIWYG editor):** `@tiptap/react` + `@tiptap/starter-kit` + `@tiptap/extension-image`. Usado no editor de conteúdo texto. Configurado em `jest.config.ts` via `transformIgnorePatterns` (ESM-only).

### Layout

- **Desktop (≥768px):** Sidebar fixa + conteúdo à direita.
- **Mobile (<768px):** Drawer (hamburger menu).
- **Componentes de layout:** `Sidebar`, `Header`, `MobileDrawer` em `components/layout/`.

### State management

- **Sem biblioteca externa** — sem Redux, Zustand, Jotai, React Query.
- **React `useState` + `useEffect` + `fetch()`** para todo estado e fetching.
  - **Por quê:** O app é um CRUD administrativo com poucas telas. A complexidade de uma lib de estado não se justifica.
- Cada página (`LessonsPage`, `UsersPage`) é dona do seu estado local.
- `DashboardLayout` mantém o estado do `user` (fetched de `/api/auth/me`) e `drawerOpen`.

### Telas e rotas

| Rota | Página | Auth | Função |
|------|--------|------|--------|
| `/` | redirect | — | Redireciona para `/lessons` |
| `/login` | `(auth)/login/page.tsx` | Pública | Login com username/password |
| `/change-password` | `(auth)/change-password/page.tsx` | JWT | Troca obrigatória de senha |
| `/lessons` | `(dashboard)/lessons/page.tsx` | JWT | Lista, upload, publish, preview de lições |
| `/contents` | `(dashboard)/contents/page.tsx` | JWT | Criação e edição de conteúdos (headless CMS) |
| `/users` | `(dashboard)/users/page.tsx` | Admin | Gerenciamento de usuários |

### Componentes de lições

- **`LessonList`** — container da lista de lições.
- **`LessonRow`** — linha expandível para cada lição. Inline edit (double-click no título **ou botão lápis**), toggle publish, botão lápis (editar título), botão lixeira (deletar lição), indicadores de status de áudio/PDF.
- **`FileRow`** — linha de upload/ação para cada tipo de arquivo (áudio ou PDF) dentro de uma LessonRow.
- **`CreateLessonDialog`** — dialog para criar nova lição (com upload opcional de arquivos).
- **`MiniPlayer`** — player de áudio inline com play/pause, barra de progresso, display de tempo.
- **`PdfViewer`** — preview de PDF: split-pane inline no desktop, modal fullscreen no mobile. Fecha com Escape.
- **`QASection`** — seção inline no `LessonRow` expandido para gerenciar Q&As da lição. Cards editáveis inline, formulário de adição com borda amarela tracejada, AlertDialog de confirmação para delete. Apenas um form aberto por vez (abrir add fecha edit e vice-versa).

### Componentes de usuários

- **`CreateUserForm`** — formulário de criação de usuário (username + isAdmin toggle).
- **`UserTable`** — tabela com ações (delete, reset password). Botão delete escondido para o usuário atual.

### Componentes de conteúdos

- **`ContentList`** — container da lista de conteúdos, mapeia `contents[]` → `ContentCard`.
- **`ContentCard`** — card para cada conteúdo. Mostra título, badge de tipo (VIDEO/TEXT com ícone), slug, botões de editar/publicar/deletar. Publish desabilitado se VIDEO sem `youtubeUrl` ou TEXT sem `htmlPath`. AlertDialogs de confirmação inline no card (mesmo padrão de `LessonRow`).
- **`ContentForm`** — formulário de criação/edição. Dois modos por tipo:
  - **VIDEO:** inputs de título + slug + URL do YouTube. Preview via iframe responsivo (16:9) quando URL válida.
  - **TEXT:** inputs de título + slug + editor `TiptapEditor` com galeria de imagens.
  - Em edição de TEXT, o HTML existente é carregado do MinIO via URL pública.
  - Slug é auto-sanitizado no `onChange` (lowercase + strip invalid chars).
  - Full-screen form: substitui a lista (sem rota separada `/contents/new`).
- **`TiptapEditor`** — editor WYSIWYG baseado em Tiptap. Toolbar: Bold, Italic, H2, H3, Image. Imagens ocupam 100% width com height proporcional. Sync bidirecional via `useEffect`.
- **`ImageGallery`** — dialog com grid de imagens do MinIO. Upload + seleção. Click na imagem insere no editor.

### Componentes de navegação

- **Sidebar / MobileDrawer:** Item "Conteúdos" (ícone `FileText`) entre "Lições" e "Usuários". Sem gating de admin — mesma visibilidade que Lições.

### Padrões de interação

- **Inline editing:** Double-click no título da lição **ou clique no botão lápis** ativa input inline. Enter salva, Escape cancela.
- **Publish guard:** Botão de publicar desabilitado se a lição não tem PDF ativo.
- **Delete+unpublish warning:** Ao deletar PDF de uma lição publicada, dialog de confirmação avisa que a lição será despublicada também.
- **Confirmações destructivas:** Todas as ações de exclusão (arquivo, usuário, Q&A) usam `AlertDialog` do shadcn com texto explícito do impacto.
- **Q&A inline editing:** Cards de Q&A em `LessonRow` mostram pergunta e resposta. Clicar no ícone de edição substitui o card por inputs inline. Salvar chama PATCH; cancelar restaura o card. Deletar abre AlertDialog mostrando o texto da pergunta.
- **Conteúdo — type picker:** Ao criar novo conteúdo, AlertDialog com 2 botões ícone (🎬 Vídeo, 📝 Texto). Seleção abre `ContentForm` em full-screen.
- **Conteúdo — publish guard:** Publicar desabilitado se VIDEO sem `youtubeUrl` ou TEXT sem `htmlPath`. Mesma UX tristate do `LessonRow` (gray disabled → gray unpublished → green published).

## O que NÃO fazer

- **Não adicionar lib de estado global** (Redux, Zustand) sem necessidade comprovada — o app é um CRUD admin, `useState` é suficiente.
- **Não usar Server Components com data fetching** para as páginas de dashboard — a arquitetura atual usa client-side fetch para simplificar mutations e re-fetch.
- **Não criar componentes fora do sistema shadcn/ui** para primitivos (button, dialog, table, input) — usar os existentes em `components/ui/`.
- **Não usar cores hardcoded** — sempre usar os tokens definidos em `tailwind.config.ts`.
