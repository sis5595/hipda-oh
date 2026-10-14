// Value-free DOM fixtures; execute the production ArkWeb extractor, not a copy.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/thread/ThreadDetailPage.ets'), 'utf8');
const method = source.slice(source.indexOf('private getThreadExtractionScript(): string'));
const arraySource = method.slice(method.indexOf('return [') + 'return '.length,
  method.indexOf("].join('\\n');") + 1);
const ast = ts.createSourceFile('extractor.ts', `const script = ${arraySource};`,
  ts.ScriptTarget.ES2020, true);
const array = ast.statements[0].declarationList.declarations[0].initializer;
assert.ok(ts.isArrayLiteralExpression(array));
const script = array.elements.map(element => {
  assert.ok(ts.isStringLiteral(element), 'Extractor must be a literal script');
  return element.text;
}).join('\n');
const contentScript = script.slice(0, script.indexOf('  const params =')) +
  'return extractContent(body, body); })()';

class Element {
  constructor(tag, children = [], attributes = {}) {
    this.nodeType = 1;
    this.tagName = tag.toUpperCase();
    this.childNodes = children;
    this.attributes = attributes;
    this.id = attributes.id || '';
    this.classList = { contains: value => (attributes.class || '').split(' ').includes(value) };
  }
  get textContent() { return this.childNodes.map(n => n.nodeValue || n.textContent || '').join(''); }
  getAttribute(name) { return this.attributes[name] || null; }
  querySelector(selector) {
    if (selector === 'font[size="1"], small') {
      return this.querySelectorAll('*').find(node => node.tagName === 'SMALL' ||
        (node.tagName === 'FONT' && node.getAttribute('size') === '1')) || null;
    }
    return null;
  }
  querySelectorAll(selector) {
    const nodes = this.childNodes.filter(n => n.nodeType === 1);
    const descendants = nodes.flatMap(n => [n, ...n.querySelectorAll('*')]);
    if (selector === '*') return descendants;
    if (selector === 'img') return descendants.filter(n => n.tagName === 'IMG');
    if (selector === 'a[href]') return descendants.filter(n => n.tagName === 'A' && n.getAttribute('href'));
    return [];
  }
  closest() { return null; }
}
const text = nodeValue => ({ nodeType: 3, nodeValue });
const element = (tag, ...children) => new Element(tag, children);
function extract(...nodes) {
  return JSON.parse(JSON.stringify(vm.runInNewContext(contentScript, {
    body: element('div', ...nodes), URL,
    location: { href: 'https://www.4d4y.com/forum/viewthread.php?tid=100' },
    document: { getElementById: () => null }
  })));
}
function value(...nodes) {
  const result = extract(...nodes);
  assert.equal(result.length, 1);
  assert.equal(result[0].kind, 'text');
  return result[0].value;
}

assert.equal(value(text('甲'), element('font', text('B2')), text('乙')), '甲B2乙');
assert.equal(value(text('甲'), text('乙')), '甲乙');
assert.equal(value(text('alpha '), element('strong', text('beta')), text(' gamma')), 'alpha beta gamma');
assert.equal(value(text('甲'), element('br'), text('乙')), '甲\n乙');
assert.equal(value(text('甲'), element('br'), element('br'), text('乙')), '甲\n\n乙');
assert.equal(value(text('甲\n  乙')), '甲 乙'); // HTML source whitespace is not a line break.
assert.equal(value(element('p', text('甲')), element('p', text('乙'))), '甲\n乙');
assert.equal(value(element('div', text('甲')), element('div', text('乙'))), '甲\n乙');
assert.equal(value(element('pre', text('甲\n  乙'))), '甲\n  乙');
assert.equal(value(text('甲'), element('script', text('not body')), element('style', text('not body')), text('乙')), '甲乙');
assert.deepEqual(extract(text('\n   '), element('br'), text(' ')), []);

