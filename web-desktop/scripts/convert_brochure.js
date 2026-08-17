const { chromium } = require('@playwright/test');
const path = require('path');

(async () => {
  const HTML_FILE = '../docs/expense_os_brochure.html';
  const OUTPUT_FILE = '../docs/Expense_OS_Brochure.pdf';

  console.log('Rendering 1:1 mobile brochure PDF with Playwright Chromium...');
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1080, height: 1080 },
    deviceScaleFactor: 2
  });
  const page = await context.newPage();

  const filePath = path.resolve(__dirname, HTML_FILE);
  await page.goto(`file://${filePath}`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2000);

  const outputPath = path.resolve(__dirname, OUTPUT_FILE);
  await page.pdf({
    path: outputPath,
    width: '1080px',
    height: '1080px',
    printBackground: true,
    margin: { top: '0px', right: '0px', bottom: '0px', left: '0px' }
  });

  await browser.close();
  console.log(`✅ Pixel-perfect 1080x1080 PDF generated: ${outputPath}`);
})();
