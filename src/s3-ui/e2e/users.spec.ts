import { test, expect, type Page } from '@playwright/test'

async function loginAsAdmin(page: Page) {
  await page.goto('/login')
  await page.getByLabel('Usuário').fill('victor')
  await page.getByLabel('Senha').fill(process.env.E2E_VICTOR_PASSWORD!)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await page.waitForURL('/lessons')
}

async function deleteE2eUsers(page: Page) {
  const res = await page.request.get('/api/users')
  const users: Array<{ id: number; username: string }> = await res.json()
  const e2eUsers = users.filter((user) => user.username.startsWith('e2e_user_'))
  await Promise.all(
    e2eUsers.map((user) => page.request.delete(`/api/users/${user.id}`)),
  )
}

test.beforeEach(async ({ page }) => {
  await loginAsAdmin(page)
})

test.afterAll(async ({ browser }) => {
  const context = await browser.newContext()
  const page = await context.newPage()
  await loginAsAdmin(page)
  await deleteE2eUsers(page)
  await context.close()
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
  await page.getByRole('button', { name: /criar/i }).click()
  await expect(page.getByText(testUsername)).toBeVisible()
})
