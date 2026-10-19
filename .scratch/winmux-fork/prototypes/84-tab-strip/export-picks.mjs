import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {dirname,join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const dir=dirname(fileURLToPath(import.meta.url));
function b(...args){const r=JSON.parse(execFileSync('agent-browser',['--session','tab-strip-131-export','--json',...args],{encoding:'utf8',maxBuffer:4e6}));assert(r.success,r.error);return r.data;}
try {
 b('set','viewport','1920','400');
 for(const look of ['today','thin','held','sidebar']) for(const grip of ['gone','clear']) {
  b('open',pathToFileURL(join(dir,'index.html')).href+`?export&look=${look}&app=chrome&grip=${grip}`);
  b('wait','200');
  if(look==='held'){b('keydown','Alt');b('wait','600');}
  if(look==='sidebar'){b('hover','#working .sidebar');b('wait','200');}
  b('screenshot',join(dir,'img',`pick-${look}-${grip}.png`));
  if(look==='held')b('keyup','Alt');
 }
 b('open',pathToFileURL(join(dir,'index.html')).href+'?export&look=held&app=chrome&grip=gone');
 b('screenshot',join(dir,'img','pick-held-rest.png'));
} finally {b('close');}
