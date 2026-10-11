/** Discuz's public middle-size avatar path, also used by HiPDA NG. No session or profile fetch. */
export function buildFourD4yAvatarUrl(userId: string | undefined): string {
  if (userId === undefined || !/^[0-9]{1,9}$/.test(userId) || Number(userId) === 0) {
    return '';
  }
  const padded: string = ('000000000' + userId).slice(-9);
  return 'https://img02.4d4y.com/forum/uc_server/data/avatar/' + padded.slice(0, 3) + '/' +
    padded.slice(3, 5) + '/' + padded.slice(5, 7) + '/' + padded.slice(7) + '_avatar_middle.jpg';
}
