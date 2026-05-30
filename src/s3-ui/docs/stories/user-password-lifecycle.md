---
status: ready-for-dev
baseline_commit: 72e2c46f0792a5e33e59232941eca1261bf9c50b
---

# Story: User Password Lifecycle (First Access + Delete + Reset)

## Story

**Como** administrador do Portal Betel,  
**Quero** que usuários criados ou com senha resetada troquem a senha obrigatoriamente no primeiro acesso, e que eu possa deletar ou resetar a senha de qualquer usuário na lista de usuários,  
**Para que** o sistema nunca fique com a senha padrão `123456` ativa indefinidamente.

## Acceptance Criteria

- **AC1:** Ao criar um usuário, a senha armazenada é sempre o hash de `123456` e o campo `mustChangePassword` é `true`.
- **AC2:** Ao fazer login com `mustChangePassword = true`, o usuário é redirecionado para `/change-password` (não para `/lessons`).
- **AC3:** Na tela `/change-password`, o usuário informa a nova senha duas vezes; se coincidirem e tiverem ≥6 caracteres, a senha é atualizada, `mustChangePassword` é setado para `false`, e ele é redirecionado para `/lessons`.
- **AC4:** Se as senhas não coincidirem ou tiverem <6 caracteres, exibe mensagem de erro inline e não redireciona.
- **AC5:** Na tela de usuários, cada linha da tabela tem botão "Deletar" que remove o usuário após confirmação via AlertDialog.
- **AC6:** Na tela de usuários, cada linha da tabela tem botão "Resetar senha" que define a senha de volta para `123456`, seta `mustChangePassword = true`, e exibe confirmação de sucesso inline.
- **AC7:** O formulário de criação de usuário não pede mais campo de senha — a senha inicial é sempre `123456`.
- **AC8:** Um usuário não pode deletar a si mesmo.

## Tasks / Subtasks

- [ ] **T1: Schema — adicionar `mustChangePassword` ao model User**
  - [ ] T1.1: Adicionar campo `mustChangePassword Boolean @default(true)` ao `prisma/schema.prisma`
  - [ ] T1.2: Rodar `npm run db:setup:dev` e `npm run db:setup:test`

- [ ] **T2: Backend — criação de usuário usa senha padrão**
  - [ ] T2.1: Escrever testes para `POST /api/users` — verifica que `mustChangePassword=true` e senha é hash de `123456`
  - [ ] T2.2: Atualizar `POST /api/users`: remover campo `password` do body, sempre hashear `123456`, setar `mustChangePassword: true`
  - [ ] T2.3: Atualizar `createUserSchema` em `lib/schemas.ts`: remover `password`

- [ ] **T3: Backend — JWT e middleware carregam `mustChangePassword`**
  - [ ] T3.1: Escrever testes para `signToken` / `verifyToken` com o novo campo
  - [ ] T3.2: Atualizar `TokenPayload` em `lib/auth.ts` para incluir `mustChangePassword: boolean`
  - [ ] T3.3: Atualizar `POST /api/auth/login` para incluir `mustChangePassword` no token e retornar `{ mustChangePassword }` no JSON de resposta
  - [ ] T3.4: Atualizar `lib/auth-edge.ts` (middleware) para redirecionar para `/change-password` se `mustChangePassword = true` e rota não for `/change-password` nem `/api/`

- [ ] **T4: Backend — rota de troca de senha**
  - [ ] T4.1: Escrever testes para `POST /api/auth/change-password`
  - [ ] T4.2: Criar `app/api/auth/change-password/route.ts`: valida `{ password, confirmPassword }`, verifica match e mínimo 6 chars, atualiza hash + `mustChangePassword: false`

- [ ] **T5: Backend — deletar e resetar senha de usuário**
  - [ ] T5.1: Escrever testes para `DELETE /api/users/[id]` (incluindo tentativa de auto-deleção)
  - [ ] T5.2: Escrever testes para `POST /api/users/[id]/reset-password`
  - [ ] T5.3: Criar `app/api/users/[id]/route.ts` com `DELETE` (requer admin, não permite auto-deleção)
  - [ ] T5.4: Criar `app/api/users/[id]/reset-password/route.ts` com `POST` (requer admin)

- [ ] **T6: Frontend — tela de troca de senha**
  - [ ] T6.1: Criar `app/(auth)/change-password/page.tsx` com form de nova senha + confirmação
  - [ ] T6.2: Ao submeter com sucesso, redireciona para `/lessons`

- [ ] **T7: Frontend — botões Deletar e Resetar senha em UserTable**
  - [ ] T7.1: Atualizar `UserTable` para aceitar `currentUserId`, `onDelete`, `onResetPassword` como props
  - [ ] T7.2: Adicionar coluna "Ações" com botões Deletar (AlertDialog de confirmação) e Resetar senha
  - [ ] T7.3: Ocultar botão Deletar para o usuário logado (sem poder deletar a si mesmo)

- [ ] **T8: Frontend — ajustar `CreateUserForm` e `UsersPage`**
  - [ ] T8.1: Remover campo de senha do `CreateUserForm`
  - [ ] T8.2: Atualizar `UsersPage` para passar `currentUserId` e handlers para `UserTable`

- [ ] **T9: Frontend — ajustar tela de login para redirecionar para `/change-password`**
  - [ ] T9.1: Verificar resposta do login; se `mustChangePassword = true`, redirecionar para `/change-password`

## Dev Notes

### Campo `mustChangePassword`

Adicionar ao model Prisma:
```prisma
mustChangePassword Boolean @default(true)
```

### Senha padrão
A senha padrão é `123456`. Ao criar usuário ou resetar, o sistema sempre hasheia esse valor com `bcrypt.hash('123456', 12)`.

### JWT payload
```ts
interface TokenPayload {
  id: number
  username: string
  isAdmin: boolean
  mustChangePassword: boolean
}
```

### Middleware (`auth-edge.ts`)
O middleware roda no Edge Runtime e não pode usar Prisma — lê diretamente do JWT. Se `mustChangePassword = true` e a rota não for `/change-password` (e não for rota de API), redireciona para `/change-password`.

### API routes existentes relevantes
- `app/api/auth/login/route.ts` — precisa incluir `mustChangePassword` no token e resposta
- `app/api/users/route.ts` — POST remove campo `password`, sempre usa `123456`
- `lib/schemas.ts` — `createUserSchema` remove campo `password`
- `lib/auth.ts` — `TokenPayload` + `signToken` + `requireAuth` + `requireAdmin`
- `lib/auth-edge.ts` — middleware de redirecionamento

### Proteção de auto-deleção
No `DELETE /api/users/[id]`, comparar `id` do token com o `id` do path. Se iguais, retornar 403.

### Estrutura de testes esperada
```
__tests__/
  api/
    users.create.test.ts          (existente — verificar se ainda passa)
    users.delete.test.ts          (novo)
    users.reset-password.test.ts  (novo)
    auth.change-password.test.ts  (novo)
    auth.login-mustchange.test.ts (novo)
  components/
    UserTable.actions.test.tsx    (novo)
```

## Dev Agent Record

### Implementation Plan
_Preencher durante implementação_

### Debug Log
_Preencher se houver problemas_

### Completion Notes
_Preencher ao concluir_

## File List

_Preencher durante implementação_

## Change Log

_Preencher ao concluir_
