/**
 * The prompt's wire format -- fixed by modules/prompt-nui/client.lua, not by us.
 *
 * ⚠️ Every field here is written by Lua and read by this feature. Renaming one means editing
 *    the module too, and the module is shared with four resources (w_crafting, w_hud,
 *    w_legal, w_wheel) -- so the names stay exactly as the Lua sends them.
 */

/** One entry in a price: money, gold, or an item stack. */
export interface PricePart {
  money?: number;
  gold?: number;
  item?: string;
  label?: string;
  image?: string;
  quantity?: number;
  quantityStyle?: string;
  tooltip?: boolean;
}

export type Price = number | PricePart | PricePart[] | false | undefined;

/** A row. `type: 'separator'` draws a rule instead of a key and a label. */
export interface PromptRow {
  type?: 'separator' | string;
  visible?: boolean;
  disabled?: boolean;
  label?: string;
  holdTime?: number | false;
  keyboardKeys?: string[];
  price?: Price;
  page?: number;
  position?: number;
}

export type PromptPosition =
  | 'bottom-right'
  | 'center-right'
  | 'top-right'
  | 'bottom-left'
  | 'center-left'
  | 'top-left';

/** The whole group, as `setGroup` delivers it. */
export interface PromptGroupState {
  /** false = draw no title at all, which is a different thing from an empty one. */
  title?: string | false;
  position: PromptPosition;
  /** Pages of rows: prompts[page][row]. Lua counts pages from 1, this from 0. */
  prompts: PromptRow[][];
  nextPageKey: string;
  currentPageIndex: number;
  forcedHide: boolean;
  /** Which keys are held right now, by key name. */
  pressedKeys: Record<string, boolean>;
}

/* ── the messages Lua sends ─────────────────────────────────────────────── */

export interface SetGroupData {
  title?: string | false;
  position?: PromptPosition;
  prompts?: PromptRow[][];
  nextPageKey?: string;
  /** 1-indexed, as Lua counts. */
  currentPage?: number;
}

export interface UpdatePromptData {
  /** Both 1-indexed, as Lua counts. */
  page: number;
  position: number;
  property: string;
  value: unknown;
}

export interface UpdateGroupData {
  property: string;
  value: unknown;
}

export interface KeyData {
  key: string;
}

export interface ForceHideData {
  value: boolean;
}
