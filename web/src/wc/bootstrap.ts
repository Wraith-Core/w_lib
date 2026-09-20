/**
 * ============================================================================
 * The w_crafting asset bridge -- textures and faces, resolved to ABSOLUTE urls.
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

const AR_RANGE =
  'U+0600-06FF,U+0750-077F,U+0870-089F,U+08A0-08FF,U+FB50-FDFF,U+FE70-FEFF,U+200C-200F,U+2010-2011,U+0660-0669';
const LAT_RANGE = 'U+0000-00FF,U+0131,U+0152-0153,U+2000-206F,U+2074,U+20AC,U+2122,U+2212';

let done = false;

/** Register every texture and face. Safe to call more than once. */
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

  // ⚠️ @font-face cannot read a CSS variable, so the faces are written with ABS_BASE baked in
  //    rather than declared in a stylesheet. Tajawal is split by unicode-range so Arabic gets
  //    a face that has Arabic glyphs while Latin keeps the RDR lettering.
  const style = document.createElement('style');
  style.textContent = `
    @font-face { font-family: "RDR Lino"; src: url("${ABS_BASE}fonts/RDRLino-Regular.woff2") format("woff2"); font-display: swap; }
    @font-face { font-family: "Hapna Slab"; src: url("${ABS_BASE}fonts/HapnaSlabSerif-DemiBold.woff2") format("woff2"); font-display: swap; }
    @font-face { font-family: "RDR Catalogue"; src: url("${ABS_BASE}fonts/RDRCatalogueBold-Bold.woff2") format("woff2"); font-display: swap; }
    @font-face { font-family: "Noto Sans Arabic"; src: url("${ABS_BASE}fonts/NotoSansArabic.woff2") format("woff2"); font-weight: 100 900; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 400; src: url("${ABS_BASE}fonts/tajawal-arabic-400-normal.woff2") format("woff2"); unicode-range: ${AR_RANGE}; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 500; src: url("${ABS_BASE}fonts/tajawal-arabic-500-normal.woff2") format("woff2"); unicode-range: ${AR_RANGE}; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 700; src: url("${ABS_BASE}fonts/tajawal-arabic-700-normal.woff2") format("woff2"); unicode-range: ${AR_RANGE}; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 400; src: url("${ABS_BASE}fonts/tajawal-latin-400-normal.woff2") format("woff2"); unicode-range: ${LAT_RANGE}; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 700; src: url("${ABS_BASE}fonts/tajawal-latin-700-normal.woff2") format("woff2"); unicode-range: ${LAT_RANGE}; font-display: swap; }

    /* ★ The prompt's own two faces. They were substituted with RDR Catalogue and RDR Lino at
       first, on the belief they did not ship anywhere -- they do, in w_lib/nui/assets/fonts,
       and the substitution was the most visible way the prompt failed to match. */
    @font-face { font-family: "Crock"; src: url("${ABS_BASE}fonts/crock.ttf") format("truetype"); font-display: block; }
    @font-face { font-family: "BebasNeue"; src: url("${ABS_BASE}fonts/BebasNeue-Regular.ttf") format("truetype"); font-display: block; }
  `;

  document.head.appendChild(style);
}
