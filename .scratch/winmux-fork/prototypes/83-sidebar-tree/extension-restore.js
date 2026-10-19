const principal=Services.scriptSecurityManager.getSystemPrincipal();
const base='file://'+Services.dirsvc.get('Home',Ci.nsIFile).path+'/sidebar-tree/extension-desk.html?title=';
const addonTab=[...gBrowser.tabs].find(t=>t.linkedBrowser.currentURI.spec.includes('addons.mozilla.org'));
if(addonTab)gBrowser.loadURI(Services.io.newURI(base+encodeURIComponent('Workspace 4 · floating')),{triggeringPrincipal:principal,browser:addonTab.linkedBrowser});
return [...gBrowser.tabs].map(t=>({title:t.label,url:t.linkedBrowser.currentURI.spec}));
