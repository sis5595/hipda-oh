import { ForumSummary } from '../model/ForumModels';

/** A presentation group for the native 4D4Y board picker. */
export interface FourD4yForumGroup {
  name: string;
  forums: ForumSummary[];
}

/**
 * Board endpoints verified against the current 4D4Y forum directory.
 *
 * This is deliberately only a board identity catalog. A logged-in ArkWeb
 * request remains the source of truth for each board's access, posting form,
 * and thread categories because those can change per account or forum rule.
 */
export const FOUR_D4Y_FORUM_GROUPS: FourD4yForumGroup[] = [
  {
    name: '交流与生活',
    forums: [
      { id: '51', name: 'La Femme' },
      { id: '2', name: 'Discovery' },
      { id: '64', name: '只讨论2.0' },
      { id: '70', name: '俄乌战争' },
      { id: '24', name: '意欲蔓延' },
      { id: '23', name: '随笔与个人文集' },
      { id: '25', name: '吃喝玩乐' }
    ]
  },
  {
    name: '数码与技术',
    forums: [
      { id: '7', name: 'Geek Talks' },
      { id: '62', name: 'Joggler' },
      { id: '9', name: 'Smartphone' },
      { id: '56', name: 'iPhone, iPod Touch，iPad' },
      { id: '60', name: 'Android' },
      { id: '12', name: 'PalmOS，Treo' },
      { id: '40', name: 'Palm芝麻宝典' },
      { id: '22', name: '麦客爱苹果' },
      { id: '14', name: 'Windows Mobile，PocketPC，HPC' },
      { id: '50', name: 'DC,NB,MP3,Gadgets...' }
    ]
  },
  {
    name: '交易',
    forums: [
      { id: '6', name: 'Buy & Sell' },
      { id: '63', name: '已完成交易' }
    ]
  }
];

/** Keep the original high-frequency boards one tap away on the home page. */
export const FOUR_D4Y_QUICK_FORUM_IDS: string[] = ['51', '2', '6', '7', '9', '60', '50'];

/** Returns one flat, independently owned board list for stateful UI use. */
export function getFourD4yForums(): ForumSummary[] {
  const forums: ForumSummary[] = [];
  FOUR_D4Y_FORUM_GROUPS.forEach((group: FourD4yForumGroup) => {
    group.forums.forEach((forum: ForumSummary) => {
      forums.push({ id: forum.id, name: forum.name, description: forum.description });
    });
  });
  return forums;
}
