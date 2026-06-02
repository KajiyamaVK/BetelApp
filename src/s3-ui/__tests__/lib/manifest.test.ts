import {
  parseManifest,
  softDeleteFile,
  applyUpload,
  nextVersion,
  removeLesson,
  upsertLesson,
  renameLesson,
  type Manifest,
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
  it('updates the title of an existing lesson without bumping version', () => {
    const manifest: Manifest = {
      version: 3,
      updated_at: '2024-01-01T00:00:00Z',
      lessons: [{ id: 1, title: 'Old Title', pdf: { active: null, checksum: '', history: [] }, audio: null, questions: [] }],
    }
    const result = renameLesson(manifest, 1, 'New Title')
    expect(result.version).toBe(3)
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
