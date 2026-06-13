'use client'

import { useState } from 'react'
import { Pencil, Trash2, Video, FileText, Loader2 } from 'lucide-react'
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

interface Content {
  id: number
  slug: string
  title: string
  type: 'VIDEO' | 'TEXT'
  youtubeUrl: string | null
  htmlPath: string | null
  published: boolean
  order: number
  pageCount?: number
}

interface ContentCardProps {
  content: Content
  onEdit: (content: Content) => void
  onDelete: (contentId: number) => void
  onPublishToggle: (contentId: number, published: boolean) => Promise<void>
}

export function ContentCard({ content, onEdit, onDelete, onPublishToggle }: ContentCardProps) {
  const [pendingPublish, setPendingPublish] = useState<boolean | null>(null)
  const [publishing, setPublishing] = useState(false)
  const [pendingDelete, setPendingDelete] = useState(false)

  // TEXT content needs htmlPath (single-page) or child pages (multi-page) before publishing.
  // The server enforces full validation; this is a UI hint.
  const canPublish = content.type === 'VIDEO'
    ? !!content.youtubeUrl
    : !!content.htmlPath || (content.pageCount != null && content.pageCount > 0)

  async function handlePublishConfirm() {
    if (pendingPublish === null) return
    setPublishing(true)
    await onPublishToggle(content.id, pendingPublish).catch(() => undefined)
    setPublishing(false)
    setPendingPublish(null)
  }

  function handleDeleteConfirm() {
    setPendingDelete(false)
    onDelete(content.id)
  }

  const TypeIcon = content.type === 'VIDEO' ? Video : FileText
  const typeBadgeLabel = content.type === 'VIDEO' ? 'Vídeo' : 'Texto'

  return (
    <>
      <div
        data-testid="content-card"
        className="bg-surface rounded-xl border border-gray-100 shadow-sm overflow-hidden"
      >
        <div className="flex items-center gap-3 px-4 py-3">
          {/* Type badge icon */}
          <span className="w-7 h-7 rounded-full bg-primary flex items-center justify-center flex-shrink-0">
            <TypeIcon size={14} className="text-text-main" />
          </span>

          {/* Title + slug */}
          <div className="flex-1 min-w-0">
            <span className="text-sm font-medium text-text-main block truncate">
              {content.title}
            </span>
            <span className="text-xs text-gray-400 block truncate">
              {typeBadgeLabel}
              {content.pageCount != null && content.pageCount > 0 && (
                <> · {content.pageCount} págs</>
              )}
              {' · '}{content.slug}
            </span>
          </div>

          {/* Edit button */}
          <button
            data-testid="edit-content-btn"
            onClick={() => onEdit(content)}
            title="Editar conteúdo"
            className="p-1 rounded text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors"
          >
            <Pencil size={15} />
          </button>

          {/* Publish/Unpublish pill */}
          <button
            data-testid="publish-content-btn"
            onClick={() => setPendingPublish(!content.published)}
            disabled={!canPublish}
            title={!canPublish ? 'Adicione conteúdo antes de publicar' : undefined}
            className={`text-xs px-2 py-1 rounded-full font-medium transition-colors ${
              !canPublish
                ? 'bg-gray-100 text-gray-300 cursor-not-allowed'
                : content.published
                  ? 'bg-green-100 text-green-700 hover:bg-green-200'
                  : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
            }`}
          >
            {content.published ? 'Despublicar' : 'Publicar'}
          </button>

          {/* Delete button */}
          <button
            data-testid="delete-content-btn"
            onClick={() => setPendingDelete(true)}
            title="Apagar conteúdo permanentemente"
            className="p-1 rounded text-red-400 hover:text-red-600 hover:bg-red-50 transition-colors"
          >
            <Trash2 size={15} />
          </button>
        </div>
      </div>

      {/* Publish/Unpublish confirmation */}
      <AlertDialog open={pendingPublish !== null} onOpenChange={(open) => !open && setPendingPublish(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {pendingPublish ? 'Publicar conteúdo?' : 'Despublicar conteúdo?'}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {pendingPublish
                ? 'O conteúdo ficará disponível no app mobile imediatamente.'
                : 'O conteúdo será removido do app mobile imediatamente.'}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={handlePublishConfirm} disabled={publishing} className="flex items-center gap-2">
              {publishing && <Loader2 size={16} className="animate-spin" />}
              {publishing ? 'Aguarde...' : 'Confirmar'}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Delete confirmation */}
      <AlertDialog open={pendingDelete} onOpenChange={(open) => !open && setPendingDelete(false)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Apagar conteúdo permanentemente?</AlertDialogTitle>
            <AlertDialogDescription>
              Esta ação é irreversível. O conteúdo será removido do banco, do manifest e todos os arquivos serão deletados do storage.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              className="bg-red-600 text-white hover:bg-red-700"
              onClick={handleDeleteConfirm}
            >
              Apagar permanentemente
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}
