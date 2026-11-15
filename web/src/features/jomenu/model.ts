/* ════════════════════════════════════════════════════════════════════════════
 * w_lib · features/jomenu/model.ts -- the state of w.menu (jo.menu), one store per owner resource.
 *
 * ★ The wire format is jo_libs 2.8.1's, unchanged: modules/menu/client.lua sends the same messages
 *   ({ event, ... }) it sent to jo's own Vue page, through the host in modules/menu/g_client.lua,
 *   which wraps each one as { action: 'wmenu', data: { owner, msg } }. This file is that Vue page's
 *   stores ported to plain TypeScript; index.tsx draws it in the board kit.
 *
 * ★ Two resources may both own a menu called "main": every owner has its own store, and every post
 *   back carries the owner, so the host hands it to the right resource.
 *
 * Fixed on the way over (jo's built page did these wrong, see the port notes in the PR / CLAUDE.md):
 *   - the cursor is always a position in the VISIBLE list, also when Lua names an item (by its index)
 *     and when an earlier item is hidden;
 *   - the back history never holds "" or the menu itself, and a missing child does not grow it;
 *   - a switch's arrows and the mouse wheel move the slider they are on, not always the first one;
 *   - priceRight: true shows the item's price instead of breaking the row; an absent price is no price;
 *   - a whole-item update is normalised like any other item; previewPalette updates reach the row;
 *   - the grid keys do nothing on a disabled item and post only when the value changed.
 * ════════════════════════════════════════════════════════════════════════════ */

import { postNui } from '../../utils/postNui';
import { play, type Sfx } from '../../wc/sound';

/* eslint-disable @typescript-eslint/no-explicit-any */
export type Any = any;

export interface JoSlider {
  type: string;
  current: Any;
  values: Any[];
  title?: string;
  translate?: boolean;
  looped?: boolean;
  forceDisplay?: boolean;
  description?: string;
  palette?: string;
  tint?: string;
  min?: number;
  max?: number;
  disabledTints?: number[];
  labels?: string[];
  displayTick?: boolean;
  tickIndex?: number;
  [key: string]: Any;
}

export interface JoStat {
  label: string;
  type: string;
  class: string;
  value: Any;
  translateLabel: boolean;
  translateValue: boolean;
}

export interface JoItem {
  title: string;
  subtitle: string;
  footer: string;
  icon: string | false;
  iconRight: string | false;
  iconClass: string;
  iconSize: string;
  child: string | false;
  sliders: JoSlider[];
  price: Any;
  priceTitle: string | false;
  priceRight: Any;
  data: Any;
  index: number;
  visible: boolean;
  description: string;
  translate: boolean;
  translateDescription: boolean;
  prefix: string | false;
  statistics: JoStat[];
  disabled: boolean;
  grid: boolean;
  textRight: string | false;
  textRightClass: string;
  translateTextRight: boolean;
  previewSlider: boolean;
  quantity: Any;
  quantityCircleClass: string;
  quality: number | false;
  qualityClass: string;
  stars?: number[];
  starsClass?: string;
  /** React key: a new one whenever the item is rebuilt. */
  key: number;
  [key: string]: Any;
}

export interface JoMenu {
  id: string;
  title: string;
  translateTitle: boolean;
  subtitle: string;
  translateSubtitle: boolean;
  type: 'list' | 'tile';
  /** 0-based position in the VISIBLE items. */
  currentIndex: number;
  items: JoItem[];
  numberOnScreen: number;
  numberOnLine: number;
  numberLineOnScreen: number;
  onBeforeEnter: boolean;
  price: Any;
  priceTitle: string | false;
  displayBackButton: boolean;
  key: number;
  [key: string]: Any;
}

export const DEFAULT_STRINGS: Record<string, string> = {
  bigTitle: 'Menu',
  headerTitle: 'Menu',
  color: 'Color',
  of: '%1 of %2',
  selection: 'Selection',
  buy: 'Buy',
  back: 'Back',
  select: 'Select',
  price: 'Price',
  devise: '$',
  number: 'Number %1',
  free: 'Free',
  variation: 'Variation',
};

