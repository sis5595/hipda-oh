// Run the production forum-list script with value-free DOM fixtures.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const base = path.resolve(__dirname, '../../main/ets');
function load(name) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(base, name), 'utf8'),
    { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText,
    { exports });
  return exports;
}
const filter = load('domain/reader/FourD4yForumFilter.ets');
const contracts = load('domain/reader/FourD4yReaderContracts.ets');
const home = fs.readFileSync(path.join(base, 'presentation/home/HomePage.ets'), 'utf8');
const start = home.indexOf('`(() => {', home.indexOf('  private async readThreadsFromWeb'));
const end = home.indexOf('})()`', start) + 5;
assert.ok(start > 0 && end > start);
const script = vm.runInNewContext(home.slice(start, end), filter);
function extract(href='space.php?uid=123456', style='color: #339933; font-weight: bold') {
  const author = {textContent:'Synthetic author',getAttribute:n => n==='href' ? href : '',querySelector:()=>null};
  const authorCell={textContent:'Synthetic author 2026-10-13',querySelector:()=>({textContent:'2026-10-13'})};
  const nums={textContent:'2 40',querySelector:s=>({textContent:s==='em'?'40':'2'})};
  const subject={querySelector:()=>null};
  const row={className:'',id:'row',innerHTML:'',querySelectorAll:()=>[],querySelector:s=> {
    if(s==='td.author, td.list_user') return authorCell;
    if(s==='td.nums, .nums') return nums;
    if(s==='td.list_user a.user, td.author cite a, td.author a, .author a') return author;
    return null;
  }};
  const title={textContent:'Synthetic highlighted topic',getAttribute:n=>n==='href'?'viewthread.php?tid=100':n==='style'?style:'',
    closest:s=>s==='tr'?row:subject};
  const document={body:{textContent:'Synthetic forum'},documentElement:{innerHTML:''},getElementById:()=>null,
    querySelector:()=>null,querySelectorAll:s=>s==='a'?[title]:s==='td.listcon'?[row]:[]};
  return JSON.parse(vm.runInNewContext(script,{URL,URLSearchParams,document,
    location:{href:'https://www.4d4y.com/forum/forumdisplay.php?fid=2&page=1&oh_load=1',
      search:'?fid=2&page=1&oh_load=1'}}));
}
const first=extract();
assert.equal(first.threads[0].authorUserId,'123456');
assert.equal(first.threads[0].titleColor,'#339933');
assert.equal(first.threads[0].isPinned,false,'highlight colour alone is not a sticky marker');
assert.ok(contracts.parseForumWebPayload(JSON.stringify(first)));
assert.equal(extract('space.php?uid=999&uid=123456').threads[0].authorUserId,'');
assert.equal(extract('https://evil.test/forum/space.php?uid=999').threads[0].authorUserId,'');
assert.equal(extract('https://attacker@www.4d4y.com/forum/space.php?uid=999').threads[0].authorUserId,'');
assert.equal(extract('forumdisplay.php?uid=999').threads[0].authorUserId,'');
assert.equal(extract('space.php?uid=bad').threads[0].authorUserId,'');
for(const style of ['background-color:#123456','color: url(https://evil.test)','color:#123456bad']) {
  assert.equal(extract(undefined,style).threads[0].titleColor,'');
}
assert.equal(extract(undefined,'font-weight:bold; color:#abc !important').threads[0].titleColor,'#abc');
for(const [key,value] of [['titleColor','url(https://evil.test)'],['authorUserId','x'],['titleColor',true]]) {
  const bad=structuredClone(first);bad.threads[0][key]=value;
  assert.equal(contracts.parseForumWebPayload(JSON.stringify(bad)),null);
}
const old=structuredClone(first);delete old.threads[0].authorUserId;delete old.threads[0].titleColor;
assert.ok(contracts.parseForumWebPayload(JSON.stringify(old)), 'older list fixtures remain valid');
console.log('Forum original-author identity and safe title highlight extraction passed.');
