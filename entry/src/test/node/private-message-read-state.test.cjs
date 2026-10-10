// Synthetic messages only. Match NG's header-icon semantics, never body styles.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
function load(relative, dependencies = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.resolve(__dirname,
    '../../main/ets', relative + '.ets'), 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, require: name => {
    assert.ok(name in dependencies, name); return dependencies[name];
  } });
  return exports;
}
const reader = load('domain/reader/FourD4yReaderContracts');
const contracts = load('domain/notice/FourD4yPrivateConversationContracts', {
  '../reader/FourD4yReaderContracts': reader
});
const parser = load('data/remote/FourD4yPrivateConversationNativeParser', {
  '../../domain/reader/FourD4yReaderContracts': reader,
  '../../domain/notice/FourD4yPrivateConversationContracts': contracts,
  './FourD4yViewerIdentityParser': load('data/remote/FourD4yViewerIdentityParser')
});
function parse(body, icon = '') {
  const payload = parser.parseFourD4yPrivateConversationPage(
    '<div id="umenu"><cite><a href="space.php?uid=1">viewer</a></cite></div>' +
    '<ul class="pm_list"><li class="s_clear" id="pm_100">' +
    '<p class="cite"><cite><a href="space.php?uid=2">sender</a></cite> 2026-10-06 10:00 ' +
    icon + '</p><div class="summary">' + body + '</div></li></ul>',
    contracts.buildFourD4yPrivateConversationUrl('2'), 1);
  assert.ok(payload);
  assert.equal(payload.messages.length, 1);
  return payload.messages[0];
}
for (const body of ['plain', '<b>bold text</b>', '<span style="font-weight:bold">bold text</span>',
  '<span class="new">new product</span>', 'text notice_newpm.gif',
  '<img src="images/default/notice_newpm.gif">']) {
  assert.equal(parse(body).isUnread, false, 'body content cannot manufacture unread state');
  assert.equal(parse(body, '<img src="images/default/notice_newpm.gif">').isUnread, true);
}
assert.equal(parse('sample', '<img src="newpm.gif">').isUnread, true);
assert.equal(parse('sample', '<img src="images/default/notice_newpm.gif?v=1">').isUnread, true);
assert.equal(parse('sample', '<img src="images/default/notice_newpm.gif.txt">').isUnread, false);
assert.equal(parse('sample', '<img src="images/default/notice_pm.gif">').isUnread, false);
assert.equal(parse('<img src="images/smilies/default/handshake.gif">').body, ':handshake:');
for (const attributes of ['class="avatar" href="space.php?uid=1"',
  'href="space.php?uid=1" class="avatar"']) {
  const payload = parser.parseFourD4yPrivateConversationPage(
    '<div id="umenu"><cite><a href="space.php?uid=1">viewer</a></cite></div>' +
    '<ul class="pm_list"><li class="s_clear" id="pm_101"><a ' + attributes + '><img src="avatar.png"></a>' +
    '<p class="cite"><cite>viewer</cite>2026-10-06 10:00</p>' +
    '<div class="summary">my sample</div></li></ul>', contracts.buildFourD4yPrivateConversationUrl('2'), 1);
  assert.equal(payload.messages[0].senderUserId, '1', 'avatar attribute order cannot erase sender identity');
  assert.equal(payload.messages[0].isMine, true, 'a self cite may be plain text rather than a profile link');
}
for (const sample of [
  { rowClass: 's_clear self', viewer: '1', mine: true },
  { rowClass: 'self s_clear', viewer: '1', mine: true },
  { rowClass: 's_clear self', viewer: '', mine: false },
  { rowClass: 's_clear not-self', viewer: '1', mine: false },
  { rowClass: 's_clear', viewer: '1', mine: false },
  { rowClass: 's_clear self', viewer: '1', sender: '2', mine: false }
]) {
  const header = sample.viewer ? '<div id="umenu"><cite><a href="space.php?uid=' +
    sample.viewer + '">viewer</a></cite></div>' : '';
  const payload = parser.parseFourD4yPrivateConversationPage(header +
    '<ul class="pm_list"><li class="' + sample.rowClass + '" id="pm_102">' +
    '<a class="avatar"><img src="avatar.png"></a><p class="cite"><cite>' +
    (sample.sender ? '<a href="space.php?uid=' + sample.sender + '">sender</a>' : 'viewer') +
    '</cite>2026-10-06 10:00</p><div class="summary"><span class="self">sample</span></div></li></ul>',
    contracts.buildFourD4yPrivateConversationUrl('2'), 1);
  assert.equal(payload.messages[0].isMine, sample.mine, JSON.stringify(sample));
  if (sample.mine) assert.equal(payload.messages[0].senderUserId, sample.viewer);
}
console.log('PASS: PM header unread state and server self-row identity; body styling is never identity.');