let keySeq = 1;
const nextKey = () => keySeq++;

/* ── shapes that cross Lua -> JSON loosely ─────────────────────────────────────────────────── */

/** A Lua list arrives as an array, or as an object keyed "1".."n" when it has holes; {} = empty. */
export function toArray<T = Any>(x: Any): T[] {
  if (x == null || x === false) return [];
  if (Array.isArray(x)) return x;
  if (typeof x === 'object') {
    const keys = Object.keys(x);
    if (keys.length === 0) return [];
    if (keys.every((k) => /^\d+$/.test(k))) {
      return keys
        .map(Number)
        .sort((a, b) => a - b)
        .map((k) => x[k]);
    }
  }
  return [x];
}

export function normSliders(x: Any): JoSlider[] {
  return toArray(x)
    .filter((s) => s && typeof s === 'object')
    .map((s) => ({ current: 1, translate: false, type: 'slider', looped: true, forceDisplay: false, ...s, values: toArray(s.values) }));
}

export function normStats(x: Any): JoStat[] {
  return toArray(x)
    .filter((s) => s && typeof s === 'object')
    .map((s) => ({ label: '', type: 'bar', class: '', value: [0, 0, 10], translateLabel: false, translateValue: false, ...s }));
}

/** number -> { money }, a Lua costs list with holes or an `operator` key -> its entries, false/absent -> false. */
export function normPrice(p: Any): Any {
  if (p === undefined || p === null || p === false) return false;
  if (typeof p === 'number') return { money: p };
  if (typeof p === 'string' && p !== '' && !isNaN(Number(p))) return { money: Number(p) };
  if (Array.isArray(p)) return p;
  if (typeof p === 'object') {
    const numeric = Object.keys(p).filter((k) => /^\d+$/.test(k));
    if (numeric.length) return numeric.map(Number).sort((a, b) => a - b).map((k) => p[k]);
    return p;
  }
  return false;
}

const TRUTHY_ITEM_KEYS = [
  'title', 'subtitle', 'footer', 'icon', 'child', 'priceTitle', 'data', 'preview', 'description', 'action',
  'prefix', 'iconClass', 'iconRight', 'grid', 'textRight', 'textRightClass', 'iconSize',
];
const DEFINED_ITEM_KEYS = [
  'translate', 'translateDescription', 'disabled', 'visible', 'translateTextRight', 'quantity',
  'quantityCircleClass', 'qualityClass', 'stars', 'starsClass',
];

export function normItem(r: Any, position: number): JoItem {
  r = r && typeof r === 'object' ? r : {};
  const it: JoItem = {
    title: '', subtitle: '', footer: '', icon: false, iconRight: false, iconClass: '', iconSize: 'normal', child: false,
    sliders: [], price: false, priceTitle: false, priceRight: false, data: {}, index: position + 1, visible: true,
    description: '', translate: false, translateDescription: false, prefix: false, statistics: [], disabled: false,
    grid: false, textRight: false, textRightClass: '', translateTextRight: false, previewSlider: false,
    quantity: false, quantityCircleClass: '', quality: false, qualityClass: '', key: nextKey(),
  };
  for (const k of TRUTHY_ITEM_KEYS) if (r[k]) it[k] = r[k];
  if (r.slider) it.sliders = normSliders(r.slider);
  if (r.sliders) it.sliders = normSliders(r.sliders);
  if (r.statistics) it.statistics = normStats(r.statistics);
  it.price = normPrice(r.price);
  if (r.priceRight !== undefined && r.priceRight !== false && r.priceRight !== null) it.priceRight = r.priceRight;
  if (r.index != null) it.index = Number(r.index);
  for (const k of DEFINED_ITEM_KEYS) if (r[k] != null) it[k] = r[k];
  if (r.quality != null && r.quality !== false) it.quality = Number(r.quality);
  if (r.previewSlider != null) it.previewSlider = !!r.previewSlider;
  if (r.previewPalette != null) it.previewSlider = !!r.previewPalette;
  it.stars = it.stars ? toArray(it.stars) : undefined;
  return it;
}

