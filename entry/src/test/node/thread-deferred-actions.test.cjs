const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/presentation/thread/ThreadDetailPage.ets'), 'utf8');
function extract(start, end) {
  const from = source.indexOf(start), to = source.indexOf(end, from);
  assert.ok(from >= 0 && to > from);
  return source.slice(from, to);
}
const callbacks = [], exported = {};
const code = 'class Reader {' +
  extract('  private requestPostDeletionConfirmation()', '  /**\n   * The form still belongs') +
  extract('  private restoreThreadRefreshPosition()', '  private failThreadLoad(') +
  extract('  private async beginPostDeletionSubmission()', '  private async readPostDeletionVerificationFromWeb()') +
  extract('  private getPostDeletionPreflightExtractionScript(', '  private onVoteControllerAttached()') +
  '} exports.Reader = Reader;';
vm.runInNewContext(ts.transpileModule(code, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
}}).outputText, { exports: exported, $r: value => value, setTimeout: fn => callbacks.push(fn),
  clearTimeout: () => {}, parseFourD4yPostDeletionSubmissionStartPayload: JSON.parse,
  isExpectedFourD4yPostDeletionSubmissionStart: (payload, tid, pid, sequence) =>
    payload.threadId === tid && payload.postId === pid && payload.submissionSequence === sequence });
