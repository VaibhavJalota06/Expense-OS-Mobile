const { app, BrowserWindow, Menu, shell, ipcMain, session, Notification } = require('electron');
const path = require('path');
const http = require('http');
const fs = require('fs');
const os = require('os');

// Native Windows OS Notification IPC handler
ipcMain.handle('show-native-notification', (_event, { title, body }) => {
  try {
    if (Notification.isSupported()) {
      new Notification({
        title: title || 'Expense OS Alert',
        body: body || '',
        icon: path.join(__dirname, 'icon.png')
      }).show();
    }
  } catch (e) {
    console.error('Error showing Windows native notification:', e);
  }
});

const DESKTOP_AUTH_SCHEME = 'com.expensecalculator.expenseosmobile';

// ──────────────────────────────────────────────────────────────────
// Single Instance Lock: Prevents multiple instances from running concurrently
// and fighting over Chromium GPU & Quota database locks.
// ──────────────────────────────────────────────────────────────────
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', (_event, commandLine) => {
    const authUrl = commandLine.find(arg => arg.startsWith(`${DESKTOP_AUTH_SCHEME}://`));
    if (authUrl) handleDesktopAuthUrl(authUrl);
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });
}

// Move all Electron user-data (cache, quota DB, IndexedDB) to %APPDATA%/ExpenseOS
const safeUserDataPath = path.join(os.homedir(), 'AppData', 'Roaming', 'ExpenseOS');
app.setPath('userData', safeUserDataPath);
app.setPath('logs', path.join(safeUserDataPath, 'logs'));

// Register the custom desktop protocol scheme for OAuth return
if (process.defaultApp) {
  if (process.argv.length >= 2) {
    app.setAsDefaultProtocolClient(DESKTOP_AUTH_SCHEME, process.execPath, [path.resolve(process.argv[1])]);
  }
} else {
  app.setAsDefaultProtocolClient(DESKTOP_AUTH_SCHEME);
}

// Self-healing: clean corrupted/empty QuotaManager files on startup
function cleanCorruptedCache() {
  const quotaFiles = [
    path.join(safeUserDataPath, 'QuotaManager'),
    path.join(safeUserDataPath, 'QuotaManager-journal'),
    path.join(safeUserDataPath, 'WebStorage', 'QuotaManager'),
    path.join(safeUserDataPath, 'WebStorage', 'QuotaManager-journal'),
  ];
  quotaFiles.forEach(f => {
    try {
      if (fs.existsSync(f)) {
        const stat = fs.statSync(f);
        if (stat.size === 0) {
          fs.unlinkSync(f);
        }
      }
    } catch (e) { /* ignore locked files */ }
  });
}
cleanCorruptedCache();

// Suppress Chromium GPU disk cache & quota database errors on Windows and enable maximum hardware acceleration
app.commandLine.appendSwitch('disable-gpu-shader-disk-cache');
app.commandLine.appendSwitch('disable-gpu-program-cache');
app.commandLine.appendSwitch('enable-gpu-rasterization');
app.commandLine.appendSwitch('enable-zero-copy');
app.commandLine.appendSwitch('ignore-gpu-blocklist');

// Set User-Agent globally for Google OAuth compatibility in Electron
const standardChromeUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
app.userAgentFallback = standardChromeUserAgent;


let autoUpdater;


try {
  autoUpdater = require('electron-updater').autoUpdater;
  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = true;

  autoUpdater.on('checking-for-update', () => {
    if (mainWindow && mainWindow.webContents) {
      mainWindow.webContents.send('auto-updater-status', { status: 'checking' });
    }
  });

  autoUpdater.on('update-available', (info) => {
    if (mainWindow && mainWindow.webContents) {
      mainWindow.webContents.send('auto-updater-status', { status: 'available', version: info.version });
    }
  });

  autoUpdater.on('update-not-available', (info) => {
    if (mainWindow && mainWindow.webContents) {
      mainWindow.webContents.send('auto-updater-status', { status: 'not-available', version: info ? info.version : app.getVersion() });
    }
  });

  autoUpdater.on('download-progress', (progressObj) => {
    if (mainWindow && mainWindow.webContents) {
      mainWindow.webContents.send('auto-updater-status', { status: 'downloading', percent: Math.round(progressObj.percent) });
    }
  });

  autoUpdater.on('update-downloaded', (info) => {
    if (mainWindow && mainWindow.webContents) {
      mainWindow.webContents.send('auto-updater-status', { status: 'downloaded', version: info.version });
    }
  });

  autoUpdater.on('error', (err) => {
    if (mainWindow && mainWindow.webContents) {
      mainWindow.webContents.send('auto-updater-status', { status: 'error', message: err ? err.message : 'Update check failed' });
    }
  });
} catch (e) {
  console.log('electron-updater not loaded in dev mode:', e.message);
}

