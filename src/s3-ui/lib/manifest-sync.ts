import { prisma } from '@/lib/prisma'
import { getObjectText, uploadObject } from '@/lib/minio'
import { parseManifest, upsertLesson, ManifestLesson } from '@/lib/manifest'
import type { Lesson, Question } from '@prisma/client'

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

  const manifestText = await getObjectText('manifest.json')
  const manifest = parseManifest(manifestText)

  const manifestLesson = buildManifestLesson(lesson, activeQuestions)
  const updatedManifest = upsertLesson(manifest, manifestLesson)
  await uploadObject('manifest.json', Buffer.from(JSON.stringify(updatedManifest, null, 2)), 'application/json')
}
