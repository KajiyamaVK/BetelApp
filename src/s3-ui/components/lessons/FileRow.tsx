'use client'

import { useRef } from 'react'
import { Trash2, Upload } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { MiniPlayer } from './MiniPlayer'

const S3_BASE = process.env.NEXT_PUBLIC_S3_BASE_URL ?? 'https://s3.kajiyama.com.br/betelsas-content'

interface FileRowProps {
  lessonId: number
  type: 'audio' | 'pdf'
  active: string | null
  filename: string | null
  onUpload: (lessonId: number, type: 'audio' | 'pdf', file: File) => void
  onDelete: (lessonId: number, type: 'audio' | 'pdf') => void
  onPreview: (path: string) => void
}

export function FileRow({ lessonId, type, active, filename, onUpload, onDelete, onPreview }: FileRowProps) {
  const inputRef = useRef<HTMLInputElement>(null)

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (file) onUpload(lessonId, type, file)
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
          className="bg-primary hover:bg-yellow-400 text-text-main"
          onClick={() => inputRef.current?.click()}
          aria-label="Upload"
        >
          <Upload size={14} className="mr-1" />
          Upload
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
