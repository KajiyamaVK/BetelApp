# Design: Sistema de Revisões (Flashcards)

**Data:** 2026-06-02
**Status:** Aprovado — pronto para implementação

---

## Visão Geral

Sistema de revisão por flashcards atrelado às lições do catecismo. O admin cadastra perguntas e respostas por lição no painel web (s3-ui). O app mobile permite ao usuário ativar revisão por lição e praticar com sessões no estilo Leitner.

---

## Arquitetura

```
s3-ui (admin)           manifest.json (MinIO)        app mobile (SQLite)
──────────────          ──────────────────────        ───────────────────
Tabela Question   →     questions: [{id,q,a}]    →   card_progress (Leitner)
(fonte da verdade)      (entrega ao app)               review_active (toggle)
```

**Princípios:**
- O DB PostgreSQL é a fonte da verdade das Q&As
- O manifest é a projeção publicada — inclui Q&As apenas quando a lição está publicada
- O progresso Leitner é local por dispositivo (SQLite) — nunca vai ao backend
- Delete sempre gera audit log (padrão do projeto)

---

## Backend — s3-ui

### Novos models Prisma

```prisma
model Question {
  id        Int       @id @default(autoincrement())
  lessonId  Int
  lesson    Lesson    @relation(fields: [lessonId], references: [id])
  question  String
  answer    String
  order     Int
  createdAt DateTime  @default(now())
  deletedAt DateTime?
}

model QuestionAuditLog {
  id           Int      @id @default(autoincrement())
  questionId   Int
  lessonId     Int
  question     String
  answer       String
  deletedAt    DateTime @default(now())
  deletedBy    String
}
```

**Regras:**
- `Question.deletedAt` = soft-delete. Queries ativas sempre filtram `deletedAt: null`.
- Delete sempre cria um `QuestionAuditLog` com o conteúdo integral da pergunta deletada.
- `order` controla a sequência exibida no app. Admin pode reordenar futuramente.
- `Lesson` ganha relação `questions Question[]`.

### API Routes (Next.js App Router)

| Método | Rota | Auth | Função |
|--------|------|------|--------|
| `GET` | `/api/lessons/[id]/questions` | JWT | Lista Q&As ativas da lição |
| `POST` | `/api/lessons/[id]/questions` | JWT | Cria nova Q&A |
| `PATCH` | `/api/lessons/[id]/questions/[qid]` | JWT | Edita pergunta ou resposta |
| `DELETE` | `/api/lessons/[id]/questions/[qid]` | JWT | Soft-delete + audit log |

### Manifest

Ao publicar uma lição, o manifest inclui suas Q&As ativas:

```json
{
  "lessons": [
    {
      "id": 4,
      "title": "Como podemos glorificar a Deus?",
      "pdf": { ... },
      "audio": { ... },
      "questions": [
        { "id": 1, "q": "Como podemos glorificar a Deus?", "a": "Amando-o e fazendo o que ele manda." },
        { "id": 2, "q": "Por que devemos glorificar a Deus?", "a": "Porque ele nos criou e nos sustenta." }
      ]
    }
  ]
}
```

- Lições sem Q&As omitem o campo `questions` (ou enviam array vazio).
- Ao despublicar, o entry some do manifest — Q&As continuam no DB intactas.
- `version` do manifest é incrementado a cada mudança de Q&A em lição publicada.

---

## s3-ui — Interface

### LessonRow expandida

Nova seção "Perguntas & Respostas" abaixo das seções de PDF e Áudio:

- **Header da seção:** título + badge com contagem + botão "+ Adicionar"
- **Q&A card:** exibe pergunta, resposta, botões "Editar" e "Deletar"
- **Editar:** substitui o card por inputs inline (pergunta + resposta). Salvar/Cancelar.
- **Deletar:** `AlertDialog` de confirmação com texto explícito. Ao confirmar → soft-delete + `QuestionAuditLog`.
- **Adicionar:** formulário inline (fundo amarelo claro, borda tracejada amarela) com campos pergunta + resposta. Salvar fecha o formulário.

