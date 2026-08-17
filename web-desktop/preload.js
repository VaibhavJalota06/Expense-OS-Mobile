const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  isElectron: true,
  openExternal: (url) => ipcRenderer.send('open-external-url', url),
  consumeOAuthSession: () => ipcRenderer.invoke('consume-oauth-session'),
  onOAuthSession: (callback) => {
    ipcRenderer.removeAllListeners('oauth-session');
    ipcRenderer.on('oauth-session', (_event, payload) => callback(payload));
  },
  checkForUpdates: () => ipcRenderer.send('check-for-updates-now'),
  restartAndInstall: () => ipcRenderer.send('restart-and-install'),
  onUpdateStatus: (callback) => {
    ipcRenderer.removeAllListeners('auto-updater-status');
    ipcRenderer.on('auto-updater-status', (_event, data) => callback(data));
  }
});
