'use client'

import { useEffect, useState, useCallback } from 'react'
import { LessonList } from '@/components/lessons/LessonList'
import { PdfViewer } from '@/components/lessons/PdfViewer'
import { CreateLessonDialog } from '@/components/lessons/CreateLessonDialog'
import { Button } from '@/components/ui/button'
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

interface Lesson {
  id: number
  title: string
  published: boolean
  audio: { active: string | null; ext: string; checksum: string; history: string[] }
  pdf: { active: string | null; checksum: string; history: string[] }
}

interface DeleteTarget { lessonId: number; type: 'audio' | 'pdf' }

function useIsMobile() {
  const [mobile, setMobile] = useState(false)
  useEffect(() => {
    const check = () => setMobile(window.innerWidth < 768)
    check()
    window.addEventListener('resize', check)
    return () => window.removeEventListener('resize', check)
  }, [])
  return mobile
}

export default function LessonsPage() {
  const [lessons, setLessons] = useState<Lesson[]>([])
  const [pdfPath, setPdfPath] = useState<string | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<DeleteTarget | null>(null)
  const [uploadingKey, setUploadingKey] = useState<string | null>(null)
  const [createDialogOpen, setCreateDialogOpen] = useState(false)
  const isMobile = useIsMobile()

  const suggestedId = lessons.length > 0 ? Math.max(...lessons.map((lesson) => lesson.id)) + 1 : 1

  const loadLessons = useCallback(async () => {
    const res = await fetch('/api/lessons')
    const data = await res.json()
    setLessons(data)
  }, [])

  useEffect(() => { loadLessons() }, [loadLessons])

  async function handleUpload(lessonId: number, type: 'audio' | 'pdf', file: File) {
    setUploadingKey(`${lessonId}-${type}`)
    const form = new FormData()
    form.append('file', file)
    await fetch(`/api/lessons/${lessonId}/upload?type=${type}`, { method: 'POST', body: form })
    await loadLessons()
    setUploadingKey(null)
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

  async function handleTitleSave(lessonId: number, title: string) {
    await fetch(`/api/lessons/${lessonId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title }),
    })
    setLessons((prev) => prev.map((lesson) => (lesson.id === lessonId ? { ...lesson, title } : lesson)))
  }

  async function handlePublishToggle(lessonId: number, published: boolean) {
    await fetch(`/api/lessons/${lessonId}/publish`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ published }),
    })
    setLessons((prev) =>
      prev.map((lesson) => (lesson.id === lessonId ? { ...lesson, published } : lesson)),
    )
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
        <LessonList
          lessons={lessons}
          uploadingKey={uploadingKey}
          onUpload={handleUpload}
          onDelete={handleDeleteRequest}
          onPreview={setPdfPath}
          onTitleSave={handleTitleSave}
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