export const visibleItems = (m: JoMenu | undefined) => (m ? m.items.filter((i) => i.visible !== false) : []);

/** Lua names an item by its index (1-based, in the full list): its position in the visible list. */
export function posOfLuaIndex(m: JoMenu, luaIndex: number): number {
  const vis = visibleItems(m);
  if (!vis.length) return 0;
  let p = vis.findIndex((i) => i.index == luaIndex);
  if (p < 0) {
    let before = 0;
    for (let k = 0; k < m.items.length && k < luaIndex - 1; k++) if (m.items[k].visible !== false) before++;
    p = before;
  }
  return Math.max(0, Math.min(p, vis.length - 1));
}

export function normMenu(t: Any): JoMenu {
  t = t && typeof t === 'object' ? t : {};
  const m: JoMenu = {
    id: String(t.id ?? ''), title: t.title ?? '', translateTitle: false, subtitle: 'Elements', translateSubtitle: false,
    type: 'list', currentIndex: 0, items: [], numberOnScreen: 8, numberOnLine: 4, numberLineOnScreen: 6,
    onBeforeEnter: false, price: false, priceTitle: false, displayBackButton: false, key: nextKey(),
  };
  m.items = toArray(t.items).map((r, i) => normItem(r, i));
  if (t.numberOnScreen) m.numberOnScreen = Math.max(1, Number(t.numberOnScreen));
  if (t.translateTitle != null) m.translateTitle = !!t.translateTitle;
  if (t.subtitle != null) m.subtitle = t.subtitle;
  if (t.translateSubtitle != null) m.translateSubtitle = !!t.translateSubtitle;
  if (t.type) m.type = t.type === 'tile' ? 'tile' : 'list';
  if (t.numberLineOnScreen != null) m.numberLineOnScreen = Math.max(1, Number(t.numberLineOnScreen));
  if (t.numberOnLine != null) m.numberOnLine = Math.max(1, Number(t.numberOnLine));
  if (t.onBeforeEnter != null) m.onBeforeEnter = !!t.onBeforeEnter;
  if (t.price !== undefined) m.price = normPrice(t.price);
  if (t.priceTitle !== undefined) m.priceTitle = t.priceTitle;
  if (t.displayBackButton !== undefined) m.displayBackButton = !!t.displayBackButton;
  if (t.currentIndex != null && Number(t.currentIndex) > 0) m.currentIndex = posOfLuaIndex(m, Number(t.currentIndex));
  return m;
}

/* ── palettes: the game's tint strips, one colour per pixel ─────────────────────────────────── */

export const PALETTE_FILES = new Set([
  'generic_wagon_palette', 'metaped_tint_animal', 'metaped_tint_combined', 'metaped_tint_combined_leather', 'metaped_tint_eye',
  'metaped_tint_eyes_ui', 'metaped_tint_generic_clean', 'metaped_tint_hair', 'metaped_tint_hair_ui', 'metaped_tint_hat',
  'metaped_tint_horse', 'metaped_tint_horse_001', 'metaped_tint_horse_leather', 'metaped_tint_leather', 'metaped_tint_makeup',
  'metaped_tint_mpadv', 'tint_eye', 'tint_generic_clean', 'tint_hair', 'tint_horse', 'tint_horse_leather', 'tint_leather',
  'tint_makeup',
]);

/** jo's alias table: the game's tint names that share one strip. */
export function paletteName(name: unknown): string {
  const n = typeof name === 'string' ? name.trim().toLowerCase() : '';
  if (PALETTE_FILES.has(n)) return n;
  if (/^metaped_tint_combined_leather\d*$/.test(n) || n === 'si_template') return 'metaped_tint_combined_leather';
  if (/^metaped_tint_hair(\d+|_bed)?$/.test(n)) return 'metaped_tint_hair';
  if (/^metaped_tint_mpadv_/.test(n)) return 'metaped_tint_mpadv';
  return 'metaped_tint_generic_clean';
}