**Comportamento:**
- Apenas um formulário de edição/adição aberto por vez.
- Salvar re-fetcha a lista de Q&As da lição.
- Se a lição está publicada, salvar/deletar Q&A regenera o manifest automaticamente (incrementa `version`).

---

## App Mobile

### Novos dados SQLite

**Tabela `card_progress`:**

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `question_id` | INTEGER | PK — ID da pergunta (do manifest) |
| `lesson_id` | INTEGER | FK referência |
| `bucket` | INTEGER | Baralho Leitner (1–5), default 1 |
| `last_reviewed_at` | TEXT | ISO 8601 |
| `next_review_at` | TEXT | ISO 8601 — calculado após cada resposta |

**Tabela `review_active`:**

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `lesson_id` | INTEGER | PK |
| `active` | INTEGER | 0 ou 1 |

### Algoritmo Leitner

| Bucket | Intervalo até próxima revisão |
|--------|-------------------------------|
| 1 | 1 dia |
| 2 | 2 dias |
| 3 | 4 dias |
| 4 | 8 dias |
| 5 | 16 dias |

- **Acertou:** `bucket = min(bucket + 1, 5)`. `nextReviewAt = hoje + intervalo[bucket]`.
- **Errou:** `bucket = 1`. `nextReviewAt = amanhã`.
- **Card novo** (sem registro em `card_progress`): `bucket = 1`, aparece na próxima sessão.

### Sync

- O sync existente (delta por `version`) baixa o manifest atualizado.
- Após sync, o app persiste Q&As das lições no SQLite.
- Q&As removidas do manifest são deletadas do SQLite local (mesma lógica de remoção de lições obsoletas).
- `card_progress` é preservado entre syncs — atualizar uma Q&A no backend não reseta o progresso local.
- Exceção: se uma Q&A for removida do manifest (deletada no backend), seu registro em `card_progress` é deletado junto — não faz sentido guardar progresso de uma pergunta que não existe mais.

### Novas telas

**Tab "Revisões" (4º tab na nav bar)**

- `IndexedStack` passa de 3 para 4 itens.
- Exibe lista de lições com `review_active = 1`.
- Banner "Revisão do Dia": agrega todos os cards onde `nextReviewAt ≤ hoje` de todas as lições ativas. Exibe contagem. Botão "Começar Sessão".
- Lições sem Q&As não aparecem na lista mesmo que toggle esteja ativo (guard).

**Tela de Sessão de Revisão**

- Barra de progresso (card N de total).
- Card com pergunta.
- Botão "Revelar Resposta" — exibe a resposta no mesmo card.
- Após revelar: botões "✗ Errei" e "✓ Acertei".
- Ao responder: atualiza `card_progress`, avança para próximo card.
- Ao finalizar todos: tela de conclusão com resumo (acertos/erros).

**Toggle no LessonDetailScreen**

- Ícone ao lado do botão de favorito no AppBar.
- **Só exibido** se a lição tem `questions.length > 0` no manifest local.
- Toca/destoca `review_active` no SQLite ao clicar.
- Visual: ícone cinza = inativo, amarelo = ativo.

### Navegação

- `MainScaffold` ganha 4º tab.
- `ReviewsScreen` → `ReviewSessionScreen` via `Navigator.push`.
- Voltar da sessão retorna para `ReviewsScreen`.

---

## O que NÃO fazer

- **Não sincronizar `card_progress` com o backend** — progresso é local por device. Sync cloud é roadmap futuro (depende de auth).
- **Não exibir toggle de revisão em lições sem Q&As** — evita confusão do usuário.
- **Não deletar `card_progress` ao desativar revisão de uma lição** — o progresso é preservado para quando o usuário reativar.
- **Não usar `questionsHistory` JSON na Lesson** — o padrão correto é tabela `Question` com `deletedAt` + `QuestionAuditLog`.
- **Não regenerar manifest em lição despublicada ao editar Q&As** — Q&As de lições não publicadas não afetam o manifest.
