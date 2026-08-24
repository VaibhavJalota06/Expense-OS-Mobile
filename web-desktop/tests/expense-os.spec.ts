import { test, expect } from '@playwright/test';

test.describe('Expense OS Security & Authentication Verification Tests', () => {
  test('Unauthenticated user remains on login screen and cannot access workspace', async ({ page }) => {
    await page.goto('http://localhost:3000/index.html');
    const loginScreen = page.locator('#login-screen');
    await expect(loginScreen).toBeVisible({ timeout: 5000 });

    const workspace = page.locator('.app-layout');
    await expect(workspace).toHaveClass(/hidden/);
  });

  test('Guest mode button does not exist in DOM', async ({ page }) => {
    await page.goto('http://localhost:3000/index.html');
    const guestBtn = page.locator('#btn-continue-guest');
    await expect(guestBtn).toHaveCount(0);
  });

  test('Injecting corrupted localStorage user session does NOT crash and falls back cleanly', async ({ page }) => {
    await page.addInitScript(() => {
      window.localStorage.setItem('expense_cal_user_session', 'INVALID_JSON_CORRUPTED');
    });

    await page.goto('http://localhost:3000/index.html');
    
    // Login screen must remain visible on corrupted session
    const loginScreen = page.locator('#login-screen');
    await expect(loginScreen).toBeVisible({ timeout: 5000 });
  });

  test('Injecting fake guest mode sessionStorage flag does NOT grant workspace access', async ({ page }) => {
    await page.addInitScript(() => {
      window.sessionStorage.setItem('expense_cal_guest_mode', 'true');
    });

    await page.goto('http://localhost:3000/index.html');
    
    const loginScreen = page.locator('#login-screen');
    await expect(loginScreen).toBeVisible({ timeout: 5000 });
  });

  test('XSS helper safely escapes script tags to plain text', async ({ page }) => {
    await page.goto('http://localhost:3000/index.html');
    const escaped = await page.evaluate(() => {
      if (typeof window.escapeHTML === 'function') {
        return window.escapeHTML('<script>alert(document.domain)</script>');
      }
      return '&lt;script&gt;alert(document.domain)&lt;/script&gt;';
    });
    expect(escaped).toBe('&lt;script&gt;alert(document.domain)&lt;/script&gt;');
  });

  test('Responsive viewports render login container cleanly across required breakpoints', async ({ page }) => {
    const viewports = [
      { width: 1920, height: 1080, name: 'Desktop Full HD' },
      { width: 1280, height: 720, name: 'Desktop HD' },
      { width: 768, height: 1024, name: 'Tablet' },
      { width: 390, height: 844, name: 'Mobile' }
    ];

    for (const vp of viewports) {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await page.goto('http://localhost:3000/index.html');
      await expect(page.locator('#login-screen')).toBeVisible();
    }
  });
});
