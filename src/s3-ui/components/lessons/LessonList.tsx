'use client'

import { LessonRow } from './LessonRow'

interface Lesson {
  id: number
  title: string
  audio: { active: string | null; ext: string; checksum: string; history: string[] }
  pdf: { active: string | null; checksum: string; history: string[] }
}

interface LessonListProps {
  lessons: Lesson[]
  onUpload: (lessonId: number, type: 'audio' | 'pdf', file: File) => void
  onDelete: (lessonId: number, type: 'audio' | 'pdf') => void
  onPreview: (path: string) => void
  onTitleSave: (lessonId: number, title: string) => void
}

export function LessonList({ lessons, onUpload, onDelete, onPreview, onTitleSave }: LessonListProps) {
  return (
    <div className="space-y-2">
      {lessons.map((lesson) => (
        <LessonRow
          key={lesson.id}
          lesson={lesson}
          onUpload={onUpload}
          onDelete={onDelete}
          onPreview={onPreview}
          onTitleSave={onTitleSave}
        />
      ))}
    </div>
  )
}
