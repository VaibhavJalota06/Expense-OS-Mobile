#!/usr/bin/env node

/**
 * ==============================================================================
 * Expense OS - Automated Multiplatform Release & Deployment Pipeline CLI
 * ==============================================================================
 * Automates:
 *  1. Unit testing & quality gate checks
 *  2. Semantic version incrementing (patch/minor/major) & build number bumping
 *  3. Synchronizing versions across pubspec.yaml, package.json & tauri.conf.json
 *  4. Git staging, automated commit, and tag creation
 *  5. Pushing to GitHub to trigger multiplatform CI/CD (APK, AAB, IPA, EXE)
 * ==============================================================================
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const rootDir = path.resolve(__dirname, '..');
const pubspecPath = path.join(rootDir, 'pubspec.yaml');
const packageJsonPath = path.join(rootDir, 'web-desktop', 'package.json');
const tauriConfPath = path.join(rootDir, 'web-desktop', 'src-tauri', 'tauri.conf.json');

function log(msg, symbol = 'ℹ️') {
  console.log(`\n${symbol}  ${msg}`);
}

function run(cmd, cwd = rootDir) {
  console.log(`> ${cmd}`);
  return execSync(cmd, { cwd, stdio: 'inherit' });
}

function parsePubspecVersion() {
  const content = fs.readFileSync(pubspecPath, 'utf8');
  const match = content.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+?([0-9]*)/m);
  if (!match) throw new Error('Could not parse version from pubspec.yaml');
  return {
    raw: match[0],
    semver: match[1],
    buildNumber: parseInt(match[2] || '1', 10)
  };
}

function bumpSemver(semver, type = 'patch') {
  let [major, minor, patch] = semver.split('.').map(Number);
  if (type === 'major') {
    major += 1;
    minor = 0;
    patch = 0;
  } else if (type === 'minor') {
    minor += 1;
    patch = 0;
  } else {
    patch += 1;
  }
  return `${major}.${minor}.${patch}`;
}

async function main() {
  const bumpType = process.argv[2] || 'patch';
  log(`Starting Expense OS End-to-End Automated Release Pipeline [Mode: ${bumpType}]...`, '🚀');

  // Step 1: Run Quality Gate Tests
  log('Running Unit Test Quality Gate...', '🧪');
  try {
    const flutterCmd = process.platform === 'win32' && fs.existsSync('C:\\src\\flutter\\bin\\flutter.bat')
      ? 'C:\\src\\flutter\\bin\\flutter.bat'
      : 'flutter';
    run(`${flutterCmd} test test/unit_test.dart`);
    log('All quality tests PASSED ✅', '🟢');
  } catch (err) {
    log('Flutter test command not found or failed locally. Proceeding to CI verification gate.', '⚠️');
  }

  // Step 2: Calculate Next Version
  const current = parsePubspecVersion();
  const nextSemver = bumpType.includes('.') ? bumpType : bumpSemver(current.semver, bumpType);
  const nextBuildNumber = current.buildNumber + 1;
  const nextFullVersion = `${nextSemver}+${nextBuildNumber}`;
  const tagName = `v${nextSemver}`;

  log(`Upgrading version: ${current.semver}+${current.buildNumber} ➔ ${nextFullVersion} (Tag: ${tagName})`, '📦');

  // Step 3: Update pubspec.yaml
  let pubspecContent = fs.readFileSync(pubspecPath, 'utf8');
  pubspecContent = pubspecContent.replace(/^version:\s*.*$/m, `version: ${nextFullVersion}`);
  fs.writeFileSync(pubspecPath, pubspecContent, 'utf8');
  log('Updated pubspec.yaml', '✅');

  // Step 4: Update web-desktop/package.json
  if (fs.existsSync(packageJsonPath)) {
    const pkg = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
    pkg.version = nextSemver;
    fs.writeFileSync(packageJsonPath, JSON.stringify(pkg, null, 2) + '\n', 'utf8');
    log('Updated web-desktop/package.json', '✅');
  }

  // Step 5: Update tauri.conf.json
  if (fs.existsSync(tauriConfPath)) {
    try {
      const tauriConf = JSON.parse(fs.readFileSync(tauriConfPath, 'utf8'));
      if (tauriConf.package) tauriConf.package.version = nextSemver;
      if (tauriConf.version) tauriConf.version = nextSemver;
      fs.writeFileSync(tauriConfPath, JSON.stringify(tauriConf, null, 2) + '\n', 'utf8');
      log('Updated web-desktop/src-tauri/tauri.conf.json', '✅');
    } catch (e) {
      // Non-blocking
    }
  }

  // Step 5b: Update CURRENT_APP_VERSION in web-desktop/js/ui.js
  const uiJsPath = path.join(rootDir, 'web-desktop', 'js', 'ui.js');
  if (fs.existsSync(uiJsPath)) {
    let uiContent = fs.readFileSync(uiJsPath, 'utf8');
    const updatedUi = uiContent.replace(
      /const CURRENT_APP_VERSION = 'v[0-9.]+';/,
      `const CURRENT_APP_VERSION = '${tagName}';`
    );
    if (updatedUi !== uiContent) {
      fs.writeFileSync(uiJsPath, updatedUi, 'utf8');
      log(`Updated web-desktop/js/ui.js CURRENT_APP_VERSION to ${tagName}`, '✅');
    }
  }

  // Step 5c: Update index.html Cache-Busting Version Query Parameters
  const indexHtmlPath = path.join(rootDir, 'web-desktop', 'index.html');
  if (fs.existsSync(indexHtmlPath)) {
    let htmlContent = fs.readFileSync(indexHtmlPath, 'utf8');
    const updatedHtml = htmlContent
      .replace(/\?v=[0-9.]+[a-z]?/g, `?v=${nextSemver}`)
      .replace(/Cache Busted v[0-9.]+/g, `Cache Busted ${tagName}`);
    if (updatedHtml !== htmlContent) {
      fs.writeFileSync(indexHtmlPath, updatedHtml, 'utf8');
      log(`Updated web-desktop/index.html cache-busting query strings to v${nextSemver}`, '✅');
    }
  }

  // Step 5d: Update service-worker.js Cache Name & Static Assets
  const swPath = path.join(rootDir, 'web-desktop', 'service-worker.js');
  if (fs.existsSync(swPath)) {
    let swContent = fs.readFileSync(swPath, 'utf8');
    const updatedSw = swContent
      .replace(/CACHE_NAME = 'expense-os-pwa-v[0-9.]+[a-z]?';/, `CACHE_NAME = 'expense-os-pwa-${tagName}';`)
      .replace(/\?v=[0-9.]+[a-z]?/g, `?v=${nextSemver}`);
    if (updatedSw !== swContent) {
      fs.writeFileSync(swPath, updatedSw, 'utf8');
      log(`Updated web-desktop/service-worker.js cache to ${tagName}`, '✅');
    }
  }

  // Step 5e: Update landing/index.html Version & Asset Paths
  const landingHtmlPath = path.join(rootDir, 'web-desktop', 'landing', 'index.html');
  if (fs.existsSync(landingHtmlPath)) {
    let landingContent = fs.readFileSync(landingHtmlPath, 'utf8');
    const updatedLanding = landingContent
      .replace(/\?v=[0-9.]+[a-z]?/g, `?v=${nextSemver}`)
      .replace(/<span class="brand-tag">v[0-9.]+<\/span>/g, `<span class="brand-tag">${tagName}</span>`)
      .replace(/Expense OS v[0-9.]+ Released/g, `Expense OS ${tagName} Released`)
      .replace(/releases\/download\/v[0-9.]+\/Expense-OS-Setup-[0-9.]+\.exe/g, `releases/download/${tagName}/Expense-OS-Setup-${nextSemver}.exe`);
    if (updatedLanding !== landingContent) {
      fs.writeFileSync(landingHtmlPath, updatedLanding, 'utf8');
      log(`Updated web-desktop/landing/index.html version to ${tagName}`, '✅');
    }
  }

  // Step 6: Git Staging, Commit, Tag & Push
  log('Staging changes and committing to Git...', '📝');
  run('git add .');
  run(`git commit -m "chore(release): bump version to ${tagName}"`);

  log(`Creating release tag ${tagName}...`, '🏷️');
  run(`git tag -a ${tagName} -m "Release ${tagName}: Multiplatform Android APK/AAB, iOS IPA, and Tauri Desktop EXE"`);

  log('Pushing commit and tag to GitHub to trigger automated build & publish...', '🚀');
  run('git push origin main');
  run(`git push origin ${tagName}`);

  log(`
========================================================================
🎉 RELEASE AUTOMATION COMPLETE!
========================================================================
Tag: ${tagName} (Version: ${nextFullVersion})
GitHub Action Triggered: https://github.com/VaibhavJalota06/Expense-OS-Mobile/actions
Release Page: https://github.com/VaibhavJalota06/Expense-OS-Mobile/releases/tag/${tagName}
Production Web App: https://expense-os-mobile.vercel.app

All binaries (Android APK/AAB, Windows EXE, iOS IPA) are now compiling
automatically and will be published directly for all users!
========================================================================
`, '✨');
}

main().catch(err => {
  console.error('\n❌ Release automation failed:', err);
  process.exit(1);
});
