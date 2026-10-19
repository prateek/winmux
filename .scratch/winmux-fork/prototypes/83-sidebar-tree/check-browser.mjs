// Headless, task-owned Chromium. Usage: node check-browser.mjs <capture directory>
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {join, dirname, resolve} from 'node:path';
const folder = dirname(fileURLToPath(import.meta.url));
const out = resolve(process.argv[2]);
mkdirSync(out, {recursive:true});
const session = 'sidebar-130-check';
const log = [];
function browser(...args) {
  const response = JSON.parse(execFileSync('agent-browser', ['--session',session,'--json',...args], {encoding:'utf8',maxBuffer:4e6}));
  assert.equal(response.success,true,response.error);
  return response.data;
}
const evaluate = code => browser('eval',code).result;
const row = (id,v='working') => `#${v} .row[data-target="${id}"]`;
const rail = id => `#working .rail-ws[data-target="${id}"]`;
const open = v => browser('open',pathToFileURL(join(folder,'index.html')).href+`?selftest&view=work&variant=${v}`);
const check = (name,fn) => {fn();log.push({name,pass:true});console.log('PASS '+name);};
const reset = () => browser('click','#reset');
const snapshot = name => browser('screenshot',join(out,name+'.png'));
try {
  browser('set','viewport','1920','1080');
  open('A');
  check('embedded fixture equals desk.json',()=>assert.deepEqual(evaluate('prototype.desk'),JSON.parse(readFileSync(join(folder,'desk.json'),'utf8'))));
  check('all drag table self-checks pass',()=>{const tests=evaluate('selftestResults');assert(tests.length>=21);assert(tests.every(t=>t.pass));log.push({selftest:tests});});
  for(const v of ['A','B','C']) {
    open(v);
    snapshot(v+'-expanded');
    check(v+' disclosure collapses and search restores the saved state',()=>{
      browser('click','#working [data-toggle="tabgroup-231"]');
      assert.equal(evaluate('document.querySelector("#working .row[data-target=w231]")===null'),true);
      browser('fill','#search','Safari');
      assert.equal(evaluate('document.getElementById("count").textContent'),'3 matches');
      for(const stage of ['stage-A','stage-B','stage-C','working']) assert.deepEqual(evaluate(`Array.from(document.querySelectorAll('#${stage} .row.window'),n=>n.dataset.target)`),['w231','w237','w238']);
      snapshot(v+'-search');
      browser('fill','#search','');
      assert.equal(evaluate('document.querySelector("#working .row[data-target=w231]")===null'),true);
      browser('click','#working [data-toggle="tabgroup-231"]');
    });
    check(v+' hover expands an unpinned rail and leaving collapses it',()=>{
      browser('click','#work-pin');
      assert.equal(evaluate('document.querySelector("#working .sidebar").classList.contains("expanded")'),false);
      snapshot(v+'-collapsed');
      const point=evaluate('(()=>{const r=document.querySelector("#working .rail").getBoundingClientRect();return {x:r.left+3,y:r.top+40}})()');
      browser('mouse','move',String(Math.round(point.x)),String(Math.round(point.y)));
      // This is a single wait for the specified hover deadline, not a readiness poll.
      browser('wait','250');
      assert.equal(evaluate('document.querySelector("#working .sidebar").classList.contains("expanded")'),true);
      browser('mouse','move','1800','180');browser('wait','250');
      assert.equal(evaluate('document.querySelector("#working .sidebar").classList.contains("expanded")'),false);
      browser('click','#work-pin');
    });
    check(v+' an unpinned drag releases its expansion lock after moving off',()=>{
      browser('click','#work-pin');
      const point=evaluate('(()=>{const r=document.querySelector("#working .rail").getBoundingClientRect();return {x:Math.round(r.left+3),y:Math.round(r.top+40)}})()');
      browser('mouse','move',String(point.x),String(point.y));browser('wait','250');
      browser('drag',row('w214'),rail('ws-4'));
      browser('mouse','move','1800','180');browser('wait','250');
      assert.equal(evaluate('prototype.index().get("w214").ws.name'),'4');
      assert.equal(evaluate('document.querySelector("#working .sidebar").classList.contains("expanded")'),false);
      browser('click','#work-pin');reset();
    });
    check(v+' native HTML drag moves a window and updates every tree and the miniature',()=>{
      const before=evaluate('document.querySelector("#working .mini").innerHTML');
      browser('drag',row('w214'),rail('ws-4'));
      assert.equal(evaluate('prototype.index().get("w214").ws.name'),'4');
      assert.notEqual(evaluate('document.querySelector("#working .mini").innerHTML'),before);
      for(const stage of ['stage-A','stage-B','stage-C','working']) assert.equal(evaluate(`document.querySelector('#${stage} [data-node="ws-4"] [data-node="w214"]')!==null`),true);
      assert.equal(evaluate('[...prototype.index().values()].filter(x=>x.node.kind==="window").length'),14);
      snapshot(v+'-accepted');
      browser('click',row('w265'));
      assert.deepEqual(evaluate('Array.from(document.querySelectorAll("#working .mini .tile:not(.floating-tile)"),n=>parseFloat(n.style.width))'),[50,50]);
    });
    reset();
    check(v+' refused window-parent drop preserves every node',()=>{
      const before=evaluate('JSON.stringify(prototype.desk)');
      browser('drag',row('w214'),row('w239'));
      assert.equal(evaluate('JSON.stringify(prototype.desk)'),before);
      assert.match(evaluate('document.getElementById("status").textContent'),/window has no children/);
      snapshot(v+'-refused');
    });
    check(v+' a window joins a tab group through its row',()=>{
      browser('drag',row('w214'),row('tabgroup-231'));
      assert.equal(evaluate('prototype.index().get("w214").parent.id'),'tabgroup-231');
    });
    reset();
    check(v+' a group moves intact to an ordinary workspace',()=>{
      browser('drag',row('root-1-1'),rail('ws-4'));
      assert.equal(evaluate('prototype.index().get("root-1-1").ws.name'),'4');
      assert.equal(evaluate('prototype.index().get("root-1-1").node.children.length'),2);
    });
    reset();
    check(v+' a split can be one tab without counting its leaves as separate tabs',()=>{
      browser('drag',row('root-1-1'),row('tabgroup-231'));
      assert.equal(evaluate('prototype.index().get("root-1-1").parent.id'),'tabgroup-231');
      assert.equal(evaluate('document.querySelector("#working .row[data-target=tabgroup-231] .title").textContent'),'Tabs · 4');
      browser('click',row('w214'));
      assert.equal(evaluate('document.querySelectorAll("#working .mini .tile img[alt=Ghostty]").length'),2);
    });
    reset();
    check(v+' Column row, mark or divider accepts a group and merges occupied tabs',()=>{
      const selector=v==='A'?row('col-2-2'):v==='B'?'#working .row.workspace .mark[data-target="col-2-2"]':'#working .divider[data-target="col-2-2"]';
      browser('drag',row('root-1-1'),selector);
      assert.equal(evaluate('prototype.index().has("root-1-1")'),false);
      assert.equal(evaluate('prototype.index().get("tabgroup-231").node.children.length'),5);
    });
    reset();
    check(v+' insertion line puts a window between split siblings',()=>{
      browser('drag',row('w239'),'#working .insert[data-target="root-1-1"][data-at="1"]');
      assert.deepEqual(evaluate('prototype.index().get("root-1-1").node.children.map(n=>n.id)'),['w214','w239','w222']);
      assert.equal(evaluate('prototype.desk.workspaces[1].rememberedFocus'),'w231');
      assert.equal(evaluate('prototype.desk.workspaces[1].focusedColumn'),2);
    });
    reset();
    check(v+' floating drop into a Column stays refused',()=>{
      const selector=v==='A'?row('col-2-1'):v==='B'?'#working .row.workspace .mark[data-target="col-2-1"]':'#working .divider[data-target="col-2-1"]';
      const before=evaluate('JSON.stringify(prototype.desk)');
      browser('drag',row('w266'),selector);
      assert.equal(evaluate('JSON.stringify(prototype.desk)'),before);
      assert.match(evaluate('document.getElementById("status").textContent'),/layout tiling/);
    });
    reset();
  }
  for(const [q,count,ids] of [['Safari',3,['w231','w237','w238']],['Grievances',1,['w250']],['qzxnomatch',0,[]]]) {
    browser('fill','#search',q);
    check('search '+q,()=>{assert.equal(evaluate('document.getElementById("count").textContent'),count+' matches');assert.deepEqual(evaluate('Array.from(document.querySelectorAll("#working .row.window"),n=>n.dataset.target)'),ids);});
    log.push({query:q,count,ids});
  }
  reset();
  const metrics=evaluate('Object.fromEntries(["A","B","C"].map(v=>[v,prototype.widthMetrics(v)]))');
  log.push({metrics});
  for(const v of ['A','B','C']) {
    check(v+' measured title width matches actual clipping',()=>{
      const width=metrics[v].needed;
      evaluate(`document.getElementById('width').value=${width};document.getElementById('width').dispatchEvent(new Event('input'))`);
      assert.equal(evaluate(`Array.from(document.querySelectorAll('#stage-${v} .title')).filter(n=>n.scrollWidth>n.clientWidth).length`),0);
      evaluate(`document.getElementById('width').value=${width-2};document.getElementById('width').dispatchEvent(new Event('input'))`);
      assert(evaluate(`Array.from(document.querySelectorAll('#stage-${v} .title')).some(n=>n.scrollWidth>n.clientWidth)`));
    });
  }
  check('no missing local images',()=>assert(evaluate('Promise.all(Array.from(document.images).filter(i=>i.hasAttribute("src")).map(i=>i.decode().then(()=>i.naturalWidth>0))).then(results=>results.every(Boolean))')));
  check('no browser JavaScript errors',()=>assert.deepEqual(browser('errors').errors,[]));
  console.log('All browser checks passed.');
} catch(error) {
  try {snapshot('failure');log.push({status:evaluate('document.getElementById("status").textContent')});} catch {}
  log.push({pass:false,error:error.stack});
  console.error(error.stack);process.exitCode=1;
} finally {
  writeFileSync(join(out,'results.json'),JSON.stringify(log,null,2)+'\n');
  browser('close');
}
