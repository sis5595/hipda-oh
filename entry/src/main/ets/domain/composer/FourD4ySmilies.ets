/**
 * Forum wire codes, not Unicode emoji. Images remain hosted by the forum.
 * Checked against /forum/forumdata/cache/smilies_var.js on 2026-10-14;
 * the display order follows NG. Never evaluate that remote script in the app.
 */
export interface FourD4ySmiley {
  code: string;
  label: string;
  imageUrl: string;
}

export interface FourD4ySmileyInsertion {
  text: string;
  caret: number;
}

const DEFAULT_CODES: string[] = [':)', ':sweat:', ':huffy:', ':cry:', ':titter:', ':handshake:',
  ':victory:', ':curse:', ':dizzy:', ':shutup:', ':funk:', ':loveliness:', ':(', ':D',
  ':cool:', ':mad:', ':o', ':P', ':lol:', ':shy:', ':sleepy:'];
const DEFAULT_FILES: string[] = ['smile', 'sweat', 'huffy', 'cry', 'titter', 'handshake',
  'victory', 'curse', 'dizzy', 'shutup', 'funk', 'loveliness', 'sad', 'biggrin',
  'cool', 'mad', 'shocked', 'tongue', 'lol', 'shy', 'sleepy'];
const DEFAULT_LABELS: string[] = ['微笑', '流汗', '生气', '哭泣', '偷笑', '握手', '胜利', '咒骂',
  '晕', '闭嘴', '惊恐', '可爱', '难过', '大笑', '酷', '愤怒', '惊讶', '吐舌', '笑', '害羞', '困'];

export function getFourD4ySmilies(group: number): FourD4ySmiley[] {
  const result: FourD4ySmiley[] = [];
  const count: number = group === 0 ? 21 : group === 1 ? 16 : group === 2 ? 24 : 0;
  for (let i: number = 0; i < count; i++) {
    const number: string = (i + 1).toString().padStart(2, '0');
    result.push({
      code: group === 0 ? DEFAULT_CODES[i] : '{:' + (group + 1) + '_' + (i + (group === 1 ? 41 : 57)) + ':}',
      label: group === 0 ? DEFAULT_LABELS[i] : (group === 1 ? '酷猴 ' : '呆呆男 ') + (i + 1),
      imageUrl: 'https://www.4d4y.com/forum/images/smilies/' +
        (group === 0 ? 'default/' + DEFAULT_FILES[i] : (group === 1 ? 'coolmonkey/' : 'grapeman/') + number) + '.gif'
    });
  }
  return result;
}

export function insertFourD4ySmiley(text: string, start: number, end: number,
  code: string): FourD4ySmileyInsertion {
  const valid: boolean = [0, 1, 2].some((group: number) =>
    getFourD4ySmilies(group).some((item: FourD4ySmiley) => item.code === code));
  const a: number = Number.isFinite(start) && start >= 0 ? Math.min(Math.floor(start), text.length) : text.length;
  const b: number = Number.isFinite(end) && end >= 0 ? Math.min(Math.floor(end), text.length) : a;
  const left: number = Math.min(a, b);
  const right: number = Math.max(a, b);
  return valid ? { text: text.slice(0, left) + code + text.slice(right), caret: left + code.length } :
    { text: text, caret: a };
}