const messageContracts = load('domain/notice/FourD4yMessageContracts', {
  '../reader/FourD4yReaderContracts': reader
});
const messageParser = load('data/remote/FourD4yMessageNativeParser', {
  '../../domain/reader/FourD4yReaderContracts': reader,
  '../../domain/notice/FourD4yMessageContracts': messageContracts,
  './FourD4yViewerIdentityParser': load('data/remote/FourD4yViewerIdentityParser')
});
const counter = messageParser.parseFourD4yNativeMessagePrompt;
for (const html of ['<html>temporary upstream error</html>',
  '<!-- <a id="myprompt">notice</a> -->',
  '<script>const sample = \'<a id="myprompt">notice</a>\';</script>',
  '<a data-id="myprompt">notice</a>',
  '<div class="cf-turnstile"></div>',
  '<a id="myprompt">notice</a><div class="cf-turnstile"></div>']) {
  const payload = counter(html, 7);
  assert.equal(messageContracts.isExpectedFourD4yMessagePromptPayload(payload, 7), false,
    'missing/challenged prompt is unknown, not an authoritative zero count');
}
assert.equal(messageContracts.isExpectedFourD4yMessagePromptPayload(
  counter('<a id="myprompt">notice</a>', 7), 7), true,
  'a recognized empty prompt still clears previously read reminders');
assert.equal(messageContracts.isExpectedFourD4yMessagePromptPayload(counter(
  '<a id="myprompt">notice</a><a id="prompt_pm">New Message (1)</a>' +
  '<script src="/cdn-cgi/challenge-platform/scripts/jsd/main.js"></script>', 7), 7), true,
  'background JS detection on a real forum page is not an interactive challenge');
assert.equal(counter('<a id="myprompt">notice</a><div class="promptcontent">' +
  '<a id="prompt_friend">Friend</a><a id="prompt_threads">Notice (3)</a></div>', 1).friendNoticeCount, 0,
  'a counter cannot consume a neighboring reminder count');
assert.equal(counter('<a id="myprompt">notice</a><a id="prompt_pm">New Message</a>' +
  '<div>New Message (99)</div>', 1).privateMessageCount, 0);
assert.equal(counter('<a id="myprompt">notice</a><a data-id="prompt_pm">New Message (99)</a>', 1)
  .privateMessageCount, 0, 'data-id is not id');
assert.equal(counter('<a id="myprompt">notice</a><a id="prompt_pm">New Message (<b>2</b>)</a>', 1)
  .privateMessageCount, 2, 'visible counter text can contain formatting');
for (const body of ['<b>bold</b>', '<span class="new">new</span>', 'notice_newpm.gif',
  '<img src="images/default/notice_newpm.gif">']) {
  for (const unread of [true, false]) {
    const payload = messageParser.parseFourD4yNativeMessagePage(
      '<ul class="pm_list"><li id="pm_100"><p class="cite"><cite>' +
      '<a href="space.php?uid=2">sender</a></cite> 今天 11:30 ' +
      (unread ? '<img src="images/default/notice_newpm.gif">' : '') +
      '</p><div class="summary">' + body + '</div></li></ul>',
      'https://www.4d4y.com/forum/pm.php?filter=privatepm&page=1', 1);
    assert.equal(payload.items[0].isUnread, unread, 'PM list must inspect its header, not message body');
    assert.equal(payload.items[0].occurredAt, '今天 11:30', 'NG uses p.cite own text for relative dates');
  }
}
console.log('PASS: isolated prompt counters and PM list header metadata.');

const unreadHeader = '<div id="umenu"><cite><a href="space.php?uid=1">viewer</a></cite></div>' +
  '<div class="pm_header colplural itemtitle s_clear"><ul><li class="current">' +
  '<a href="pm.php?filter=newpm">未读消息</a></li></ul></div>';
const unreadRow = '<ul class="pm_list"><li id="pm_12" class="s_clear">' +
  '<p class="cite"><cite><a href="space.php?uid=2">sender</a></cite>今天 10:00 ' +
  '<img src="images/default/notice_newpm.gif"></p><div class="summary">synthetic</div>' +
  '<p class="more"><a href="pm.php?uid=2&filter=newpm&daterange=1">查看</a></p></li></ul>';
assert.equal(messageParser.parseFourD4yUnreadPrivateMessageCount(unreadHeader + unreadRow), 1);
assert.equal(messageParser.parseFourD4yUnreadPrivateMessageCount(unreadHeader + '<p class="nodata">暂无数据</p>'), 0);
for (const html of [unreadHeader, unreadRow, unreadHeader.replace('filter=newpm', 'filter=privatepm') + unreadRow,
  unreadHeader + unreadRow.replace('notice_newpm.gif', 'notice_pm.gif'),
  unreadHeader + '<ul class="pm_list"><li id="pm_12">malformed row</li></ul>',
  unreadHeader + '<ul class="pm_list"></ul>']) {
  assert.equal(messageParser.parseFourD4yUnreadPrivateMessageCount(html), null,
    'unrecognized, wrong-filter, read or malformed rows cannot manufacture a confirmed zero');
}
console.log('PASS: NG unread-list count requires current filter, viewer and complete rows or explicit empty state.');

