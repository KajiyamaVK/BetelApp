export const ContentLocation = {
  HOME: 'HOME',
  HELP_DEVOCIONAIS: 'HELP_DEVOCIONAIS',
  HELP_MUSICAS: 'HELP_MUSICAS',
  HELP_REVISOES: 'HELP_REVISOES',
  HELP_FAVORITOS: 'HELP_FAVORITOS',
} as const

export type ContentLocation = (typeof ContentLocation)[keyof typeof ContentLocation]

export const CONTENT_LOCATION_LABELS: Record<ContentLocation, string> = {
  HOME: 'Tela Inicial',
  HELP_DEVOCIONAIS: 'Ajuda: Aba Devocionais',
  HELP_MUSICAS: 'Ajuda: Aba Músicas',
  HELP_REVISOES: 'Ajuda: Aba Revisões',
  HELP_FAVORITOS: 'Ajuda: Aba Favoritos',
}
