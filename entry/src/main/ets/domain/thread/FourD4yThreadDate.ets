/**
 * Formats the original topic creation date for the compact forum list.
 * Comparisons use local calendar days, not an elapsed 24-hour window, so a
 * topic posted before midnight is correctly labelled as yesterday.
 */
export function formatFourD4yThreadCreatedDate(rawValue: string, nowMillis: number = Date.now()): string {
  const raw: string = rawValue.trim();
  if (raw.indexOf('今天') >= 0) {
    return '今天';
  }
  if (raw.indexOf('昨天') >= 0) {
    return '昨天';
  }

  const match: RegExpExecArray | null = /(\d{4})-(\d{1,2})-(\d{1,2})/.exec(raw);
  if (match === null) {
    return '';
  }
  const year: number = Number.parseInt(match[1], 10);
  const month: number = Number.parseInt(match[2], 10);
  const day: number = Number.parseInt(match[3], 10);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return '';
  }

  const created: Date = new Date(year, month - 1, day);
  if (created.getFullYear() !== year || created.getMonth() !== month - 1 || created.getDate() !== day) {
    return '';
  }
  const now: Date = new Date(nowMillis);
  if (isSameLocalCalendarDay(created, now)) {
    return '今天';
  }
  const yesterday: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
  if (isSameLocalCalendarDay(created, yesterday)) {
    return '昨天';
  }
  return year.toString() + '-' + padTwoDigits(month) + '-' + padTwoDigits(day);
}

/** Matches NG: only six-digit counts are shortened, to one decimal wan. */
export function formatFourD4yThreadCount(value: number): string {
  const count: number = Number.isFinite(value) ? Math.max(0, Math.floor(value)) : 0;
  if (count <= 99999) {
    return count.toString();
  }
  const wan: number = Math.round(count / 1000) / 10;
  return wan.toString() + '万';
}

function isSameLocalCalendarDay(left: Date, right: Date): boolean {
  return left.getFullYear() === right.getFullYear() && left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate();
}

function padTwoDigits(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}