const pageSource = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/notice/PrivateMessageDetailPage.ets'), 'utf8');
assert.match(pageSource, /this\.messageRowVersions\.key\(message\)/,
  'plain DTO read-state changes must invalidate the affected row, not preserve the old ForEach view');
assert.match(pageSource, /this\.messages = this\.messageRowVersions\.track\(payload\.messages\)/);
const begin = pageSource.indexOf('  private scheduleReadConfirmationIfNeeded(');
const end = pageSource.indexOf('  private clearReadConfirmation()', begin);
const failStart = pageSource.indexOf('  private failLoad(');
const exported = {}, callbacks = [];
vm.runInNewContext(ts.transpileModule('class Page {' + pageSource.slice(begin, end) +
  pageSource.slice(failStart, pageSource.lastIndexOf('\n}')) + '} exports.Page = Page;',
  { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText,
  { exports: exported, setTimeout: callback => { callbacks.push(callback); return callbacks.length; } });
for (const scenario of ['normal', 'leave', 'different-user', 'busy', 'account-switch']) {
  let reads = 0;
  let generation = 1;
  const page = new exported.Page();
  Object.assign(page, { hasScheduledReadConfirmation: false, isPrivateMessageRouteReady: true,
    routeSessionGeneration: 1, accountState: { getSessionGeneration: () => generation },
    route: { participantUserId: '2' }, clearReadConfirmation: () => {}, isRequestPending: () => false,
    loadConversation: keep => { assert.equal(keep, true); reads++; } });
  page.scheduleReadConfirmationIfNeeded({ messages: [{ isUnread: true }] }, '2');
  page.scheduleReadConfirmationIfNeeded({ messages: [{ isUnread: true }] }, '2');
  assert.equal(callbacks.length, 1, 'only one confirmation read, never an infinite poll');
  if (scenario === 'leave') page.isPrivateMessageRouteReady = false;
  if (scenario === 'different-user') page.route.participantUserId = '3';
  if (scenario === 'busy') page.isRequestPending = () => true;
  if (scenario === 'account-switch') generation = 2;
  callbacks.shift()();
  assert.equal(reads, scenario === 'normal' ? 1 : 0);
}
const page = new exported.Page();
const messages = [{ messageId: 'pm:1' }];
Object.assign(page, { loadSequence: 1, preservesVisibleContent: true, isRefreshing: true,
  isPrivateMessageRouteReady: true, routeSessionGeneration: 1, accountState: { getSessionGeneration: () => 1 },
  messages, clearLoadWatchdog: () => {} });
page.failLoad(1, 'synthetic refresh failure');
assert.equal(page.messages, messages, 'background failure preserves the visible message objects');
assert.equal(page.statusMessage, 'synthetic refresh failure', 'background failure remains diagnosable');
assert.equal(page.isRefreshing, false);
console.log('PASS: bounded read confirmation, exit/route guards, row invalidation and non-destructive failure.');

// A native failure from the old session must not log out or clear the new one.
const loadStart = pageSource.indexOf('  private async loadConversation(');
const loadEnd = pageSource.indexOf('  private startLoadWatchdog(', loadStart);
const loadExports = {};
vm.runInNewContext(ts.transpileModule('class Loader {' + pageSource.slice(loadStart, loadEnd) +
  '} exports.Loader = Loader;', { compilerOptions: { target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS } }).outputText, {
  exports: loadExports, buildFourD4yPrivateConversationUrl: () => 'https://www.4d4y.com/forum/pm.php?uid=2'
});
(async () => {
  for (const scenario of ['late-login-failure', 'late-error', 'already-stale']) {
    let generation = 1, requests = 0, resolve, reject, failures = 0;
    const deferred = new Promise((res, rej) => { resolve = res; reject = rej; });
    const instance = Object.assign(new loadExports.Loader(), {
      isPrivateMessageRouteReady: true, routeSessionGeneration: 1,
      accountState: { getSessionGeneration: () => generation }, route: { participantUserId: '2' },
      loadSequence: 0, terminalLoadSequence: 0, messages: [{ messageId: 'old' }], isLoggedIn: true,
      startLoadWatchdog: () => {}, isRequestPending: () => true,
      nativeClient: { loadPrivateConversation: () => { requests++; return deferred; } },
      failLoad: () => { failures++; }
    });
    if (scenario === 'already-stale') generation = 2;
    const pending = instance.loadConversation();
    generation = 2;
    if (scenario === 'late-error') reject(new Error('synthetic')); else resolve({ status: 'server-login-required' });
    await pending;
    assert.equal(instance.isLoggedIn, true);
    assert.equal(instance.messages.length, 1);
    assert.equal(failures, 0);
    assert.equal(requests, scenario === 'already-stale' ? 0 : 1);
  }
  console.log('PASS: PM native reads reject old-session results and errors.');
})().catch(error => { console.error(error); process.exitCode = 1; });
