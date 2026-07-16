'use client'

import { ContentCard } from './ContentCard'
import type { Content } from '@/types/api'

interface ContentListProps {
  contents: Content[]
  onEdit: (content: Content) => void
  onDelete: (contentId: number) => void
  onPublishToggle: (contentId: number, published: boolean) => Promise<void>
}

export function ContentList({ contents, onEdit, onDelete, onPublishToggle }: ContentListProps) {
  return (
    <div className="space-y-2">
      {contents.map((content) => (
        <ContentCard
          key={content.id}
          content={content}
          onEdit={onEdit}
          onDelete={onDelete}
          onPublishToggle={onPublishToggle}
        />
      ))}
    </div>
  )
}