/* ── one owner's store ───────────────────────────────────────────────────────────────────────── */

const SOUND: Record<string, Sfx> = { button: 'hover', selected: 'select', menu_open: 'open', menu_close: 'close', coins: 'finish' };

export class OwnerStore {
  owner: string;
  menus: Record<string, JoMenu> = {};
  parentTree: string[] = [];
  currentMenuId = '';
  show = false;
  shownAt = 0;
  /** last time this owner's menu was shown: the newest shown owner draws and gets the keys */
  order = 0;
  instant = false;
  showLoader = false;
  right = false;
  volume = 0.5;
  strings: Record<string, string> = { ...DEFAULT_STRINGS };
  dataToSend: Any = {};
  private lastSound = '';

  constructor(owner: string, private bump: () => void, private nextOrder: () => number) {
    this.owner = owner;
  }

  /* ── reading ── */

  get cMenu(): JoMenu | undefined {
    return this.menus[this.currentMenuId];
  }

  get cItems(): JoItem[] {
    return visibleItems(this.cMenu);
  }

  get cIndex(): number {
    const n = this.cItems.length;
    const m = this.cMenu;
    if (!m || !n) return 0;
    return Math.max(0, Math.min(m.currentIndex, n - 1));
  }

  get cItem(): JoItem | undefined {
    return this.cItems[this.cIndex];
  }

  lang(key: Any): string {
    if (typeof key !== 'string' || key === '') return '#' + key;
    const v = this.strings[key];
    return v ? v : '#' + key;
  }

  sprintf(fmt: string, ...args: Any[]): string {
    return String(fmt).replace(/%(\d+)/gi, (_, n) => String(args[Number(n) - 1] ?? ''));
  }

  /** The price the panel shows: a slider value's own price first, then the item's. */
  itemPrice(it: JoItem | undefined): Any {
    if (!it) return false;
    for (const s of it.sliders) {
      if (s.type === 'grid' || s.type === 'palette') continue;
      const v = s.values[Number(s.current) - 1];
      if (v && typeof v === 'object' && v.price !== undefined) return normPrice(v.price);
    }
    return it.price || false;
  }

  sound(name: string) {
    const sfx = SOUND[name];
    if (!sfx) return;
    // jo's 50 ms de-duplication: one action never rings the same cue twice
    if (this.lastSound === name) return;
    this.lastSound = name;
    setTimeout(() => (this.lastSound = ''), 50);
    play(sfx, this.volume / 0.5);
  }

  /* ── posts back to Lua, through the host ── */

  post<T = unknown>(name: string, payload: Any) {
    return postNui<T>(`wmenu:${name}`, { ...payload, owner: this.owner });
  }

  addDataToSend(path: Array<string | number>, value: Any) {
    let node = this.dataToSend;
    for (let i = 0; i < path.length - 1; i++) {
      const k = path[i];
      if (node[k] == null) node[k] = typeof path[i + 1] === 'number' ? [] : {};
      node = node[k];
    }
    node[path[path.length - 1]] = value;
  }

  updatePreview(forceItemEvent = false) {
    const it = this.cItem;
    const payload: Any = { menu: this.currentMenuId, item: this.dataToSend, forceItemEvent, forceMenuEvent: false };
    if (it) payload.index = it.index;
    this.dataToSend = {};
    void this.post('updatePreview', payload);
  }

  /* ── navigation between menus ── */

  async openMenu(id: string): Promise<boolean> {
    if (!Object.prototype.hasOwnProperty.call(this.menus, id)) {
      void this.post('missingMenu', { menu: id });
      return false;
    }
    if (this.menus[id].onBeforeEnter) await this.post('onBeforeEnter', { menu: id });
    this.currentMenuId = id;
    this.bump();
    this.updatePreview();
    return true;
  }

