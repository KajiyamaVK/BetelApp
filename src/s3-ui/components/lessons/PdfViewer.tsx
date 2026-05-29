'use client'

import { X, ExternalLink } from 'lucide-react'
import { useEffect } from 'react'

const S3_BASE = process.env.NEXT_PUBLIC_S3_BASE_URL ?? 'https://s3.kajiyama.com.br/betelsas-content'

interface PdfViewerProps {
  path: string
  onClose: () => void
  isMobile: boolean
}

export function PdfViewer({ path, onClose, isMobile }: PdfViewerProps) {
  const url = `${S3_BASE}/${path}`

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  if (isMobile) {
    return (
      <div className="fixed inset-0 z-50 bg-black">
        <iframe src={url} className="w-full h-full border-0" title="PDF Viewer" />
        <button
          onClick={onClose}
          aria-label="Fechar PDF"
          className="fixed top-4 right-4 z-50 bg-white rounded-full w-9 h-9 flex items-center justify-center shadow-lg text-text-main hover:bg-gray-100"
        >
          <X size={18} />
        </button>
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full bg-surface border-l border-gray-200">
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-200">
        <span className="text-sm font-medium text-text-main truncate">📄 {path.split('/').pop()}</span>
        <div className="flex items-center gap-2">
          <a
            href={url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs text-gray-500 hover:text-primary flex items-center gap-1"
          >
            Abrir em nova aba
            <ExternalLink size={12} />
          </a>
          <button
            onClick={onClose}
            aria-label="Fechar PDF"
            className="text-gray-400 hover:text-gray-700 ml-2"
          >
            <X size={18} />
          </button>
        </div>
      </div>
      <iframe src={url} className="flex-1 border-0" title="PDF Viewer" />
    </div>
  )
}
