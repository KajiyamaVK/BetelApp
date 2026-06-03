---
layer: business
project: s3-ui
last_reviewed: 2026-05-31
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

- **Publicar/despublicar:**
  - **Publicar:** Reconstrói a entrada no `manifest.json` a partir dos metadados do DB. Requer que `pdfActive` exista.
  - **Despublicar:** Remove a lição inteiramente do manifest. A lição desaparece do app mobile imediatamente.

- **Editar título:** Atualiza apenas o DB. ⚠️ **O `manifest.json` não é atualizado** — o título no manifest pode ficar stale até o próximo publish/upload.

- **Soft-delete de arquivo:** Move o path `active` para `history`, seta `active: null`. O arquivo real permanece no MinIO (nunca é deletado do bucket).
  - **Por quê:** Permite rollback e auditoria. Storage é barato; a complexidade de cleanup não se justifica.

- **Delete PDF + auto-unpublish:** Se o PDF de uma lição publicada é deletado, a lição é automaticamente despublicada (confirmação obrigatória no dialog).

### File upload

- **Tipos aceitos:**
  - Áudio: `audio/mpeg` (MP3 apenas)
  - PDF: `application/pdf`

- **Sem limite de tamanho** — nenhuma validação de tamanho no servidor. ⚠️ Gap conhecido.

- **Versionamento de arquivos:** Paths são versionados como `lessons/{id}/audio_v{N}.mp3` e `lessons/{id}/lesson_v{N}.pdf`. `N` é calculado por regex `/_v(\d+)\.(mp3|pdf)$/` no histórico.

- **Checksum:** MD5 hex calculado server-side. Armazenado no DB e no manifest.

### Manifest

- **Formato:** `{ version: number, updated_at: string, lessons: ManifestLesson[] }`.
- **Evolução in-place:** Nunca é regenerado do zero — sempre read-then-modify do MinIO.
- **`version` incrementa** em: criar lição, publicar, despublicar.
- **`version` NÃO incrementa** em: upload de arquivo, soft-delete de arquivo (apenas `updated_at` é bumped).
  - **Por quê:** O app mobile usa `version` para decidir se faz sync. Upload/delete de arquivo sem incrementar `version` significa que o mobile só pega mudanças quando a lição é (re-)publicada.

### Usuários

- **Dois papéis:** `isAdmin: true` (admin completo) ou `false` (pode gerenciar lições).
- **Sem super-admin** — qualquer admin pode fazer tudo.
- **Self-delete bloqueado:** Admin não pode deletar o próprio usuário (403).
- **Sem edição de usuário** — não existe `PUT /api/users/[id]`. As únicas mutations são: criar, deletar, reset senha.
- **Reset de senha:** Volta para `123456` com `mustChangePassword: true`.

### Input validation

- **Zod** em todas as API routes — `loginSchema`, `createUserSchema`, `uploadQuerySchema`, `updateTitleSchema`, `togglePublishSchema`, `createLessonSchema` em `lib/schemas.ts`.
- Erro de validação retorna 400 com a primeira mensagem do Zod.

### Error handling

- **API:** Validation via Zod → 400. Auth guard → 401/403. Prisma P2002 (unique) → 409. Demais erros Prisma e MinIO → 500 genérico ou bubble up não tratado.
- **UI:** Erros de formulário exibidos inline. ⚠️ **Upload e publish toggle não exibem erros** — falhas são silenciosas.

## O que NÃO fazer

- **Não migrar para NextAuth/Auth.js** sem necessidade — o sistema JWT custom atende o escopo atual.
- **Não confiar no middleware Edge para proteção de admin** — ele usa claims stale do JWT. A proteção real é `requireAdmin()` nas API routes.
- **Não criar endpoint de edição de `isAdmin` via API** sem redesenhar o fluxo — atualmente a única forma de revogar admin é diretamente no DB.
- **Não gerar manifest do zero** — sempre ler o existente do MinIO e modificar. A geração from-scratch pode perder histórico de versões de arquivos.
- **Não implementar hard-delete no MinIO** sem sistema de backup — arquivos soft-deleted podem ser necessários para rollback.
- **Não aceitar tipos de áudio além de MP3** sem atualizar o content type no upload e o client mobile.
