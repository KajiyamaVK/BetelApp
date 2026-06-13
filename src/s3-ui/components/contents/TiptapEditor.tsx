'use client'

import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Image from '@tiptap/extension-image'
import { useEffect, useRef, useState } from 'react'
import { Bold, Italic, Heading2, Heading3, ImageIcon } from 'lucide-react'

interface TiptapEditorProps {
  value: string
  onChange: (html: string) => void
  onImageClick: () => void
  /** Called once the editor is ready — exposes an insert function for images at cursor position */
  onEditorReady?: (insertImage: (url: string) => void) => void
}

export function TiptapEditor({ value, onChange, onImageClick, onEditorReady }: TiptapEditorProps) {
  // Force re-render on every editor transaction (selection change, mark toggle, etc.)
  // so toolbar buttons reflect the current active state (bold, italic, heading).
  // Without this, `editor.isActive()` returns stale values in the JSX.
  const [, setTransactionCounter] = useState(0)

  const editor = useEditor({
    extensions: [
      StarterKit,
      Image.configure({
        HTMLAttributes: {
          // Images take full width with proportional height
          style: 'width: 100%; height: auto; border-radius: 8px; margin: 8px 0;',
        },
      }),
    ],
    content: value,
    onUpdate: ({ editor: currentEditor }) => {
      onChange(currentEditor.getHTML())
    },
    onTransaction: () => {
      setTransactionCounter((prev) => prev + 1)
    },
  })

  // Use a ref to avoid re-running the effect when onEditorReady changes identity
  // (which happens on every parent render when passed as an inline arrow function).
  const onEditorReadyRef = useRef(onEditorReady)
  onEditorReadyRef.current = onEditorReady

  // Expose an image-insert function so the parent can insert at the cursor position
  useEffect(() => {
    if (editor && onEditorReadyRef.current) {
      onEditorReadyRef.current((url: string) => {
        editor.chain().focus().setImage({ src: url }).run()
      })
    }
  }, [editor])

  // Sync external value changes into the editor (e.g. when loading saved content)
  useEffect(() => {
    if (editor && value !== editor.getHTML()) {
      editor.commands.setContent(value)
    }
  }, [editor, value])

  if (!editor) return null

  return (
    <div className="border rounded-lg overflow-hidden">
      <div className="flex items-center gap-1 p-2 border-b bg-gray-50">
        <ToolbarButton
          onClick={() => editor.chain().focus().toggleBold().run()}
          active={editor.isActive('bold')}
          title="Negrito"
        >
          <Bold size={16} />
        </ToolbarButton>

        <ToolbarButton
          onClick={() => editor.chain().focus().toggleItalic().run()}
          active={editor.isActive('italic')}
          title="Itálico"
        >
          <Italic size={16} />
        </ToolbarButton>

        <div className="w-px h-5 bg-gray-300 mx-1" />

        <ToolbarButton
          onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
          active={editor.isActive('heading', { level: 2 })}
          title="Título"
        >
          <Heading2 size={16} />
        </ToolbarButton>

        <ToolbarButton
          onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}
          active={editor.isActive('heading', { level: 3 })}
          title="Subtítulo"
        >
          <Heading3 size={16} />
        </ToolbarButton>

        <div className="w-px h-5 bg-gray-300 mx-1" />

        <ToolbarButton
          onClick={onImageClick}
          active={false}
          title="Inserir imagem"
        >
          <ImageIcon size={16} />
        </ToolbarButton>
      </div>

      <EditorContent
        editor={editor}
        className="prose prose-sm max-w-none p-4 min-h-[200px] focus:outline-none
          [&_.ProseMirror]:outline-none [&_.ProseMirror]:min-h-[180px] bg-white
          [&_h2]:text-xl [&_h2]:font-bold [&_h2]:mt-4 [&_h2]:mb-2
          [&_h3]:text-lg [&_h3]:font-semibold [&_h3]:mt-3 [&_h3]:mb-1"
      />
    </div>
  )
}

function ToolbarButton({
  onClick,
  active,
  title,
  children,
}: {
  onClick: () => void
  active: boolean
  title: string
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      // Prevent mousedown from stealing focus from ProseMirror —
      // without this, clicking a toolbar button blurs the editor
      // and the toggle command loses the cursor/selection context.
      onMouseDown={(event) => event.preventDefault()}
      title={title}
      className={`p-1.5 rounded transition-colors ${
        active
          ? 'bg-primary text-text-main'
          : 'text-gray-500 hover:bg-gray-200'
      }`}
    >
      {children}
    </button>
  )
}
