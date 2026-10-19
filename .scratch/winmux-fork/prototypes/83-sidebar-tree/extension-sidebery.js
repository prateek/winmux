const {AddonManager}=ChromeUtils.importESModule('resource://gre/modules/AddonManager.sys.mjs');
const done=arguments[arguments.length-1];
(async()=>{
 await (await AddonManager.getAddonByID('@tst-search')).disable();
 await (await AddonManager.getAddonByID('treestyletab@piro.sakura.ne.jp')).disable();
 await (await AddonManager.getAddonByID('{3c078156-979c-498b-8990-85f7987dd929}')).enable();
 await SidebarController.show('_3c078156-979c-498b-8990-85f7987dd929_-sidebar-action');
 done([...document.querySelectorAll('[id]')].filter(n=>n.id.includes('sidebar-action')).map(n=>({id:n.id,label:n.getAttribute('label')})));
})().catch(e=>done({error:String(e)}));
