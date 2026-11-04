/**
 * The screen scale for the runtime styles (Mantine / emotion), the same rule as web/ui-scale.cjs
 * applies to the CSS files at build time: every `Npx` becomes a multiple of --ws-px (1px at
 * 1080p; 0.667 at 720p, 2 at 4K, 4 at 8K; height decides on ultrawide). Keep both in step.
 */
const PX = /(^|[^\w.#-])(-?\d*\.?\d+)px\b/g;

const fmt = (n: number) => String(+n.toFixed(4));

/** 1 design px in real px, the same rule as --ws-px: min(height / 1080, width / 1920), never below 720p's .6667.
 *  For sizes measured in JS (a pop-up's width, a gap to the screen edge) of pieces whose CSS is scaled. */
export const wsScale = (): number =>
  Math.max(0.6667, Math.min((window.innerHeight || 1080) / 1080, (window.innerWidth || 1920) / 1920));

export function scaleValue(value: string, font: boolean): string {
  if (!value || value.indexOf('px') < 0 || /var\(--ws-f?px\)/.test(value)) return value;
  const keep: string[] = [];
  const masked = value.replace(/url\([^)]*\)|"[^"]*"|'[^']*'/g, (m) => {
    keep.push(m);
    return `\u0000${keep.length - 1}\u0000`;
  });
  const unit = font ? 'var(--ws-fpx)' : 'var(--ws-px)';
  const out = masked.replace(PX, (all, pre: string, num: string) => {
    const n = parseFloat(num);
    if (!n) return all;
    const scaled = `calc(${fmt(n)} * ${unit})`;
    if (Math.abs(n) <= 2) return `${pre}${n > 0 ? 'max' : 'min'}(${fmt(n)}px, ${scaled})`;
    return `${pre}${scaled}`;
  });
  return out.replace(/\u0000(\d+)\u0000/g, (_m, i: string) => keep[+i]);
}

const isFont = (prop: string) => {
  const p = prop.trim().toLowerCase();
  return p === 'font-size' || p === 'font';
};

/** stylis middleware: scales the px in every declaration emotion writes. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function uiScaleStylis(element: any): void {
  if (element.type !== 'decl') return;
  const v = element.children;
  if (typeof v !== 'string' || v.indexOf('px') < 0) return;
  element.return = `${element.props}:${scaleValue(v, isFont(String(element.props)))};`;
}
