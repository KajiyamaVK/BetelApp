'use client'

import { useState } from 'react'
import { ChevronDown, ChevronUp, Trash2 } from 'lucide-react'
import { FileRow } from './FileRow'
import { QASection } from './QASection'
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

interface LessonRowProps {
  lesson: Lesson
  isAdmin: boolean
  uploadingKey: string | null
  onUpload: (lessonId: number, type: 'audio' | 'pdf', file: File) => void
  onDelete: (lessonId: number, type: 'audio' | 'pdf') => void
  onDeleteLesson: (lessonId: number) => void
  onPreview: (path: string) => void
  onTitleSave: (lessonId: number, title: string) => void
  onPublishToggle: (lessonId: number, published: boolean) => Promise<void>
}

export function LessonRow({ lesson, isAdmin, uploadingKey, onUpload, onDelete, onDeleteLesson, onPreview, onTitleSave, onPublishToggle }: LessonRowProps) {
  const [expanded, setExpanded] = useState(false)
  const [editing, setEditing] = useState(false)
  const [title, setTitle] = useState(lesson.title)
  const [pendingPublish, setPendingPublish] = useState<boolean | null>(null)
  const [pendingPdfDelete, setPendingPdfDelete] = useState(false)
  const [pendingLessonDelete, setPendingLessonDelete] = useState(false)

  function saveTitle() {
    setEditing(false)
    if (title.trim() && title !== lesson.title) {
      onTitleSave(lesson.id, title.trim())
    }
  }

  function handlePublishClick(e: React.MouseEvent) {
    e.stopPropagation()
    setPendingPublish(!lesson.published)
  }

  async function handleConfirm() {
    if (pendingPublish !== null) {
      // Always close the dialog after confirmation, regardless of outcome.
      // Error surfacing is the parent page's responsibility.
      await onPublishToggle(lesson.id, pendingPublish).catch(() => undefined)
    }
    setPendingPublish(null)
  }

  function handleDeleteRequest(lessonId: number, type: 'audio' | 'pdf') {
    if (type === 'pdf' && lesson.published) {
      setPendingPdfDelete(true)
    } else {
      onDelete(lessonId, type)
    }
  }

  async function handlePdfDeleteConfirm() {
    onDelete(lesson.id, 'pdf')
    try {
      await onPublishToggle(lesson.id, false)
    } finally {
      setPendingPdfDelete(false)
    }
  }

  const audioBadge = lesson.audio.active
    ? <span className="text-success text-xs">✓</span>
    : <span className="text-warning text-xs">⚠</span>

  const pdfBadge = lesson.pdf.active
    ? <span className="text-success text-xs">✓</span>
    : <span className="text-warning text-xs">⚠</span>

  return (
    <>
      <div data-testid="lesson-row" className="bg-surface rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        <div
          className="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-gray-50 transition-colors"
          onClick={() => !editing && setExpanded(!expanded)}
        >
          <span className="w-7 h-7 rounded-full bg-primary flex items-center justify-center text-xs font-bold text-text-main flex-shrink-0">
            {lesson.id}
          </span>

          {editing ? (
            <input
              className="flex-1 text-sm font-medium border-b border-primary outline-none bg-transparent"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              onBlur={saveTitle}
              onKeyDown={(e) => e.key === 'Enter' && saveTitle()}
              autoFocus
              onClick={(e) => e.stopPropagation()}
            />
          ) : (
            <span
              data-testid="lesson-title"
              className="flex-1 text-sm font-medium text-text-main hover:text-primary transition-colors"
              onDoubleClick={(e) => { e.stopPropagation(); setEditing(true) }}
            >
              {title}
            </span>
          )}

          <div className="flex items-center gap-2 text-xs text-gray-400">
            <span>🎵 {audioBadge}</span>
            <span>📄 {pdfBadge}</span>
          </div>

          <button
            onClick={handlePublishClick}
            disabled={!lesson.pdf.active}
            title={!lesson.pdf.active ? 'Adicione um PDF antes de publicar' : undefined}
            className={`text-xs px-2 py-1 rounded-full font-medium transition-colors ${
              !lesson.pdf.active
                ? 'bg-gray-100 text-gray-300 cursor-not-allowed'
                : lesson.published
                  ? 'bg-green-100 text-green-700 hover:bg-green-200'
                  : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
            }`}
          >
            {lesson.published ? 'Despublicar' : 'Publicar'}
          </button>

          {isAdmin && (
            <button
              data-testid="delete-lesson-btn"
              onClick={(e) => { e.stopPropagation(); setPendingLessonDelete(true) }}
              title="Apagar lição permanentemente"
              className="p-1 rounded text-red-400 hover:text-red-600 hover:bg-red-50 transition-colors"
            >
              <Trash2 size={15} />
            </button>
          )}

          {expanded ? <ChevronUp size={16} className="text-gray-400" /> : <ChevronDown size={16} className="text-gray-400" />}
        </div>

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
      </div>

      <AlertDialog open={pendingPdfDelete} onOpenChange={(open) => !open && setPendingPdfDelete(false)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Remover PDF e despublicar?</AlertDialogTitle>
            <AlertDialogDescription>
              Esta lição está publicada. Ao remover o PDF ela será despublicada automaticamente e deixará de aparecer no app mobile.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-delete-bg text-delete-text hover:bg-red-200"
              onClick={handlePdfDeleteConfirm}
            >
              Confirmar
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={pendingPublish !== null} onOpenChange={(open) => !open && setPendingPublish(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {pendingPublish ? 'Publicar lição?' : 'Despublicar lição?'}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {pendingPublish
                ? 'A lição ficará visível no app mobile imediatamente.'
                : 'A lição será removida do app mobile imediatamente.'}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={handleConfirm}>Confirmar</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={pendingLessonDelete} onOpenChange={(open) => !open && setPendingLessonDelete(false)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Apagar lição permanentemente?</AlertDialogTitle>
            <AlertDialogDescription>
              Esta ação é irreversível. A lição será removida do banco, do manifest e todos os arquivos serão deletados do storage.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-red-600 text-white hover:bg-red-700"
              onClick={() => { setPendingLessonDelete(false); onDeleteLesson(lesson.id) }}
            >
              Apagar permanentemente
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}
