import {
  parseManifest,
  softDeleteFile,
  applyUpload,
  nextVersion,
  removeLesson,
  upsertLesson,
  renameLesson,
  upsertContent,
  removeContent,
  type Manifest,
  type ManifestContent,
} from '@/lib/manifest'

const baseManifest = {
  version: 1,
  updated_at: '2026-01-01T00:00:00Z',
  lessons: [
    {
      id: 1,
      title: 'Qual o Fim principal?',
      audio: { active: 'lessons/1/audio_v1.mp3', ext: 'mp3', checksum: 'abc', history: [] },
      pdf: { active: 'lessons/1/lesson_v1.pdf', checksum: 'def', history: [] },
    },
  ],
}

describe('parseManifest', () => {
  it('parses valid JSON', () => {
    const result = parseManifest(JSON.stringify(baseManifest))
    expect(result.lessons).toHaveLength(1)
  })

  it('throws on invalid JSON', () => {
    expect(() => parseManifest('not json')).toThrow()
  })
})

describe('softDeleteFile', () => {
  it('sets audio active to null and appends history', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    const result = softDeleteFile(manifest, 1, 'audio')
    expect(result.lessons[0].audio!.active).toBeNull()
    expect(result.lessons[0].audio!.history).toContain('lessons/1/audio_v1.mp3')
  })

  it('sets pdf active to null and appends history', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    const result = softDeleteFile(manifest, 1, 'pdf')
    expect(result.lessons[0].pdf.active).toBeNull()
    expect(result.lessons[0].pdf.history).toContain('lessons/1/lesson_v1.pdf')
  })

  it('is a no-op when active is already null', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    manifest.lessons[0].audio!.active = null
    const result = softDeleteFile(manifest, 1, 'audio')
    expect(result.lessons[0].audio!.history).toHaveLength(0)
  })
})

describe('nextVersion', () => {
  it('returns 1 when history is empty and active is null', () => {
    expect(nextVersion(null, [])).toBe(1)
  })

  it('returns 2 when active is v1', () => {
    expect(nextVersion('lessons/1/audio_v1.mp3', [])).toBe(2)
  })

  it('returns max+1 across active and history', () => {
    expect(nextVersion('lessons/1/audio_v2.mp3', ['lessons/1/audio_v1.mp3'])).toBe(3)
  })
})

describe('removeLesson', () => {
  it('removes lesson from the list', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    const result = removeLesson(manifest, 1)
    expect(result.lessons).toHaveLength(0)
  })

  it('increments manifest version', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    const result = removeLesson(manifest, 1)
    expect(result.version).toBe(2)
  })

  it('is a no-op for unknown lesson id but still increments version', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    const result = removeLesson(manifest, 999)
    expect(result.lessons).toHaveLength(1)
    expect(result.version).toBe(2)
  })
})

describe('upsertLesson', () => {
  it('adds a new lesson to the list', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    const newLesson = { id: 2, title: 'New', pdf: { active: 'a', checksum: 'b', history: [] }, audio: null, questions: [] }
    const result = upsertLesson(manifest, newLesson)
    expect(result.lessons).toHaveLength(2)
  })

  it('replaces an existing lesson', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    const updated = { ...manifest.lessons[0], title: 'Updated Title' }
    const result = upsertLesson(manifest, updated)
    expect(result.lessons).toHaveLength(1)
    expect(result.lessons[0].title).toBe('Updated Title')
  })

  it('increments manifest version', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    const newLesson = { id: 2, title: 'New', pdf: { active: 'a', checksum: 'b', history: [] }, audio: null, questions: [] }
    const result = upsertLesson(manifest, newLesson)
    expect(result.version).toBe(2)
  })
})

describe('renameLesson', () => {
  it('updates the title of an existing lesson and increments version so mobile clients re-sync', () => {
    const manifest: Manifest = {
      version: 3,
      updated_at: '2024-01-01T00:00:00Z',
      lessons: [{ id: 1, title: 'Old Title', pdf: { active: null, checksum: '', history: [] }, audio: null, questions: [] }],
    }
    const result = renameLesson(manifest, 1, 'New Title')
    expect(result.version).toBe(4)
    expect(result.lessons[0].title).toBe('New Title')
    expect(result.updated_at).not.toBe('2024-01-01T00:00:00Z')
  })

  it('returns manifest unchanged when lesson is not found', () => {
    const manifest: Manifest = {
      version: 1,
      updated_at: '2024-01-01T00:00:00Z',
      lessons: [],
    }
    const result = renameLesson(manifest, 99, 'Ghost')
    expect(result).toStrictEqual(manifest)
  })
})

