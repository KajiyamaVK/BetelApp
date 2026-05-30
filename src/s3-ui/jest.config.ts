import type { Config } from 'jest'
import nextJest from 'next/jest.js'

const createJestConfig = nextJest({ dir: './' })

const config: Config = {
  testEnvironment: 'jest-environment-jsdom',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.ts'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
  },
  // Exclude Playwright E2E test files — they are run by `npx playwright test`, not Jest.
  testPathIgnorePatterns: ['/node_modules/', '<rootDir>/e2e/'],
  // Run tests sequentially to prevent DB contention between parallel workers.
  maxWorkers: 1,
}

// next/jest prepends '/node_modules/' which swallows any trailing exceptions.
// We override transformIgnorePatterns after next/jest builds the config so
// that ESM-only packages like jose are transpiled by the SWC transformer.
const createConfig = async () => {
  const nextConfig = await createJestConfig(config)()
  return {
    ...nextConfig,
    transformIgnorePatterns: [
      // Allow the SWC transform to process jose (ESM-only) and any other
      // ESM packages we add in the future.
      '/node_modules/(?!(jose)/)',
      '^.+\\.module\\.(css|sass|scss)$',
    ],
  }
}

export default createConfig
