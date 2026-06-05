---
layer: ui
project: s3-ui
last_reviewed: 2026-06-05
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

### Padrões de interação

- **Inline editing:** Double-click no título da lição **ou clique no botão lápis** ativa input inline. Enter salva, Escape cancela.
- **Publish guard:** Botão de publicar desabilitado se a lição não tem PDF ativo.
- **Delete+unpublish warning:** Ao deletar PDF de uma lição publicada, dialog de confirmação avisa que a lição será despublicada também.
- **Confirmações destructivas:** Todas as ações de exclusão (arquivo, usuário, Q&A) usam `AlertDialog` do shadcn com texto explícito do impacto.
- **Q&A inline editing:** Cards de Q&A em `LessonRow` mostram pergunta e resposta. Clicar no ícone de edição substitui o card por inputs inline. Salvar chama PATCH; cancelar restaura o card. Deletar abre AlertDialog mostrando o texto da pergunta.

## O que NÃO fazer

- **Não adicionar lib de estado global** (Redux, Zustand) sem necessidade comprovada — o app é um CRUD admin, `useState` é suficiente.
- **Não usar Server Components com data fetching** para as páginas de dashboard — a arquitetura atual usa client-side fetch para simplificar mutations e re-fetch.
- **Não criar componentes fora do sistema shadcn/ui** para primitivos (button, dialog, table, input) — usar os existentes em `components/ui/`.
- **Não usar cores hardcoded** — sempre usar os tokens definidos em `tailwind.config.ts`.
