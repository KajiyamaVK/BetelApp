'use client'

import { useEffect, useState, useCallback } from 'react'
import { LessonList } from '@/components/lessons/LessonList'
import { PdfViewer } from '@/components/lessons/PdfViewer'
import { CreateLessonDialog } from '@/components/lessons/CreateLessonDialog'
import { Button } from '@/components/ui/button'
import { ErrorBanner } from '@/components/ui/ErrorBanner'
import { useIsMobile } from '@/hooks/useIsMobile'
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
import type { Lesson } from '@/types/api'

interface DeleteTarget { lessonId: number; type: 'audio' | 'pdf' }

export default function LessonsPage() {
  const [lessons, setLessons] = useState<Lesson[]>([])
  const [isAdmin, setIsAdmin] = useState(false)
  const [pdfPath, setPdfPath] = useState<string | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<DeleteTarget | null>(null)
  const [uploadingKey, setUploadingKey] = useState<string | null>(null)
  const [createDialogOpen, setCreateDialogOpen] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const isMobile = useIsMobile()

  const suggestedId = lessons.length > 0 ? lessons.reduce((max, l) => Math.max(max, l.id), 0) + 1 : 1

  const loadLessons = useCallback(async () => {
    const res = await fetch('/api/lessons')
    const data = await res.json()
    setLessons(data)
  }, [])

  useEffect(() => {
    loadLessons()
    // isAdmin is derived from the layout's /api/auth/me fetch — re-fetch here only for the admin flag
    fetch('/api/auth/me').then((res) => res.json()).then((data) => { if (data.isAdmin) setIsAdmin(true) })
  }, [loadLessons])

  async function handleUpload(lessonId: number, type: 'audio' | 'pdf', file: File) {
    setErrorMessage(null)
    setUploadingKey(`${lessonId}-${type}`)
    try {
      const form = new FormData()
      form.append('file', file)
      const res = await fetch(`/api/lessons/${lessonId}/upload?type=${type}`, { method: 'POST', body: form })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        setErrorMessage(body.error ?? 'Erro ao fazer upload. Tente novamente.')
        return
      }
      await loadLessons()
    } catch {
      setErrorMessage('Erro de rede ao fazer upload. Verifique sua conexão.')
    } finally {
      setUploadingKey(null)
    }
  }

  function handleDeleteRequest(lessonId: number, type: 'audio' | 'pdf') {
    setDeleteTarget({ lessonId, type })
  }

  async function handleDeleteConfirm() {
    if (!deleteTarget) return
    await fetch(`/api/lessons/${deleteTarget.lessonId}/file?type=${deleteTarget.type}`, { method: 'DELETE' })
    setDeleteTarget(null)
    await loadLessons()
  }

  async function handleLessonSave(lessonId: number, title: string, order: number): Promise<string | null> {
    const res = await fetch(`/api/lessons/${lessonId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, order }),
    })
    if (res.ok) {
      setLessons((prev) => prev.map((lesson) => (lesson.id === lessonId ? { ...lesson, title, order } : lesson)))
      return null
    }
    const body = await res.json().catch(() => ({}))
    return body.error ?? 'Erro ao salvar lição. Tente novamente.'
  }

  async function handleDeleteLesson(lessonId: number) {
    setErrorMessage(null)
    const res = await fetch(`/api/lessons/${lessonId}`, { method: 'DELETE' })
    if (!res.ok) {
      const body = await res.json().catch(() => ({}))
      setErrorMessage(body.error ?? 'Erro ao apagar lição. Tente novamente.')
      return
    }
    setLessons((prev) => prev.filter((lesson) => lesson.id !== lessonId))
  }

  async function handlePublishToggle(lessonId: number, published: boolean) {
    setErrorMessage(null)
    try {
      const res = await fetch(`/api/lessons/${lessonId}/publish`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ published }),
      })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        setErrorMessage(body.error ?? 'Erro ao alterar publicação. Tente novamente.')
        return
      }
      setLessons((prev) =>
        prev.map((lesson) => (lesson.id === lessonId ? { ...lesson, published } : lesson)),
      )
    } catch {
      setErrorMessage('Erro de rede ao alterar publicação. Verifique sua conexão.')
    }
  }

  return (
    <div className={`flex h-full ${pdfPath && !isMobile ? 'gap-4' : ''}`}>
      <div className={`flex-1 min-w-0 ${pdfPath && !isMobile ? 'w-1/2' : 'w-full'}`}>
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-xl font-bold text-text-main">Lições</h1>
          <div className="flex items-center gap-3">
            {uploadingKey && <span className="text-xs text-gray-400 animate-pulse">Enviando...</span>}
            <Button
              onClick={() => setCreateDialogOpen(true)}
              className="bg-primary hover:bg-yellow-400 text-text-main font-semibold"
              size="sm"
            >
              + Nova Lição
            </Button>
          </div>
        </div>

        {errorMessage && (
          <ErrorBanner message={errorMessage} onClose={() => setErrorMessage(null)} />
        )}

        <LessonList
          lessons={lessons}
          isAdmin={isAdmin}
          uploadingKey={uploadingKey}
          onUpload={handleUpload}
          onDelete={handleDeleteRequest}
          onDeleteLesson={handleDeleteLesson}
          onPreview={setPdfPath}
          onLessonSave={handleLessonSave}
          onPublishToggle={handlePublishToggle}
        />
      </div>

      {pdfPath && (
        <div className={isMobile ? '' : 'w-1/2 flex flex-col'}>
          <PdfViewer path={pdfPath} onClose={() => setPdfPath(null)} isMobile={isMobile} />
        </div>
      )}

      <CreateLessonDialog
        open={createDialogOpen}
        suggestedId={suggestedId}
        onCreated={() => { setCreateDialogOpen(false); loadLessons() }}
        onClose={() => setCreateDialogOpen(false)}
      />

      <AlertDialog open={!!deleteTarget} onOpenChange={(isOpen) => !isOpen && setDeleteTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmar exclusão</AlertDialogTitle>
            <AlertDialogDescription>
              O arquivo será removido da lição. O arquivo original permanece no storage.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-delete-bg text-delete-text hover:bg-red-200"
              onClick={handleDeleteConfirm}
            >
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
