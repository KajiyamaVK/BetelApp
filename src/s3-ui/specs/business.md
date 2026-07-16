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

- **Token:** cookie `httpOnly` chamado `token`, `sameSite: lax`, `secure: true` em produção.
  - **Expiração dupla:** `maxAge: 604800` (7 dias em segundos) no cookie **e** `exp` de 7 dias no payload JWT. Ambos são definidos em conjunto em `/api/auth/login` e `/api/auth/change-password`. Mesmo que o cookie persista além do prazo, o JWT será rejeitado por `verifyToken` quando o `exp` vencer.

- **Payload do JWT:** `{ id, username, isAdmin, mustChangePassword }`.

- **Duas funções guard:**
  | Guard | Verifica | Onde usado |
  |-------|----------|------------|
  | `requireAuth(req)` | JWT válido → retorna `{ userId, username }` | Mutations de lição |
  | `requireAdmin(req)` | JWT válido + **re-query ao DB** para confirmar `isAdmin` | Todas as rotas de `/api/users` |

- **`requireAdmin` faz DB lookup deliberadamente** — garante que revogar `isAdmin` no banco tem efeito imediato, sem esperar o JWT de 7 dias expirar.

- **`GET /api/auth/me`:** Retorna `{ id, username, isAdmin }` a partir do JWT existente no cookie. Retorna 401 se o token estiver ausente ou inválido. **Não** retorna `mustChangePassword`. Usado pelo frontend para identificar o usuário logado sem fazer um DB lookup adicional.

- **Logout:** `POST /api/auth/logout` — limpa o cookie `token` definindo `maxAge: 0`. Não há invalidação server-side (sem blocklist). O token continua tecnicamente válido até seu vencimento de 7 dias, mas sem o cookie o browser não o reenvia.

- **Resposta do login:** `POST /api/auth/login` retorna `{ ok: true, mustChangePassword: boolean }`. O frontend usa `mustChangePassword` para redirecionar imediatamente para `/change-password` (se `true`) ou `/lessons` (se `false`) sem esperar o middleware interceptar a próxima navegação.

- **Dois módulos de auth:**
  - `lib/auth.ts` — módulo completo: `signToken`, `verifyToken`, `requireAuth`, `requireAdmin`, `TOKEN_COOKIE`. Importa `prisma` — somente Node.js Runtime.
  - `lib/auth-edge.ts` — subconjunto Edge-compatível: apenas `verifyToken` e `TOKEN_COOKIE`. Sem import do Prisma. Usado exclusivamente pelo `middleware.ts`.
  - **Regra:** O middleware deve importar de `auth-edge.ts`. Importar `auth.ts` no middleware causa falha de build/runtime no Edge Runtime porque o Prisma não está disponível. Ver tabela completa em `infra.md` → Módulos de auth por runtime.

- **Assimetria middleware vs. API:**
  - **Middleware (Edge Runtime):** Verifica `isAdmin` pelo claim do JWT (sem Prisma disponível no Edge). Revogação de admin não é instantânea no middleware — depende da expiração do JWT.
  - **API routes (Node Runtime):** `requireAdmin` faz lookup ao DB (revogação instantânea).
  - **Por quê:** Prisma não roda no Edge Runtime. A proteção real está nas API routes; o middleware é defense-in-depth.

### Middleware

- **Paths públicos:** `/login`, `/change-password`, `/api/auth/login`, `/api/auth/change-password`, `/privacy-policy`.
  - `/privacy-policy` é público para cumprir requisitos legais da Play Store — não requer login.
- **Auth guard:** Token ausente ou inválido → redirect para `/login`.
- **Force password change:** `mustChangePassword === true` → redirect para `/change-password` (exceto rotas `/api/` e a própria `/change-password`).
- **Admin guard:** `/users` e `/api/users` requerem `isAdmin === true` no JWT.
  - Falha em rota de página (`/users*`): redireciona para `/lessons`.
  - Falha em rota de API (`/api/users*`): retorna JSON `{ error: 'Forbidden' }` com status 403.
- **Matcher:** O middleware não é invocado para `_next/static/**`, `_next/image/**` e `favicon.ico` (excluídos via `config.matcher`). Esses assets estáticos não passam por verificação de autenticação — são sempre servidos sem token. Todos os outros paths (incluindo rotas de API) passam pelo middleware.

