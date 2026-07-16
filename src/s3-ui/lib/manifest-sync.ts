import { prisma } from '@/lib/prisma'
import { getObjectText, uploadObject } from '@/lib/minio'
import { Manifest, parseManifest, upsertLesson, ManifestLesson } from '@/lib/manifest'
import type { Lesson, Question } from '@prisma/client'

export const MANIFEST_OBJECT = 'manifest.json'

/** Reads and parses the manifest from MinIO without writing. */
export async function readManifest(): Promise<Manifest> {
  return parseManifest(await getObjectText(MANIFEST_OBJECT))
}

/**
 * Reads the manifest from MinIO, applies a transform, and writes the result back.
 * Skips the write when the transform returns the same object reference (no-op).
 * Returns the resulting manifest.
 */
export async function updateManifest(transform: (manifest: Manifest) => Manifest): Promise<Manifest> {
  const before = await readManifest()
  const after = transform(before)
  if (after !== before) {
    await uploadObject(MANIFEST_OBJECT, Buffer.from(JSON.stringify(after, null, 2)), 'application/json')
  }
  return after
}

/**
 * Builds a ManifestLesson from a Prisma Lesson record and its active questions.
 * Shared by publish/route.ts and resyncLessonInManifestIfPublished to avoid
 * duplicating the field mapping in both callers — changes to the manifest schema
 * only need to be made here.
 */
export function buildManifestLesson(lesson: Lesson, questions: Question[]): ManifestLesson {
  return {
    id: lesson.id,
    title: lesson.title,
    pdf: {
      active: lesson.pdfActive,
      checksum: lesson.pdfChecksum ?? '',
      history: (lesson.pdfHistory as string[]) ?? [],
    },
    audio: lesson.audioActive
      ? {
          active: lesson.audioActive,
          ext: lesson.audioExt ?? 'mp3',
          checksum: lesson.audioChecksum ?? '',
          history: (lesson.audioHistory as string[]) ?? [],
        }
      : null,
    questions: questions.map((question) => ({
      id: question.id,
      q: question.question,
      a: question.answer,
    })),
  }
}

/**
 * Re-syncs the manifest entry for the given lesson if it is currently published.
 * Fetches active (non-deleted) questions and writes an updated manifest to MinIO.
 * No-ops silently when the lesson is unpublished — the manifest should not contain it.
 * Intended for best-effort calls from Q&A mutation routes; callers should catch errors.
 */
export async function resyncLessonInManifestIfPublished(lessonId: number): Promise<void> {
  const lesson = await prisma.lesson.findUnique({ where: { id: lessonId } })
  if (!lesson?.published) return

  const activeQuestions = await prisma.question.findMany({
    where: { lessonId, deletedAt: null },
    orderBy: { order: 'asc' },
  })

  const manifestLesson = buildManifestLesson(lesson, activeQuestions)
  await updateManifest((manifest) => upsertLesson(manifest, manifestLesson))
}
