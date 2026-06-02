'use client'

import { useState, useRef } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog'

interface CreateLessonDialogProps {
  open: boolean
  suggestedId: number
  onCreated: () => void
  onClose: () => void
}

export function CreateLessonDialog({ open, suggestedId, onCreated, onClose }: CreateLessonDialogProps) {
  const [lessonId, setLessonId] = useState(String(suggestedId))
  const [title, setTitle] = useState('')
  const [pdfFile, setPdfFile] = useState<File | null>(null)
  const [audioFile, setAudioFile] = useState<File | null>(null)
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  const pdfInputRef = useRef<HTMLInputElement>(null)
  const audioInputRef = useRef<HTMLInputElement>(null)

  function reset() {
    setLessonId(String(suggestedId))
    setTitle('')
    setPdfFile(null)
    setAudioFile(null)
    setError('')
    setSaving(false)
    if (pdfInputRef.current) pdfInputRef.current.value = ''
    if (audioInputRef.current) audioInputRef.current.value = ''
  }

  function handleClose() {
    reset()
    onClose()
  }

  async function handleSave() {
    setError('')

    if (!title.trim()) {
      setError('O título é obrigatório')
      return
    }

    const parsedId = parseInt(lessonId, 10)
    if (isNaN(parsedId) || parsedId <= 0) {
      setError('O número da lição deve ser um inteiro positivo')
      return
    }

    setSaving(true)
    try {
      const createRes = await fetch('/api/lessons', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: parsedId, title: title.trim() }),
      })

      if (!createRes.ok) {
        const data = await createRes.json().catch(() => ({}))
        setError(data.error ?? 'Erro ao criar lição')
        return
      }

      if (pdfFile) {
        const form = new FormData()
        form.append('file', pdfFile)
        const uploadRes = await fetch(`/api/lessons/${parsedId}/upload?type=pdf`, { method: 'POST', body: form })
        if (!uploadRes.ok) {
          const data = await uploadRes.json().catch(() => ({}))
          setError(data.error ?? 'Erro ao fazer upload do PDF')
          return
        }
      }

      if (audioFile) {
        const form = new FormData()
        form.append('file', audioFile)
        const uploadRes = await fetch(`/api/lessons/${parsedId}/upload?type=audio`, { method: 'POST', body: form })
        if (!uploadRes.ok) {
          const data = await uploadRes.json().catch(() => ({}))
          setError(data.error ?? 'Erro ao fazer upload do áudio')
          return
        }
      }

      reset()
      onCreated()
    } finally {
      setSaving(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={(isOpen) => !isOpen && handleClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Nova Lição</DialogTitle>
        </DialogHeader>

        <div className="space-y-4 py-2">
          <div className="space-y-1">
            <Label htmlFor="lesson-id">Número da lição</Label>
            <Input
              id="lesson-id"
              type="number"
              min={1}
              value={lessonId}
              onChange={(e) => setLessonId(e.target.value)}
            />
          </div>

          <div className="space-y-1">
            <Label htmlFor="lesson-title">Título</Label>
            <Input
              id="lesson-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Ex: Qual o Fim principal do Homem?"
            />
          </div>

          <div className="space-y-1">
            <Label htmlFor="lesson-pdf">PDF</Label>
            <input
              id="lesson-pdf"
              ref={pdfInputRef}
              type="file"
              accept="application/pdf"
              className="block w-full text-sm text-gray-500 file:mr-3 file:py-1 file:px-3 file:rounded-md file:border-0 file:text-xs file:font-medium file:bg-primary file:text-text-main hover:file:bg-yellow-400"
              onChange={(e) => setPdfFile(e.target.files?.[0] ?? null)}
            />
          </div>

          <div className="space-y-1">
            <Label htmlFor="lesson-audio">Áudio</Label>
            <input
              id="lesson-audio"
              ref={audioInputRef}
              type="file"
              accept="audio/mpeg"
              className="block w-full text-sm text-gray-500 file:mr-3 file:py-1 file:px-3 file:rounded-md file:border-0 file:text-xs file:font-medium file:bg-primary file:text-text-main hover:file:bg-yellow-400"
              onChange={(e) => setAudioFile(e.target.files?.[0] ?? null)}
            />
          </div>

          {error && <p className="text-sm text-warning">{error}</p>}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={handleClose} disabled={saving}>
            Cancelar
          </Button>
          <Button
            onClick={handleSave}
            disabled={saving}
            className="bg-primary hover:bg-yellow-400 text-text-main font-semibold"
          >
            {saving ? 'Salvando...' : 'Salvar'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
