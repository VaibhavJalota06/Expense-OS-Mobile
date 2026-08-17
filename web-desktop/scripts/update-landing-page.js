const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const rootDir = path.join(__dirname, '..');
const pkgPath = path.join(rootDir, 'package.json');
const landingHtmlPath = path.join(rootDir, 'landing', 'index.html');

if (!fs.existsSync(pkgPath)) {
  console.error('❌ package.json not found!');
  process.exit(1);
}

const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
const version = pkg.version;
console.log(`\n🌟 Updating Landing Page for Expense OS v${version}...`);

if (fs.existsSync(landingHtmlPath)) {
  let content = fs.readFileSync(landingHtmlPath, 'utf8');

  // Replace version references in stylesheet/script query params, hero badge, and download URL
  const updatedContent = content
    .replace(/href="style\.css\?v=[0-9.]+"/g, `href="style.css?v=${version}"`)
    .replace(/src="script\.js\?v=[0-9.]+"/g, `src="script.js?v=${version}"`)
    .replace(/Expense OS v[0-9.]+ Released/g, `Expense OS v${version} Released`)
    .replace(
      /releases\/download\/v[0-9.]+\/Expense-OS-Setup-[0-9.]+\.exe/g,
      `releases/download/v${version}/Expense-OS-Setup-${version}.exe`
    );

  if (content !== updatedContent) {
    fs.writeFileSync(landingHtmlPath, updatedContent, 'utf8');
    console.log(`✅ Updated landing/index.html version references to v${version}`);
  } else {
    console.log(`ℹ️ landing/index.html is already up to date for v${version}`);
  }
} else {
  console.error('⚠️ landing/index.html not found!');
}

// Also update CURRENT_APP_VERSION in web/script.js
const webScriptPath = path.join(rootDir, 'web', 'script.js');
if (fs.existsSync(webScriptPath)) {
  let scriptContent = fs.readFileSync(webScriptPath, 'utf8');
  const updatedScript = scriptContent.replace(
    /const CURRENT_APP_VERSION = 'v[0-9.]+';/,
    `const CURRENT_APP_VERSION = 'v${version}';`
  );
  if (scriptContent !== updatedScript) {
    fs.writeFileSync(webScriptPath, updatedScript, 'utf8');
    console.log(`✅ Updated web/script.js CURRENT_APP_VERSION to v${version}`);
  } else {
    console.log(`ℹ️ web/script.js CURRENT_APP_VERSION is already v${version}`);
  }
} else {
  console.error('⚠️ web/script.js not found!');
}

// Git commit & push to master and gh-pages
try {
  console.log('🔄 Staging and committing landing page changes...');
  execSync('git add landing/index.html web/script.js', { cwd: rootDir, stdio: 'inherit' });
  
  const status = execSync('git status --porcelain landing/index.html', { cwd: rootDir }).toString().trim();
  if (status) {
    execSync(`git commit -m "Update landing page to v${version}"`, { cwd: rootDir, stdio: 'inherit' });
    console.log(`✅ Committed landing page update for v${version}`);
  }

  console.log('🚀 Pushing changes to GitHub master branch...');
  execSync('git push origin master', { cwd: rootDir, stdio: 'inherit' });

  console.log('🌐 Deploying latest landing page & web app to GitHub Pages (gh-pages branch)...');
  execSync('git push origin master:gh-pages --force', { cwd: rootDir, stdio: 'inherit' });

  console.log('\n🎉 SUCCESS: Landing page updated & published to GitHub Pages!');
} catch (err) {
  console.error('⚠️ Notice during Git update/deploy:', err.message);
}
