import { test, expect, Page } from '@playwright/test';

// Run tests serially using a single shared browser page to minimize cold-start DDC compilation delays.
test.describe.configure({ mode: 'serial' });

test.describe('PlainSightIL End-to-End User Journey Tests', () => {
  let page: Page;

  test.beforeAll(async ({ browser }) => {
    // Extend hook timeout to 3 minutes for cold DDC compilation
    test.setTimeout(180000);
    // Create page and set console listeners
    page = await browser.newPage();
    page.on('console', msg => console.log(`[Browser Console] ${msg.type()}: ${msg.text()}`));
    page.on('pageerror', err => console.log(`[Browser Page Error] ${err.stack || err.message}`));

    console.log('Navigating to PlainSightIL for initial setup...');
    await page.goto('http://localhost:8080/?enable-accessibility=true');

    // Clear localStorage once at the start (not via persistent addInitScript)
    await page.evaluate(() => {
      window.localStorage.clear();
      window.sessionStorage.clear();
    });

    console.log('Reloading after clearing storage...');
    await page.goto('http://localhost:8080/?enable-accessibility=true');
    
    // Wait for DDC script compilation to complete (up to 120 seconds)
        const placeholder = page.locator('flt-semantics-placeholder').first();
    await expect(placeholder).toBeAttached({ timeout: 120000 });
    await placeholder.dispatchEvent('click');
    console.log('PlainSightIL bootstrapped and accessibility layer initialized.');
  });

  test.afterAll(async () => {
    if (page) {
      await page.close();
    }
  });

  test('E2E-AUTH-01: Guest Session Login Flow', async () => {
    // Assert we start on the Login screen
    await expect(page.getByText('Welcome Back')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('Continue as Guest')).toBeVisible();
    await expect(page.getByText('Sign in with Google')).toBeVisible();

    // Tap Continue as Guest
    await page.getByText('Continue as Guest').click();

    // Assert we successfully navigate to the Dashboard
    await expect(page.getByText('Democratizing Civic Data')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('PlainSight IL').first()).toBeVisible();
  });

  test('E2E-LOC-01: Language Switcher & UI Translation', async () => {
    // Assert initial language toggle key is "HE" (English mode active)
    const langBtn = page.getByText('HE', { exact: true });
    await expect(langBtn).toBeVisible();
    await langBtn.click();

    // Assert content translates to Hebrew (RTL mode)
    await expect(page.getByText('הנגשת מידע ממשלתי לציבור')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText('אנטנות סלולריות').first()).toBeVisible();
    await expect(page.getByText('חברות בפירוק').first()).toBeVisible();

    // Assert toggle button text updates to "EN"
    await expect(page.getByText('EN', { exact: true })).toBeVisible();

    // Tap language toggle to return to English (LTR mode)
    await page.getByText('EN', { exact: true }).click();
    await expect(page.getByText('Democratizing Civic Data')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText('HE', { exact: true })).toBeVisible();
  });

  test('E2E-ANT-01 & E2E-ANT-02: Map Ingestion, Clusters & Layer Toggle', async () => {
    // Navigate to Cellular Antennas card
    const antennasCard = page.getByText('Cellular Antennas').first();
    await expect(antennasCard).toBeVisible();
    await antennasCard.click();

    // Assert map visualizer is loaded
    await expect(page.getByText('Active Towers')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('Construction Permits')).toBeVisible();

    // Verify Layer Toggle (Active Towers -> Construction Permits)
    await page.getByText('Construction Permits').click();

    // Verify Layer Toggle back (Construction Permits -> Active Towers)
    await page.getByText('Active Towers').click();
  });

  test('E2E-ANT-03: GPS Recenter Fallbacks', async () => {
    // Locate the GPS Recenter button
    const recenterBtn = page.getByText('Recenter on Location').first();
    await expect(recenterBtn).toBeVisible({ timeout: 10000 });
    await recenterBtn.click();

    // Assert location access explanation dialog is shown
    await expect(page.getByText('Location Access')).toBeVisible({ timeout: 10000 });

    // Tap "Cancel" to simulate user permission denial
    await page.getByText('Cancel').click();

    // Assert fallback SnackBar displays coordinates warning
    await expect(page.getByText('Could not access current location. Centering on Tel Aviv.')).toBeVisible({ timeout: 10000 });

    // Tap GPS Recenter again
    await recenterBtn.click();
    await expect(page.getByText('Location Access')).toBeVisible({ timeout: 5000 });

    // Tap "Allow" to simulate consent
    await page.getByText('Allow').click();

    // Assert dialog closes
    await expect(page.getByText('Location Access')).not.toBeVisible();

    // Go back to Dashboard
    await page.getByText('Back').first().click();
    await expect(page.getByText('Democratizing Civic Data')).toBeVisible({ timeout: 15000 });
  });

  test('E2E-LIQ-01 & E2E-LIQ-02: Directory Search, Filtering, and Scroll', async () => {
    // Navigate to Directory tab in the bottom bar
    const directoryTab = page.getByRole('button', { name: 'Directory' }).first();
    await expect(directoryTab).toBeVisible();
    await directoryTab.click();

    // Locate "מאגר הכונס הרשמי" card and click "Open Visualizer"
    const card = page.locator('[aria-label*="מאגר הכונס הרשמי"], [aria-label*="הכונס הרשמי"]').first();
    await expect(card).toBeVisible({ timeout: 15000 });

    const openVisualizerBtn = card.getByText('Open Visualizer').first();
    await expect(openVisualizerBtn).toBeVisible();
    await openVisualizerBtn.click();

    // Assert we are on the Companies in Liquidation visualizer page
    await expect(page.getByText('Companies in Liquidation')).toBeVisible({ timeout: 15000 });

    // Locate the search input using placeholder
    const searchInput = page.locator('input[placeholder*="Search by Name"], [aria-label*="Search by Name"]');
    await expect(searchInput).toBeVisible({ timeout: 10000 });

    // Fill search with "פרסום"
    await searchInput.fill('פרסום');

    // Assert "בשן פרסום ויחסי צבור בע~מ" is visible and other companies are filtered out
    await expect(page.getByText('בשן פרסום ויחסי צבור בע~מ').first()).toBeVisible({ timeout: 10000 });
    await expect(page.getByText('מלון הגליל בע~מ').first()).not.toBeVisible();

    // Clear the search field
    await searchInput.fill('');

    // Assert other companies are restored
    await expect(page.getByText('מלון הגליל בע~מ').first()).toBeVisible({ timeout: 10000 });
  });

  test('E2E-OFF-01: Offline Mode Caching', async ({ context }) => {
    // Set page to offline mode (sever network connection)
    await context.setOffline(true);

    // Navigate back to Directory screen to clear visualizer DOM state
    await page.getByText('Back').first().click();
    await expect(page.getByText('Dataset Directory')).toBeVisible({ timeout: 10000 });

    // Navigate to Directory tab again while offline
    const directoryTab = page.getByRole('button', { name: 'Directory' }).first();
    await directoryTab.click();

    // Open the liquidation visualizer again while offline
    const card = page.locator('[aria-label*="מאגר הכונס הרשמי"], [aria-label*="הכונס הרשמי"]').first();
    await expect(card).toBeVisible({ timeout: 10000 });
    await card.getByText('Open Visualizer').first().click();

    // Assert previously loaded cache items are retrieved and visible offline
    await expect(page.getByText('מלון הגליל בע~מ').first()).toBeVisible({ timeout: 10000 });
    await expect(page.getByText('בשן פרסום ויחסי צבור בע~מ').first()).toBeVisible({ timeout: 10000 });

    // Restore connection and clean up offline state
    await context.setOffline(false);
  });

  test('E2E-AUTH-02: Session Persistence Bypass', async () => {
    const valBefore = await page.evaluate(() => window.localStorage.getItem('guest_mode'));
    expect(valBefore).toBe('true');

    // Reload the page (simulating restart/re-launch)
    console.log('Reloading page to test session persistence...');
    await page.goto('http://localhost:8080/?enable-accessibility=true');
    
    const valAfter = await page.evaluate(() => window.localStorage.getItem('guest_mode'));
    expect(valAfter).toBe('true');

    // Re-enable accessibility on page reload
    const placeholder = page.locator('flt-semantics-placeholder').first();
    await expect(placeholder).toBeAttached({ timeout: 60000 });
    await placeholder.dispatchEvent('click');

    // Assert we bypass LoginPage and load directly to Dashboard
    await expect(page.getByText('Democratizing Civic Data')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('Continue as Guest')).not.toBeVisible();
    await expect(page.getByText('Sign in with Google')).not.toBeVisible();
  });
});
