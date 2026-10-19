import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const session='sidebar-130-rule-reversion',folder=dirname(fileURLToPath(import.meta.url));
const b=(...args)=>{const r=JSON.parse(execFileSync('agent-browser',['--session',session,'--json',...args],{encoding:'utf8',maxBuffer:4e6}));assert(r.success,r.error);return r.data;};
try{
 b('open',pathToFileURL(join(folder,'index.html')).href+'?selftest');
 const rows=b('eval','prototype.pickTests()').result;
 writeFileSync(process.argv[2],JSON.stringify(rows,null,2)+'\n');
 for(const row of rows){console.log((row.pass?'PASS ':'FAIL ')+row.name);assert.equal(row.pass,process.argv.includes('--old')?!row.changed:true,row.name);}
}finally{b('close');}