### Senhas

- **Hashing:** `bcryptjs` com salt rounds = 12.
- **Senha padrão:** `123456` — usada na criação e no reset de senha.
- **`mustChangePassword: true`** setado em criação e reset — o middleware força troca antes de qualquer acesso.
- **Regras de troca:** mínimo 6 caracteres, `password === confirmPassword`. Validação duplicada: UI + API (Zod).
- **Proibição de senha padrão:** A API `/api/auth/change-password` rejeita explicitamente `123456` com status 400 (`"A senha não pode ser 123456"`). A UI exibe a restrição e o servidor a reforça — não há discrepância.
- **JWT rotacionado na troca:** `POST /api/auth/change-password` emite um novo JWT com `mustChangePassword: false` e o grava no cookie imediatamente na resposta. Sem essa rotação, o middleware continuaria redirecionando para `/change-password` em todas as requisições seguintes até o token original expirar, porque o claim `mustChangePassword` no JWT antigo ainda seria `true`.
- **Login genérico:** Retorna `"Invalid credentials"` tanto para username inexistente quanto para senha errada (sem oracle de enumeração).

### Lições — regras de negócio

- **Criar lição:** `id` (int positivo) + `title` (non-empty). O `id` é manual, não autoincrement. Duplicação retorna 409. O campo `order` é inicializado automaticamente com o mesmo valor de `id` na criação — o admin não precisa fornecê-lo. Pode ser alterado depois via `PUT /api/lessons/[id]`.

- **`id` vs `order`:** `id` é a chave interna (usada nos paths do MinIO). `order` é o número de exibição da lição no app mobile e no painel admin. São independentes — o admin pode reordenar sem alterar os paths de arquivo.

- **Publicar/despublicar:**
  - **Publicar:** Reconstrói a entrada no `manifest.json` a partir dos metadados do DB. Requer que `pdfActive` exista.
  - **Despublicar:** Remove a lição inteiramente do manifest. A lição desaparece do app mobile imediatamente.

- **Editar lição (título e/ou ordem):** `PUT /api/lessons/[id]` aceita `{ title?, order? }` (ao menos um obrigatório). Se `title` foi alterado, atualiza o `manifest.json` via `renameLesson` e incrementa `version`. Alteração de `order` não afeta o manifest — é apenas um número de exibição no painel e no app.
- **Conflito de `order`:** Se o novo `order` já está em uso por outra lição, `PUT /api/lessons/[id]` retorna 409 com `"Esse número de lição já está em uso"`. O frontend exibe o erro inline no `EditLessonDialog`.

- **Hard-delete de arquivo:** Remove o path `active` do DB, seta `active: null`, e **deleta o arquivo real do MinIO** via `deleteObject`. Não há mais soft-delete — arquivos deletados não são recuperáveis.
  - **Por quê:** Comportamento esperado pelo admin; soft-delete adicionava complexidade sem benefício real para este contexto.

- **Delete de lição:** Remove a lição do DB, do manifest, **todas as questões associadas** (hard-delete), e todos os arquivos do MinIO via `deleteFolder`. Antes de deletar, escreve uma entrada em `LessonAuditLog` com `action: 'delete'` e o `userId` do admin que executou a ação. O log usa plain Int (sem FK) e sobrevive ao delete da lição.
- **Delete de lição — guard:** `DELETE /api/lessons/[id]` requer `requireAdmin`. Na UI, o botão de delete só é renderizado quando `isAdmin === true` (verificado via `/api/auth/me` no carregamento da página).

- **Delete PDF + auto-unpublish:** Se o PDF de uma lição publicada é deletado, a lição é automaticamente despublicada (confirmação obrigatória no dialog).

### File upload

- **Tipos aceitos:**
  - Áudio: `audio/mpeg` (MP3 apenas)
  - PDF: `application/pdf`

- **Limites de tamanho:**
  - PDF: máximo **50 MB**. Servidor retorna 413 com mensagem em português quando excedido.
  - Áudio: máximo **20 MB**. Servidor retorna 413 com mensagem em português quando excedido.
  - Validação dupla: client-side (alerta nativo antes do upload) e server-side (header `Content-Length` + tamanho real do `File`).