(async () => {
  for (const scenario of ['normal', 'leave', 'new-form', 'different-post']) {
    let resolve, posts = 0;
    const reader = new exported.Reader();
    Object.assign(reader, { isThreadPageAlive: true, postDeletionFormReady: true,
      postDeletionConfirmationPending: false, isPostDeletionSubmitting: false,
      postDeletionPreflightPostId: '12345', postDeletionPreflightSequence: 1,
      getUIContext: () => ({ getPromptAction: () => ({
        showDialog: () => new Promise(done => { resolve = done; }) }) }),
      beginPostDeletionSubmission: () => { posts++; } });
    reader.requestPostDeletionConfirmation();
    if (scenario === 'leave') reader.isThreadPageAlive = false;
    if (scenario === 'new-form') reader.postDeletionPreflightSequence++;
    if (scenario === 'different-post') reader.postDeletionPreflightPostId = '999';
    resolve({ index: 1 }); await Promise.resolve(); await Promise.resolve();
    assert.equal(posts, scenario === 'normal' ? 1 : 0,
      'a delayed delete confirmation must remain bound to its original page/form/post');
  }
  for (const scenario of ['normal', 'leave', 'reload']) {
    let scrolls = 0;
    const reader = new exported.Reader();
    Object.assign(reader, { isThreadPageAlive: true, webLoadSequence: 1,
      pendingRefreshScrollOffset: 120,
      postListScroller: { scrollTo: () => scrolls++ } });
    reader.restoreThreadRefreshPosition();
    if (scenario === 'leave') reader.isThreadPageAlive = false;
    if (scenario === 'reload') reader.webLoadSequence++;
    callbacks.shift()();
    assert.equal(scrolls, scenario === 'normal' ? 1 : 0);
  }
  console.log('Thread deferred deletion confirmation and refresh-position regression passed.');
  for (const navigationThrows of [false, true]) {
    let reads = 0, writes = 0;
    const reader = new exported.Reader();
    Object.assign(reader, { isThreadPageAlive: true, route: { threadId: '123' },
      postDeletionPreflightPostId: '456', posts: [{ id: '456', floor: 1 }],
      postDeletionFormReady: true, isPostDeletionSubmitting: false,
      postDeletionSubmissionSequence: 0, postDeletionVerificationPollTimeoutId: -1,
      isPostDeletionWebControllerAttached: true, startPostDeletionSubmissionWatchdog: () => {},
      failPostDeletionSubmission: message => assert.fail(message),
      readPostDeletionVerificationFromWeb: async () => reads++,
      postDeletionWebController: {
        loadUrl: () => assert.fail('verification must not interrupt the POST/redirect'),
        runJavaScript: async () => {
          writes++;
          if (navigationThrows) throw new Error('navigation started');
          return JSON.stringify({ threadId: '123', postId: '456', submissionSequence: 1, started: true });
        }
      }
    });
    await reader.beginPostDeletionSubmission();
    assert.equal(writes, 1);
    assert.equal(reads, 0, 'wait for the result page rather than inspecting an in-flight POST');
    assert.equal(callbacks.length, 0, 'no timed navigation after starting deletion');
    reader.onPostDeletionResultPageEnd();
    assert.equal(reads, 1);
    reader.schedulePostDeletionVerification(1, 1000);
    callbacks.shift()();
    assert.equal(reads, 2);
    assert.equal(writes, 1);
    reader.isThreadPageAlive = false;
    reader.onPostDeletionResultPageEnd();
    assert.equal(reads, 2);
  }
  const reader = new exported.Reader(); reader.route = { forumId: '51' };
  function verify(href, challenge = false, readable = true) {
    const document = { title: 'test', querySelector: selector => {
      if (selector.includes('cf-turnstile')) return challenge ? {} : null;
      if (selector === '[id^=postmessage_]') return readable ? {} : null;
      return null;
    }, getElementById: () => null };
    return JSON.parse(vm.runInNewContext(reader.getPostDeletionVerificationScript('123', '456', 7), {
      URL, location: { href }, document
    }));
  }
  const target = 'https://www.4d4y.com/forum/viewthread.php?tid=123';
  assert.equal(verify(target).isTargetThreadPage, true);
  assert.equal(verify(target, false, false).isTargetThreadPage, false,
    'an error page with the original URL cannot confirm successful removal');
  assert.equal(verify(target, true).hasChallenge, true);
  assert.equal(verify('https://evil.example/forum/viewthread.php?tid=123').isTargetThreadPage, false);
  assert.equal(verify('https://www.4d4y.com/forum/forumdisplay.php?fid=2').isForumPage, false);
  assert.equal(verify('https://www.4d4y.com/forum/forumdisplay.php?fid=51').isForumPage, true);

  const mutationSource = fs.readFileSync(path.resolve(__dirname,
    '../../main/ets/domain/thread/FourD4yThreadMutationState.ets'), 'utf8');
  const homeSource = fs.readFileSync(path.resolve(__dirname,
    '../../main/ets/presentation/home/HomePage.ets'), 'utf8');
  const homeStart = homeSource.indexOf('  private onConfirmedThreadDeletion(');
  const homeEnd = homeSource.indexOf('  private loadThreads(', homeStart);
  const accountStart = homeSource.indexOf('  private refreshAfterAccountManagement(');
  const accountEnd = homeSource.indexOf('  private openAppearanceSheet(', accountStart);
  assert.ok(homeStart >= 0 && homeEnd > homeStart);
  vm.runInNewContext(ts.transpileModule(mutationSource + '\nclass Home {' +
    homeSource.slice(homeStart, homeEnd) + homeSource.slice(accountStart, accountEnd) +
    '\n} exports.Home = Home;', { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  }}).outputText, { exports: exported });
  const mutations = new exported.FourD4yThreadMutationState();
  const home = new exported.Home(); let refreshes = 0;
  Object.assign(home, { isHomeAlive: true, forums: [{ id: '51' }], selectedForumIndex: 0,
    threads: [{ id: '123' }, { id: '789' }], threadRowVersions: { track: items => items },
    accountState: { getSessionGeneration: () => 2 },
    loadForumPage: (page, append) => { assert.equal(page, 1); assert.equal(append, false); refreshes++; } });
  const subscription = mutations.subscribeDeletion(event => home.onConfirmedThreadDeletion(event));
  mutations.notifyDeleted('123', '51', 1); // stale account
  mutations.notifyDeleted('123', '2', 2); // another board
  mutations.notifyDeleted('invalid', '51', 2);
  assert.equal(refreshes, 0);
  mutations.notifyDeleted('123', '51', 2);
  assert.equal(refreshes, 1);
  assert.deepEqual(home.threads, [{ id: '789' }]);
  home.isHomeAlive = false;
  mutations.notifyDeleted('789', '51', 2);
  assert.equal(refreshes, 1);
  mutations.unsubscribeDeletion(subscription);
  home.isHomeAlive = true;
  mutations.notifyDeleted('789', '51', 2);
  assert.equal(refreshes, 1);
  let identityRefreshes = 0, promptRefreshes = 0, mirrorGeneration = 0;
  Object.assign(home, { unreadPromptSequence: 7, isUnreadPromptLoading: true,
    observedReplyCounts: { syncSession: value => { mirrorGeneration = value; } },
    restoreDrawerAccount: async () => identityRefreshes++,
    refreshLoginState: async () => promptRefreshes++ });
  home.refreshAfterAccountManagement(1);
  assert.equal(refreshes, 2);
  assert.equal(home.threads.length, 0);
  assert.equal(home.unreadPromptSequence, 8);
  assert.equal(home.isUnreadPromptLoading, false);
  assert.equal(mirrorGeneration, 2);
  assert.equal(identityRefreshes, 1);
  assert.equal(promptRefreshes, 1);
  home.refreshAfterAccountManagement(2);
  assert.equal(refreshes, 2, 'unchanged account does not reload the board');
  assert.equal(promptRefreshes, 2);
  home.isHomeAlive = false;
  home.refreshAfterAccountManagement(1);
  assert.equal(promptRefreshes, 2);
})().catch(error => { console.error(error); process.exitCode = 1; });
