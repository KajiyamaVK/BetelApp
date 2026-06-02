import { test, expect } from '@playwright/test'

test.beforeEach(async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Usuário').fill('victor')
  await page.getByLabel('Senha').fill(process.env.E2E_VICTOR_PASSWORD!)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await page.waitForURL('/lessons')
})

test('lesson list shows 24 items', async ({ page }) => {
  const items = page.locator('[data-testid="lesson-row"]')
  // Wait for at least one row to appear (async fetch from /api/lessons) before asserting total count
  await items.first().waitFor({ timeout: 15000 })
  await expect(items).toHaveCount(24)
})

test('publish button toggles label between Publicar and Despublicar after confirmation', async ({ page }) => {
  // Wait for rows to load, then find the first row that has an enabled publish toggle
  await page.locator('[data-testid="lesson-row"]').first().waitFor({ timeout: 15000 })
  const enabledToggleBtn = page
    .locator('[data-testid="lesson-row"]')
    .locator('button:not([disabled])')
    .filter({ hasText: /publicar|despublicar/i })
    .first()
  await enabledToggleBtn.waitFor({ timeout: 5000 })

  const toggleBtn = enabledToggleBtn
  const initialLabel = await toggleBtn.textContent()

  // Click opens a confirmation dialog — confirm it
  await toggleBtn.click()
  await page.getByRole('button', { name: 'Confirmar' }).click()

  const expectedLabel = initialLabel?.trim().toLowerCase() === 'publicar' ? 'Despublicar' : 'Publicar'
  await expect(toggleBtn).toHaveText(expectedLabel)

  // Restore original state by confirming again
  await toggleBtn.click()
  await page.getByRole('button', { name: 'Confirmar' }).click()
  await expect(toggleBtn).toHaveText(initialLabel!.trim())
})

test('create lesson with pdf: dialog closes, lesson appears in list with pdf badge', async ({ page }) => {
  await page.locator('[data-testid="lesson-row"]').first().waitFor({ timeout: 15000 })

  const initialCount = await page.locator('[data-testid="lesson-row"]').count()

  await page.getByRole('button', { name: '+ Nova Lição' }).click()
  await page.locator('#lesson-title').waitFor({ timeout: 5000 })

  await page.locator('#lesson-id').fill('200')
  await page.locator('#lesson-title').fill('Lição E2E com PDF')

  // Cria um PDF mínimo válido em memória via JS
  const pdfBytes = Buffer.from(
    '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000058 00000 n\n0000000115 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n190\n%%EOF'
  )
  await page.locator('#lesson-pdf').setInputFiles({
    name: 'test.pdf',
    mimeType: 'application/pdf',
    buffer: pdfBytes,
  })

  await page.getByRole('button', { name: 'Salvar' }).click()

  // Dialog deve fechar automaticamente após criar + upload
  await expect(page.locator('[role="dialog"]')).toBeHidden({ timeout: 15000 })

  // Lista deve ter mais um item sem reload
  await expect(page.locator('[data-testid="lesson-row"]')).toHaveCount(initialCount + 1, { timeout: 5000 })

  // Lição 200 deve ter badge PDF ✓ (não ⚠)
  const newRow = page.locator('[data-testid="lesson-row"]').filter({ hasText: 'Lição E2E com PDF' })
  await expect(newRow).toBeVisible()
  await expect(newRow.locator('span').filter({ hasText: '✓' }).last()).toBeVisible()
})

test('create lesson without pdf: dialog closes and lesson appears in list', async ({ page }) => {
  await page.locator('[data-testid="lesson-row"]').first().waitFor({ timeout: 15000 })

  const initialCount = await page.locator('[data-testid="lesson-row"]').count()

  await page.getByRole('button', { name: '+ Nova Lição' }).click()
  await page.locator('#lesson-title').waitFor({ timeout: 5000 })

  await page.locator('#lesson-id').fill('201')
  await page.locator('#lesson-title').fill('Lição E2E sem PDF')

  await page.getByRole('button', { name: 'Salvar' }).click()

  await expect(page.locator('[role="dialog"]')).toBeHidden({ timeout: 15000 })
  await expect(page.locator('[data-testid="lesson-row"]')).toHaveCount(initialCount + 1, { timeout: 5000 })
})

test('create lesson with duplicate id shows error inside dialog', async ({ page }) => {
  await page.locator('[data-testid="lesson-row"]').first().waitFor({ timeout: 15000 })

  await page.getByRole('button', { name: '+ Nova Lição' }).click()
  await page.locator('#lesson-title').waitFor({ timeout: 5000 })

  // ID 2 já existe
  await page.locator('#lesson-id').fill('2')
  await page.locator('#lesson-title').fill('Duplicada')

  await page.getByRole('button', { name: 'Salvar' }).click()

  // Dialog deve permanecer aberto com mensagem de erro
  await expect(page.locator('[role="dialog"]')).toBeVisible({ timeout: 5000 })
  await expect(page.locator('[role="dialog"]').getByText(/já existe/i)).toBeVisible({ timeout: 5000 })
})

test('edit lesson title inline via double-click', async ({ page }) => {
  const firstTitle = page.locator('[data-testid="lesson-title"]').first()
  const originalText = await firstTitle.textContent()
  await firstTitle.dblclick()
  await page.keyboard.press('Control+A')
  await page.keyboard.type('New Test Title E2E')
  await page.keyboard.press('Enter')
  await expect(firstTitle).toHaveText('New Test Title E2E')
  // Restore original title
  await firstTitle.dblclick()
  await page.keyboard.press('Control+A')
  await page.keyboard.type(originalText ?? 'Qual o Fim principal?')
  await page.keyboard.press('Enter')
})