- **Versionamento de arquivos:** Paths são versionados como `lessons/{id}/audio_v{N}.mp3` e `lessons/{id}/lesson_v{N}.pdf`. `N` é calculado por regex `/_v(\d+)\.(mp3|pdf)$/` no histórico.

- **Checksum:** MD5 hex calculado server-side. Armazenado no DB e no manifest.

### Manifest

- **Formato:** `{ version: number, updated_at: string, lessons: ManifestLesson[], contents: ManifestContent[] }`.
- **Backward compat:** Manifests existentes podem não ter `contents`. Normalizado em `parseManifest` com `contents: raw.contents ?? []`.
- **Evolução in-place:** Nunca é regenerado do zero — sempre read-then-modify do MinIO.
- **`version` INCREMENTA** em:
  - Criar lição
  - Publicar ou despublicar lição
  - Renomear título de lição (sem este bump, o mobile nunca sincroniza mudanças de título)
  - Publicar ou despublicar conteúdo (`upsertContent` / `removeContent`)

- **`version` NÃO incrementa** em:
  - Upload de arquivo de lição
  - Delete de arquivo de lição (apenas `updated_at` é bumped)
  - Criar ou deletar conteúdo sem publicar (operação de rascunho, não visível ao mobile)
  - Editar conteúdo (auto-unpublish remove do manifest e incrementa `version` via `removeContent`)
  - **Por quê:** O app mobile usa `version` para decidir se faz sync. Upload/delete de arquivo sem incrementar `version` significa que o mobile só pega mudanças quando a lição é (re-)publicada.

- **Escrita condicional no upload de arquivo:**
  - Se a lição está **despublicada** e não está no manifest: apenas o arquivo é salvo no MinIO e o DB é atualizado. O `manifest.json` **não é escrito**. A lição só aparecerá no manifest quando for publicada via `PATCH /api/lessons/[id]/publish`.
  - Se a lição está **publicada** mas não está no manifest (ex: re-upload após despublicação): a lição é re-inserida temporariamente no manifest em memória para que `applyUpload` possa versioná-la, e então o manifest é escrito normalmente.
  - **Por quê:** Evita que arquivos de lições não publicadas apareçam prematuramente no manifest — o manifest é a fonte de verdade do que o app mobile vê.
  - **Por quê:** Sem o bump no rename, o app mobile nunca sincroniza mudanças de título (o sync é baseado apenas em `version`).

### Usuários

- **Dois papéis:** `isAdmin: true` (admin completo) ou `false` (pode gerenciar lições).
- **Sem super-admin** — qualquer admin pode fazer tudo.
- **Self-delete bloqueado:** Admin não pode deletar o próprio usuário (403).
- **`GET /api/users`** — lista todos os usuários ordenados por `createdAt` asc. Requer admin. Retorna `{ id, username, isAdmin, mustChangePassword, createdAt }[]` — `passwordHash` nunca é exposto nas respostas de API.
- **Sem edição de usuário** — não existe `PUT /api/users/[id]`. As únicas mutations são: criar, deletar, reset senha.
- **Reset de senha:** Volta para `123456` com `mustChangePassword: true`.
- **Responses de erro dos endpoints de usuário:**
  - `DELETE /api/users/[id]` — 403 se o admin tentar se auto-deletar; 404 se o ID não existir.
  - `POST /api/users/[id]/reset-password` — 404 se o ID não existir.
  - Em ambos: 401 se sem token, 403 se token válido mas não-admin.

### Q&A (perguntas e respostas)

- **Campo `order`:** Calculado no backend via `MAX(order) + 1` das questões ativas da lição. O frontend não envia `order` no POST.
  - **Por quê:** `order: questions.length` no frontend falha quando há gaps de deleções — duas questões podem receber o mesmo `order`. O backend é a única fonte confiável.

- **Delete de questão:** Soft-delete (seta `deletedAt`). O registro permanece no banco para auditoria via `QuestionAuditLog`.

### Conteúdos — regras de negócio

- **Headless CMS minimalista:** O portal cria e edita conteúdos. O dev do app mobile decide onde cada conteúdo aparece, hardcoded por slug (ex: `BetelDialog.show(context, contentSlug: 'welcome-video')`).

