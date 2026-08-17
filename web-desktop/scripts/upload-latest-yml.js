const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  const envLines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
  envLines.forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx !== -1) {
        process.env[trimmed.substring(0, eqIdx).trim()] = trimmed.substring(eqIdx + 1).trim();
      }
    }
  });
}

const token = process.env.GH_TOKEN;
const pkg = require('../package.json');

async function uploadLatestYml() {
  try {
    const releasesRes = await fetch('https://api.github.com/repos/VaibhavJalota06/Expense-Calculator-Desktop/releases', {
      headers: { Authorization: `token ${token}` }
    });
    const releases = await releasesRes.json();
    const match = releases.find(r => r.tag_name === `v${pkg.version}` || r.tag_name === pkg.version);

    if (!match) {
      console.error('Release not found!');
      return;
    }

    const latestYmlPath = path.join(__dirname, '..', 'dist', 'latest.yml');
    if (!fs.existsSync(latestYmlPath)) {
      console.error('dist/latest.yml does not exist!');
      return;
    }
    const latestYmlContent = fs.readFileSync(latestYmlPath);

    // Delete old latest.yml asset if already exists
    const existingAsset = match.assets ? match.assets.find(a => a.name === 'latest.yml') : null;
    if (existingAsset) {
      await fetch(`https://api.github.com/repos/VaibhavJalota06/Expense-Calculator-Desktop/releases/assets/${existingAsset.id}`, {
        method: 'DELETE',
        headers: { Authorization: `token ${token}` }
      });
    }

    const uploadUrl = match.upload_url.replace('{?name,label}', '?name=latest.yml');
    const uploadRes = await fetch(uploadUrl, {
      method: 'POST',
      headers: {
        Authorization: `token ${token}`,
        'Content-Type': 'application/x-yaml',
        'Content-Length': latestYmlContent.length
      },
      body: latestYmlContent
    });

    if (uploadRes.status === 201 || uploadRes.status === 200) {
      console.log('✅ latest.yml uploaded to GitHub release v' + pkg.version + ' successfully!');
    } else {
      console.log('Upload response status:', uploadRes.status, await uploadRes.text());
    }
  } catch (e) {
    console.error('Upload latest.yml error:', e);
  }
}

uploadLatestYml();
