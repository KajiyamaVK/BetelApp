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
  | delete-bg | `#EF9A9A` | Background de botões de exclusão |
  | delete-text | `#C62828` | Texto de botões de exclusão |
  | success | `#81C784` | Estados de sucesso |
  | warning | `#E57373` | Estados de alerta / mensagens de erro inline |

- **Tipografia:** Poppins (sans) + Geist fonts bundled localmente.

- **Componentes shadcn/ui em uso:** accordion, alert-dialog, badge, button, checkbox, dialog, drawer, input, label, table.

- **`dialog` vs `alert-dialog`:** Use `alert-dialog` para confirmações destrutivas (delete, publish, unpublish) — bloqueia interação até ser dispensado. Use `dialog` para painéis não-bloqueantes (ImageGallery, EditLessonDialog) onde o usuário pode querer ver o contexto ao redor. Usos atuais:
  - `dialog`: `ImageGallery` (painel de seleção de imagens), `EditLessonDialog` (modal de edição de lição)
  - `alert-dialog`: Todas as confirmações destrutivas (delete de Q&A, arquivo, conteúdo, lição; publish/unpublish de lição e conteúdo; seletor de tipo de conteúdo)

- **Tiptap (WYSIWYG editor):** `@tiptap/react` + `@tiptap/starter-kit` + `@tiptap/extension-image`. Usado no editor de conteúdo texto. Configurado em `jest.config.ts` via `transformIgnorePatterns` (ESM-only).

### Layout

- **Desktop (≥768px):** Sidebar fixa + conteúdo à direita.
- **Mobile (<768px):** Drawer (hamburger menu).
- **Componentes de layout:** `Sidebar`, `Header`, `MobileDrawer` em `components/layout/`.
  - **`Sidebar`** (`hidden md:flex`): visível apenas em desktop (≥768px). Contém logo, nav items, username e botão de logout.
  - **`Header`** (`md:hidden`): visível apenas em mobile (<768px). Barra amarela (`bg-primary`) com o título "Portal Betel" e o botão hamburger que abre o `MobileDrawer`. Não existe header visível no desktop.
  - **`MobileDrawer`**: drawer lateral (direção `left`) controlado pelo `DashboardLayout` via estado `drawerOpen`.
- **DashboardLayout — loading state:** Retorna `null` enquanto o request `GET /api/auth/me` está pendente — a página fica em branco até o user ser carregado. Não há skeleton/spinner. Este é comportamento intencional; não adicionar loading state sem necessidade comprovada.

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
| `/privacy-policy` | `privacy-policy/page.tsx` | Pública | Política de Privacidade — exigida pela Play Store |

### Componentes de lições

- **`LessonList`** — container da lista de lições.
- **`LessonRow`** — linha expandível para cada lição. Botão lápis abre `EditLessonDialog` (título + ordem). Toggle publish com AlertDialog de confirmação. Botão lixeira (deletar lição) — **visível apenas para admins** (`isAdmin === true`), abre AlertDialog de confirmação com aviso de irreversibilidade. Indicadores de status de áudio/PDF (✓/⚠).
- **`FileRow`** — linha de upload/ação para cada tipo de arquivo (áudio ou PDF) dentro de uma LessonRow.
- **`CreateLessonDialog`** — dialog para criar nova lição (com upload opcional de arquivos). Campos: "Número da lição" (pré-preenchido com `max(id) + 1` das lições existentes, editável), "Título" (obrigatório), "PDF" (opcional), "Áudio" (opcional). O número sugerido usa `max(id)` e não `count` para tolerar gaps de lições deletadas. Erros de criação (ex: ID duplicado) são exibidos inline dentro do dialog sem fechá-lo.
- **`MiniPlayer`** — player de áudio inline com play/pause, barra de progresso, display de tempo.
- **`PdfViewer`** — preview de PDF: split-pane inline no desktop, modal fullscreen no mobile. Fecha com Escape.
- **`QASection`** — seção inline no `LessonRow` expandido para gerenciar Q&As da lição. Montada sob demanda (lazy mount) — `GET /api/lessons/[id]/questions` é chamado no mount, ou seja, apenas quando o usuário expande a linha. Cada expansão dispara um novo fetch (sem cache). Mostra spinner "Carregando perguntas..." durante o fetch inicial. Cards editáveis inline, formulário de adição com borda amarela tracejada, AlertDialog de confirmação para delete. Apenas um form aberto por vez (abrir add fecha edit e vice-versa).

