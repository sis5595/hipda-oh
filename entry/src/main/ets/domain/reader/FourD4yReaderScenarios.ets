import { FourD4yReaderOutcome } from './FourD4yReaderContracts';

export enum FourD4yReaderScenarioStatus {
  Verified = 'verified',
  PendingCapture = 'pendingCapture'
}

export interface FourD4yReaderScenario {
  id: string;
  surface: 'forum' | 'thread';
  status: FourD4yReaderScenarioStatus;
  expectedOutcome: FourD4yReaderOutcome;
  description: string;
}

/**
 * A deliberately small, 4D4Y-specific regression inventory. Entries are
 * added only after a live page or a user-reported behavior establishes the
 * scenario; this is not a list of assumptions copied from another forum.
 */
export const FOUR_D4Y_READER_SCENARIOS: FourD4yReaderScenario[] = [
  {
    id: 'forum-logged-in-mobile-list', surface: 'forum',
    status: FourD4yReaderScenarioStatus.Verified,
    expectedOutcome: FourD4yReaderOutcome.Content,
    description: '登录态移动列表；已在 Mate 60 的 Discovery 板块采样。'
  },
  {
    id: 'forum-login-required', surface: 'forum',
    status: FourD4yReaderScenarioStatus.Verified,
    expectedOutcome: FourD4yReaderOutcome.LoginRequired,
    description: '游客访问受限板块时显示登录表单，页面可同时带 Cloudflare 脚本。'
  },
  {
    id: 'forum-pinned-row', surface: 'forum',
    status: FourD4yReaderScenarioStatus.Verified,
    expectedOutcome: FourD4yReaderOutcome.Content,
    description: '已在 Mate 60 的登录态 Discovery 移动列表采样：置顶标题同时带 bold 和 #EE1B2E 样式。'
  },
  {
    id: 'forum-verification-only', surface: 'forum',
    status: FourD4yReaderScenarioStatus.PendingCapture,
    expectedOutcome: FourD4yReaderOutcome.VerificationRequired,
    description: '仅安全验证、无登录表单的页面。'
  },
  {
    id: 'thread-no-reply', surface: 'thread',
    status: FourD4yReaderScenarioStatus.Verified,
    expectedOutcome: FourD4yReaderOutcome.Content,
    description: '仅楼主的一层主题；已在 Mate 60 的 Buy & Sell 板块采样。'
  },
  {
    id: 'thread-multi-page', surface: 'thread',
    status: FourD4yReaderScenarioStatus.Verified,
    expectedOutcome: FourD4yReaderOutcome.Content,
    description: '50 楼分页和末页跳转；已用多页主题验证。'
  },
  {
    id: 'thread-postmessage-fallback', surface: 'thread',
    status: FourD4yReaderScenarioStatus.Verified,
    expectedOutcome: FourD4yReaderOutcome.Content,
    description: '2026-09-01 Mate 60 只读抽查：有效多页主题仅暴露 postmessage_ 楼层正文根，仍须解析为内容。'
  },
  {
    id: 'thread-blocked-post', surface: 'thread',
    status: FourD4yReaderScenarioStatus.Verified,
    expectedOutcome: FourD4yReaderOutcome.Content,
    description: '被屏蔽楼层的 legacy 页面含 .locked；已用实际 4D4Y 页面采样。'
  },
  {
    id: 'thread-quote-floor-link', surface: 'thread',
    status: FourD4yReaderScenarioStatus.Verified,
    expectedOutcome: FourD4yReaderOutcome.Content,
    description: '2026-09-04 Mate 60 多页主题采样：论坛明确显示 n# 的引用链接可跨页直达；无来源的纯文字引用保持静态。'
  },
  {
    id: 'thread-inline-image-and-attachment', surface: 'thread',
    status: FourD4yReaderScenarioStatus.Verified,
    expectedOutcome: FourD4yReaderOutcome.Content,
    description: '内嵌图片去除重复文件名，独立附件保留下载入口。'
  },
  {
    id: 'thread-open-public-multi-poll', surface: 'thread',
    status: FourD4yReaderScenarioStatus.Verified,
    expectedOutcome: FourD4yReaderOutcome.Content,
    description: '2026-08-29 user-provided NG sample: an unvoted public multiple-choice poll, up to five choices, with results visible after voting.'
  }
];

export function findFourD4yReaderScenario(id: string): FourD4yReaderScenario | null {
  for (let index: number = 0; index < FOUR_D4Y_READER_SCENARIOS.length; index += 1) {
    const scenario: FourD4yReaderScenario = FOUR_D4Y_READER_SCENARIOS[index];
    if (scenario.id === id) {
      return scenario;
    }
  }
  return null;
}

export function getPendingFourD4yReaderScenarios(): FourD4yReaderScenario[] {
  return FOUR_D4Y_READER_SCENARIOS.filter((scenario: FourD4yReaderScenario) =>
    scenario.status === FourD4yReaderScenarioStatus.PendingCapture);
}
