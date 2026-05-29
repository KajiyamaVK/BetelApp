import { test, expect } from '@playwright/test'

test('valid login redirects to /lessons', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Usuário').fill('victor')
  await page.getByLabel('Senha').fill(process.env.E2E_VICTOR_PASSWORD!)
  await page.getByRole('button', { name: 'Entrar' }).click()
  // Wait for client-side navigation after successful login
  await page.waitForURL('/lessons', { timeout: 15000 })
  await expect(page).toHaveURL('/lessons')
})

test('invalid login shows error message', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Usuário').fill('victor')
  await page.getByLabel('Senha').fill('wrong-password')
  await page.getByRole('button', { name: 'Entrar' }).click()
  // The API returns "Invalid credentials" in English; the page renders it directly
  await expect(page.getByText(/invalid credentials/i)).toBeVisible()
})
