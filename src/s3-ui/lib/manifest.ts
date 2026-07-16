export interface ManifestQuestion {
  id: number
  q: string
  a: string
}

export interface ManifestLesson {
  id: number
  title: string
  audio: { active: string | null; ext: string; checksum: string; history: string[] } | null
  pdf: { active: string | null; checksum: string; history: string[] }
  questions: ManifestQuestion[]
}

export interface ManifestContentVideo {
  id: number
  slug: string
  title: string
  type: 'VIDEO'
  youtubeUrl: string
}

export interface ManifestContentText {
  id: number
  slug: string
  title: string
  type: 'TEXT'
  html: string
}

// Multi-page TEXT content: pages array replaces the single html field.
// The mobile app renders each element as a separate swipeable page in BetelDialog.
export interface ManifestContentMultiText {
  id: number
  slug: string
  title: string
  type: 'TEXT'
  pages: string[]
}

export type ManifestContent = ManifestContentVideo | ManifestContentText | ManifestContentMultiText

export interface Manifest {
  version: number
  updated_at: string
  lessons: ManifestLesson[]
  contents: ManifestContent[]
}

/** Parses a JSON string into a Manifest; throws SyntaxError on malformed input.
 *  Normalizes the contents field to [] for backward compat with old manifests
 *  that predate the contents feature.
 */
export function parseManifest(json: string): Manifest {
  const raw = JSON.parse(json) as Partial<Manifest> & Pick<Manifest, 'version' | 'updated_at' | 'lessons'>
  return { ...raw, contents: raw.contents ?? [] }
}

/**
 * Soft-deletes the active file for the given lesson and type.
 * Moves the current active path into history and sets active to null.
 * Returns the manifest unchanged if the lesson is not found or active is already null.
 */
export function softDeleteFile(
  manifest: Manifest,
  lessonId: number,
  type: 'audio' | 'pdf',
): Manifest {
  const lesson = manifest.lessons.find((lesson) => lesson.id === lessonId)
  if (!lesson) return manifest

  const entry = lesson[type]
  if (!entry || !entry.active) return manifest

  return {
    ...manifest,
    version: manifest.version + 1,
    updated_at: new Date().toISOString(),
    lessons: manifest.lessons.map((l) =>
      l.id !== lessonId
        ? l
        : {
            ...l,
            [type]:
              type === 'audio'
                ? { ...(l.audio!), history: [...l.audio!.history, l.audio!.active!], active: null }
                : { ...l.pdf, history: [...l.pdf.history, l.pdf.active!], active: null },
          },
    ),
  }
}

/**
 * Calculates the next version number by scanning all known paths (active + history)
 * for version suffixes like `_v3.mp3` and returning max + 1.
 * Returns 1 when no versioned paths exist yet.
 */
export function nextVersion(active: string | null, history: string[]): number {
  const allPaths = [...history, ...(active ? [active] : [])]
  if (allPaths.length === 0) return 1

  const versionNumbers = allPaths.map((path) => {
    const match = path.match(/_v(\d+)\.(mp3|pdf)$/)
    return match ? parseInt(match[1], 10) : 0
  })

  return Math.max(...versionNumbers) + 1
}

/** Removes a lesson from the manifest by id and increments version. */
export function removeLesson(manifest: Manifest, lessonId: number): Manifest {
  return {
    ...manifest,
    version: manifest.version + 1,
    updated_at: new Date().toISOString(),
    lessons: manifest.lessons.filter((lesson) => lesson.id !== lessonId),
  }
}

/** Adds or replaces a lesson entry in the manifest and increments version. */
export function upsertLesson(manifest: Manifest, lesson: ManifestLesson): Manifest {
  const exists = manifest.lessons.some((existing) => existing.id === lesson.id)
  return {
    ...manifest,
    version: manifest.version + 1,
    updated_at: new Date().toISOString(),
    lessons: exists
      ? manifest.lessons.map((existing) => (existing.id === lesson.id ? lesson : existing))
      : [...manifest.lessons, lesson],
  }
}

/**
 * Updates the title of an existing lesson entry in the manifest and increments version
 * so mobile clients detect the change on next sync.
 * Returns the manifest unchanged if the lesson is not found.
 */
export function renameLesson(manifest: Manifest, lessonId: number, newTitle: string): Manifest {
  const exists = manifest.lessons.some((lesson) => lesson.id === lessonId)
  if (!exists) return manifest
  return {
    ...manifest,
    version: manifest.version + 1,
    updated_at: new Date().toISOString(),
    lessons: manifest.lessons.map((lesson) =>
      lesson.id === lessonId ? { ...lesson, title: newTitle } : lesson,
    ),
  }
}

/**
 * Applies a new file upload to the manifest:
 * - bumps the version number
 * - moves the previous active path into history
 * - sets the new active path
 * - updates the checksum
 */
export function applyUpload(
  manifest: Manifest,
  lessonId: number,
  type: 'audio' | 'pdf',
  checksum: string,
): Manifest {
  const lesson = manifest.lessons.find((lesson) => lesson.id === lessonId)
  if (!lesson) return manifest

  const entry = lesson[type]
  if (!entry) return manifest

  const version = nextVersion(entry.active, entry.history)
  const extension = type === 'audio' ? 'mp3' : 'pdf'
  const filePrefix = type === 'audio' ? 'audio' : 'lesson'
  const newPath = `lessons/${lessonId}/${filePrefix}_v${version}.${extension}`
  const newHistory = entry.active ? [...entry.history, entry.active] : entry.history

  const updatedEntry =
    type === 'audio'
      ? { ...(entry as NonNullable<ManifestLesson['audio']>), active: newPath, checksum, history: newHistory }
      : { ...entry, active: newPath, checksum, history: newHistory }

  return {
    ...manifest,
    version: manifest.version + 1,
    updated_at: new Date().toISOString(),
    lessons: manifest.lessons.map((l) =>
      l.id !== lessonId ? l : { ...l, [type]: updatedEntry },
    ),
  }
}

/** Adds or replaces a content entry in the manifest and increments version. */
export function upsertContent(manifest: Manifest, content: ManifestContent): Manifest {
  const exists = manifest.contents.some((existing) => existing.id === content.id)
  return {
    ...manifest,
    version: manifest.version + 1,
    updated_at: new Date().toISOString(),
    contents: exists
      ? manifest.contents.map((existing) => (existing.id === content.id ? content : existing))
      : [...manifest.contents, content],
  }
}

/** Removes a content entry from the manifest by id and increments version. */
export function removeContent(manifest: Manifest, contentId: number): Manifest {
  return {
    ...manifest,
    version: manifest.version + 1,
    updated_at: new Date().toISOString(),
    contents: manifest.contents.filter((content) => content.id !== contentId),
  }
}
