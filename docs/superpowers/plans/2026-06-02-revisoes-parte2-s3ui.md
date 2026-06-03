# Revisões — Parte 2: s3-ui UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar seção "Perguntas & Respostas" dentro da `LessonRow` expandida no painel admin, com adicionar/editar/deletar inline.

**Architecture:** Novo componente `QASection` isolado que recebe `lessonId` e gerencia seu próprio estado e fetch. `LessonRow` apenas monta `QASection` dentro da área expandida — sem props adicionais no `LessonRow`. Segue padrão de `useState` + `fetch()` já estabelecido no projeto (sem lib de estado global).

**Tech Stack:** React, Next.js, Tailwind CSS, shadcn/ui (AlertDialog, Button, Input), TypeScript

**Pré-requisito:** Parte 1 (backend) deve estar implementada antes desta parte.

---

## Estrutura de arquivos

| Ação | Arquivo |
|------|---------|
| Create | `src/s3-ui/components/lessons/QASection.tsx` |
| Modify | `src/s3-ui/components/lessons/LessonRow.tsx` |

---

### Task 6: Componente QASection

**Files:**
- Create: `src/s3-ui/components/lessons/QASection.tsx`
- Modify: `src/s3-ui/components/lessons/LessonRow.tsx`

- [ ] **Step 1: Criar o componente QASection**

Criar `src/s3-ui/components/lessons/QASection.tsx`:

