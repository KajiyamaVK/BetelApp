---
layer: business
project: s3-ui
last_reviewed: 2026-06-13
---

## Propósito

Governa regras de negócio do s3-ui — fluxos de autenticação, permissões, validações, e comportamentos esperados do painel web.

## Decisões

### Autenticação

- **JWT customizado com `jose` (HS256)** — sem NextAuth, sem Auth.js.
  - **Por quê:** O app é interno, com poucos usuários. A complexidade de NextAuth não se justifica para um sistema de admin com auth simples.

- **Token:** cookie `httpOnly` chamado `token`, `sameSite: lax`, `secure: true` em produção, expira em 7 dias.

- **Payload do JWT:** `{ id, username, isAdmin, mustChangePassword }`.

- **Duas funções guard:**
  | Guard | Verifica | Onde usado |
  |-------|----------|------------|
  | `requireAuth(req)` | JWT válido → retorna `{ userId }` | Mutations de lição |
  | `requireAdmin(req)` | JWT válido + **re-query ao DB** para confirmar `isAdmin` | Todas as rotas de `/api/users` |

- **`requireAdmin` faz DB lookup deliberadamente** — garante que revogar `isAdmin` no banco tem efeito imediato, sem esperar o JWT de 7 dias expirar.

- **Assimetria middleware vs. API:**
  - **Middleware (Edge Runtime):** Verifica `isAdmin` pelo claim do JWT (sem Prisma disponível no Edge). Revogação de admin não é instantânea no middleware — depende da expiração do JWT.
  - **API routes (Node Runtime):** `requireAdmin` faz lookup ao DB (revogação instantânea).
  - **Por quê:** Prisma não roda no Edge Runtime. A proteção real está nas API routes; o middleware é defense-in-depth.

### Middleware

- **Paths públicos:** `/login`, `/change-password`, `/api/auth/login`, `/api/auth/change-password`.
- **Auth guard:** Token ausente ou inválido → redirect para `/login`.
- **Force password change:** `mustChangePassword === true` → redirect para `/change-password` (exceto rotas `/api/` e a própria `/change-password`).
- **Admin guard:** `/users` e `/api/users` requerem `isAdmin === true` no JWT.

### Senhas

- **Hashing:** `bcryptjs` com salt rounds = 12.
- **Senha padrão:** `123456` — usada na criação e no reset de senha.
- **`mustChangePassword: true`** setado em criação e reset — o middleware força troca antes de qualquer acesso.
- **Regras de troca:** mínimo 6 caracteres, `password === confirmPassword`. Validação duplicada: UI + API (Zod).
- **⚠️ Gap conhecido:** Não há validação server-side impedindo que o usuário defina a senha de volta para `123456`. O texto da UI sugere que não pode, mas o servidor aceita.
- **Login genérico:** Retorna `"Invalid credentials"` tanto para username inexistente quanto para senha errada (sem oracle de enumeração).

### Lições — regras de negócio

- **Criar lição:** `id` (int positivo) + `title` (non-empty). O `id` é manual, não autoincrement. Duplicação retorna 409.

- **`id` vs `order`:** `id` é a chave interna (usada nos paths do MinIO). `order` é o número de exibição da lição no app mobile e no painel admin. São independentes — o admin pode reordenar sem alterar os paths de arquivo.

- **Publicar/despublicar:**
  - **Publicar:** Reconstrói a entrada no `manifest.json` a partir dos metadados do DB. Requer que `pdfActive` exista.
  - **Despublicar:** Remove a lição inteiramente do manifest. A lição desaparece do app mobile imediatamente.

- **Editar lição (título e/ou ordem):** `PUT /api/lessons/[id]` aceita `{ title?, order? }` (ao menos um obrigatório). Se `title` foi alterado, atualiza o `manifest.json` via `renameLesson` e incrementa `version`. Alteração de `order` não afeta o manifest — é apenas um número de exibição no painel e no app.

