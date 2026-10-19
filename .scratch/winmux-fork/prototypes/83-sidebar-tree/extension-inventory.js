const {AddonManager}=ChromeUtils.importESModule('resource://gre/modules/AddonManager.sys.mjs');
const done=arguments[arguments.length-1];
AddonManager.getAllAddons().then(addons=>done(addons.filter(a=>a.type==='extension').map(a=>({id:a.id,name:a.name,active:a.isActive,version:a.version}))));