  goToMenu(id: string) {
    const from = this.currentMenuId;
    // the history grows only with a real menu we are leaving for another one
    if (this.menus[id] && from && from !== id && this.menus[from] && this.parentTree[this.parentTree.length - 1] !== from) {
      this.parentTree.push(from);
    }
    void this.openMenu(id);
  }

  backToParentMenu() {
    const id = this.parentTree.pop();
    if (id !== undefined) void this.openMenu(id);
  }

  /* ── keys ── */

  menuDown() {
    const m = this.cMenu;
    const n = this.cItems.length;
    if (!m || !n) return;
    const cur = this.cIndex;
    if (m.type === 'tile') m.currentIndex = cur === n - 1 ? 0 : Math.min(cur + m.numberOnLine, n - 1);
    else m.currentIndex = cur < n - 1 ? cur + 1 : 0;
    this.sound('button');
    this.bump();
    this.updatePreview();
  }

  menuUp() {
    const m = this.cMenu;
    const n = this.cItems.length;
    if (!m || !n) return;
    const cur = this.cIndex;
    if (m.type === 'tile') m.currentIndex = cur > 0 ? Math.max(cur - m.numberOnLine, 0) : n - 1;
    else m.currentIndex = cur > 0 ? cur - 1 : n - 1;
    this.sound('button');
    this.bump();
    this.updatePreview();
  }

  menuRight() {
    const m = this.cMenu;
    const n = this.cItems.length;
    if (!m || !n || m.type === 'list') return;
    m.currentIndex = this.cIndex < n - 1 ? this.cIndex + 1 : 0;
    this.sound('button');
    this.bump();
    this.updatePreview();
  }

  menuLeft() {
    const m = this.cMenu;
    const n = this.cItems.length;
    if (!m || !n || m.type === 'list') return;
    m.currentIndex = this.cIndex > 0 ? this.cIndex - 1 : n - 1;
    this.sound('button');
    this.bump();
    this.updatePreview();
  }

  /** A row picked by the mouse: the first click selects it, a click on the selected row enters it. */
  pick(pos: number) {
    const m = this.cMenu;
    if (!m) return;
    if (this.cIndex === pos) return this.menuEnter();
    m.currentIndex = pos;
    this.sound('button');
    this.bump();
    this.updatePreview();
  }

  menuEnter() {
    const it = this.cItem;
    if (!it || it.disabled) return;
    this.sound('button');
    if (it.child) this.goToMenu(String(it.child));
    else void this.post('click', { menu: this.currentMenuId, item: it });
  }

  menuBack() {
    void this.post('backMenu', { menu: this.currentMenuId, item: this.cItem ?? {} });
    if (this.parentTree.length > 0) {
      this.sound('button');
      this.backToParentMenu();
    }
  }

  /* ── sliders ── */

  private sliderAt(idx?: number): [number, JoSlider | undefined] {
    const it = this.cItem;
    if (!it || !it.sliders.length) return [-1, undefined];
    let e: number;
    if (idx == null) e = Math.max(it.sliders.findIndex((s) => s.type === 'switch'), 0);
    else e = Math.min(idx, it.sliders.length - 1);
    return [e, it.sliders[e]];
  }

  private sliderStep(idx: number | undefined, dir: -1 | 1) {
    const it = this.cItem;
    if (!it || it.disabled) return;
    const [e, s] = this.sliderAt(idx);
    if (!s) return;
    if (s.type === 'grid') return dir < 0 ? this.gridLeft(e) : this.gridRight(e);
    if (s.type === 'palette') {
      if (s.max == null || s.max < 0) return; // its strip has not loaded yet
      const off = new Set(toArray<number>(s.disabledTints).map(Number));
      const min = s.min ?? 0;
      let n = Number(s.current) + dir;
      while (n >= min && n <= s.max && off.has(n)) n += dir;
      if (n < min || n > s.max) return; // palettes stop at their ends
      s.current = n;
    } else {
      const len = s.values.length;
      const cur = Number(s.current) || 1;
      if (len <= 1) return;
      if (!s.looped && ((dir < 0 && cur === 1) || (dir > 0 && cur === len))) return;
      let n = cur + dir;
      if (n <= 0) n = len;
      if (n > len) n = 1;
      s.current = n;
    }
    this.sound('button');
    this.addDataToSend(['sliders', e, 'current'], s.current);
    this.bump();
    this.updatePreview();
  }

