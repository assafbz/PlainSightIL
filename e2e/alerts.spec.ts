import { test, expect, Page } from '@playwright/test';

test.describe.configure({ mode: 'serial' });

test.describe('PlainSightIL End-to-End Alerts Tests', () => {
  let page: Page;
  
  const firestorePort = process.env.FIRESTORE_PORT || '8081';
  const authPort = process.env.AUTH_PORT || '9099';
  const functionsPort = process.env.FUNCTIONS_PORT || '5002';
  const queryParams = `?enable-accessibility=true&firestore_port=${firestorePort}&auth_port=${authPort}&functions_port=${functionsPort}`;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(180000);
    const context = await browser.newContext();
    page = await context.newPage();
    await page.setViewportSize({ width: 1280, height: 1200 });
    
    await page.goto(`/${queryParams}`);
    
    const placeholder = page.locator('flt-semantics-placeholder').first();
    await expect(placeholder).toBeAttached({ timeout: 120000 });
    await placeholder.dispatchEvent('click');
  });

  test.afterAll(async () => {
    if (page) {
      await page.close();
    }
  });

  test('E2E-ALERT-01: Alerts feed guest state and layout verification', async () => {
    // Assert we start on the Login screen and tap Continue as Guest
    await expect(page.getByText('Welcome Back')).toBeVisible({ timeout: 15000 });
    await page.getByText('Continue as Guest').click();
    await expect(page.getByText('Democratizing Civic Data')).toBeVisible({ timeout: 15000 });

    // Navigate to tab 2 (Alerts)
    const alertsTab = page.getByRole('button', { name: 'Alerts' }).first();
    await expect(alertsTab).toBeVisible();
    await alertsTab.click();

    // Verify guest state is shown since we are not authenticated
    await expect(page.getByText('Stay Updated')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('Sign in with Google')).toBeVisible();

    // Go back to Home / Dashboard tab
    const homeTab = page.getByRole('button', { name: 'Home' }).first();
    await homeTab.click();
    await expect(page.getByText('Democratizing Civic Data')).toBeVisible({ timeout: 10000 });
  });
});
