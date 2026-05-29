import { test, expect } from '@playwright/test'

test.beforeEach(async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Usuário').fill('victor')
  await page.getByLabel('Senha').fill(process.env.E2E_VICTOR_PASSWORD!)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await page.waitForURL('/lessons')
})

test('admin can access users page', async ({ page }) => {
  await page.goto('/users')
  await expect(page.getByRole('heading', { name: 'Usuários' })).toBeVisible()
})

test('admin can create a new user', async ({ page }) => {
  await page.goto('/users')
  const timestamp = Date.now()
  const testUsername = `e2e_user_${timestamp}`
  await page.getByLabel('Usuário').fill(testUsername)
  await page.getByLabel('Senha').fill('pass1234')
  await page.getByRole('button', { name: /criar/i }).click()
  await expect(page.getByText(testUsername)).toBeVisible()
})
