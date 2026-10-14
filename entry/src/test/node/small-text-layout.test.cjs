const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const base=path.resolve(__dirname,'../../main/ets');
const source=fs.readFileSync(path.join(base,'presentation/thread/ThreadDetailPage.ets'),'utf8');
const start=source.indexOf('  private isInlineSmallContent(');
const end=source.indexOf('  @Builder',start);
const out={};
vm.runInNewContext(ts.transpileModule('class Reader {'+source.slice(start,end)+'} exports.Reader=Reader;',
  {compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText,{exports:out});
const reader=new out.Reader();
const text={kind:'text',value:'body'};
const tail={kind:'link',value:'small label',url:'https://example.com/',isSmallText:true};
const image={kind:'image',value:'image',url:'https://example.com/a.jpg'};
const content=[text,tail,image];
assert.equal(reader.isInlineSmallContent(content,1),true);
assert.equal(reader.getInlineSmallSuffix(content,0),tail);
assert.equal(reader.getInlineSmallSuffix(content,1),undefined);
assert.equal(reader.isInlineSmallContent(content,2),false,'image index must stay unchanged');
assert.equal(reader.isInlineSmallContent([image,tail],1),false,'tail after media needs its own line');
assert.equal(reader.isInlineSmallContent([{kind:'quote',value:'quote'},tail],1),false);
assert.equal(reader.isInlineSmallContent([text,{...tail,isSmallText:false}],1),false);
assert.equal(reader.isInlineSmallContent([{...text,isSmallText:true},tail],1),false);
const contracts={};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(base,'domain/reader/FourD4yReaderContracts.ets'),'utf8'),
  {compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText,{exports:contracts});
const payload={threadId:'100',viewerUserId:'1',title:'Synthetic',currentPage:1,lastPage:1,loadSequence:1,
  layout:'legacy-post',postNodeCount:1,accessState:'available',hasChallenge:false,errorMessage:'',
  posts:[{id:'200',threadId:'100',floor:1,authorName:'Synthetic author',content:[text,tail,image]}]};
assert.ok(contracts.parseThreadWebPayload(JSON.stringify(payload)));
for(const bad of [{...tail,isSmallText:'true'},{...image,isSmallText:true}]) {
  const changed=structuredClone(payload);changed.posts[0].content=[bad];
  assert.equal(contracts.parseThreadWebPayload(JSON.stringify(changed)),null);
}
console.log('Small signature inline grouping, media indexes and reader contract passed.');
