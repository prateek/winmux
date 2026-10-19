import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {writeFileSync,mkdirSync} from 'node:fs';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {dirname,join,resolve} from 'node:path';
const dir=dirname(fileURLToPath(import.meta.url)),out=resolve(process.argv[2]);
mkdirSync(out,{recursive:true});
const log=[];
function b(...args){const r=JSON.parse(execFileSync('agent-browser',['--session','tab-strip-131','--json',...args],{encoding:'utf8',maxBuffer:8e6}));assert(r.success,r.error);return r.data;}
const ev=s=>b('eval',s).result;
function check(name,fn){fn();log.push({name,pass:true});}
try {
 b('set','viewport','1920','1080');
 b('open',pathToFileURL(join(dir,'index.html')).href+'?selftest&work');
 check('geometry and hint reducer self-checks',()=>{const rows=ev('selftestResults');assert(rows.length>=40);assert(rows.every(r=>r.pass),JSON.stringify(rows.filter(r=>!r.pass)));log.push({rows});});
 for(const app of ['chrome','code','ghostty']) for(const look of ['today','thin','held','sidebar']) for(const grip of ['gone','clear']) {
  b('click',`#apps [data-app="${app}"]`);b('click',`#looks [data-look="${look}"]`);b('click',`#grips [data-grip="${grip}"]`);
  check(`${app}/${look}/${grip}`,()=>{assert.equal(ev('selection.app'),app);assert.equal(ev('selection.look'),look);assert.equal(ev('selection.grip'),grip);assert(ev('document.querySelector("#working .app-shot").naturalWidth')>0);});
  b('screenshot',join(out,`page-${app}-${look}-${grip}.png`));
 }
 b('click','#looks [data-look="held"]');b('click','#apps [data-app="chrome"]');
 b('keydown','Alt');b('wait','200');
 check('held strip absent before 500ms',()=>assert.equal(ev('hint.shown'),false));
 b('wait','400');
 check('held strip revealed after deadline',()=>assert.equal(ev('hint.shown'),true));
 b('screenshot',join(out,'page-held-midhold.png'));
 b('keyup','Alt');check('release hides',()=>assert.equal(ev('hint.shown'),false));
 b('keydown','Alt');b('press','x');b('wait','600');check('key spoils pending hold',()=>assert.equal(ev('hint.shown'),false));b('keyup','Alt');
 b('mouse','move','1700','100');b('keydown','Alt');b('mouse','down','left');b('mouse','up','left');b('wait','600');check('click spoils pending hold',()=>assert.equal(ev('hint.shown'),false));b('keyup','Alt');
 b('click','#looks [data-look="today"]');b('hover','#working .tab[data-index="1"]');
 check('hover exposes background close affordance',()=>assert.equal(ev("getComputedStyle(document.querySelector('#working .tab:nth-child(2) .close')).opacity"),'1'));
 b('screenshot',join(out,'page-tab-hover.png'));
 b('click','#working .tab[data-index="4"]');check('strip tab switches app',()=>assert.equal(ev('selection.app'),'code'));
 b('click','#grips [data-grip="clear"]');b('hover','#working .handle');b('screenshot',join(out,'page-handle-hover.png'));
 b('click','#looks [data-look="sidebar"]');b('hover','#working .sidebar');b('wait','250');
 check('real sidebar capture expands on hover',()=>assert.equal(ev('document.querySelector("#working .sidebar").classList.contains("expanded")'),true));
 b('screenshot',join(out,'page-sidebar-expanded.png'));
 b('mouse','move','1800','80');b('wait','250');check('rail collapses on exit',()=>assert.equal(ev('document.querySelector("#working .sidebar").classList.contains("expanded")'),false));
 b('click','[data-theme="dark"]');b('screenshot',join(out,'page-dark.png'));b('click','[data-theme="light"]');
 check('light and dark switches',()=>assert.equal(ev('document.documentElement.dataset.theme'),'light'));
 b('open',pathToFileURL(join(dir,'index.html')).href+'?selftest');
 for(const state of ['rest','tab-hover','grip-hover','hints']) {
  b('select','#baseline-state',state);
  check('native baseline selector '+state,()=>assert(ev(`[...document.querySelectorAll('#baseline img')].every(i=>i.src.includes('${state}')&&i.naturalWidth>0)`)));
 }
 b('click','#small-stages figure:last-child');check('small stage selects its look',()=>assert.equal(ev('selection.look'),'sidebar'));
 b('click','#looks [data-look="today"]');b('click','#grips [data-grip="clear"]');b('click','#working .handle');
 check('clear handle explains its drag target',()=>assert(ev('document.getElementById("status").textContent.includes("whole group of 5")')));
 b('click','#working .gutter');check('empty chrome names its group drag',()=>assert(ev('document.getElementById("status").textContent.includes("whole group of 5")')));
 b('open',pathToFileURL(join(dir,'index.html')).href+'?selftest&work');
 const negatives=ev("looks.thin.height=36;selftest().filter(r=>!r.pass)");
 check('wrong thin height is detected',()=>assert(negatives.some(r=>r.name==='thin strip at rest')));
 log.push({negativeControl:negatives});
 b('open',pathToFileURL(join(dir,'index.html')).href+'?selftest&work');
 check('restored geometry passes',()=>assert(ev('selftestResults.every(r=>r.pass)')));
 writeFileSync(join(out,'browser-checks.json'),JSON.stringify(log,null,2));
 console.log(`PASS ${log.filter(r=>r.pass).length} browser checks`);
} finally {b('close');}
