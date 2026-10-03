import { encodeFourD4yPostField } from './FourD4yPostEncoding';

export const FOUR_D4Y_TOPIC_SUBMIT_ATTRIBUTE: string = 'data-hipda-oh-topic-submit';

export interface FourD4yNewThreadDraft {
  forumId: string;
  categoryValue: string;
  subject: string;
  message: string;
  tags: string;
  imageIds: string[];
  discardedImageIds: string[];
  submissionSequence: number;
}

/**
 * NG protocol principle: one encoded POST, explicit attachments, and the final
 * redirected tid as success evidence. Cookie and formhash never leave ArkWeb.
 * A result is bounded metadata; the response HTML is neither logged nor stored.
 */
export function buildFourD4yNewThreadSubmissionScript(draft: FourD4yNewThreadDraft): string {
  if (!/^\d+$/.test(draft.forumId) || !Number.isSafeInteger(draft.submissionSequence) ||
    draft.submissionSequence < 1) {
    throw new Error('invalid-topic-target');
  }
  const category: string = /^\d+$/.test(draft.categoryValue) ? draft.categoryValue : '0';
  return [
    '(() => {',
    'const attr = ' + JSON.stringify(FOUR_D4Y_TOPIC_SUBMIT_ATTRIBUTE) + ';',
    'const sequence = ' + draft.submissionSequence + ';',
    'const root = document.documentElement;',
    'const existing = root.getAttribute(attr);',
    'if (existing) { const status = JSON.parse(existing); if (status.submissionSequence === sequence) return "already-started"; }',
    'const fid = ' + JSON.stringify(draft.forumId) + ';',
    'if (location.origin !== "https://www.4d4y.com") throw new Error("unexpected-topic-origin");',
    'const form = Array.from(document.forms).find(f => { const u = new URL(f.action, location.href); return u.origin === location.origin && u.pathname === "/forum/post.php" && u.searchParams.get("action") === "newthread" && u.searchParams.get("fid") === fid && f.querySelector("textarea[name=message]"); });',
    'const hash = form && form.querySelector("input[name=formhash]");',
    'if (!form || form.method.toLowerCase() !== "post" || !hash || !/^[a-f0-9]{8}$/i.test(hash.value) || !form.querySelector("input[name=subject]")) throw new Error("topic-contract-changed");',
    'if (!/^(gbk|gb2312|gb18030)$/i.test(document.characterSet)) throw new Error("topic-charset-changed");',
    'const url = new URL("post.php", location.href);',
    'url.searchParams.set("action", "newthread"); url.searchParams.set("fid", fid);',
    'url.searchParams.set("typeid", ' + JSON.stringify(category) + '); url.searchParams.set("topicsubmit", "yes");',
    'const fields = ["formhash=" + encodeURIComponent(hash.value), "posttime=" + Date.now(), "wysiwyg=0", "usesig=1", "attention_add=1",',
    '"subject=" + ' + JSON.stringify(encodeFourD4yPostField(draft.subject)) + ', "message=" + ' + JSON.stringify(encodeFourD4yPostField(draft.message)) + '];',
    'if (form.querySelector("input[name=tags]")) fields.push("tags=" + ' + JSON.stringify(encodeFourD4yPostField(draft.tags)) + ');',
    JSON.stringify(draft.imageIds) + '.filter(id => /^\\d+$/.test(id)).forEach(id => fields.push("attachnew%5B%5D%5Bdescription%5D=" + id));',
    JSON.stringify(draft.discardedImageIds) + '.filter(id => /^\\d+$/.test(id)).forEach(id => fields.push("attachdel%5B%5D=" + id));',
    'const publish = (phase, payload) => root.setAttribute(attr, JSON.stringify({submissionSequence: sequence, phase, payload}));',
    'publish("pending", null);',
    'fetch(url.toString(), { method: "POST", mode: "same-origin", credentials: "same-origin", cache: "no-store", referrerPolicy: "same-origin", headers: {"Content-Type": "application/x-www-form-urlencoded"}, body: fields.join("&") }).then(async response => {',
    'const final = new URL(response.url);',
    'if (final.origin !== location.origin || !response.ok) { publish("uncertain", null); return; }',
    'const tid = final.searchParams.get("tid") || "";',
    'const succeeded = (final.pathname === "/forum/viewthread.php" || final.pathname === "/forum/redirect.php") && /^\\d+$/.test(tid);',
    'const doc = new DOMParser().parseFromString(new TextDecoder("gbk").decode(await response.arrayBuffer()), "text/html");',
    'const loginRequired = !!doc.querySelector("input[name=username], input[name=password]");',
    'const alert = doc.querySelector(".alert_info, .alert_error, #messagetext");',
    'const errorMessage = alert ? (alert.textContent || "").trim().replace(/\\s*\\[\\s*点击这里返回上一页\\s*\\]\\s*$/, "").slice(0, 240) : "";',
    'if (!succeeded && !loginRequired && !errorMessage) { publish("uncertain", null); return; }',
    'publish("result", {mode: "newThread", threadId: "", submissionSequence: sequence, succeeded: succeeded && !loginRequired, createdThreadId: succeeded && !loginRequired ? tid : "", loginRequired, errorMessage});',
    '}).catch(() => publish("uncertain", null));',
    'return "started";',
    '})()'
  ].join('\n');
}

export function buildFourD4yNewThreadResultReadScript(sequence: number): string {
  return '(() => { const raw = document.documentElement.getAttribute(' +
    JSON.stringify(FOUR_D4Y_TOPIC_SUBMIT_ATTRIBUTE) +
    '); if (!raw) return "pending"; const s = JSON.parse(raw); if (s.submissionSequence !== ' + sequence +
    ') return "pending"; return s.phase === "result" ? JSON.stringify(s.payload) : s.phase; })()';
}
