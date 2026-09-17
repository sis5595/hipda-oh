import { FourD4yMyContentMode } from '../../domain/mine/FourD4yMyContentContracts';

/** The drawer can open either server-owned personal list without an extra tap. */
export interface MyContentRouteParams {
  mode: FourD4yMyContentMode;
}

export function createMyContentRouteParams(
  mode: FourD4yMyContentMode = FourD4yMyContentMode.Threads): MyContentRouteParams {
  return { mode: mode };
}

export function readMyContentRouteMode(route: MyContentRouteParams | null | undefined): FourD4yMyContentMode {
  return route !== undefined && route !== null && route.mode === FourD4yMyContentMode.Replies ?
    FourD4yMyContentMode.Replies : FourD4yMyContentMode.Threads;
}