```tsx
'use client'

import { useState, useEffect, useCallback } from 'react'
import { Pencil, Trash2, Plus, X, Check } from 'lucide-react'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'

interface Question {
  id: number
  lessonId: number
  question: string
  answer: string
  order: number
}

interface QASectionProps {
  lessonId: number
}

type EditingState = { questionId: number; question: string; answer: string } | null
type AddingState = { question: string; answer: string } | null

export function QASection({ lessonId }: QASectionProps) {
  const [questions, setQuestions] = useState<Question[]>([])
  const [loading, setLoading] = useState(true)
  const [editing, setEditing] = useState<EditingState>(null)
  const [adding, setAdding] = useState<AddingState>(null)
  const [pendingDelete, setPendingDelete] = useState<Question | null>(null)
  const [saving, setSaving] = useState(false)

  const fetchQuestions = useCallback(async () => {
    const res = await fetch(`/api/lessons/${lessonId}/questions`)
    if (res.ok) {
      const data = await res.json()
      setQuestions(data)
    }
    setLoading(false)
  }, [lessonId])

  useEffect(() => {
    fetchQuestions()
  }, [fetchQuestions])

  async function handleSaveNew() {
    if (!adding || !adding.question.trim() || !adding.answer.trim()) return
    setSaving(true)
    const res = await fetch(`/api/lessons/${lessonId}/questions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        question: adding.question.trim(),
        answer: adding.answer.trim(),
        order: questions.length,
      }),
    })
    setSaving(false)
    if (res.ok) {
      setAdding(null)
      await fetchQuestions()
    }
  }

  async function handleSaveEdit() {
    if (!editing || !editing.question.trim() || !editing.answer.trim()) return
    setSaving(true)
    const res = await fetch(`/api/lessons/${lessonId}/questions/${editing.questionId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        question: editing.question.trim(),
        answer: editing.answer.trim(),
      }),
    })
    setSaving(false)
    if (res.ok) {
      setEditing(null)
      await fetchQuestions()
    }
  }

  async function handleConfirmDelete() {
    if (!pendingDelete) return
    await fetch(`/api/lessons/${lessonId}/questions/${pendingDelete.id}`, {
      method: 'DELETE',
    })
    setPendingDelete(null)
    await fetchQuestions()
  }

  function startEdit(question: Question) {
    setAdding(null)
    setEditing({ questionId: question.id, question: question.question, answer: question.answer })
  }

  function startAdd() {
    setEditing(null)
    setAdding({ question: '', answer: '' })
  }

  if (loading) {
    return <div className="text-xs text-gray-400 py-2">Carregando perguntas...</div>
  }

  return (
    <>
      <div className="border-t border-gray-100 pt-4 mt-2">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-text-main">Perguntas & Respostas</span>
            {questions.length > 0 && (
              <span className="bg-primary text-text-main text-xs rounded-full px-2 py-0.5 font-medium">
                {questions.length}
              </span>
            )}
          </div>
          {adding === null && (
            <button
              onClick={startAdd}
              className="flex items-center gap-1 text-xs bg-primary text-text-main px-3 py-1.5 rounded-md font-semibold hover:bg-yellow-400 transition-colors"
            >
              <Plus size={12} />
              Adicionar
            </button>
          )}
        </div>

        <div className="space-y-2">
          {questions.map((question) => (
            <div key={question.id} className="bg-white border border-gray-200 rounded-lg p-3">
              {editing?.questionId === question.id ? (
                <div className="space-y-2">
                  <input
                    className="w-full border border-gray-300 rounded-md px-3 py-1.5 text-sm outline-none focus:border-primary"
                    value={editing.question}
                    onChange={(e) => setEditing({ ...editing, question: e.target.value })}
                    placeholder="Pergunta..."
                    autoFocus
                  />
                  <input
                    className="w-full border border-gray-300 rounded-md px-3 py-1.5 text-sm outline-none focus:border-primary"
                    value={editing.answer}
                    onChange={(e) => setEditing({ ...editing, answer: e.target.value })}
                    placeholder="Resposta..."
                  />
                  <div className="flex justify-end gap-2">
                    <button
                      onClick={() => setEditing(null)}
                      className="flex items-center gap-1 text-xs border border-gray-300 rounded-md px-3 py-1.5 text-gray-600 hover:bg-gray-50"
                    >
                      <X size={12} /> Cancelar
                    </button>
                    <button
                      onClick={handleSaveEdit}
                      disabled={saving}
                      className="flex items-center gap-1 text-xs bg-primary text-text-main rounded-md px-3 py-1.5 font-semibold hover:bg-yellow-400 disabled:opacity-50"
                    >
                      <Check size={12} /> Salvar
                    </button>
                  </div>
                </div>
              ) : (
                <div className="flex items-start gap-3">
                  <span className="bg-gray-100 text-gray-500 text-xs rounded px-2 py-0.5 whitespace-nowrap mt-0.5">
                    Q {question.order + 1}
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm text-text-main">{question.question}</div>
                    <div className="text-xs text-gray-500 border-t border-gray-100 mt-1.5 pt-1.5">
                      ↳ {question.answer}
                    </div>
                  </div>
                  <div className="flex gap-1.5 flex-shrink-0">
                    <button
                      onClick={() => startEdit(question)}
                      className="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded transition-colors"
                      title="Editar"
                    >
                      <Pencil size={13} />
                    </button>
                    <button
                      onClick={() => setPendingDelete(question)}
                      className="p-1.5 text-red-300 hover:text-red-500 hover:bg-red-50 rounded transition-colors"
                      title="Deletar"
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>

        {adding !== null && (
          <div className="mt-2 bg-yellow-50 border border-dashed border-primary rounded-lg p-3 space-y-2">
            <div className="text-xs text-gray-500 uppercase font-medium">Nova pergunta</div>
            <input
              className="w-full border border-gray-300 rounded-md px-3 py-1.5 text-sm outline-none focus:border-primary bg-white"
              value={adding.question}
              onChange={(e) => setAdding({ ...adding, question: e.target.value })}
              placeholder="Pergunta..."
              autoFocus
            />
            <input
              className="w-full border border-gray-300 rounded-md px-3 py-1.5 text-sm outline-none focus:border-primary bg-white"
              value={adding.answer}
              onChange={(e) => setAdding({ ...adding, answer: e.target.value })}
              placeholder="Resposta..."
            />
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setAdding(null)}
                className="flex items-center gap-1 text-xs border border-gray-300 rounded-md px-3 py-1.5 text-gray-600 hover:bg-gray-50"
              >
                <X size={12} /> Cancelar
              </button>
              <button
                onClick={handleSaveNew}
                disabled={saving || !adding.question.trim() || !adding.answer.trim()}
                className="flex items-center gap-1 text-xs bg-primary text-text-main rounded-md px-3 py-1.5 font-semibold hover:bg-yellow-400 disabled:opacity-50"
              >
                <Check size={12} /> Salvar
              </button>
            </div>
          </div>
        )}
      </div>

      <AlertDialog open={pendingDelete !== null} onOpenChange={(open) => !open && setPendingDelete(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Deletar pergunta?</AlertDialogTitle>
            <AlertDialogDescription>
              A pergunta &ldquo;{pendingDelete?.question}&rdquo; será removida permanentemente desta lição. Esta ação não pode ser desfeita.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-delete-bg text-delete-text hover:bg-red-200"
              onClick={handleConfirmDelete}
            >
              Deletar
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}
```

- [ ] **Step 2: Montar QASection dentro do LessonRow expandido**

Em `src/s3-ui/components/lessons/LessonRow.tsx`, adicionar import e montar o componente na área expandida.

Adicionar ao topo do arquivo (junto com os outros imports):
```ts
import { QASection } from './QASection'
```

Na área expandida (dentro do bloco `{expanded && ...}`), adicionar `<QASection>` após os dois `<FileRow>`:

```tsx
{expanded && (
  <div className="px-4 pb-4 space-y-2 border-t border-gray-50 pt-3">
    <FileRow
      lessonId={lesson.id}
      type="audio"
      active={lesson.audio.active}
      filename={lesson.audio.active ? lesson.audio.active.split('/').pop() ?? null : null}
      uploading={uploadingKey === `${lesson.id}-audio`}
      onUpload={onUpload}
      onDelete={handleDeleteRequest}
      onPreview={onPreview}
    />
    <FileRow
      lessonId={lesson.id}
      type="pdf"
      active={lesson.pdf.active}
      filename={lesson.pdf.active ? lesson.pdf.active.split('/').pop() ?? null : null}
      uploading={uploadingKey === `${lesson.id}-pdf`}
      onUpload={onUpload}
      onDelete={handleDeleteRequest}
      onPreview={onPreview}
    />
    <QASection lessonId={lesson.id} />
  </div>
)}
```

- [ ] **Step 3: Verificar build sem erros de TypeScript**

```bash
cd src/s3-ui
npx tsc --noEmit 2>&1 | head -30
```

Esperado: sem erros.

- [ ] **Step 4: Subir o servidor de dev e testar manualmente**

```bash
cd src/s3-ui
npm run dev
```

Abrir http://localhost:3000/lessons, expandir uma lição, verificar:
- Seção "Perguntas & Respostas" aparece abaixo de áudio/PDF
- Botão "+ Adicionar" abre formulário inline
- Salvar cria a pergunta e fecha o formulário
- Editar exibe inputs preenchidos
- Deletar abre AlertDialog e remove a pergunta

- [ ] **Step 5: Commit**

```bash
git add src/s3-ui/components/lessons/QASection.tsx \
        src/s3-ui/components/lessons/LessonRow.tsx
git commit -m "feat(s3-ui): add QASection component to LessonRow for inline Q&A management"
```
