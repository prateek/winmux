// Usage: node normalize.mjs <raw readback directory> <desk.json destination>
import {readFileSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
const [raw, output] = process.argv.slice(2);
const read = name => JSON.parse(readFileSync(join(raw, name), 'utf8'));
const snapshot = read('agent.json');
const remembered = read('focus-from-captures.json').workspaces;
const windows = snapshot.inventory.windows;
const byId = new Map(windows.map(w => [w.windowId, w]));
function windowNode(id) {
  const w = byId.get(id);
  if (!w) throw Error(`Missing window ${id}`);
  return {id: `w${id}`, kind: 'window', app: w.appName, title: w.title,
    focused: w.focused, floating: w.layout === 'floating', frame: w.frame};
}
function node(n, id) {
  if (n.kind === 'window') return {...windowNode(n.windowId), size: n.size};
  if (n.kind === 'tabGroup') return {id: n.tabGroupId, kind: 'tabs', layout: 'tab-group',
    orientation: 'vertical', active: `w${n.activeWindowId}`, size: n.size,
    children: n.tabs.map(windowNode)};
  return {id, kind: 'split', layout: n.layout, orientation: n.direction, size: n.size,
    children: n.children.map((c, i) => node(c, `${id}-${i}`))};
}
const workspaces = snapshot.inventory.workspaces.map(ws => {
  const columns = read(`columns-${ws.name}.json`);
  const root = node(snapshot.reasoning.rawTrees.find(r => r.workspace === ws.name).tree, `root-${ws.name}`);
  const children = columns.length ? columns.map(c => {
    const ids = new Set(c['window-ids'].map(id => `w${id}`));
    const leaves = n => n.kind === 'window' ? [n.id] : n.children.flatMap(leaves);
    const content = root.children.filter(n => leaves(n).some(id => ids.has(id)));
    for (const n of content) if (!leaves(n).every(id => ids.has(id))) throw Error('Column spans a raw node');
    return {id: `col-${ws.name}-${c.index}`, kind: 'column', index: c.index, width: c.width, children: content};
  }) : [root];
  const floating = windows.filter(w => w.workspace === ws.name && w.layout === 'floating').map(w => windowNode(w.windowId));
  if (floating.length) children.push({id: `float-${ws.name}`, kind: 'floating', children: floating});
  return {id: `ws-${ws.name}`, kind: 'workspace', name: ws.name, focused: ws.focused,
    columns: columns.length > 0, rememberedFocus: `w${remembered[ws.name]}`,
    focusedColumn: columns.find(c => c['window-ids'].includes(remembered[ws.name]))?.index || 1,
    children};
});
const result = {schema: 1, sourceCommit: '1fbbdc72', display: {width: 1920, height: 1080}, workspaces};
const leaves = n => n.kind === 'window' ? [n] : n.children.flatMap(leaves);
if (workspaces.flatMap(leaves).length !== 14) throw Error('Expected fourteen windows');
writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
