/**
 * ============================================================================
 * The w_crafting asset bridge -- textures resolved to ABSOLUTE urls, and the faces warmed.
 *
 * ⚠️ THE ONE RULE: a relative url() stored in a CSS custom property does NOT resolve once it
 *    is substituted through var() into mask-image or background. It renders BLANK in Chrome
 *    and in the in-game CEF -- even though the very same relative path works fine in a plain
 *    <img src> or an @font-face rule. That is the classic symptom of "the fonts and the item
 *    pictures load, but every frame and glyph is empty".
 *
 *    And never hardcode a root-absolute "/tex/..." either: that ignores the base the page was
 *    served under and 404s in a preview.
 *
 *    BASE resolved against document.baseURI is correct everywhere: the vite dev server, the
 *    built bundle (base './'), and nui:// in game. Ported verbatim from w_crafting/main.jsx,
 *    including this warning -- it was learned the hard way there.
 * ============================================================================
 */

import { isEnvBrowser } from '../utils/misc';

const BASE = import.meta.env.BASE_URL;
const ABS_BASE = new URL(BASE, document.baseURI).href;

const tex = (path: string) => `url("${ABS_BASE}${path}")`;

/** Absolute url for an asset used as-is (an <img src>, an Audio source). */
export const wcAsset = (path: string) => ABS_BASE + path;

declare global {
  interface Window {
    rsmAsset?: (path: string) => string;
  }
}

/** The RDR2 interface art, every piece exposed as --tex-<name>. */
const TEXTURES: Record<string, string[]> = {
  'tex/ui': [
    'crafting_highlight_t',
    'crafting_highlight_b',
    'crafting_highlight_l',
    'crafting_highlight_r',
    'crafting_highlight_tl',
    'crafting_highlight_tr',
    'crafting_highlight_bl',
    'crafting_highlight_br',
    'crafting_outline',
    'divider_line',
    'title_divider',
    'vertical_divider_line',
    'list_item_h_line_narrow',
    'menu_header_1a',
    'selection_box_bg_1a',
    'selection_box_bg_1c',
    'toast_bg',
    'help_text_bg',
    'lock',
    'menu_icon_rank',
    'star',
    'rating_star',
    'cross',
    'tick',
    'selection_arrow_left',
    'selection_arrow_right',
    'weapon_stats_bar',
    'weapon_stats_bar_mask',
    'menu_bar',
    'swatch_bg_1a',
    'counter_bg_1a',
    'warning',
    'info',
  ],
  'tex/blips': [
    'blip_campfire',
    'blip_shop_blacksmith',
    'blip_ammo_bullets',
    'blip_shop_gunsmith',
    'blip_camp_tent',
    'blip_camp',
    'blip_time_of_day',
  ],
};

/**
 * Which texture names are finished pictures rather than mask art.
 *
 * ⚠️ This distinction is not cosmetic. .wc-glyph paints `background-color: currentColor` and
 *    uses the texture as a MASK, which only works for white-on-transparent art. Three of the
 *    blips -- campfire, blacksmith, gunsmith -- are filled discs: roughly half of their pixels
 *    are opaque dark. Masking one paints its whole disc in the text colour, so the icon
 *    arrived as a solid blob with no detail in it at all.
 *
 *    The blips are drawn with their own colour and are meant to be <img>. The remaining four
 *    are line art and would mask correctly, but they go through the same path so a caller
 *    never has to know which of the seven is which.
 */
const IMAGE_TEXTURES = new Set(TEXTURES['tex/blips']);

/** Where a registered texture lives, or undefined when the name is not one of ours. */
export function texturePath(name: string): string | undefined {
  for (const [dir, names] of Object.entries(TEXTURES)) {
    if (names.includes(name)) return `${dir}/${name}.png`;
  }
}

/** True when the named texture must be drawn as a picture instead of masked. */
export const isImageTexture = (name: string) => IMAGE_TEXTURES.has(name);

/**
 * The faces to fetch before anything is shown.
 *
 * ★ The faces themselves are declared by the theme package (w_lib/nui/theme/fonts.css, linked
 *   from index.html), not here. A NUI frame loads hidden, and a face is only fetched the first
 *   time something asks for it -- so without this the first menu of a session opens in the
 *   fallback face and redraws a frame later. Asking for each one up front (with a Latin and an
 *   Arabic letter, so both halves of a split face load) makes that first open land finished.
 */
const WARM_FACES = [
  '600 20px "EB Garamond"',
  '400 20px "EB Garamond"',
  '400 20px "Lalezar"',
  '400 20px "Amiri"',
  '700 20px "Amiri"',
  '400 20px "Tajawal"',
  '500 20px "Tajawal"',
  '700 20px "Tajawal"',
  '400 20px "Hapna Slab"',
  '400 20px "RDR Catalogue"',
  '400 20px "RDR Lino"',
];

function warmFaces(): void {
  const fonts = (document as Document & { fonts?: FontFaceSet }).fonts;
  if (!fonts || typeof fonts.load !== 'function') return;
  for (const face of WARM_FACES) fonts.load(face, 'Aa\u0639').catch(() => undefined);
}

let done = false;

/** Register every texture and warm the theme's faces. Safe to call more than once. */
export function bootstrapWcAssets(): void {
  if (done || typeof document === 'undefined') return;
  done = true;

  window.rsmAsset = wcAsset;

  const root = document.documentElement.style;

  // The preview scene, as a variable so the stylesheet can paint it behind everything in browser preview only.
  if (isEnvBrowser()) {
    root.setProperty('--wl-backdrop', tex('img/backdrop.jpg'));
  } else {
    root.setProperty('--wl-backdrop', 'none');
  }

  for (const [dir, names] of Object.entries(TEXTURES)) {
    for (const name of names) root.setProperty(`--tex-${name}`, tex(`${dir}/${name}.png`));
  }

  /* ★ 4.4.0: the board kit's own four (kit/kit.css): the torn edge and the grain (tex/kit, copied from w_train),
     and the game's brushed selection band in its long and short form. */
  root.setProperty('--tex-tear', tex('tex/kit/tear.png'));
  root.setProperty('--tex-grain', tex('tex/kit/grain.png'));
  root.setProperty('--tex-band', tex('tex/ui/selection_box_bg_1a.png'));
  root.setProperty('--tex-band-sm', tex('tex/ui/selection_box_bg_1c.png'));

  // ★ The faces come from the theme's fonts.css. It is a <link> in <head>, so by 'load' it has
  //   been parsed and every @font-face is known; ask for them then.
  if (document.readyState === 'complete') warmFaces();
  else window.addEventListener('load', warmFaces, { once: true });
}
