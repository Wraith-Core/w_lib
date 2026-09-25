/**
 * ============================================================================
 * The palette, as a clamp -- for colours the frame does not choose.
 *
 * ★ Every colour this frame paints by itself is a token (w_lib/nui/theme/tokens.css). What is
 *   left is colour that ARRIVES: a script's titleColor or a reading's colour on a notice, a
 *   house colour behind a crest, a <span style="color:..."> inside a description, a colour a
 *   player picked in an older build. The owner's rule is the game's: ink, paper and one red, on
 *   every interface, without exception. So a colour that arrives is brought onto the palette at
 *   the moment it is DRAWN -- the nearest tone by lightness, its transparency kept.
 *
 * ⚠️ Render time only. Nothing here rewrites what a script sent or what a database holds: the
 *    stored colour stays exactly as it was, and a form field keeps its value until the player
 *    picks a new one (PaletteField). Clamping on the way in would destroy data a server may
 *    still need.
 *
 * ★ Red is not a tone. It is the theme's one mark (critical, refusal, the destructive confirm),
 *   so a red that arrives as TEXT colour does not become red text: the text takes a paper tone
 *   and the red survives as an underline -- the mark, where the meaning was.
 * ============================================================================
 */

/** The palette's tones, light to dark (tokens.css). */
export const TONES = {
  paper: '#EDE6D6',
  paperDim: '#B9AF9C',
  paperFaint: '#7D7466',
  ink5: '#38322A',
  ink4: '#27231C',
  ink3: '#1D1A15',
  ink2: '#15130F',
  ink: '#0B0A08',
} as const;

export const RED = '#CB0101';

/** Every tone: for fills and plates (a crest's field, a swatch). */
export const ALL_TONES: readonly string[] = Object.values(TONES);
/** Text that stands on ink or over the world: the paper steps a reader can still read. */
export const TEXT_TONES: readonly string[] = [TONES.paper, TONES.paperDim];
/** Secondary readings (a clock, a unit) may also go to the faint step. */
export const READING_TONES: readonly string[] = [TONES.paper, TONES.paperDim, TONES.paperFaint];

type RGBA = [number, number, number, number];

let ctx: CanvasRenderingContext2D | null | undefined;

/** Any CSS colour string -> [r, g, b, a], through the browser's own parser; null if it is not one. */
export function parseColor(input: unknown): RGBA | null {
  if (typeof input !== 'string') return null;
  const text = input.trim();
  if (!text || /^(inherit|initial|unset|revert|currentcolor|none)$/i.test(text)) return null;
  if (ctx === undefined) ctx = document.createElement('canvas').getContext('2d');
  if (!ctx) return null;
  // Two sentinels: an invalid colour leaves fillStyle unchanged, so it is caught either way.
  ctx.fillStyle = '#010203';
  ctx.fillStyle = text;
  const a = String(ctx.fillStyle);
  ctx.fillStyle = '#040506';
  ctx.fillStyle = text;
  const b = String(ctx.fillStyle);
  if (a !== b) return null;
  const hex = /^#([0-9a-f]{6})$/i.exec(a);
  if (hex) {
    const n = parseInt(hex[1], 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255, 1];
  }
  const m = /^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$/i.exec(a);
  return m ? [Number(m[1]), Number(m[2]), Number(m[3]), m[4] === undefined ? 1 : Number(m[4])] : null;
}

const lin = (c: number) => {
  const s = c / 255;
  return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
};

/** CIE lightness L* (0..100): how light a colour LOOKS, which is what "nearest tone" should mean. */
const lightness = ([r, g, b]: RGBA | [number, number, number]) => {
  const y = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
  return y > 216 / 24389 ? 116 * Math.cbrt(y) - 16 : (24389 / 27) * y;
};

const TONE_L = new Map<string, number>();
const toneLightness = (hex: string) => {
  let l = TONE_L.get(hex);
  if (l === undefined) {
    l = lightness(parseHex(hex));
    TONE_L.set(hex, l);
  }
  return l;
};

const parseHex = (hex: string): [number, number, number] => {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
};

/** A saturated red: the colour a script uses to say "refused", "wanted", "danger". */
export function isRedMark(input: unknown): boolean {
  const c = parseColor(input);
  if (!c || c[3] === 0) return false;
  const [r, g, b] = c;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  if (max < 90 || max !== r || (max - min) / max < 0.5) return false;
  // hue within ~20 degrees of pure red
  const hue = (60 * (g - b)) / (max - min);
  return hue > -20 && hue < 20;
}

/** The tone (as its hex) nearest to a colour by lightness, whatever the colour's alpha. */
export function nearestTone(input: unknown, tones: readonly string[] = ALL_TONES): string | undefined {
  const c = parseColor(input);
  if (!c) return undefined;
  const l = lightness(c);
  let best = tones[0];
  let dist = Infinity;
  for (const t of tones) {
    const d = Math.abs(toneLightness(t) - l);
    if (d < dist) {
      dist = d;
      best = t;
    }
  }
  return best;
}