  sliderLeft(idx?: number) {
    this.sliderStep(idx, -1);
  }

  sliderRight(idx?: number) {
    this.sliderStep(idx, 1);
  }

  /** The mouse on a box, a sprite, a palette cell (value = the new current), or a grid (value = [fx, fy]). */
  setSliderCurrent(index: number, value: Any) {
    const it = this.cItem;
    if (!it || it.disabled) return;
    const s = it.sliders[index];
    if (!s) return;
    if (s.type === 'grid') {
      const fr = value as number[];
      let changed = false;
      for (const k of [1, 0]) {
        const ax = s.values[k];
        if (!ax || fr[k] == null) continue;
        const min = Number(ax.min ?? 0);
        const max = Number(ax.max ?? 1);
        const gap = Number(ax.gap) || 1;
        let v = fr[k] * (max - min) + min;
        v = Math.round(v / gap) * gap;
        v = Math.max(min, Math.min(max, v));
        v = Math.round(v * 1e6) / 1e6;
        if (v !== ax.current) {
          ax.current = v;
          this.addDataToSend(['sliders', index, 'values', k, 'current'], v);
          changed = true;
        }
      }
      if (!changed) return;
    } else {
      if (s.current == value) return;
      s.current = value;
      this.addDataToSend(['sliders', index, 'current'], value);
    }
    this.sound('button');
    this.bump();
    this.updatePreview();
  }

  private gridIndex(e: number | undefined, axes: 1 | 2): number {
    const it = this.cItem;
    if (!it) return -1;
    if (e != null && it.sliders[e]?.type === 'grid') return e;
    let i = it.sliders.findIndex((s) => s.type === 'grid' && s.values.length >= 2);
    if (i < 0 && axes === 1) i = it.sliders.findIndex((s) => s.type === 'grid');
    return i;
  }

  private gridMove(e: number | undefined, axis: 0 | 1, dir: -1 | 1) {
    const it = this.cItem;
    if (!it || it.disabled) return;
    const i = this.gridIndex(e, axis === 0 ? 1 : 2);
    if (i < 0) return;
    const ax = it.sliders[i].values[axis];
    if (!ax) return;
    const min = Number(ax.min ?? 0);
    const max = Number(ax.max ?? 1);
    const gap = Number(ax.gap) || 1;
    const v = Math.round(Math.max(min, Math.min(max, Number(ax.current ?? min) + dir * gap)) * 1e6) / 1e6;
    if (v === ax.current) return;
    ax.current = v;
    this.addDataToSend(['sliders', i, 'values', axis, 'current'], v);
    this.sound('button');
    this.bump();
    this.updatePreview();
  }

  gridLeft(e?: number) {
    this.gridMove(e, 0, -1);
  }
  gridRight(e?: number) {
    this.gridMove(e, 0, 1);
  }
  gridUp(e?: number) {
    this.gridMove(e, 1, -1);
  }
  gridDown(e?: number) {
    this.gridMove(e, 1, 1);
  }

  /* ── the messages from Lua ── */