- **Dois tipos:** `VIDEO` (YouTube URL) e `TEXT` (HTML com imagens via editor WYSIWYG).
  - `type` não pode ser alterado após criação — delete + recreate se necessário.

- **Slug:** Auto-gerado pelo backend a partir de `title` via `slugify()` (`lib/schemas.ts`). Regenerado automaticamente quando `title` é editado. Único no banco via `@unique` no schema. O admin não envia slug — não existe campo de slug na API de criação nem edição.
  - **Algoritmo `slugify`:** NFD normalization → strip de diacríticos combinantes (ã→a, é→e, ç→c) → lowercase → trim → remove não-alfanuméricos exceto espaços e hífens → espaços→hífens → colapsa hífens consecutivos → remove hífens no início/fim. Títulos com pontuação (vírgulas, ponto de exclamação) têm esses caracteres removidos.
  - **Unicidade primária verificada por `title`** (não por slug): a API faz `findFirst` por título antes do insert e retorna 409 em duplicata. O índice `@unique` do slug é uma segunda barreira de segurança.
  - **Advertência ao mobile:** slugs de conteúdos raiz mudam quando o título é editado. Slugs de páginas filhas seguem o padrão `{parent.slug}-p{N}` e são regenerados pelo backend.

- **Criar conteúdo (root):** `title` + `type` (+ `youtubeUrl` se VIDEO). `slug` é auto-gerado de `title` via `slugify()`. Unicidade verificada por `title` entre conteúdos raiz (`parentId IS NULL`); 409 em duplicata. `id` é autoincrement (diferente de Lesson). Criar não toca o manifest.

- **Criar página filho:** `POST /api/contents` com `{ parentId }`. Apenas TEXT parents são aceitos (VIDEO → 400). `pageIndex` calculado como count de filhos existentes. `slug` e `title` são auto-gerados: `{parent.slug}-p{N}` e `{parent.title} — Página {N+1}`.

- **Editar conteúdo:** `PUT /api/contents/[id]`. Aceita `title`, `youtubeUrl`, `order` + campo `html` (string). `slug` é regenerado automaticamente quando `title` muda. O `html` é salvo como arquivo no MinIO (`contents/{id}/content.html`). Se o conteúdo estava publicado, é **auto-despublicado** (remove do manifest); a resposta inclui `wasAutoUnpublished: true`. Para conteúdos multi-página, o `ContentForm` orquestra no frontend: deleta páginas removidas via `DELETE /api/contents/[id]/pages/[pageId]`, cria novas via `POST /api/contents` com `parentId`, atualiza HTML das existentes via `PUT /api/contents/[childId]`.

- **Publicar/despublicar:**
  - **Publicar VIDEO:** Monta `ManifestContentVideo` com `youtubeUrl` e chama `upsertContent`.
  - **Publicar TEXT (single-page, legacy):** Sem filhos + `htmlPath` presente → lê HTML do MinIO via `getObjectText(htmlPath)`, inline no manifest como `ManifestContentText` com campo `html`.
  - **Publicar TEXT (multi-page):** Com filhos → todos os filhos devem ter `htmlPath`; qualquer página sem HTML → 400 com contagem de páginas faltantes. Lê HTML de cada filho em ordem `pageIndex`, monta `ManifestContentMultiText` com array `pages`.
  - **Publish guard:** TEXT single-page sem `htmlPath` → 400. TEXT multi-page sem nenhum filho com htmlPath → 400. VIDEO sem `youtubeUrl` → desabilitado na UI.
  - **Despublicar:** Chama `removeContent` — conteúdo desaparece do app mobile imediatamente.

- **Deletar página filho:** `DELETE /api/contents/[id]/pages/[pageId]`. Deleta pasta MinIO do filho (best-effort). Remove do DB. Re-indexa filhos restantes (pageIndex 0-based, slug e title regenerados). Se o pai estava publicado, auto-despublica e remove do manifest.

- **HTML inlined no manifest:** O HTML do conteúdo TEXT é armazenado como arquivo no MinIO para edição, mas é **inlined diretamente** no `manifest.json` ao publicar. O mobile lê um único arquivo e tem todo o conteúdo.
  - **Por quê:** Evita requests extras no mobile. O manifest é leve o suficiente para incluir HTML inline.

