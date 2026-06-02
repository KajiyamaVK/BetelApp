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
