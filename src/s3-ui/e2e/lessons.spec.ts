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