- **Hard-delete de arquivo:** Remove o path `active` do DB, seta `active: null`, e **deleta o arquivo real do MinIO** via `deleteObject`. Não há mais soft-delete — arquivos deletados não são recuperáveis.
  - **Por quê:** Comportamento esperado pelo admin; soft-delete adicionava complexidade sem benefício real para este contexto.

- **Delete de lição:** Remove a lição do DB, do manifest, **todas as questões associadas** (hard-delete), e todos os arquivos do MinIO via `deleteFolder`.

- **Delete PDF + auto-unpublish:** Se o PDF de uma lição publicada é deletado, a lição é automaticamente despublicada (confirmação obrigatória no dialog).

### File upload

- **Tipos aceitos:**
  - Áudio: `audio/mpeg` (MP3 apenas)
  - PDF: `application/pdf`

- **Sem limite de tamanho** — nenhuma validação de tamanho no servidor. ⚠️ Gap conhecido.

- **Versionamento de arquivos:** Paths são versionados como `lessons/{id}/audio_v{N}.mp3` e `lessons/{id}/lesson_v{N}.pdf`. `N` é calculado por regex `/_v(\d+)\.(mp3|pdf)$/` no histórico.

- **Checksum:** MD5 hex calculado server-side. Armazenado no DB e no manifest.

### Manifest

- **Formato:** `{ version: number, updated_at: string, lessons: ManifestLesson[], contents: ManifestContent[] }`.
- **Backward compat:** Manifests existentes podem não ter `contents`. Normalizado em `parseManifest` com `contents: raw.contents ?? []`.
- **Evolução in-place:** Nunca é regenerado do zero — sempre read-then-modify do MinIO.
- **`version` incrementa** em: criar lição, publicar, despublicar.
- **`version` NÃO incrementa** em: upload de arquivo, delete de arquivo (apenas `updated_at` é bumped).
  - **Por quê:** O app mobile usa `version` para decidir se faz sync. Upload/delete de arquivo sem incrementar `version` significa que o mobile só pega mudanças quando a lição é (re-)publicada.

- **`version` INCREMENTA** em: criar lição, publicar, despublicar, **renomear título**.
  - **Por quê:** Sem o bump no rename, o app mobile nunca sincroniza mudanças de título (o sync é baseado apenas em `version`).

### Usuários

- **Dois papéis:** `isAdmin: true` (admin completo) ou `false` (pode gerenciar lições).
- **Sem super-admin** — qualquer admin pode fazer tudo.
- **Self-delete bloqueado:** Admin não pode deletar o próprio usuário (403).
- **Sem edição de usuário** — não existe `PUT /api/users/[id]`. As únicas mutations são: criar, deletar, reset senha.
- **Reset de senha:** Volta para `123456` com `mustChangePassword: true`.

### Q&A (perguntas e respostas)

- **Campo `order`:** Calculado no backend via `MAX(order) + 1` das questões ativas da lição. O frontend não envia `order` no POST.
  - **Por quê:** `order: questions.length` no frontend falha quando há gaps de deleções — duas questões podem receber o mesmo `order`. O backend é a única fonte confiável.

- **Delete de questão:** Soft-delete (seta `deletedAt`). O registro permanece no banco para auditoria via `QuestionAuditLog`.

### Conteúdos — regras de negócio

- **Headless CMS minimalista:** O portal cria e edita conteúdos. O dev do app mobile decide onde cada conteúdo aparece, hardcoded por slug (ex: `BetelDialog.show(context, contentSlug: 'welcome-video')`).

- **Dois tipos:** `VIDEO` (YouTube URL) e `TEXT` (HTML com imagens via editor WYSIWYG).
  - `type` não pode ser alterado após criação — delete + recreate se necessário.

- **Slug:** Identificador único imutável para uso no código mobile. Regex `/^[a-z0-9-]+$/` — apenas letras minúsculas, números e hífens. Único no banco (409 se duplicado).

