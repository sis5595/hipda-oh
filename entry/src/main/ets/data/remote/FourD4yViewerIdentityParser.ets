/** Project the signed-in viewer, never the first author/recipient in the body. */
export function extractFourD4yViewerUserId(html: string): string {
  const withoutComments: string = html.replace(/<!--[\s\S]*?-->/g, '');
  const withoutScripts: string = withoutComments.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');
  const menuStart: RegExpExecArray | null =
    /<(div|span)\b[^>]*\sid\s*=\s*["']umenu["'][^>]*>/i.exec(withoutScripts);
  if (menuStart !== null) {
    // Balance only the container's own tag; a nested prompt span must not
    // truncate the self menu. Never continue looking outside that container.
    const tags: RegExp = new RegExp('<(/?)' + menuStart[1] + '\\b[^>]*>', 'gi');
    tags.lastIndex = menuStart.index + menuStart[0].length;
    const start: number = tags.lastIndex;
    let depth: number = 1;
    let tag: RegExpExecArray | null = tags.exec(withoutScripts);
    while (tag !== null) {
      depth += tag[1] === '/' ? -1 : 1;
      if (depth === 0) {
        const menu: string = withoutScripts.slice(start, tag.index);
        const cite: RegExpMatchArray | null = menu.match(/<cite\b[^>]*>([\s\S]*?)<\/cite>/i);
        const anchors: RegExp = /<a\b[^>]*\shref\s*=\s*["']([^"']+)["'][^>]*>/gi;
        const scope: string = cite === null ? menu : cite[1];
        let anchor: RegExpExecArray | null = anchors.exec(scope);
        while (anchor !== null) {
          const href: string = anchor[1].replace(/&amp;/gi, '&');
          const uid: RegExpMatchArray | null = href.match(
            /^(?:https:\/\/www\.4d4y\.com\/forum\/|\/forum\/|\.\/)?space\.php\?uid=([1-9]\d{0,15})(?:[&#]|$)/i);
          if (uid !== null) {
            return uid[1];
          }
          anchor = anchors.exec(scope);
        }
        return '';
      }
      tag = tags.exec(withoutScripts);
    }
    return '';
  }
  // Some full-site result templates omit the visible menu but publish this
  // explicit viewer variable. Generic uid= links are never a fallback.
  const scripts: RegExp = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
  let script: RegExpExecArray | null = scripts.exec(withoutComments);
  while (script !== null) {
    const uid: RegExpMatchArray | null = script[1].match(/\bdiscuz_uid\s*=\s*["']?([1-9]\d{0,15})(?:["';\s]|$)/);
    if (uid !== null) {
      return uid[1];
    }
    script = scripts.exec(withoutComments);
  }
  return '';
}