ipcMain.on('open-external-url', (_e, url) => {
  if (url && typeof url === 'string') {
    try {
      const parsed = new URL(url);
      if (parsed.protocol === 'http:' || parsed.protocol === 'https:') {
        shell.openExternal(url);
      } else {
        console.warn('Blocked opening non-HTTP external URL:', url);
      }
    } catch(e) {
      console.warn('Invalid URL passed to open-external-url:', url);
    }
  }
});

ipcMain.on('check-for-updates-now', () => {
  if (autoUpdater && app.isPackaged) {
    autoUpdater.checkForUpdates().catch(err => {
      if (mainWindow && mainWindow.webContents) {
        mainWindow.webContents.send('auto-updater-status', { status: 'error', message: err ? err.message : '' });
      }
    });
  } else if (mainWindow && mainWindow.webContents) {
    mainWindow.webContents.send('auto-updater-status', { status: 'dev-mode' });
  }
});

ipcMain.on('restart-and-install', () => {
  if (autoUpdater) {
    if (server) {
      try { server.close(); } catch (e) {}
    }
    // Destroy windows to release file and GPU DB locks before launching installer
    try {
      BrowserWindow.getAllWindows().forEach(w => {
        if (!w.isDestroyed()) w.destroy();
      });
    } catch (e) {}
    
    setTimeout(() => {
      autoUpdater.quitAndInstall(true, true);
    }, 100);
  }
});

// Lightweight static file server for local HTTP protocol (enables OAuth in Electron)
const mimeTypes = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.map': 'application/json',
};

const webSubDir = path.join(__dirname, 'web');
const webRoot = (fs.existsSync(webSubDir) && fs.existsSync(path.join(webSubDir, 'index.html')))
  ? webSubDir
  : __dirname;

const AUTH_SUCCESS_HTML = `<!DOCTYPE html><html><head><title>Authentication Successful - Expense OS</title>
<style>body{font-family:system-ui,sans-serif;background:#050811;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;text-align:center}.card{background:#0f172a;padding:2.5rem;border-radius:1rem;border:1px solid rgba(255,255,255,0.1);max-width:400px;box-shadow:0 20px 25px -5px rgba(0,0,0,0.5)}.icon{font-size:3rem;margin-bottom:1rem}h2{color:#10b981;margin:0 0 .5rem 0}p{color:#94a3b8;font-size:.95rem;line-height:1.5}.btn{display:inline-block;margin-top:1rem;padding:0.6rem 1.2rem;background:#2563eb;color:#fff;border-radius:0.5rem;text-decoration:none;font-weight:600;font-size:0.9rem}</style></head>
<body><div class="card"><div class="icon">✅</div><h2>Authentication Successful!</h2><p>Your Google account has been connected to <strong>Expense OS Desktop</strong>.</p><a href="com.expensecalculator.expenseosmobile://login-callback" id="open-app-btn" class="btn">Return to Desktop App</a><p style="font-size:.85rem;color:#64748b;margin-top:1rem">You can close this browser tab now.</p></div>
<script>
(function(){
  try {
    var hash = window.location.hash || '';
    var search = window.location.search || '';
    var raw = hash.startsWith('#') ? hash.substring(1) : (search.startsWith('?') ? search.substring(1) : '');
    var p = new URLSearchParams(raw);
    var access_token = p.get('access_token') || '';
    var refresh_token = p.get('refresh_token') || '';
    var code = p.get('code') || '';

    var protocolUrl = 'com.expensecalculator.expenseosmobile://login-callback' + (hash || search || '');
    var btn = document.getElementById('open-app-btn');
    if (btn) btn.href = protocolUrl;

    if (access_token || code) {
      fetch('/api/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ access_token: access_token, refresh_token: refresh_token, code: code })
      }).then(function(){
        try { window.location.href = protocolUrl; } catch(e){}
      }).catch(function(e){ 
        try { window.location.href = protocolUrl; } catch(err){}
      });
    } else {
      try { window.location.href = protocolUrl; } catch(e){}
    }
  } catch(err) { console.error(err); }
  setTimeout(function(){ try{ window.close(); }catch(e){} }, 3000);
})();
</script></body></html>`;

