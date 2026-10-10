/** Match NG's self-menu boundary, never a post author's profile link. */
export function buildFourD4yAccountIdentityScript(): string {
  return `(() => {
    if (location.origin !== 'https://www.4d4y.com' || !location.pathname.startsWith('/forum/')) return '';
    const link = document.querySelector('#umenu cite a[href*="space.php"]');
    if (!link) return '';
    const url = new URL(link.getAttribute('href') || '', location.href);
    const uid = url.searchParams.get('uid') || '';
    const name = (link.textContent || '').trim();
    if (url.origin !== location.origin || url.pathname !== '/forum/space.php' || !/^\\d{1,16}$/.test(uid) || !name) return '';
    return JSON.stringify({ userId: uid, displayName: name });
  })()`;
}
