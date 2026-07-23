'use client'

import { useRef } from 'react'
import { Trash2, Upload } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Spinner } from '@/components/ui/Spinner'
import { MiniPlayer } from './MiniPlayer'
import { S3_BASE } from '@/lib/constants'

const MAX_AUDIO_BYTES = 20 * 1024 * 1024
const MAX_PDF_BYTES = 50 * 1024 * 1024

interface FileRowProps {
  lessonId: number
  type: 'audio' | 'pdf'
  active: string | null
  uploading?: boolean
  onUpload: (lessonId: number, type: 'audio' | 'pdf', file: File) => void
  onDelete: (lessonId: number, type: 'audio' | 'pdf') => void
  onPreview: (path: string) => void
}

export function FileRow({ lessonId, type, active, uploading = false, onUpload, onDelete, onPreview }: FileRowProps) {
  const filename = active ? active.split('/').pop() ?? null : null
  const inputRef = useRef<HTMLInputElement>(null)

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    const limit = type === 'audio' ? MAX_AUDIO_BYTES : MAX_PDF_BYTES
    const limitLabel = type === 'audio' ? '20 MB' : '50 MB'
    if (file.size > limit) {
      alert(`O arquivo excede o limite de ${limitLabel}. Escolha um arquivo menor.`)
      e.target.value = ''
      return
    }
    onUpload(lessonId, type, file)
  }

  if (!active) {
    return (
      <div className="flex items-center justify-between bg-gray-50 rounded-lg px-3 py-2">
        <span className="text-sm text-gray-400">
          {type === 'audio' ? '🎵 Nenhum áudio' : '📄 Nenhum PDF'}
        </span>
        <input
          ref={inputRef}
          type="file"
          className="hidden"
          accept={type === 'audio' ? 'audio/mpeg' : 'application/pdf'}
          onChange={handleFileChange}
        />
        <Button
          size="sm"
          className="bg-primary hover:bg-yellow-400 text-text-main min-w-[80px]"
          onClick={() => inputRef.current?.click()}
          disabled={uploading}
          aria-label="Upload"
        >
          {uploading ? <Spinner /> : <><Upload size={14} className="mr-1" />Upload</>}
        </Button>
      </div>
    )
  }

  const url = `${S3_BASE}/${active}`

  return (
    <div className="bg-gray-50 rounded-lg px-3 py-2 border-l-2 border-primary">
      {type === 'audio' ? (
        <div className="flex items-center gap-2">
          <div className="flex-1">
            <p className="text-xs text-gray-400 mb-1">🎵 {filename}</p>
            <MiniPlayer src={url} />
          </div>
          <Button
            size="sm"
            variant="ghost"
            className="text-delete-text bg-delete-bg hover:bg-red-200 ml-2"
            onClick={() => onDelete(lessonId, type)}
            aria-label="Delete audio"
          >
            <Trash2 size={14} />
          </Button>
        </div>
      ) : (
        <div className="flex items-center justify-between">
          <button
            className="text-sm text-text-main underline hover:text-primary transition-colors"
            onClick={() => onPreview(active)}
          >
            {filename}
          </button>
          <Button
            size="sm"
            variant="ghost"
            className="text-delete-text bg-delete-bg hover:bg-red-200"
            onClick={() => onDelete(lessonId, type)}
            aria-label="Delete pdf"
          >
            <Trash2 size={14} />
          </Button>
        </div>
      )}
    </div>
  )
}