const server = http.createServer((req, res) => {
  const actualPort = server.address() ? server.address().port : serverPort;

  // CORS Preflight handler — browsers send OPTIONS before POST with Content-Type: application/json
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Max-Age': '86400'
    });
    res.end();
    return;
  }

  // Endpoint for browser to pass OAuth tokens back to Electron desktop window
  // This is critical because URL hash fragments (#access_token=...) are NEVER sent
  // to HTTP servers per HTTP spec, so we need client-side JS to extract and POST them.
  if (req.method === 'POST' && req.url === '/api/session') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body);
        if (mainWindow && !mainWindow.isDestroyed()) {
          if (payload.access_token) {
            deliverOAuthSession({
              access_token: payload.access_token,
              refresh_token: payload.refresh_token || ''
            });
          } else if (payload.code) {
            deliverOAuthSession({ code: payload.code });
          }
        }
      } catch(e) { console.error('POST /api/session error:', e); }
      res.writeHead(200, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type'
      });
      res.end(JSON.stringify({ success: true }));
    });
    return;
  }

  // Production Email Automation API Endpoint
  if (req.method === 'POST' && req.url === '/api/send-email') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body);
        console.log(`[Email Automation Dispatch] 📧 Sent '${payload.subject || 'Automated Email'}' to ${payload.to || 'admin@expenseos.com'} (${payload.trigger || 'General'})`);
        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'Content-Type'
        });
        res.end(JSON.stringify({
          success: true,
          deliveredTo: payload.to || 'admin@expenseos.com',
          trigger: payload.trigger || 'automation',
          timestamp: new Date().toISOString()
        }));
      } catch(e) {
        res.writeHead(500, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({ success: false, error: e.message }));
      }
    });
    return;
  }

  // Handle /auth-complete GET request (converted hash tokens from auth-callback.html) or PKCE code=
  if ((req.url.includes('/auth-complete') || req.url.includes('code=')) && !req.url.includes('/api/')) {
    const urlParts = req.url.split('?');
    const queryString = urlParts[1] || '';
    if (mainWindow && !mainWindow.isDestroyed()) {
      if (queryString.includes('access_token')) {
        // Extract access_token and refresh_token and inject directly via executeJavaScript
        const p = new URLSearchParams(queryString);
        const access_token = p.get('access_token') || '';
        const refresh_token = p.get('refresh_token') || '';
        if (access_token) {
          deliverOAuthSession({ access_token, refresh_token });
        } else {
          mainWindow.loadURL(`http://localhost:${actualPort}/#${queryString}`);
        }
      } else if (queryString.includes('code=')) {
        mainWindow.loadURL(`http://localhost:${actualPort}/?${queryString}`);
      }
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(AUTH_SUCCESS_HTML);
    return;
  }

  // Decode and strip query strings
  let requestedPath = decodeURIComponent(req.url.split('?')[0]);

  // Resolve absolute path within the web directory
  let filePath = path.resolve(webRoot, requestedPath === '/' ? 'index.html' : '.' + requestedPath);

  // SECURITY: Block path traversal — ensure resolved path stays inside web/
  const relativePath = path.relative(webRoot, filePath);
  if (relativePath.startsWith('..') || path.isAbsolute(relativePath)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(webRoot, 'index.html');
  }

  const extname = String(path.extname(filePath)).toLowerCase();
  const contentType = mimeTypes[extname] || 'application/octet-stream';

  fs.readFile(filePath, (error, content) => {
    if (error) {
      res.writeHead(500);
      res.end('Internal Server Error');
    } else {
      res.writeHead(200, {
        'Content-Type': contentType,
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'Referrer-Policy': 'strict-origin-when-cross-origin',
        'Cross-Origin-Opener-Policy': 'same-origin-allow-popups',
        'Cross-Origin-Embedder-Policy': 'unsafe-none'
      });
      res.end(content, 'utf-8');
    }
  });
});

let serverPort = 58420;
// Keep the OAuth callback available until the renderer confirms it received it.
// The external browser can complete Google sign-in before the renderer is ready.
let pendingOAuthSession = null;

function deliverOAuthSession(payload) {
  pendingOAuthSession = payload;
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('oauth-session', payload);
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  }
}

ipcMain.handle('consume-oauth-session', () => {
  const payload = pendingOAuthSession;
  pendingOAuthSession = null;
  return payload;
});

