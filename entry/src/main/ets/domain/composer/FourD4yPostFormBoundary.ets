export function isCurrentFourD4yPostPreflightUrl(url: string, action: string, threadId: string,
  postId: string, marker: string, sequence: number, forumId: string = ''): boolean {
  if (!/^https:\/\/www\.4d4y\.com\/forum\/post\.php\?[^#\s]+$/.test(url) ||
    !Number.isSafeInteger(sequence) || sequence < 1) return false;
  const params: string[] = url.substring(url.indexOf('?') + 1).split('&');
  const matches = (key: string, value: string): boolean => {
    const values: string[] = params.filter((part: string): boolean => part.split('=')[0] === key);
    return values.length === 1 && values[0] === key + '=' + value;
  };
  return matches('action', action) && matches(marker, String(sequence)) &&
    (action === 'newthread' ? /^\d+$/.test(forumId) && matches('fid', forumId) :
      /^\d+$/.test(threadId) && matches('tid', threadId)) &&
    (action !== 'edit' || /^\d+$/.test(postId) && matches('pid', postId));
}

/** Final write boundary shared by quick reply, advanced reply and edit. */
export function buildFourD4yPostFormBoundaryScript(action: string, threadId: string, postId: string,
  marker: string, sequence: number): string {
  return `
    const expectedPostAction = ${JSON.stringify(action)};
    const expectedPostThread = ${JSON.stringify(threadId)};
    const expectedPostId = ${JSON.stringify(postId)};
    const postEndpoint = (url) => url.origin === 'https://www.4d4y.com' && url.pathname === '/forum/post.php';
    const singlePostParam = (url, key, value) => url.searchParams.getAll(key).length === 1 &&
      url.searchParams.get(key) === value;
    const postDocument = new URL(location.href);
    if (!postEndpoint(postDocument) || window.__hipdaPostSubmitted ||
      !singlePostParam(postDocument, 'action', expectedPostAction) ||
      !singlePostParam(postDocument, 'tid', expectedPostThread) ||
      !singlePostParam(postDocument, ${JSON.stringify(marker)}, ${JSON.stringify(String(sequence))}) ||
      (expectedPostAction === 'edit' && !singlePostParam(postDocument, 'pid', expectedPostId))) {
      throw new Error('post-document-not-current');
    }
    const postFormMatches = (candidate) => {
      try {
        const target = new URL(candidate.getAttribute('action') || location.href, location.href);
        if (!postEndpoint(target) || !singlePostParam(target, 'action', expectedPostAction) ||
          (candidate.method || '').toLowerCase() !== 'post') return false;
        const matchesIdentity = (key, value) => {
          const inUrl = target.searchParams.getAll(key);
          const inBody = Array.from(candidate.querySelectorAll('input[name]')).filter(
            node => node.getAttribute('name') === key).map(node => node.value);
          return inUrl.length <= 1 && inUrl.concat(inBody).length > 0 &&
            inUrl.concat(inBody).every(entry => entry === value);
        };
        return matchesIdentity('tid', expectedPostThread) &&
          (expectedPostAction !== 'edit' || matchesIdentity('pid', expectedPostId));
      } catch (_) { return false; }
    };
    const form = Array.from(document.forms || []).find(postFormMatches);
    const message = form ? form.querySelector('textarea[name=message]') : null;
    const postToken = form ? form.querySelector('input[name=formhash]') : null;
    if (!form || !message || !postToken || !postToken.value) throw new Error('post-form-not-ready');
    const actionUrl = new URL(form.getAttribute('action') || location.href, location.href);
  `;
}
