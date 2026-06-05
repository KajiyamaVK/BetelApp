'use client'

import { LessonRow } from './LessonRow'

interface Lesson {
  id: number
  order: number
  title: string
  published: boolean
  audio: { active: string | null; ext: string; checksum: string; history: string[] }
  pdf: { active: string | null; checksum: string; history: string[] }
}

interface LessonListProps {
  lessons: Lesson[]
  isAdmin: boolean
  uploadingKey: string | null
  onUpload: (lessonId: number, type: 'audio' | 'pdf', file: File) => void
  onDelete: (lessonId: number, type: 'audio' | 'pdf') => void
  onDeleteLesson: (lessonId: number) => void
  onPreview: (path: string) => void
  onLessonSave: (lessonId: number, title: string, order: number) => Promise<string | null>
  onPublishToggle: (lessonId: number, published: boolean) => Promise<void>
}

export function LessonList({ lessons, isAdmin, uploadingKey, onUpload, onDelete, onDeleteLesson, onPreview, onLessonSave, onPublishToggle }: LessonListProps) {
  return (
    <div className="space-y-2">
      {lessons.map((lesson) => (
        <LessonRow
          key={lesson.id}
          lesson={lesson}
          isAdmin={isAdmin}
          uploadingKey={uploadingKey}
          onUpload={onUpload}
          onDelete={onDelete}
          onDeleteLesson={onDeleteLesson}
          onPreview={onPreview}
          onLessonSave={onLessonSave}
          onPublishToggle={onPublishToggle}
        />
      ))}
    </div>
  )
}