const image = new Element('img', [], { src: 'https://www.4d4y.com/forum/attachments/sample.jpg' });
const content = extract(text('甲'), image, text('乙'));
assert.deepEqual(content.map(item => item.kind), ['text', 'image', 'text']);
assert.equal(content[0].value, '甲');
assert.equal(content[2].value, '乙');
assert.equal(content[1].url, image.getAttribute('src'));
const link = new Element('a', [text('样例链接')], { href: 'https://example.com/' });
assert.deepEqual(extract(text('甲'), link, text('乙')).map(item => item.kind), ['text', 'link', 'text']);
const smallFont = new Element('font', [text('样例尾巴')], { size: '1' });
const smallLink = new Element('a', [smallFont], { href: 'https://example.com/' });
const withTail = extract(text('正文'), smallLink);
assert.equal(withTail[0].isSmallText, undefined);
assert.equal(withTail[1].isSmallText, true);
assert.equal(withTail[1].kind, 'link');
assert.equal(withTail[1].value, '样例尾巴');
assert.equal(withTail[1].url, 'https://example.com/');
assert.equal(extract(new Element('font', [link], {size:'1'}))[0].isSmallText, true);
assert.deepEqual(extract(text('正文'), smallFont).map(item => [item.kind, item.value, item.isSmallText]),
  [['text','正文',undefined], ['text','样例尾巴',true]], 'small plain tails must not merge into ordinary text');
const mixedLink = new Element('a', [text('普通文字'), smallFont], {href:'https://example.com/'});
assert.equal(extract(mixedLink)[0].isSmallText, undefined, 'mixed link text must not all shrink');
assert.equal(extract(link, smallLink).length, 2, 'normal link and small signature to the same URL both survive');
assert.equal(extract(new Element('font', [text('正文')], {size:'2'}))[0].isSmallText, undefined);
const menu = new Element('div', [text('not body')], { class: 't_attach attachimg' });
assert.equal(value(text('甲'), menu, text('乙')), '甲乙');
const status = new Element('i', [text('not body')], { class: 'pstatus' });
assert.equal(value(text('甲'), status, text('乙')), '甲乙');
console.log('PASS: inline continuity; explicit/blank/paragraph/pre line breaks; whitespace; media/link/status boundaries.');

const pagingStart = script.indexOf('  let lastPage =');
const pagingEnd = script.indexOf('  const currentMatch =', pagingStart);
assert.ok(pagingStart >= 0 && pagingEnd > pagingStart);
const pagingScript = '(() => {' + script.slice(pagingStart, pagingEnd) + 'return lastPage; })()';
function lastPage(href, links) {
  return vm.runInNewContext(pagingScript, { URL, location: { href }, params: new URL(href).searchParams,
    document: { querySelectorAll: () => links.map(([url, inPost = false]) => ({
      getAttribute: () => url, closest: () => inPost ? {} : null
    })) } });
}
const threadUrl = 'https://www.4d4y.com/forum/viewthread.php?tid=100';
assert.equal(lastPage(threadUrl, [['viewthread.php?tid=100&page=3'],
  ['viewthread.php?tid=200&page=99'], ['viewthread.php?tid=100&page=99', true],
  ['https://evil.example/forum/viewthread.php?tid=100&page=88'],
  ['forumdisplay.php?fid=2&page=77'], ['viewthread.php?tid=100&authorid=2&page=22']]), 3);
assert.equal(lastPage(threadUrl + '&page=4', []), 4);
assert.equal(lastPage(threadUrl, []), 1);
assert.equal(lastPage(threadUrl + '&authorid=2', [['viewthread.php?tid=100&page=9'],
  ['viewthread.php?tid=100&authorid=2&page=2']]), 2);
assert.equal(lastPage(threadUrl, [['viewthread.php?tid=100&amp;page=5']]), 5);
console.log('PASS: pagination ignores body links, other topics, boards, origins and author scopes.');

