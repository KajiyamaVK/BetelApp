'use client'

import { useState, useEffect, useCallback } from 'react'
import { Upload, Loader2 } from 'lucide-react'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'

interface ImageGalleryProps {
  open: boolean
  onClose: () => void
  onSelect: (url: string) => void
}

interface GalleryImage {
  name: string
  url: string
}

export function ImageGallery({ open, onClose, onSelect }: ImageGalleryProps) {
  const [images, setImages] = useState<GalleryImage[]>([])
  const [loading, setLoading] = useState(false)
  const [uploading, setUploading] = useState(false)

  const loadImages = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/contents/images')
      if (res.ok) {
        const data = await res.json()
        setImages(data)
      }
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    if (open) loadImages()
  }, [open, loadImages])

  async function handleUpload(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    if (!file) return

    setUploading(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const res = await fetch('/api/contents/images', {
        method: 'POST',
        body: formData,
      })
      if (res.ok) {
        await loadImages()
      }
    } finally {
      setUploading(false)
      // Reset the input so re-selecting the same file triggers onChange
      event.target.value = ''
    }
  }

  function handleSelect(url: string) {
    onSelect(url)
    onClose()
  }

  return (
    <Dialog open={open} onOpenChange={(isOpen) => !isOpen && onClose()}>
      <DialogContent className="max-w-2xl max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Galeria de Imagens</DialogTitle>
        </DialogHeader>

        <div className="flex justify-end mb-4">
          <label className={`inline-flex items-center gap-2 px-3 py-1.5 text-sm border rounded-md cursor-pointer hover:bg-accent ${uploading ? 'opacity-50 pointer-events-none' : ''}`}>
            {uploading ? (
              <Loader2 size={16} className="animate-spin" />
            ) : (
              <Upload size={16} />
            )}
            {uploading ? 'Enviando...' : 'Upload'}
            <input
              type="file"
              accept="image/jpeg,image/png,image/gif,image/webp"
              className="hidden"
              onChange={handleUpload}
              disabled={uploading}
            />
          </label>
        </div>

        {loading ? (
          <div className="flex justify-center py-12">
            <Loader2 size={24} className="animate-spin text-gray-400" />
          </div>
        ) : images.length === 0 ? (
          <p className="text-center text-gray-400 py-12 text-sm">
            Nenhuma imagem encontrada. Faça upload da primeira.
          </p>
        ) : (
          <div className="grid grid-cols-3 gap-3">
            {images.map((image) => (
              <button
                key={image.name}
                onClick={() => handleSelect(image.url)}
                className="aspect-square rounded-lg overflow-hidden border-2 border-transparent
                  hover:border-primary transition-colors focus:outline-none focus:border-primary"
              >
                <img
                  src={image.url}
                  alt=""
                  className="w-full h-full object-cover"
                />
              </button>
            ))}
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}
