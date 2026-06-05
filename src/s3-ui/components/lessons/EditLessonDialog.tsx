'use client'

import { useState } from 'react'
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

interface EditLessonDialogProps {
  open: boolean
  lessonId: number
  initialTitle: string
  initialOrder: number
  onSave: (lessonId: number, title: string, order: number) => Promise<string | null>
  onClose: () => void
}

export function EditLessonDialog({ open, lessonId, initialTitle, initialOrder, onSave, onClose }: EditLessonDialogProps) {
  const [title, setTitle] = useState(initialTitle)
  const [order, setOrder] = useState(String(initialOrder))
  const [error, setError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  function handleOpenChange(isOpen: boolean) {
    if (!isOpen) {
      setTitle(initialTitle)
      setOrder(String(initialOrder))
      setError(null)
      onClose()
    }
  }

  async function handleSave() {
    const parsedOrder = parseInt(order, 10)
    const newTitle = title.trim()

    const titleChanged = newTitle !== initialTitle && newTitle.length > 0
    const orderChanged = !isNaN(parsedOrder) && parsedOrder >= 0 && parsedOrder !== initialOrder

    if (!titleChanged && !orderChanged) {
      onClose()
      return
    }

    setSaving(true)
    setError(null)
    const err = await onSave(lessonId, titleChanged ? newTitle : initialTitle, orderChanged ? parsedOrder : initialOrder)
    setSaving(false)

    if (err) {
      setError(err)
    } else {
      setTitle(titleChanged ? newTitle : initialTitle)
      setOrder(String(orderChanged ? parsedOrder : initialOrder))
      onClose()
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Editar Lição</DialogTitle>
        </DialogHeader>

        <div className="space-y-4 py-2">
          <div className="space-y-1">
            <Label htmlFor="edit-lesson-order">Nº da lição</Label>
            <Input
              id="edit-lesson-order"
              type="number"
              min={0}
              value={order}
              onChange={(e) => setOrder(e.target.value)}
            />
          </div>

          <div className="space-y-1">
            <Label htmlFor="edit-lesson-title">Título</Label>
            <Input
              id="edit-lesson-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />
          </div>

          {error && <p className="text-sm text-warning">{error}</p>}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={saving}>
            Cancelar
          </Button>
          <Button
            onClick={handleSave}
            disabled={saving}
            className="bg-primary hover:bg-yellow-400 text-text-main font-semibold flex items-center gap-2"
          >
            {saving && (
              <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
            )}
            {saving ? 'Salvando...' : 'Salvar'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