// Cross the actual producer/consumer boundary, including an old/anonymous
// floor with no profile link. A missing optional identity must not invalidate
// the whole page or accidentally inherit another floor's author.
const contracts = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/domain/reader/FourD4yReaderContracts.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: contracts });
function extractPage(authorHref, forumLinks = []) {
  const author = authorHref === undefined ? null : new Element('a', [text('sample')], { href: authorHref });
  const body = new Element('div', [text('sample body')], { id: 'postmessage_1' });
  const post = new Element('div', [body], { id: 'post_1' });
  post.querySelector = selector => {
    if (selector.startsWith('.sub a[')) return author;
    if (selector === '[id^="postmessage_"]') return body;
    return null;
  };
  return vm.runInNewContext(script, { URL, URLSearchParams,
    location: { href: threadUrl, search: new URL(threadUrl).search },
    document: { body: element('body'), title: 'sample', scripts: [],
      documentElement: { innerHTML: '' }, getElementById: () => null,
      querySelector: () => null,
      querySelectorAll: selector => selector === '[id]' ? [post, body] :
        (selector === '#nav a[href]' ? forumLinks : []) }
  });
}
for (const href of [undefined, 'space.php?uid=123', 'space.php?uid=invalid']) {
  const raw = extractPage(href);
  const parsed = contracts.parseThreadWebPayload(raw);
  assert.ok(parsed, 'the production extractor must satisfy its own reader contract without an author UID');
  assert.equal(parsed.posts.length, 1);
  assert.equal(parsed.posts[0].content[0].value, 'sample body');
  assert.equal(parsed.posts[0].authorUserId, href === 'space.php?uid=123' ? '123' : undefined);
  assert.ok(contracts.parseThreadWebPayload(JSON.stringify(raw)), 'ArkWeb double-wrapped JSON remains supported');
}
const invalidIdentity = JSON.parse(extractPage('space.php?uid=123'));
invalidIdentity.posts[0].authorUserId = 'not-an-id';
assert.equal(contracts.parseThreadWebPayload(JSON.stringify(invalidIdentity)), null,
  'do not relax validation of a supplied identity');
console.log('PASS: full thread extractor/reader contract with present, absent and malformed profile links.');

const navLink = (href, insidePost = false) => ({ getAttribute: () => href,
  closest: () => insidePost ? {} : null });
for (const [links, expected] of [
  [[], ''],
  [[navLink('forumdisplay.php?fid=2')], '2'],
  [[navLink('forumdisplay.php?fid=51&amp;page=1')], '51'],
  [[navLink('https://evil.example/forum/forumdisplay.php?fid=99')], ''],
  [[navLink('http://www.4d4y.com/forum/forumdisplay.php?fid=99')], ''],
  [[navLink('https://user:pass@www.4d4y.com/forum/forumdisplay.php?fid=99')], ''],
  [[navLink('viewthread.php?fid=99&tid=100')], ''],
  [[navLink('forumdisplay.php?fid=2&fid=99')], ''],
  [[navLink('forumdisplay.php?fid=invalid')], ''],
  [[navLink('forumdisplay.php?fid=99', true), navLink('forumdisplay.php?fid=2')], '2']
]) {
  const parsed = contracts.parseThreadWebPayload(extractPage('space.php?uid=123', links));
  assert.ok(parsed);
  assert.equal(parsed.forumId, expected);
}
for (const invalid of ['invalid', '2&fid=99', 2, null]) {
  const payload = JSON.parse(extractPage('space.php?uid=123'));
  payload.forumId = invalid;
  assert.equal(contracts.parseThreadWebPayload(JSON.stringify(payload)), null);
}
const oldPayload = JSON.parse(extractPage('space.php?uid=123'));
delete oldPayload.forumId;
assert.ok(contracts.parseThreadWebPayload(JSON.stringify(oldPayload)));
console.log('PASS: breadcrumb-only board identity; no post/quote links, foreign origins or ambiguous fid.');
