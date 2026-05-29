'use client'

import { useState } from 'react'
import { ChevronDown, ChevronUp } from 'lucide-react'
import { FileRow } from './FileRow'

interface Lesson {
  id: number
  title: string
  audio: { active: string | null; ext: string; checksum: string; history: string[] }
  pdf: { active: string | null; checksum: string; history: string[] }
}

interface LessonRowProps {
  lesson: Lesson
  onUpload: (lessonId: number, type: 'audio' | 'pdf', file: File) => void
  onDelete: (lessonId: number, type: 'audio' | 'pdf') => void
  onPreview: (path: string) => void
  onTitleSave: (lessonId: number, title: string) => void
}

export function LessonRow({ lesson, onUpload, onDelete, onPreview, onTitleSave }: LessonRowProps) {
  const [expanded, setExpanded] = useState(false)
  const [editing, setEditing] = useState(false)
  const [title, setTitle] = useState(lesson.title)

  function saveTitle() {
    setEditing(false)
    if (title.trim() && title !== lesson.title) {
      onTitleSave(lesson.id, title.trim())
    }
  }

  const audioBadge = lesson.audio.active
    ? <span className="text-success text-xs">✓</span>
    : <span className="text-warning text-xs">⚠</span>

  const pdfBadge = lesson.pdf.active
    ? <span className="text-success text-xs">✓</span>
    : <span className="text-warning text-xs">⚠</span>

  return (
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

        {expanded ? <ChevronUp size={16} className="text-gray-400" /> : <ChevronDown size={16} className="text-gray-400" />}
      </div>

      {expanded && (
        <div className="px-4 pb-4 space-y-2 border-t border-gray-50 pt-3">
          <FileRow
            lessonId={lesson.id}
            type="audio"
            active={lesson.audio.active}
            filename={lesson.audio.active ? lesson.audio.active.split('/').pop() ?? null : null}
            onUpload={onUpload}
            onDelete={onDelete}
            onPreview={onPreview}
          />
          <FileRow
            lessonId={lesson.id}
            type="pdf"
            active={lesson.pdf.active}
            filename={lesson.pdf.active ? lesson.pdf.active.split('/').pop() ?? null : null}
            onUpload={onUpload}
            onDelete={onDelete}
            onPreview={onPreview}
          />
        </div>
      )}
    </div>
  )
}