### Componentes de usuários

- **`CreateUserForm`** — formulário de criação de usuário: campo `username` + checkbox `isAdmin`. **Sem campo de senha** — a senha inicial é sempre `123456` (setada pelo servidor). O formulário exibe uma nota informativa sobre isso. Envia `{ username, isAdmin }` ao `POST /api/users`.
- **`UserTable`** — tabela com ações por linha:
  - **Badge "Não acessou"** — exibido ao lado do username quando `mustChangePassword === true` (usuário criado ou com senha resetada que ainda não fez o primeiro login).
  - **Botão "Resetar senha"** — visível para todos os usuários, incluindo o próprio usuário logado.
  - **Botão "Deletar"** — escondido para o usuário logado atual; visível para todos os demais.

### Componentes de conteúdos

- **`ContentList`** — container da lista de conteúdos, mapeia `contents[]` → `ContentCard`.
- **`ContentCard`** — card para cada conteúdo. Mostra título, badge de tipo (VIDEO/TEXT com ícone), contagem de páginas (`{N} págs` quando multi-page), slug, botões de editar/publicar/deletar. Publish desabilitado se VIDEO sem `youtubeUrl`, TEXT single-page sem `htmlPath`, ou TEXT multi-page sem `pageCount > 0`. AlertDialogs de confirmação para publish/unpublish e delete (ver Padrões de interação).
- **`ContentForm`** — formulário de criação/edição. Dois modos por tipo:
  - **VIDEO:** input de título + URL do YouTube. Preview via iframe responsivo (16:9) quando a URL é reconhecida como YouTube válida. Formatos suportados: `youtu.be/ID`, `youtube.com/watch?v=ID`, `youtube.com/embed/ID`, `youtube.com/shorts/ID`. Extração do ID é client-side — sem chamada à API do YouTube. Se o ID não puder ser extraído, nenhum preview é exibido (sem erro).
  - **TEXT (single-page, legacy):** input de título + editor `TiptapEditor` com galeria de imagens. Em edição, HTML carregado do MinIO via URL pública.
  - **TEXT (multi-page):** sidebar lateral com lista de páginas ("Página 1", "Página 2", ...) e botão "+ Página". Cada página tem editor `TiptapEditor` independente (re-montado com `key={activePageIndex}` ao trocar de página). Botão X remove a página (mínimo 1 página obrigatória). Em edição, cada página filho é carregada via `GET /api/contents/[id]` + fetch do HTML do MinIO por filho.
  - Ao salvar conteúdo publicado, `AlertDialog` informa que o conteúdo foi auto-despublicado e deve ser republicado após revisão (`wasAutoUnpublished: true` na resposta da API).
  - Slug é auto-gerado pelo backend a partir do título — o campo slug não existe no formulário.
  - Full-screen form: substitui a lista (sem rota separada `/contents/new`).
- **`TiptapEditor`** — editor WYSIWYG baseado em Tiptap. Toolbar: Bold, Italic, H2, H3, Image. Imagens ocupam 100% width com height proporcional. Sync bidirecional via `useEffect`.
- **`ImageGallery`** — dialog com grid de imagens do MinIO. Upload + seleção. Click na imagem insere no editor.

### Componentes de navegação

- **Sidebar / MobileDrawer:** Navegação com três itens:
  - "Lições" (ícone `BookOpen`) — visível para todos os usuários autenticados.
  - "Conteúdos" (ícone `FileText`) — visível para todos os usuários autenticados (sem gating de admin).
  - "Usuários" (ícone `Users`) — visível **somente quando `isAdmin: true`**. O `DashboardLayout` busca o usuário em `/api/auth/me` e passa `isAdmin` como prop para `Sidebar` e `MobileDrawer`.
  - Ambos os componentes aplicam o mesmo gating — o item "Usuários" não aparece para usuários não-admin em nenhum viewport.

### Padrões de interação