- **Criar conteúdo:** `slug` + `title` + `type` (+ `youtubeUrl` se VIDEO). `id` é autoincrement (diferente de Lesson). Criar não toca o manifest — conteúdo precisa ser publicado separadamente.

- **Editar conteúdo:** `PUT /api/contents/[id]`. Aceita `slug`, `title`, `youtubeUrl`, `order` + campo `html` (string). O `html` é enviado como JSON, mas o backend o salva como arquivo no MinIO (`contents/{id}/content.html`). Se o conteúdo está publicado, a edição sincroniza o manifest automaticamente (best-effort).

- **Publicar/despublicar:**
  - **Publicar VIDEO:** Monta `ManifestContentVideo` com `youtubeUrl` e chama `upsertContent`.
  - **Publicar TEXT:** Lê HTML do MinIO via `getObjectText(htmlPath)`, inline no manifest como campo `html` do `ManifestContentText`, chama `upsertContent`.
  - **Publish guard:** TEXT sem `htmlPath` → 400 (análogo a lição sem PDF). VIDEO sem `youtubeUrl` → desabilitado na UI.
  - **Despublicar:** Chama `removeContent` — conteúdo desaparece do app mobile imediatamente.

- **HTML inlined no manifest:** O HTML do conteúdo TEXT é armazenado como arquivo no MinIO para edição, mas é **inlined diretamente** no `manifest.json` ao publicar. O mobile lê um único arquivo e tem todo o conteúdo.
  - **Por quê:** Evita requests extras no mobile. O manifest é leve o suficiente para incluir HTML inline.

- **Galeria de imagens:** Imagens compartilhadas em `contents/images/` — não vinculadas a um conteúdo específico. Delete de conteúdo deleta `contents/{id}/` mas NÃO `contents/images/`.
  - **Tipos aceitos:** JPEG, PNG, GIF, WebP. Nomes gerados com `crypto.randomUUID()`.
  - **Sem limite de tamanho** — ⚠️ gap conhecido (mesmo que lições).

- **Delete de conteúdo:** Remove do DB, do manifest (best-effort), e deleta pasta `contents/{id}/` do MinIO. Hard-delete irreversível.

### Input validation

- **Zod** em todas as API routes — `loginSchema`, `createUserSchema`, `uploadQuerySchema`, `updateTitleSchema`, `togglePublishSchema`, `createLessonSchema`, `createContentSchema`, `updateContentSchema` em `lib/schemas.ts`.
- **`createContentSchema`** usa `z.discriminatedUnion('type', [...])` para validar VIDEO vs TEXT separadamente.
- **`updateContentSchema`** não permite alterar `type`.
- Erro de validação retorna 400 com a primeira mensagem do Zod.

### Error handling

- **API:** Validation via Zod → 400. Auth guard → 401/403. Prisma P2002 (unique) → 409. Demais erros Prisma e MinIO → 500 genérico ou bubble up não tratado.
- **UI:** Erros de formulário exibidos inline. ⚠️ **Upload e publish toggle não exibem erros** — falhas são silenciosas.

## O que NÃO fazer

- **Não migrar para NextAuth/Auth.js** sem necessidade — o sistema JWT custom atende o escopo atual.
- **Não confiar no middleware Edge para proteção de admin** — ele usa claims stale do JWT. A proteção real é `requireAdmin()` nas API routes.
- **Não criar endpoint de edição de `isAdmin` via API** sem redesenhar o fluxo — atualmente a única forma de revogar admin é diretamente no DB.
- **Não gerar manifest do zero** — sempre ler o existente do MinIO e modificar. A geração from-scratch pode perder histórico de versões de arquivos.
- **Não implementar soft-delete de arquivo** — o projeto usa hard-delete. Arquivos deletados não são recuperáveis; essa é a decisão tomada conscientemente.
- **Não aceitar tipos de áudio além de MP3** sem atualizar o content type no upload e o client mobile.
