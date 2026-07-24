'use client'

import { useState, useEffect, useCallback } from 'react'
import { ArrowLeft, Loader2, AlertTriangle, Plus, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import { TiptapEditor } from './TiptapEditor'
import { ImageGallery } from './ImageGallery'
import {
  ContentLocation,
  CONTENT_LOCATION_LABELS,
  type ContentLocation as ContentLocationType,
} from '@/lib/contentLocation'

interface ContentFormProps {
  /** When set, the form is in edit mode — PUT instead of POST */
  contentId?: number
  type: 'VIDEO' | 'TEXT'
  initialData?: {
    title: string
    youtubeUrl?: string
    html?: string
    displayLocation?: ContentLocationType
  }
  onSaved: () => void
  onCancel: () => void
}

/** Represents a single page in a multi-page TEXT content */
interface PageState {
  id: number | null  // null = new page not yet persisted
  html: string
}

/** Extracts the YouTube video ID from common URL formats (watch, short, embed) */
function extractYouTubeId(url: string): string | null {
  try {
    const parsed = new URL(url)

    // youtu.be/VIDEO_ID
    if (parsed.hostname === 'youtu.be') {
      return parsed.pathname.slice(1) || null
    }

    // youtube.com/watch?v=VIDEO_ID or youtube.com/embed/VIDEO_ID
    if (parsed.hostname.includes('youtube.com')) {
      const watchParam = parsed.searchParams.get('v')
      if (watchParam) return watchParam

      const embedMatch = parsed.pathname.match(/\/embed\/([^/?]+)/)
      if (embedMatch) return embedMatch[1]

      const shortsMatch = parsed.pathname.match(/\/shorts\/([^/?]+)/)
      if (shortsMatch) return shortsMatch[1]
    }
  } catch {
    // Invalid URL — no video ID
  }
  return null
}

/** Checks if a title is already taken by another content (client-side uniqueness check) */
async function checkTitleUnique(title: string, excludeId?: number): Promise<boolean> {
  const res = await fetch('/api/contents')
  if (!res.ok) return true // Assume unique if API fails — server will catch duplicates
  const contents: { id: number; title: string }[] = await res.json()
  return !contents.some(
    (content) => content.title.toLowerCase() === title.toLowerCase() && content.id !== excludeId,
  )
}

export function ContentForm({ contentId, type, initialData, onSaved, onCancel }: ContentFormProps) {
  const [title, setTitle] = useState(initialData?.title ?? '')
  const [youtubeUrl, setYoutubeUrl] = useState(initialData?.youtubeUrl ?? '')
  const [displayLocation, setDisplayLocation] = useState<ContentLocationType>(
    initialData?.displayLocation ?? ContentLocation.HOME,
  )
  const [galleryOpen, setGalleryOpen] = useState(false)
  const [saving, setSaving] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [wasUnpublished, setWasUnpublished] = useState(false)

  // Multi-page state for TEXT content
  const [pages, setPages] = useState<PageState[]>([{ id: null, html: '' }])
  const [activePageIndex, setActivePageIndex] = useState(0)
  // Track which page IDs existed at load time — deletions are computed by diffing
  const [initialPageIds, setInitialPageIds] = useState<number[]>([])

  // Holds the editor's insert-at-cursor function, set by TiptapEditor.onEditorReady
  const [insertImageAtCursor, setInsertImageAtCursor] = useState<((url: string) => void) | null>(null)

  const isEdit = contentId !== undefined

  // Load existing pages when editing a TEXT content
  useEffect(() => {
    if (!isEdit || type !== 'TEXT') return

    async function loadPages() {
      setLoading(true)
      try {
        const res = await fetch(`/api/contents/${contentId}`)
        if (!res.ok) return

        const data = await res.json()
        const children = data.children ?? []
        const s3Base = process.env.NEXT_PUBLIC_S3_BASE_URL ?? ''

        if (children.length > 0) {
          // Multi-page: load HTML for each child from MinIO
          const loadedPages: PageState[] = await Promise.all(
            children.map(async (child: { id: number; htmlPath: string | null }) => {
              let html = ''
              if (child.htmlPath) {
                try {
                  const htmlRes = await fetch(`${s3Base}/${child.htmlPath}`)
                  if (htmlRes.ok) html = await htmlRes.text()
                } catch { /* best-effort */ }
              }
              return { id: child.id, html }
            }),
          )
          setPages(loadedPages)
          setInitialPageIds(loadedPages.map((page) => page.id!))
        } else if (data.htmlPath) {
          // Single-page (legacy): load from parent's htmlPath
          try {
            const htmlRes = await fetch(`${s3Base}/${data.htmlPath}`)
            if (htmlRes.ok) {
              const html = await htmlRes.text()
              setPages([{ id: null, html }])
            }
          } catch { /* best-effort */ }
        }
      } finally {
        setLoading(false)
      }
    }

    loadPages()
  }, [contentId, isEdit, type])

  // Update the active page's HTML when the editor content changes
  const handlePageHtmlChange = useCallback((html: string) => {
    setPages((prev) => prev.map((page, index) =>
      index === activePageIndex ? { ...page, html } : page,
    ))
  }, [activePageIndex])

  function addPage() {
    setPages((prev) => [...prev, { id: null, html: '' }])
    setActivePageIndex(pages.length)
  }

  function removePage(index: number) {
    if (pages.length <= 1) return // Must keep at least 1 page
    setPages((prev) => prev.filter((_, pageIdx) => pageIdx !== index))
    // Adjust active page index if needed
    if (activePageIndex >= pages.length - 1) {
      setActivePageIndex(Math.max(0, pages.length - 2))
    } else if (activePageIndex > index) {
      setActivePageIndex(activePageIndex - 1)
    }
  }

  function handleImageSelect(imageUrl: string) {
    if (insertImageAtCursor) {
      insertImageAtCursor(imageUrl)
    } else {
      handlePageHtmlChange(pages[activePageIndex].html + `<img src="${imageUrl}" />`)
    }
  }

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault()
    setErrorMessage(null)

    if (!title.trim()) { setErrorMessage('Título obrigatório'); return }
    if (type === 'VIDEO' && !youtubeUrl.trim()) { setErrorMessage('URL do YouTube obrigatória'); return }

    setSaving(true)
    try {
      const isUnique = await checkTitleUnique(title, contentId)
      if (!isUnique) {
        setErrorMessage('Já existe um conteúdo com este título')
        setSaving(false)
        return
      }

      if (isEdit) {
        await saveEditMode()
      } else {
        await saveCreateMode()
      }

      onSaved()
    } catch {
      setErrorMessage('Erro ao salvar. Tente novamente.')
    } finally {
      setSaving(false)
    }
  }

  async function saveEditMode() {
    // Update parent title
    const parentBody: Record<string, unknown> = { title, displayLocation }
    if (type === 'VIDEO') parentBody.youtubeUrl = youtubeUrl

    const parentRes = await fetch(`/api/contents/${contentId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(parentBody),
    })
    if (!parentRes.ok) {
      const data = await parentRes.json().catch(() => ({}))
      throw new Error(data.error ?? 'Erro ao salvar')
    }
    const parentData = await parentRes.json().catch(() => ({}))

    if (type === 'TEXT') {
      // Delete pages that were removed
      const currentPageIds = pages.filter((page) => page.id !== null).map((page) => page.id!)
      const deletedPageIds = initialPageIds.filter((pageId) => !currentPageIds.includes(pageId))
      for (const pageId of deletedPageIds) {
        await fetch(`/api/contents/${contentId}/pages/${pageId}`, { method: 'DELETE' })
      }

      // Create/update each page
      for (let index = 0; index < pages.length; index++) {
        const page = pages[index]
        if (page.id) {
          // Existing page — update HTML
          await fetch(`/api/contents/${page.id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ html: page.html }),
          })
        } else {
          // New page — create as child then upload HTML
          const createRes = await fetch('/api/contents', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ parentId: contentId }),
          })
          if (createRes.ok && page.html) {
            const created = await createRes.json()
            await fetch(`/api/contents/${created.id}`, {
              method: 'PUT',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ html: page.html }),
            })
          }
        }
      }
    }

    if (parentData.wasAutoUnpublished) {
      setWasUnpublished(true)
    }
  }

  async function saveCreateMode() {
    const body: Record<string, unknown> = { title, type, displayLocation }
    if (type === 'VIDEO') body.youtubeUrl = youtubeUrl

    const res = await fetch('/api/contents', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    if (!res.ok) {
      const data = await res.json().catch(() => ({}))
      throw new Error(data.error ?? 'Erro ao criar')
    }

    const created = await res.json()

    // For TEXT, create child pages and upload HTML
    if (type === 'TEXT') {
      for (let index = 0; index < pages.length; index++) {
        const page = pages[index]
        // Create child page
        const childRes = await fetch('/api/contents', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ parentId: created.id }),
        })
        if (childRes.ok && page.html) {
          const child = await childRes.json()
          await fetch(`/api/contents/${child.id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ html: page.html }),
          })
        }
      }
    }
  }

  const youtubeVideoId = extractYouTubeId(youtubeUrl)

  // Page sidebar — rendered outside the form, to the left of the entire form
  const pageSidebar = type === 'TEXT' && !loading && (
    <div className="w-36 shrink-0 space-y-1 pt-1">
      {pages.map((_, index) => (
        <div key={index} className="flex items-center gap-1">
          <button
            type="button"
            onClick={() => setActivePageIndex(index)}
            className={`flex-1 text-left text-sm px-3 py-1.5 rounded transition-colors ${
              index === activePageIndex
                ? 'bg-primary text-text-main font-semibold'
                : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            Página {index + 1}
          </button>
          {pages.length > 1 && (
            <button
              type="button"
              onClick={() => removePage(index)}
              className="p-1 text-gray-400 hover:text-red-500 transition-colors"
              title="Remover página"
            >
              <X size={14} />
            </button>
          )}
        </div>
      ))}
      <button
        type="button"
        onClick={addPage}
        className="flex items-center gap-1 text-xs text-gray-500 hover:text-primary px-3 py-1.5 transition-colors w-full"
      >
        <Plus size={14} />
        Página
      </button>
    </div>
  )

  return (
    <div className="max-w-4xl">
      <button
        onClick={onCancel}
        className="flex items-center gap-1 text-sm text-gray-500 hover:text-text-main transition-colors mb-4"
      >
        <ArrowLeft size={16} />
        Voltar
      </button>

      <h2 className="text-lg font-bold text-text-main mb-4">
        {isEdit ? 'Editar Conteúdo' : `Novo Conteúdo — ${type === 'VIDEO' ? 'Vídeo' : 'Texto'}`}
      </h2>

      {errorMessage && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
          {errorMessage}
          <button className="ml-2 underline text-xs" onClick={() => setErrorMessage(null)}>Fechar</button>
        </div>
      )}

      {/* For TEXT: sidebar sits to the right of the entire form, stretching its full height */}
      <div className="flex gap-4">
        <form onSubmit={handleSubmit} className="space-y-4 flex-1 min-w-0">
          {/* Title field */}
          <div className="max-w-lg">
            <label className="block text-sm font-medium text-text-main mb-1">Título</label>
            <input
              type="text"
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              placeholder="Ex: Bem-vindo ao curso"
              className="w-full px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>

          {/* Display location */}
          <div className="max-w-lg">
            <label className="block text-sm font-medium text-text-main mb-1">Exibir em</label>
            <select
              value={displayLocation}
              onChange={(event) => setDisplayLocation(event.target.value as ContentLocationType)}
              className="w-full px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary bg-white"
            >
              {Object.values(ContentLocation).map((loc) => (
                <option key={loc} value={loc}>
                  {CONTENT_LOCATION_LABELS[loc]}
                </option>
              ))}
            </select>
          </div>

          {/* VIDEO: YouTube URL + preview */}
          {type === 'VIDEO' && (
            <div className="max-w-lg">
              <label className="block text-sm font-medium text-text-main mb-1">URL do YouTube</label>
              <input
                type="url"
                value={youtubeUrl}
                onChange={(event) => setYoutubeUrl(event.target.value)}
                placeholder="https://www.youtube.com/watch?v=..."
                className="w-full px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              />

              {youtubeVideoId && (
                <div className="mt-3 rounded-lg overflow-hidden border border-gray-200">
                  <div className="relative w-full" style={{ paddingBottom: '56.25%' }}>
                    <iframe
                      src={`https://www.youtube.com/embed/${youtubeVideoId}`}
                      title="Preview do vídeo"
                      className="absolute inset-0 w-full h-full"
                      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                      allowFullScreen
                    />
                  </div>
                </div>
              )}
            </div>
          )}

          {/* TEXT: Tiptap editor for the active page */}
          {type === 'TEXT' && (
            <div>
              <label className="block text-sm font-medium text-text-main mb-1">Conteúdo</label>
              {loading ? (
                <div className="flex justify-center py-12">
                  <Loader2 size={24} className="animate-spin text-gray-400" />
                </div>
              ) : (
                <TiptapEditor
                  key={activePageIndex}
                  value={pages[activePageIndex]?.html ?? ''}
                  onChange={handlePageHtmlChange}
                  onImageClick={() => setGalleryOpen(true)}
                  onEditorReady={(insertFn) => setInsertImageAtCursor(() => insertFn)}
                />
              )}
            </div>
          )}

          {/* Actions */}
          <div className="flex items-center gap-3 pt-2">
            <Button
              type="submit"
              disabled={saving}
              className="bg-primary hover:bg-yellow-400 text-text-main font-semibold"
            >
              {saving && <Loader2 size={16} className="animate-spin mr-2" />}
              {saving ? 'Salvando...' : isEdit ? 'Salvar' : 'Criar'}
            </Button>
            <Button type="button" variant="outline" onClick={onCancel}>
              Cancelar
            </Button>
          </div>
        </form>
        {pageSidebar}
      </div>

      {/* Image gallery dialog for TEXT content */}
      {type === 'TEXT' && (
        <ImageGallery
          open={galleryOpen}
          onClose={() => setGalleryOpen(false)}
          onSelect={handleImageSelect}
        />
      )}

      {/* Auto-unpublish warning — shown when editing published content */}
      <AlertDialog open={wasUnpublished} onOpenChange={(open) => { if (!open) { setWasUnpublished(false); onSaved() } }}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2">
              <AlertTriangle size={18} className="text-primary" />
              Conteúdo despublicado
            </AlertDialogTitle>
            <AlertDialogDescription>
              As alterações foram salvas. O conteúdo foi despublicado automaticamente para que você possa revisar antes de publicar novamente.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogAction onClick={() => { setWasUnpublished(false); onSaved() }}>
              Entendi
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