describe('applyUpload', () => {
  it('sets new active path, moves old to history, bumps version', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    const result = applyUpload(manifest, 1, 'audio', 'abc123')
    expect(result.lessons[0].audio!.active).toBe('lessons/1/audio_v2.mp3')
    expect(result.lessons[0].audio!.history).toContain('lessons/1/audio_v1.mp3')
    expect(result.lessons[0].audio!.checksum).toBe('abc123')
  })

  it('sets new pdf active path', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifest))
    const result = applyUpload(manifest, 1, 'pdf', 'xyz')
    expect(result.lessons[0].pdf.active).toBe('lessons/1/lesson_v2.pdf')
  })
})

const baseManifestWithContents: Manifest = {
  version: 1,
  updated_at: '2026-01-01T00:00:00Z',
  lessons: [],
  contents: [
    { id: 1, slug: 'welcome-video', title: 'Bem-vindo', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=abc' },
    { id: 2, slug: 'about-catechism', title: 'Sobre o Catecismo', type: 'TEXT', html: '<p>Conteúdo</p>' },
  ],
}

describe('parseManifest — backward compat with contents', () => {
  it('defaults contents to empty array when field is absent', () => {
    // Simulates an old manifest.json that predates the contents feature
    const oldManifest = { version: 5, updated_at: '2026-01-01', lessons: [] }
    const result = parseManifest(JSON.stringify(oldManifest))
    expect(result.contents).toEqual([])
  })

  it('preserves existing contents array when present', () => {
    const result = parseManifest(JSON.stringify(baseManifestWithContents))
    expect(result.contents).toHaveLength(2)
    expect(result.contents[0].slug).toBe('welcome-video')
  })
})

describe('upsertContent', () => {
  it('adds a new content entry to the manifest', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifestWithContents)) as Manifest
    const newContent: ManifestContent = {
      id: 3, slug: 'new-content', title: 'Novo', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=xyz',
    }
    const result = upsertContent(manifest, newContent)
    expect(result.contents).toHaveLength(3)
    expect(result.contents[2].slug).toBe('new-content')
  })

  it('replaces an existing content entry by id', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifestWithContents)) as Manifest
    const updated: ManifestContent = {
      id: 1, slug: 'welcome-video', title: 'Atualizado', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=new',
    }
    const result = upsertContent(manifest, updated)
    expect(result.contents).toHaveLength(2)
    expect(result.contents[0].title).toBe('Atualizado')
  })

  it('increments manifest version', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifestWithContents)) as Manifest
    const newContent: ManifestContent = {
      id: 3, slug: 'test', title: 'Test', type: 'TEXT', html: '<p>hi</p>',
    }
    const result = upsertContent(manifest, newContent)
    expect(result.version).toBe(2)
  })

  it('updates updated_at timestamp', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifestWithContents)) as Manifest
    const newContent: ManifestContent = {
      id: 3, slug: 'test', title: 'Test', type: 'TEXT', html: '<p>hi</p>',
    }
    const result = upsertContent(manifest, newContent)
    expect(result.updated_at).not.toBe('2026-01-01T00:00:00Z')
  })
})

describe('removeContent', () => {
  it('removes a content entry by id', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifestWithContents)) as Manifest
    const result = removeContent(manifest, 1)
    expect(result.contents).toHaveLength(1)
    expect(result.contents[0].id).toBe(2)
  })

  it('increments manifest version', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifestWithContents)) as Manifest
    const result = removeContent(manifest, 1)
    expect(result.version).toBe(2)
  })

  it('is a no-op for unknown content id but still increments version', () => {
    const manifest = JSON.parse(JSON.stringify(baseManifestWithContents)) as Manifest
    const result = removeContent(manifest, 999)
    expect(result.contents).toHaveLength(2)
    expect(result.version).toBe(2)
  })
})
