const {AddonManager}=ChromeUtils.importESModule('resource://gre/modules/AddonManager.sys.mjs');
const done=arguments[arguments.length-1];
(async()=>{
 const sidebery=await AddonManager.getAddonByID('{3c078156-979c-498b-8990-85f7987dd929}');await sidebery.disable();
 const initial=[...gBrowser.tabs],principal=Services.scriptSecurityManager.getSystemPrincipal();
 const base='file://'+Services.dirsvc.get('Home',Ci.nsIFile).path+'/sidebar-tree/extension-desk.html?title=';
 const created=[];
 function add(title,parent){const tab=gBrowser.addTab(base+encodeURIComponent(title),{triggeringPrincipal:principal,openerBrowser:parent?.linkedBrowser,inBackground:true});created.push({title,tab});return tab;}
 const one=add('Workspace 1 · terminals');for(const title of ['Zed · winmux.ncl','Ghostty · upper desk','Ghostty · lower desk','Floating · Updater'])add(title,one);
 const two=add('Workspace 2 · reading');add('Column 1 · Notes',two);const safari=add('Column 2 · Safari tabs',two);for(const title of ['Lenses and Search','Fixed Columns','Subscription events'])add(title,safari);add('Column 3 · Things I will get to',two);
 const three=add('Workspace 3 · writing');const writing=add('TextEdit tabs',three);for(const title of ['Grievances','Soft language'])add(title,writing);add('Finder · desk',three);
 const four=add('Workspace 4 · floating');add('Preview · wallpaper',four);add('Calculator',four);
 gBrowser.selectedTab=one;for(const tab of initial)gBrowser.removeTab(tab,{animate:false});
 done(created.map(({title,tab})=>({title,position:tab._tPos,opener:tab.openerTab?.label||null})));
})().catch(e=>done({error:String(e)}));