- **Edição de lição:** Clicar no botão lápis (`edit-lesson-btn`) abre `EditLessonDialog` — um `Dialog` com campos para título e número de exibição (`order`). Salvar chama `PUT /api/lessons/[id]`; cancelar ou fechar restaura os valores anteriores. O dialog exibe mensagem de erro inline se o `order` já estiver em uso (409). Double-click no título não está mais mapeado a nenhuma ação.
- **Publish guard:** Botão de publicar desabilitado se a lição não tem PDF ativo.
- **Publish/unpublish confirmation:** Clicar no botão "Publicar" ou "Despublicar" não dispara a API imediatamente. Abre um `AlertDialog` com:
  - Publicar: "A lição ficará visível no app mobile imediatamente."
  - Despublicar: "A lição será removida do app mobile imediatamente."
  O botão "Confirmar" no dialog dispara a requisição e mostra um spinner com "Aguarde..." enquanto aguarda a resposta. Cancelar fecha o dialog sem alterar o estado da lição.
- **Delete+unpublish warning:** Ao deletar PDF de uma lição publicada, dialog de confirmação avisa que a lição será despublicada também.
- **Confirmações destructivas:** Todas as ações de exclusão (arquivo, usuário, Q&A) usam `AlertDialog` do shadcn com texto explícito do impacto.
- **Usuários — confirmação de delete:** AlertDialog com texto "Esta ação é irreversível. O usuário será removido permanentemente." Spinner inline no botão durante a operação.
- **Usuários — confirmação de reset de senha:** AlertDialog com texto "A senha do usuário será redefinida para **123456**. Ele deverá trocá-la no próximo acesso." Spinner inline no botão durante a operação.
- **Usuários — feedback de reset bem-sucedido:** Banner verde inline exibido após reset concluído, com o nome do usuário e instruções (`Senha de "{username}" resetada para 123456. O usuário deverá trocá-la no próximo acesso.`). Fechado manualmente pelo admin (sem auto-dismiss). A linha do usuário na tabela tem `mustChangePassword: true` atualizado localmente após o reset (otimista), sem reload completo da lista.
- **Q&A inline editing:** Cards de Q&A em `LessonRow` mostram pergunta e resposta. Clicar no ícone de edição substitui o card por inputs inline. Salvar chama PATCH; cancelar restaura o card. Deletar abre AlertDialog mostrando o texto da pergunta.
- **Conteúdo — type picker:** Ao criar novo conteúdo, `AlertDialog` com dois card-buttons em grid de 2 colunas. Cada card mostra o ícone lucide (`Video` ou `FileText`), um label ("Vídeo" / "Texto") e um subtítulo ("YouTube" / "Editor com imagens"). Cards têm `hover:border-primary hover:bg-yellow-50`. Um botão "Cancelar" fecha o dialog sem criar. Seleção fecha o dialog e abre `ContentForm` em full-screen substituindo a lista.
- **Conteúdo — publish guard:** Publicar desabilitado se VIDEO sem `youtubeUrl`, TEXT single-page sem `htmlPath`, ou TEXT multi-page sem `pageCount > 0`. Botão tristate (gray disabled → gray unpublished → green published). Clicar no botão abre `AlertDialog` de confirmação antes de chamar a API:
  - Publicar: "O conteúdo ficará disponível no app mobile imediatamente."
  - Despublicar: "O conteúdo será removido do app mobile imediatamente."
  Botão Confirmar mostra spinner `Loader2` durante o request.
- **Delete de conteúdo:** `AlertDialog` no `ContentCard` com texto explícito: "Esta ação é irreversível. O conteúdo será removido do banco, do manifest e todos os arquivos serão deletados do storage."
- **Erros de conteúdo:** Publish/unpublish, delete e save do `ContentForm` exibem banner vermelho descartável no topo da `ContentsPage` (mesmo padrão da `LessonsPage`). Não há falhas silenciosas nas páginas de Lições e Conteúdos.

## O que NÃO fazer

- **Não adicionar lib de estado global** (Redux, Zustand) sem necessidade comprovada — o app é um CRUD admin, `useState` é suficiente.
- **Não usar Server Components com data fetching** para as páginas de dashboard — a arquitetura atual usa client-side fetch para simplificar mutations e re-fetch.
- **Não criar componentes fora do sistema shadcn/ui** para primitivos (button, dialog, table, input) — usar os existentes em `components/ui/`.
- **Não usar cores hardcoded** — sempre usar os tokens definidos em `tailwind.config.ts`.