  handle(msg: Any) {
    const name = msg?.event;
    switch (name) {
      case 'updateMenu': {
        const raw = msg.menu ?? {};
        const id = String(raw.id ?? '');
        const prev = this.menus[id];
        const m = normMenu(raw);
        if (prev && raw.currentIndex == null) m.currentIndex = prev.currentIndex;
        if (m.currentIndex >= visibleItems(m).length) m.currentIndex = 0;
        if (msg.reset) m.currentIndex = 0;
        this.menus[id] = m;
        break;
      }
      case 'updateMenuData': {
        const old = this.menus[msg.menu];
        if (!old) return;
        const m = normMenu({ ...msg.data, id: msg.menu, currentIndex: undefined });
        m.currentIndex = old.currentIndex;
        this.menus[msg.menu] = m;
        break;
      }
      case 'updateMenuValues':
        this.applyValues(msg.menu, toArray(msg.updated));
        break;
      case 'resetMenu':
        if (this.menus[msg.menu]) this.menus[msg.menu].currentIndex = 0;
        break;
      case 'setCurrentMenu': {
        const id = String(msg.menu ?? '');
        if (!this.menus[id]) return;
        if (msg.reset) this.menus[id].currentIndex = 0;
        this.goToMenu(id);
        if (!msg.keepHistoric) this.parentTree = [];
        break;
      }
      case 'setCurrentIndex': {
        const m = this.menus[msg.menu];
        if (!m) return;
        m.currentIndex = posOfLuaIndex(m, Number(msg.index));
        if (msg.menu === this.currentMenuId) this.updatePreview();
        break;
      }
      case 'removeMenu':
        delete this.menus[msg.menu];
        this.parentTree = this.parentTree.filter((id) => id !== msg.menu);
        break;
      case 'updateShow': {
        const show = !!msg.show;
        this.instant = !!msg.cancelAnimation;
        if (show && !this.show) {
          this.shownAt = performance.now();
          this.order = this.nextOrder();
          if (!this.instant) this.sound('menu_open');
        } else if (!show && this.show && !this.instant) {
          this.sound('menu_close');
        }
        this.show = show;
        if (show) this.updatePreview();
        break;
      }
      case 'updateLang':
        if (msg.lang && typeof msg.lang === 'object') this.strings = { ...this.strings, ...msg.lang };
        break;
      case 'updateVolume':
        this.volume = Math.max(0, Math.min(1, Number(msg.volume) || 0));
        break;
      case 'updateMenuPosition':
        this.right = msg.menuRight === 'right';
        break;
      case 'startAudio':
        if (typeof msg.sound === 'string') play(SOUND[msg.sound] ?? 'hover', this.volume / 0.5);
        break;
      case 'displayLoader':
        this.showLoader = !!msg.show;
        break;
      case 'menuBack':
      case 'backToParentMenu':
        if (name === 'menuBack') this.menuBack();
        else this.backToParentMenu();
        break;
      case 'menuEnter':
        this.menuEnter();
        break;
      case 'menuUp':
        this.menuUp();
        break;
      case 'menuDown':
        this.menuDown();
        break;
      case 'menuLeft':
        this.menuLeft();
        break;
      case 'menuRight':
        this.menuRight();
        break;
      case 'resetAllMenu':
        Object.values(this.menus).forEach((m) => (m.currentIndex = 0));
        break;
      case 'setMenuVisible':
        Object.values(this.menus).forEach((m) => m.items.forEach((it) => it.child === msg.menu && (it.visible = !!msg.visible)));
        break;
      case 'updateItem': {
        const m = this.menus[msg.menu];
        const it = m?.items.find((i) => i.index == msg.index);
        if (it && msg.item && typeof msg.item === 'object') deepMerge(it, msg.item);
        break;
      }
      default:
        return;
    }
    this.bump();
  }

  private applyValues(menuId: string, updated: Any[]) {
    const m = this.menus[menuId];
    if (!m) return;
    let previewNeeded = false;
    for (const u of updated) {
      if (!u || typeof u !== 'object') continue;
      const keys = toArray(u.keys).map((k: Any) => (typeof k === 'number' ? k - 1 : k));
      if (!keys.length) continue;
      const last = keys[keys.length - 1];
      let node: Any = m;
      let ok = true;
      for (let a = 0; a < keys.length - 1; a++) {
        node = node?.[keys[a]];
        if (node == null || typeof node !== 'object') {
          ok = false;
          break;
        }
      }
      if (!ok) continue;

      if (u.action === 'delete') {
        if (Array.isArray(node)) node.splice(last as number, 1);
        else delete node[last];
        continue;
      }
      if (u.action !== 'update') continue;

      const isMenu = node === m;
      const isItemList = node === m.items;
      if (isItemList) {
        node[last] = normItem(u.value, last as number);
      } else if (isMenu) {
        setMenuKey(m, String(last), u.value);
        if (last === 'currentIndex') {
          m.currentIndex = posOfLuaIndex(m, Number(u.value));
          if (menuId === this.currentMenuId) previewNeeded = true;
        }
      } else if (m.items.includes(node)) {
        setItemKey(node as JoItem, String(last), u.value);
      } else {
        node[last] = u.value;
      }
    }
    if (previewNeeded) this.updatePreview(true);
  }
}

