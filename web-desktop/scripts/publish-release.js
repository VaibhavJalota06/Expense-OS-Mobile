const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Load .env if present
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  const envLines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
  envLines.forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx !== -1) {
        const key = trimmed.substring(0, eqIdx).trim();
        const val = trimmed.substring(eqIdx + 1).trim();
        process.env[key] = val;
      }
    }
  });
}

if (!process.env.GH_TOKEN) {
  console.error('\n❌ ERROR: GH_TOKEN is missing!');
  console.error('To automate publishing, paste your GitHub Token into a .env file in the project root:');
  console.error('GH_TOKEN=ghp_your_github_token_here\n');
  process.exit(1);
}

// Clean old build files in dist folder
const distPath = path.join(__dirname, '..', 'dist');
if (fs.existsSync(distPath)) {
  console.log('🧹 Cleaning old build files in dist/ folder...');
  try {
    fs.rmSync(distPath, { recursive: true, force: true });
  } catch (err) {
    console.log('Notice: dist folder clean warning:', err.message);
  }
}

console.log('🚀 Building and automatically publishing release to GitHub Releases...');
try {
  execSync('npx electron-builder --win -p always', { stdio: 'inherit' });

  // Auto-publish draft release if electron-builder created it as draft
  const pkg = require('../package.json');
  const token = process.env.GH_TOKEN;
  if (token && pkg.version) {
    try {
      const res = execSync(`node -e "fetch('https://api.github.com/repos/VaibhavJalota06/Expense-Calculator-Desktop/releases', { headers: { Authorization: 'token ${token}' } }).then(r => r.json()).then(async releases => { const match = releases.find(r => r.tag_name === 'v${pkg.version}' || r.tag_name === '${pkg.version}'); if (match && match.draft) { await fetch('https://api.github.com/repos/VaibhavJalota06/Expense-Calculator-Desktop/releases/' + match.id, { method: 'PATCH', headers: { Authorization: 'token ${token}', 'Content-Type': 'application/json' }, body: JSON.stringify({ draft: false, prerelease: false, make_latest: 'true' }) }); console.log('Draft release v${pkg.version} officially published to public!'); } }).catch(() => {})"`).toString();
      if (res.trim()) console.log(res.trim());
    } catch (e) {}
  }

  // Ensure latest.yml is attached to GitHub Release for electron-updater
  try {
    execSync('node scripts/upload-latest-yml.js', { stdio: 'inherit' });
  } catch (e) {}

  // Automatically update and publish the landing page to GitHub Pages
  try {
    execSync('node scripts/update-landing-page.js', { stdio: 'inherit' });
  } catch (e) {}

  console.log('\n🎉 SUCCESS: Release published to GitHub Releases automatically!');
} catch (err) {
  console.error('\n❌ Build/Publish failed:', err.message);
  process.exit(1);
}
