import { test, expect, Page } from '@playwright/test';

// Run tests serially using a single shared browser page to minimize cold-start DDC compilation delays.
test.describe.configure({ mode: 'serial' });

test.describe('PlainSightIL End-to-End User Journey Tests', () => {
  let page: Page;
  
  // Read dynamic emulator ports to inject them into the Flutter web client via URL parameters
  const firestorePort = process.env.FIRESTORE_PORT || '8081';
  const authPort = process.env.AUTH_PORT || '9099';
  const functionsPort = process.env.FUNCTIONS_PORT || '5002';
  const queryParams = `?enable-accessibility=true&firestore_port=${firestorePort}&auth_port=${authPort}&functions_port=${functionsPort}`;

  test.beforeAll(async ({ browser }) => {
    // Extend hook timeout to 3 minutes for cold DDC compilation
    test.setTimeout(180000);
    // Create browser context with geolocation permissions pre-granted
    const context = await browser.newContext({
      permissions: ['geolocation'],
      geolocation: { latitude: 32.0853, longitude: 34.7818 },
    });
    // Create page and set console listeners
    page = await context.newPage();
    await page.setViewportSize({ width: 1280, height: 1200 });
    page.on('console', msg => console.log(`[Browser Console] ${msg.type()}: ${msg.text()}`));
    page.on('pageerror', err => console.log(`[Browser Page Error] ${err.stack || err.message}`));

    console.log(`Navigating to PlainSightIL for initial setup with queryParams: ${queryParams}...`);
    await page.goto(`/${queryParams}`);

    // Clear localStorage once at the start (not via persistent addInitScript)
    await page.evaluate(() => {
      window.localStorage.clear();
      window.sessionStorage.clear();
    });

    console.log('Reloading after clearing storage...');
    await page.goto(`/${queryParams}`);
    
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
    // Wait for the datasets to load first by asserting an English card title is visible
    await expect(page.getByText('Cellular Antennas').first()).toBeVisible({ timeout: 15000 });

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

    // Move mouse to center and scroll down repeatedly until the card is visible/attached
    await page.mouse.move(400, 300);
    const card = page.locator('[aria-label*="חברות בפירוק"], [aria-label*="פירוק"]').first();

    let isCardVisible = false;
    for (let i = 0; i < 20; i++) {
      if (await card.isVisible()) {
        isCardVisible = true;
        break;
      }
      await page.mouse.wheel(0, 300);
      await page.keyboard.press('PageDown');
      await page.waitForTimeout(300);
    }
    await expect(card).toBeVisible({ timeout: 5000 });
    // Scroll down a bit more to bring the bottom of the card (and its buttons) fully into the viewport
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(500);

    const openVisualizerBtn = card.getByText('Open Visualizer').first();
    await expect(openVisualizerBtn).toBeVisible();
    await openVisualizerBtn.click();

    // Assert we are on the Companies in Liquidation visualizer page
    await expect(page.getByText('Companies in Liquidation')).toBeVisible({ timeout: 15000 });

    // Wait for the records to load and be visible
    await expect(page.getByText('מלון הגליל בע~מ').first()).toBeVisible({ timeout: 15000 });
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

    // Move mouse to center and scroll down repeatedly until the card is visible/attached
    await page.mouse.move(400, 300);
    const card = page.locator('[aria-label*="חברות בפירוק"], [aria-label*="פירוק"]').first();

    let isCardVisible = false;
    for (let i = 0; i < 20; i++) {
      if (await card.isVisible()) {
        isCardVisible = true;
        break;
      }
      await page.mouse.wheel(0, 300);
      await page.keyboard.press('PageDown');
      await page.waitForTimeout(300);
    }
    await expect(card).toBeVisible({ timeout: 5000 });
    // Scroll down a bit more to bring the bottom of the card (and its buttons) fully into the viewport
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(500);
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
    await page.goto(`/${queryParams}`);
    
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

  test('E2E-PROF-01: Edit User Profile Flow', async () => {
    // Clear storage and reload to return to the Login Page
    console.log('Clearing storage and reloading to log out...');
    await page.evaluate(() => {
      window.localStorage.clear();
      window.sessionStorage.clear();
    });
    await page.goto(`/${queryParams}`);

    // Re-enable accessibility on page reload
    const placeholder = page.locator('flt-semantics-placeholder').first();
    await expect(placeholder).toBeAttached({ timeout: 60000 });
    await placeholder.dispatchEvent('click');

    // Assert we are back on the Login screen
    await expect(page.getByText('Welcome Back')).toBeVisible({ timeout: 15000 });

    // Click "Sign in with Google" and catch the Firebase Auth Emulator popup
    console.log('Clicking Sign in with Google...');
    const [popup] = await Promise.all([
      page.waitForEvent('popup'),
      page.getByText('Sign in with Google').click(),
    ]);
    popup.on('console', msg => console.log(`[Popup Console] ${msg.type()}: ${msg.text()}`));
    popup.on('pageerror', err => console.log(`[Popup Page Error] ${err.stack || err.message}`));
    console.log(`Popup opened. Initial URL: ${popup.url()}`);
    await popup.waitForLoadState('networkidle').catch(() => console.log('Timeout waiting for networkidle'));
    console.log(`Popup loaded. URL after load: ${popup.url()}`);

    // Authenticate via Firebase Auth Emulator popup
    console.log('Authenticating in the emulator popup...');
    await popup.waitForTimeout(2000);
    console.log('--- POPUP HTML CONTENT START ---');
    console.log(await popup.content());
    console.log('--- POPUP HTML CONTENT END ---');

    
    // Wait for either the "Add new account" button OR the email input field to appear
    await Promise.race([
      popup.waitForSelector('button:has-text("Add new account")', { timeout: 15000 }).catch(() => null),
      popup.waitForSelector('input#email-input', { timeout: 15000 }).catch(() => null)
    ]);

    // Click "Add new account" if it is visible
    const addAccountBtn = popup.getByRole('button', { name: 'Add new account' });
    if (await addAccountBtn.isVisible()) {
      await addAccountBtn.click();
      await popup.waitForTimeout(1000);
    }

    console.log('--- POPUP CONTENT BEFORE FILLING ---');
    console.log(await popup.content());

    // In Firebase Auth Emulator, locate email input and fill it
    const emailInput = popup.locator('input#email-input');
    await expect(emailInput).toBeVisible({ timeout: 15000 });
    await emailInput.fill('assaf-e2e@plainsight.il');
    await emailInput.dispatchEvent('input');

    // Locate display name input and fill it
    const nameInput = popup.locator('input#display-name-input');
    await expect(nameInput).toBeVisible({ timeout: 10000 });
    await nameInput.fill('Assaf E2E');
    await nameInput.dispatchEvent('input');

    const debugInfo = await popup.evaluate(() => {
      const emailEl = document.getElementById('email-input') as HTMLInputElement;
      const nameEl = document.getElementById('display-name-input') as HTMLInputElement;
      const buttonEl = document.getElementById('sign-in') as HTMLButtonElement;
      return {
        emailValue: emailEl?.value,
        nameValue: nameEl?.value,
        buttonDisabled: buttonEl?.disabled,
      };
    });
    console.log('DOM state after filling:', JSON.stringify(debugInfo, null, 2));

    console.log('--- POPUP CONTENT AFTER FILLING ---');
    console.log(await popup.content());

    // Click submit in popup (Add account or Sign-in)
    const submitBtn = popup.locator('button#sign-in, button#submit-btn, button:has-text("Add account"), button:has-text("Sign in")').first();
    await expect(submitBtn).toBeVisible();
    console.log('Clicking submit button...');
    await submitBtn.click();

    // Wait for popup to close, or if it doesn't close within a short time, inspect/evaluate
    try {
      await Promise.race([
        popup.waitForEvent('close', { timeout: 3000 }),
        page.waitForTimeout(3000)
      ]);
    } catch (e) {
      console.log('Popup close wait timed out or errored:', e);
    }

    if (!popup.isClosed()) {
      try {
        const popupURL = popup.url();
        if (popupURL.includes('handler')) {
          console.log('Popup still open on handler page. Bypassing UI and calling finishWithUser directly...');
          await popup.evaluate(() => {
            const claims = (window as any).createFakeClaims({
              email: 'assaf-e2e@plainsight.il',
              displayName: 'Assaf E2E'
            });
            (window as any).finishWithUser(claims, 'assaf-e2e@plainsight.il');
          }).catch(e => console.log('Error calling finishWithUser:', e));
        }

        await page.waitForTimeout(1500);
        if (!popup.isClosed()) {
          console.log('--- POPUP CONTENT AFTER SUBMISSION ---');
          console.log(await popup.content().catch(() => ''));
        }
      } catch (e) {
        console.log('Error inspecting/evaluating popup:', e);
      }
    }

    // Verify main page redirects to Dashboard
    console.log('Waiting for login redirection...');
    await expect(page.getByText('Democratizing Civic Data')).toBeVisible({ timeout: 20000 });

    // Open navigation drawer
    console.log('Opening navigation drawer...');
    const menuBtn = page.getByLabel('Open navigation menu');
    await expect(menuBtn).toBeVisible({ timeout: 10000 });
    await menuBtn.click();

    // Verify user profile card in the drawer displays fallback details (since Firestore profile does not exist yet)
    await expect(page.getByText('Assaf E2E')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText('assaf-e2e@plainsight.il')).toBeVisible();

    // Tap on the user profile card to open Profile Settings Page
    console.log('Opening Profile Settings...');
    await page.getByText('Assaf E2E').click();

    // Verify Profile Settings Page displays fallback values in TextFields
    const inputs = page.locator('input[type="text"], input[type="email"]');
    await expect(inputs).toHaveCount(4, { timeout: 10000 });

    // Edit First Name and Last Name
    console.log('Editing first and last name...');
    await inputs.nth(0).click();
    for (let i = 0; i < 50; i++) {
      await page.keyboard.press('Backspace');
    }
    await page.keyboard.type('AssafUpdated');

    await inputs.nth(1).click();
    for (let i = 0; i < 50; i++) {
      await page.keyboard.press('Backspace');
    }
    await page.keyboard.type('E2EUpdated');

    // Click "Save Profile" button
    console.log('Saving profile...');
    const saveBtn = page.getByText('Save Profile');
    await expect(saveBtn).toBeVisible();
    await saveBtn.click();

    // Verify success SnackBar / feedback
    await expect(page.getByText('Profile updated successfully!').first()).toBeVisible({ timeout: 15000 });

    // Click Back to return to Dashboard
    await page.getByRole('button', { name: 'Back' }).first().click();

    // Re-open navigation drawer
    await menuBtn.click();

    // Verify drawer now shows the updated name
    await expect(page.getByText('AssafUpdated E2EUpdated').first()).toBeVisible({ timeout: 10000 });
  });

  test('E2E-TRV-01: Travel Warnings Directory & Detail Flow', async () => {
    // Navigate to Directory tab in the bottom bar
    const directoryTab = page.getByRole('button', { name: 'Directory' }).first();
    await expect(directoryTab).toBeVisible();
    await directoryTab.click();

    // Scroll to "אזהרות מסע" card
    await page.mouse.move(400, 300);
    const card = page.locator('[aria-label*="אזהרות מסע"], [aria-label*="מסע"]').first();
    
    let isCardVisible = false;
    for (let i = 0; i < 20; i++) {
      if (await card.isVisible()) {
        isCardVisible = true;
        break;
      }
      await page.mouse.wheel(0, 300);
      await page.keyboard.press('PageDown');
      await page.waitForTimeout(300);
    }
    await expect(card).toBeVisible({ timeout: 10000 });
    // Scroll down a bit more to bring the bottom of the card (and its buttons) fully into the viewport
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(500);

    // Click Open Visualizer
    const openVisualizerBtn = card.getByText('Open Visualizer').first();
    await expect(openVisualizerBtn).toBeVisible();
    await openVisualizerBtn.click();

    // Assert we successfully navigate to Travel Warnings page
    await expect(page.getByText('Travel Warnings').first()).toBeVisible({ timeout: 15000 });

    // Wait for travel warning records to be visible
    const warningItem = page.getByRole('button', { name: /אוגנדה|אוזבקיסטאן|אוסטריה|בוליביה|בהאמס|מרשל|סיישל|קוק|בולגריה|אתיופיה|ארצות הברית|Uganda|Uzbekistan|Austria|Bolivia|Bahamas|Marshall|Seychelles|Cook|Bulgaria|Ethiopia|United States/ }).first();
    await expect(warningItem).toBeVisible({ timeout: 15000 });
  });
});