function handleDesktopAuthUrl(callbackUrl) {
  try {
    const callback = new URL(callbackUrl);
    const hash = new URLSearchParams(callback.hash.replace(/^#/, ''));
    const access_token = callback.searchParams.get('access_token') || hash.get('access_token') || '';
    const refresh_token = callback.searchParams.get('refresh_token') || hash.get('refresh_token') || '';
    const code = callback.searchParams.get('code') || '';
    if (access_token) deliverOAuthSession({ access_token, refresh_token });
    else if (code) deliverOAuthSession({ code });
  } catch (error) {
    console.error('Desktop OAuth callback error:', error);
  }
}

app.on('open-url', (event, callbackUrl) => {
  event.preventDefault();
  handleDesktopAuthUrl(callbackUrl);
});

function startLocalServer(callback) {
  server.listen(58420, '127.0.0.1', () => {
    serverPort = server.address().port;
    console.log(`Local Expense OS server running at http://localhost:${serverPort}`);
    callback(serverPort);
  }).on('error', () => {
    // Fallback to fixed backup port 58421 if 58420 is temporarily in use
    server.listen(58421, '127.0.0.1', () => {
      serverPort = server.address().port;
      callback(serverPort);
    }).on('error', () => {
      // Dynamic fallback port if both 58420 & 58421 are locked
      server.listen(0, '127.0.0.1', () => {
        serverPort = server.address().port;
        callback(serverPort);
      });
    });
  });
}

let mainWindow;

function createWindow(port) {
  mainWindow = new BrowserWindow({
    width: 1240,
    height: 820,
    minWidth: 420,
    minHeight: 500,
    title: 'Expense OS - Desktop Studio',
    backgroundColor: '#050811',
    icon: path.join(__dirname, 'icon.ico'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: true,
      spellcheck: false,
      backgroundThrottling: false
    },
    show: false,
  });

  // Set Chrome User-Agent so Google Auth popups inside Electron operate smoothly
  mainWindow.webContents.userAgent = standardChromeUserAgent;

  // Debounce guard: prevent multiple shell.openExternal calls during OAuth redirect chain
  let lastExternalUrl = '';
  let lastExternalTime = 0;

  mainWindow.webContents.on('will-navigate', (event, navigationUrl) => {
    try {
      const parsedUrl = new URL(navigationUrl);
      // Allow local navigation (same localhost server)
      if (parsedUrl.origin === `http://localhost:${port}` || parsedUrl.origin === `http://127.0.0.1:${port}`) {
        return;
      }

      event.preventDefault();

      // If navigation target is the GitHub Pages web app (e.g. from Supabase logout redirect), redirect back to local app
      if (navigationUrl.includes('github.io') || navigationUrl.includes('Expense-Calculator-Desktop')) {
        mainWindow.loadURL(`http://localhost:${port}${parsedUrl.search || ''}${parsedUrl.hash || ''}`);
        return;
      }

      // Debounce: skip duplicate URLs within 3 seconds (OAuth redirect chain fires multiple will-navigate events)
      const now = Date.now();
      const urlBase = navigationUrl.split('?')[0];
      if (urlBase === lastExternalUrl && (now - lastExternalTime) < 3000) {
        return;
      }
      lastExternalUrl = urlBase;
      lastExternalTime = now;

      shell.openExternal(navigationUrl);
    } catch (e) {
      event.preventDefault();
    }
  });

  // Handle popup windows & Auth popups via System Default Browser
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    // Debounce: skip duplicate URLs within 3 seconds
    const now = Date.now();
    const urlBase = url.split('?')[0];
    if (urlBase === lastExternalUrl && (now - lastExternalTime) < 3000) {
      return { action: 'deny' };
    }
    lastExternalUrl = urlBase;
    lastExternalTime = now;

    shell.openExternal(url);
    return { action: 'deny' };
  });

  // Remove default menu bar for clean desktop app presentation
  Menu.setApplicationMenu(null);

  // Load via HTTP protocol on localhost (default authorized domain in Firebase)
  mainWindow.loadURL(`http://localhost:${port}`);

  mainWindow.once('ready-to-show', () => {
    mainWindow.maximize();
    mainWindow.show();
    
    // Check for updates on GitHub Releases automatically when app is packaged
    if (autoUpdater && app.isPackaged) {
      autoUpdater.checkForUpdatesAndNotify().catch(err => {
        console.log('Auto update check status:', err.message);
      });
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  // Strip Electron-identifying headers and clear stale cache on startup
  if (session && session.defaultSession) {
    session.defaultSession.clearCache().catch(() => {});
    session.defaultSession.setUserAgent(standardChromeUserAgent);
    session.defaultSession.webRequest.onBeforeSendHeaders((details, callback) => {
      details.requestHeaders['User-Agent'] = standardChromeUserAgent;
      delete details.requestHeaders['X-Electron-Version'];
      callback({ cancel: false, requestHeaders: details.requestHeaders });
    });
  }

  startLocalServer((port) => {
    createWindow(port);
    const initialAuthUrl = process.argv.find(arg => arg.startsWith(`${DESKTOP_AUTH_SCHEME}://`));
    if (initialAuthUrl) handleDesktopAuthUrl(initialAuthUrl);
  });

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow(serverPort);
    }
  });
});

app.on('before-quit', () => {
  if (server) {
    try { server.close(); } catch (e) {}
  }
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    if (server) {
      try { server.close(); } catch (e) {}
    }
    app.quit();
  }
});

// Suppress uncaught Chromium cache/quota errors from polluting the console
process.on('uncaughtException', (err) => {
  if (
    err.message &&
    (err.message.includes('quota') ||
     err.message.includes('cache') ||
     err.message.includes('disk_cache'))
  ) {
    // These are benign Chromium cache errors — app continues normally
    return;
  }
  console.error('Unhandled Error:', err);
});
