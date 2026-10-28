# Testing Frameworks — Setup & Reference

Updated: April 2026

---

## JavaScript / TypeScript

### Vitest (Recommended for Vite/Next.js projects)

```bash
npm install -D vitest @vitest/ui happy-dom @testing-library/react
```

**`vitest.config.ts`**:
```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'happy-dom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov']
    }
  }
})
```

**Writing tests**:
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Counter } from './Counter'

describe('Counter', () => {
  it('starts at zero', () => {
    render(<Counter />)
    expect(screen.getByText('Count: 0')).toBeInTheDocument()
  })

  it('increments on click', async () => {
    const user = userEvent.setup()
    render(<Counter />)
    await user.click(screen.getByRole('button', { name: /increment/i }))
    expect(screen.getByText('Count: 1')).toBeInTheDocument()
  })

  it('calls onMax when reaches max', async () => {
    const onMax = vi.fn()
    const user = userEvent.setup()
    render(<Counter max={1} onMax={onMax} />)
    await user.click(screen.getByRole('button', { name: /increment/i }))
    expect(onMax).toHaveBeenCalledOnce()
  })
})
```

```bash
npx vitest          # watch mode
npx vitest run      # single run
npx vitest --ui     # visual UI at http://localhost:51204
npx vitest coverage # coverage report
```

---

### Playwright — E2E Testing

```bash
npm install -D @playwright/test
npx playwright install
```

**`playwright.config.ts`**:
```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'Mobile Chrome', use: { ...devices['Pixel 5'] } },
  ],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
})
```

**Writing E2E tests**:
```typescript
import { test, expect } from '@playwright/test'

test.describe('Authentication', () => {
  test('user can log in', async ({ page }) => {
    await page.goto('/login')

    await page.getByLabel('Email').fill('user@example.com')
    await page.getByLabel('Password').fill('password123')
    await page.getByRole('button', { name: 'Sign In' }).click()

    await expect(page).toHaveURL('/dashboard')
    await expect(page.getByText('Welcome back')).toBeVisible()
  })

  test('shows error for invalid credentials', async ({ page }) => {
    await page.goto('/login')
    await page.getByLabel('Email').fill('wrong@example.com')
    await page.getByLabel('Password').fill('wrong')
    await page.getByRole('button', { name: 'Sign In' }).click()

    await expect(page.getByText('Invalid credentials')).toBeVisible()
  })
})

test('API intercept', async ({ page }) => {
  await page.route('/api/users', route => {
    route.fulfill({
      status: 200,
      body: JSON.stringify([{ id: 1, name: 'Alice' }])
    })
  })

  await page.goto('/users')
  await expect(page.getByText('Alice')).toBeVisible()
})
```

```bash
npx playwright test
npx playwright test --ui           # interactive UI
npx playwright test --headed       # see browser
npx playwright codegen http://localhost:3000  # record test
npx playwright show-report        # HTML report
```

---

### Cypress

```bash
npm install -D cypress
npx cypress open
```

```typescript
// cypress/e2e/login.cy.ts
describe('Login', () => {
  beforeEach(() => {
    cy.visit('/login')
  })

  it('logs in successfully', () => {
    cy.get('[data-testid="email"]').type('user@example.com')
    cy.get('[data-testid="password"]').type('password123')
    cy.get('button[type="submit"]').click()
    cy.url().should('include', '/dashboard')
  })

  it('intercepts API', () => {
    cy.intercept('GET', '/api/users', { fixture: 'users.json' }).as('getUsers')
    cy.visit('/users')
    cy.wait('@getUsers')
    cy.contains('Alice').should('exist')
  })
})
```

---

## Python Testing

### pytest

```bash
pip install pytest pytest-asyncio httpx pytest-cov
```

**`tests/test_users.py`**:
```python
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.fixture
async def client():
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client

@pytest.mark.asyncio
async def test_get_users(client):
    response = await client.get("/users")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

@pytest.mark.asyncio
async def test_create_user(client):
    response = await client.post("/users", json={"name": "Alice", "email": "a@b.com"})
    assert response.status_code == 201
    assert response.json()["name"] == "Alice"

@pytest.mark.asyncio
async def test_not_found(client):
    response = await client.get("/users/nonexistent")
    assert response.status_code == 404
```

**`pytest.ini`**:
```ini
[pytest]
asyncio_mode = auto
testpaths = tests
addopts = -v --cov=app --cov-report=term-missing
```

```bash
pytest                           # run all
pytest tests/test_users.py       # single file
pytest -k "test_create"          # by name pattern
pytest --cov --cov-report=html   # with HTML coverage
```

---

## Testing Best Practices

### Test pyramid
```
         /\
        /E2E\         — Few, slow, full-system (Playwright)
       /------\
      /Integr. \      — Some, DB/API integration (pytest-asyncio)
     /----------\
    /   Unit     \    — Many, fast, isolated (Vitest/pytest)
   /──────────────\
```

### Testing checklist
- [ ] Happy path works
- [ ] Error cases handled (400, 404, 500)
- [ ] Auth/permissions enforced
- [ ] Edge cases (empty list, max length, special chars)
- [ ] Performance (timeout, concurrent requests)
- [ ] Accessibility (ARIA roles, keyboard nav)

### Mock strategies
```typescript
// Mock a module
vi.mock('@/lib/db', () => ({
  db: { user: { findMany: vi.fn().mockResolvedValue([]) } }
}))

// Mock a single function
const mockFetch = vi.spyOn(global, 'fetch').mockResolvedValue({
  ok: true,
  json: () => Promise.resolve({ data: [] })
} as Response)

// Mock timers
vi.useFakeTimers()
vi.advanceTimersByTime(1000)
vi.useRealTimers()
```

### CI configuration
```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - run: npm ci
      - run: npm test -- --coverage

  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run build
      - run: npx playwright test
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
```
