export interface ManifestLesson {
  id: number
  title: string
  audio: { active: string | null; ext: string; checksum: string; history: string[] } | null
  pdf: { active: string | null; checksum: string; history: string[] }
}

export interface Manifest {
  version: number
  updated_at: string
  lessons: ManifestLesson[]
}

/** Parses a JSON string into a Manifest; throws SyntaxError on malformed input */
export function parseManifest(json: string): Manifest {
  return JSON.parse(json) as Manifest
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
  if (entry.active) {
    entry.history = [...entry.history, entry.active]
    entry.active = null
  }

  return { ...manifest, updated_at: new Date().toISOString() }
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
  const version = nextVersion(entry.active, entry.history)
  const extension = type === 'audio' ? 'mp3' : 'pdf'
  const filePrefix = type === 'audio' ? 'audio' : 'lesson'
  const newPath = `lessons/${lessonId}/${filePrefix}_v${version}.${extension}`

  if (entry.active) entry.history = [...entry.history, entry.active]
  entry.active = newPath
  entry.checksum = checksum

  return { ...manifest, updated_at: new Date().toISOString() }
}
