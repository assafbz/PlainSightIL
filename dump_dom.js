const { chromium } = require('@playwright/test');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  console.log('Navigating to http://localhost:8080/?enable-accessibility=true...');
  await page.goto('http://localhost:8080/?enable-accessibility=true');
  
  console.log('Waiting 5 seconds for Flutter to bootstrap...');
  await page.waitForTimeout(5000);
  
  console.log('Dispatching click event to accessibility placeholder...');
  const btn = page.locator('flt-semantics-placeholder').first();
  await btn.dispatchEvent('click');
  
  console.log('Waiting 3 seconds for semantics host to rebuild...');
  await page.waitForTimeout(3000);

  console.log('Clicking Continue as Guest...');
  await page.getByText('Continue as Guest').click();
  await page.waitForTimeout(3000);

  console.log('Reloading page...');
  await page.goto('http://localhost:8080/?enable-accessibility=true');
  
  console.log('Dispatching accessibility click after reload...');
  const btn2 = page.locator('flt-semantics-placeholder').first();
  await btn2.dispatchEvent('click');
  await page.waitForTimeout(5000);
  
  const content = await page.content();
  console.log('--- DOM CONTENT POST-RELOAD ---');
  const hostIdx = content.indexOf('<flt-semantics-host');
  if (hostIdx !== -1) {
    const endHostIdx = content.indexOf('</flt-semantics-host>');
    console.log(content.substring(hostIdx, endHostIdx !== -1 ? endHostIdx + 21 : hostIdx + 4000));
  } else {
    console.log('flt-semantics-host not found!');
  }
  console.log('---------------------------------------');
  
  await browser.close();
})();