- **Galeria de imagens:** Imagens compartilhadas em `contents/images/` — não vinculadas a um conteúdo específico. Delete de conteúdo deleta `contents/{id}/` mas NÃO `contents/images/`.
  - **Tipos aceitos:** JPEG, PNG, GIF, WebP. Nomes gerados com `crypto.randomUUID()`.
  - **Sem limite de tamanho** — ⚠️ gap conhecido (mesmo que lições).

- **Multi-página TEXT:** Conteúdos do tipo TEXT podem ser compostos por múltiplas páginas. O registro raiz (`parentId IS NULL`) contém título, slug e estado de publicação. Páginas individuais são registros filhos com `parentId` apontando ao raiz e `pageIndex` indicando a posição (0-based). Deletar o conteúdo raiz remove os filhos via cascade.

- **Delete de conteúdo:** Remove do DB, do manifest (best-effort), e deleta pasta `contents/{id}/` do MinIO. Hard-delete irreversível.

### Input validation

- **Zod** em todas as API routes — `loginSchema`, `createUserSchema`, `uploadQuerySchema`, `updateTitleSchema`, `updateLessonSchema`, `togglePublishSchema`, `createLessonSchema`, `createQuestionSchema`, `updateQuestionSchema`, `createContentSchema`, `updateContentSchema` em `lib/schemas.ts`.
  - `changePasswordSchema` é definido localmente em `app/api/auth/change-password/route.ts` (não está centralizado em `lib/schemas.ts`).
- **`createUserSchema`:** `{ username: string (min 1), isAdmin: boolean }`. `isAdmin` é obrigatório (não tem default). Campos extras (ex: `password`) são silenciosamente descartados pelo Zod — o servidor sempre usa `123456` como senha inicial, independente do que o cliente enviar.
- **`createContentSchema`** usa `z.discriminatedUnion('type', [...])` para validar VIDEO vs TEXT separadamente. Campos: `title` (obrigatório), `type`, `youtubeUrl` (obrigatório se VIDEO), `order` (opcional). **Sem campo `slug`** — slug é gerado pelo backend.
- **`updateContentSchema`** não permite alterar `type`.
- Erro de validação retorna 400 com a primeira mensagem do Zod.

### Error handling

- **API:** Validation via Zod → 400. Auth guard → 401/403. Prisma P2002 (unique) → 409. Demais erros Prisma e MinIO → 500 genérico ou bubble up não tratado.
- **UI:** Todos os erros de mutação (upload, publish toggle, delete lição, delete conteúdo, publish conteúdo) são exibidos como banner inline vermelho descartável acima da lista, com botão "Fechar". Erros de formulário de criação/edição são exibidos inline no formulário. Não há falhas silenciosas nas páginas de Lições e Conteúdos.
  - **Padrão do banner:** `bg-red-50 border border-red-200 rounded-lg text-sm text-red-700`. Mensagem padrão se o servidor não retornar `body.error`: texto descritivo da operação (ex: "Erro ao fazer upload. Tente novamente."). Erros de rede têm mensagem separada indicando verificação de conexão.

- **`GET /api/lessons` — sem guard de auth:** O endpoint de listagem de lições não exige token JWT. A proteção é feita pelo middleware (que redireciona para `/login` no browser), mas chamadas diretas à API sem token retornam 200. Isso é intencional — os dados de lições não são sensíveis; o que importa é proteger as mutations (POST/PUT/DELETE/PATCH).

## O que NÃO fazer

- **Não migrar para NextAuth/Auth.js** sem necessidade — o sistema JWT custom atende o escopo atual.
- **Não confiar no middleware Edge para proteção de admin** — ele usa claims stale do JWT. A proteção real é `requireAdmin()` nas API routes.
- **Não criar endpoint de edição de `isAdmin` via API** sem redesenhar o fluxo — atualmente a única forma de revogar admin é diretamente no DB.
- **Não gerar manifest do zero** — sempre ler o existente do MinIO e modificar. A geração from-scratch pode perder histórico de versões de arquivos.
- **Não implementar soft-delete de arquivo** — o projeto usa hard-delete. Arquivos deletados não são recuperáveis; essa é a decisão tomada conscientemente.
- **Não aceitar tipos de áudio além de MP3** sem atualizar o content type no upload e o client mobile.