/**
 * Any CSS colour -> the nearest palette tone by lightness, its alpha kept.
 * Returns undefined for something that is not a colour, and leaves `transparent` alone.
 */
export function toPalette(input: unknown, tones: readonly string[] = ALL_TONES): string | undefined {
  const c = parseColor(input);
  if (!c) return undefined;
  if (c[3] === 0) return 'transparent';
  const best = nearestTone(input, tones) as string;
  if (c[3] >= 1) return best;
  const [r, g, b] = parseHex(best);
  return `rgba(${r}, ${g}, ${b}, ${Math.round(c[3] * 1000) / 1000})`;
}

/** The inline style a script's text colour becomes: a paper tone, and the red mark if it was red. */
export function textStyle(input: unknown, tones: readonly string[] = TEXT_TONES): Record<string, string> | undefined {
  const color = toPalette(input, tones);
  if (!color) return undefined;
  if (!isRedMark(input)) return { color };
  return {
    color,
    textDecorationLine: 'underline',
    textDecorationColor: RED,
    textDecorationThickness: '2px',
    textUnderlineOffset: '0.22em',
  };
}

/* ── colours inside markup ─────────────────────────────────────────────── */

const COLOR_TOKEN = /#[0-9a-f]{3,8}\b|(?:rgb|hsl)a?\([^)]*\)|\b[a-z]{3,20}\b/gi;
const TEXT_PROPS = /^(color|-webkit-text-fill-color|caret-color)$/i;
const PAINT_PROPS = /color|background|border|outline|shadow|fill|stroke|decoration/i;

/** Every colour in one declaration's value, clamped. Words that are not colours pass through. */
function clampValue(value: string, tones: readonly string[]): string {
  return value.replace(COLOR_TOKEN, (token) => {
    if (/^(transparent|inherit|initial|unset|currentcolor|none)$/i.test(token)) return token;
    const c = parseColor(token);
    return c ? toPalette(token, tones) ?? token : token;
  });
}

function clampStyle(style: string): string {
  return style
    .split(';')
    .map((decl) => {
      const i = decl.indexOf(':');
      if (i < 0) return decl;
      const prop = decl.slice(0, i).trim();
      const value = decl.slice(i + 1);
      if (TEXT_PROPS.test(prop)) {
        const red = isRedMark(value.trim());
        const out = `${decl.slice(0, i)}:${clampValue(value, TEXT_TONES)}`;
        return red
          ? `${out};text-decoration-line:underline;text-decoration-color:${RED};text-decoration-thickness:2px;text-underline-offset:.22em`
          : out;
      }
      if (PAINT_PROPS.test(prop)) return `${decl.slice(0, i)}:${clampValue(value, ALL_TONES)}`;
      return decl;
    })
    .join(';');
}

const MARKUP_HINT = /style\s*=|<font|\bfill\s*=|\bstroke\s*=|\bcolor\s*=|bgcolor/i;

/**
 * The colours a script put inside markup (a description, a label, 2D/3D text) brought onto the
 * palette: style="color:..." and every other painted property, <font color>, SVG fill/stroke.
 * Markup with no colour in it is returned untouched, so the common case costs one regex test.
 */
export function monoHtml(html: string): string {
  if (!html || !MARKUP_HINT.test(html) || typeof document === 'undefined') return html;
  // ★ Cached: 3D text is re-sent every frame, and the same markup must not be re-parsed 60 times a second.
  const hit = HTML_CACHE.get(html);
  if (hit !== undefined) return hit;
  const out = clampMarkup(html);
  if (HTML_CACHE.size >= 256) HTML_CACHE.delete(HTML_CACHE.keys().next().value as string);
  HTML_CACHE.set(html, out);
  return out;
}

const HTML_CACHE = new Map<string, string>();

function clampMarkup(html: string): string {
  const t = document.createElement('template');
  t.innerHTML = html;
  t.content.querySelectorAll('*').forEach((el) => {
    const style = el.getAttribute('style');
    if (style) el.setAttribute('style', clampStyle(style));
    const font = el.getAttribute('color');
    if (font) {
      const red = isRedMark(font);
      el.setAttribute('color', toPalette(font, TEXT_TONES) ?? font);
      if (red) el.setAttribute('style', `${el.getAttribute('style') ?? ''};text-decoration:underline ${RED} 2px`);
    }
    const bg = el.getAttribute('bgcolor');
    if (bg) el.setAttribute('bgcolor', toPalette(bg) ?? bg);
    for (const attr of ['fill', 'stroke']) {
      const v = el.getAttribute(attr);
      if (v && parseColor(v)) el.setAttribute(attr, toPalette(v) ?? v);
    }
  });
  return t.innerHTML;
}