function setMenuKey(m: JoMenu, key: string, v: Any) {
  switch (key) {
    case 'items':
      m.items = toArray(v).map((r, i) => normItem(r, i));
      return;
    case 'type':
      m.type = v === 'tile' ? 'tile' : 'list';
      return;
    case 'price':
      m.price = normPrice(v);
      return;
    case 'numberOnScreen':
    case 'numberOnLine':
    case 'numberLineOnScreen':
      m[key] = Math.max(1, Number(v) || 1);
      return;
    case 'currentIndex':
      return; // the caller maps it
    default:
      m[key] = v;
  }
}

function setItemKey(it: JoItem, key: string, v: Any) {
  switch (key) {
    case 'sliders':
    case 'slider':
      it.sliders = normSliders(v);
      return;
    case 'statistics':
      it.statistics = normStats(v);
      return;
    case 'price':
      it.price = normPrice(v);
      return;
    case 'priceRight':
      it.priceRight = v === null || v === undefined ? false : v;
      return;
    case 'quality':
      it.quality = v === false || v == null ? false : Number(v);
      return;
    case 'previewPalette':
    case 'previewSlider':
      it.previewSlider = !!v;
      return;
    case 'stars':
      it.stars = v ? toArray(v) : undefined;
      return;
    case 'index':
      it.index = Number(v);
      return;
    default:
      it[key] = v;
  }
}

function deepMerge(t: Any, r: Any) {
  for (const k of Object.keys(r)) {
    const rv = r[k];
    if (rv == null) continue;
    if (typeof t[k] !== typeof rv || k === 'values') t[k] = rv;
    else if (typeof rv === 'object') {
      if (t[k] == null) t[k] = rv;
      else deepMerge(t[k], rv);
    } else t[k] = rv;
  }
  if (r.sliders) t.sliders = normSliders(t.sliders);
  if (r.statistics) t.statistics = normStats(t.statistics);
  if (r.price !== undefined) t.price = normPrice(t.price);
}

/* ── every owner, and which one draws ────────────────────────────────────────────────────────── */

type Listener = () => void;

class Hub {
  stores = new Map<string, OwnerStore>();
  version = 0;
  private listeners = new Set<Listener>();
  private orderSeq = 0;

  bump = () => {
    this.version++;
    this.listeners.forEach((l) => l());
  };

  subscribe = (l: Listener) => {
    this.listeners.add(l);
    return () => this.listeners.delete(l);
  };

  getVersion = () => this.version;

  store(owner: string): OwnerStore {
    let s = this.stores.get(owner);
    if (!s) {
      s = new OwnerStore(owner, this.bump, () => ++this.orderSeq);
      this.stores.set(owner, s);
    }
    return s;
  }

  /** The newest shown owner draws and gets the keys; when it hides, the one under it comes back. */
  active(): OwnerStore | undefined {
    let best: OwnerStore | undefined;
    this.stores.forEach((s) => {
      if (s.show && (!best || s.order > best.order)) best = s;
    });
    return best;
  }

  receive(owner: unknown, msg: Any) {
    if (typeof owner !== 'string' || !msg || typeof msg !== 'object') return;
    if (msg.event === 'dropOwner') {
      if (this.stores.delete(owner)) this.bump();
      return;
    }
    this.store(owner).handle(msg);
  }
}

export const hub = new Hub();
