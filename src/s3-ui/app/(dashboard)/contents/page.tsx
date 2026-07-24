'use client'

import { useEffect, useState, useCallback } from 'react'
import { Video, FileText } from 'lucide-react'
import { ContentList } from '@/components/contents/ContentList'
import { ContentForm } from '@/components/contents/ContentForm'
import { Button } from '@/components/ui/button'
import { ErrorBanner } from '@/components/ui/ErrorBanner'
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import type { Content } from '@/types/api'
import type { ContentLocation } from '@/lib/contentLocation'

export default function ContentsPage() {
  const [contents, setContents] = useState<Content[]>([])
  const [editingContent, setEditingContent] = useState<Content | null>(null)
  const [creatingType, setCreatingType] = useState<'VIDEO' | 'TEXT' | null>(null)
  const [typePickerOpen, setTypePickerOpen] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const loadContents = useCallback(async () => {
    const res = await fetch('/api/contents')
    if (res.ok) {
      const data = await res.json()
      setContents(data)
    }
  }, [])

  useEffect(() => {
    loadContents()
  }, [loadContents])

  async function handleDelete(contentId: number) {
    setErrorMessage(null)
    const res = await fetch(`/api/contents/${contentId}`, { method: 'DELETE' })
    if (!res.ok) {
      const body = await res.json().catch(() => ({}))
      setErrorMessage(body.error ?? 'Erro ao apagar conteúdo. Tente novamente.')
      return
    }
    setContents((prev) => prev.filter((content) => content.id !== contentId))
  }

  async function handlePublishToggle(contentId: number, published: boolean) {
    setErrorMessage(null)
    try {
      const res = await fetch(`/api/contents/${contentId}/publish`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ published }),
      })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        setErrorMessage(body.error ?? 'Erro ao alterar publicação. Tente novamente.')
        return
      }
      setContents((prev) =>
        prev.map((content) => (content.id === contentId ? { ...content, published } : content)),
      )
    } catch {
      setErrorMessage('Erro de rede ao alterar publicação. Verifique sua conexão.')
    }
  }

  function handleEdit(content: Content) {
    setEditingContent(content)
  }

  function handleSaved() {
    setEditingContent(null)
    setCreatingType(null)
    loadContents()
  }

  function handleCancel() {
    setEditingContent(null)
    setCreatingType(null)
  }

  // When editing or creating, show the form full-screen (replaces the list)
  if (editingContent) {
    return (
      <ContentForm
        contentId={editingContent.id}
        type={editingContent.type as 'VIDEO' | 'TEXT'}
        initialData={{
          title: editingContent.title,
          youtubeUrl: editingContent.youtubeUrl ?? undefined,
          displayLocation: editingContent.displayLocation as ContentLocation,
        }}
        onSaved={handleSaved}
        onCancel={handleCancel}
      />
    )
  }

  if (creatingType) {
    return (
      <ContentForm
        type={creatingType}
        onSaved={handleSaved}
        onCancel={handleCancel}
      />
    )
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-xl font-bold text-text-main">Conteúdos</h1>
        <Button
          onClick={() => setTypePickerOpen(true)}
          className="bg-primary hover:bg-yellow-400 text-text-main font-semibold"
          size="sm"
        >
          + Novo Conteúdo
        </Button>
      </div>

      {errorMessage && (
        <ErrorBanner message={errorMessage} onClose={() => setErrorMessage(null)} />
      )}

      {contents.length === 0 ? (
        <p className="text-center text-gray-400 py-12 text-sm">
          Nenhum conteúdo criado ainda. Clique em &quot;+ Novo Conteúdo&quot; para começar.
        </p>
      ) : (
        <ContentList
          contents={contents}
          onEdit={handleEdit}
          onDelete={handleDelete}
          onPublishToggle={handlePublishToggle}
        />
      )}

      {/* Content type picker dialog */}
      <AlertDialog open={typePickerOpen} onOpenChange={(open) => !open && setTypePickerOpen(false)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Tipo de conteúdo</AlertDialogTitle>
            <AlertDialogDescription>
              Selecione o tipo de conteúdo que deseja criar.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <div className="grid grid-cols-2 gap-3 py-2">
            <button
              onClick={() => { setTypePickerOpen(false); setCreatingType('VIDEO') }}
              className="flex flex-col items-center gap-2 p-4 rounded-lg border-2 border-transparent
                hover:border-primary hover:bg-yellow-50 transition-colors"
            >
              <Video size={28} className="text-primary" />
              <span className="text-sm font-medium text-text-main">Vídeo</span>
              <span className="text-xs text-gray-400">YouTube</span>
            </button>
            <button
              onClick={() => { setTypePickerOpen(false); setCreatingType('TEXT') }}
              className="flex flex-col items-center gap-2 p-4 rounded-lg border-2 border-transparent
                hover:border-primary hover:bg-yellow-50 transition-colors"
            >
              <FileText size={28} className="text-primary" />
              <span className="text-sm font-medium text-text-main">Texto</span>
              <span className="text-xs text-gray-400">Editor com imagens</span>
            </button>
          </div>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
