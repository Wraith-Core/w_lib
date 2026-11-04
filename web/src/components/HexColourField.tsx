import React from 'react';
import { createPortal } from 'react-dom';
import './HexColourField.css';
import { wsScale } from '../utils/uiScale';

/**
 * A colour typed as hex, with a ▲ inside the box that opens a colour wheel above it.
 *
 * ★ Not PaletteField. That one is the house rule for the theme's own colours (eight paper tones). This is
 *   for a colour that is DATA the script stores and shows somewhere else in full colour -- a name plate, a
 *   crest -- where the reader really means "this red". The panel field type is 'hexcolor'.
 * * The wheel: the angle is the hue, the distance from the middle the saturation; a brightness slider and an
 *   opacity slider under it. It reports '#rrggbb', or '#rrggbbaa' when not fully opaque.
 * * Dragging sends many colours a second; the script hears at most one every 120 ms (and the last one).
 * * The wheel is portalled to <body> at fixed coordinates (as WSelect's list): no scrolling block clips it.
 */
type HSVA = { h: number; s: number; v: number; a: number };

/* Where the reader last dragged the wheel (its top-left corner): it opens there again until the page reloads. */
let dragged: { left: number; top: number } | null = null;

const hex2 = (n: number) => Math.round(Math.max(0, Math.min(255, n))).toString(16).padStart(2, '0');

function hsvToRgb(h: number, s: number, v: number): [number, number, number] {
  const f = (n: number) => { const k = (n + h / 60) % 6; return v - v * s * Math.max(0, Math.min(k, 4 - k, 1)); };
  return [f(5) * 255, f(3) * 255, f(1) * 255];
}

function rgbToHsv(r: number, g: number, b: number): [number, number, number] {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
  let h = 0;
  if (d) h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [(h * 60 + 360) % 360, max ? d / max : 0, max];
}

export function parseHex(value: string): HSVA | null {
  const m = /^#?([0-9a-f]{6})([0-9a-f]{2})?$/i.exec((value ?? '').trim());
  if (!m) return null;
  const [h, s, v] = rgbToHsv(parseInt(m[1].slice(0, 2), 16), parseInt(m[1].slice(2, 4), 16), parseInt(m[1].slice(4, 6), 16));
  return { h, s, v, a: m[2] ? parseInt(m[2], 16) / 255 : 1 };
}

export function toHex(c: HSVA): string {
  const [r, g, b] = hsvToRgb(c.h, c.s, c.v);
  const a = Math.round(c.a * 255);
  return `#${hex2(r)}${hex2(g)}${hex2(b)}${a >= 255 ? '' : hex2(a)}`;
}

const HexColourField: React.FC<{
  value: string;
  onChange: (hex: string) => void;       // every whole colour (typed, or from the wheel, throttled)
  disabled?: boolean;
  placeholder?: string;
  ariaLabel?: string;
  labels?: { brightness?: string; opacity?: string; wheel?: string; move?: string };
}> = ({ value, onChange, disabled, placeholder, ariaLabel, labels }) => {
  const [text, setText] = React.useState(value);
  const [open, setOpen] = React.useState(false);
  const [c, setC] = React.useState<HSVA>(() => parseHex(value) ?? { h: 0, s: 0, v: 0.95, a: 1 });
  const [box, setBox] = React.useState<{ left: number; top?: number; bottom?: number } | null>(null);
  const btn = React.useRef<HTMLButtonElement | null>(null);
  const pop = React.useRef<HTMLDivElement | null>(null);
  const disc = React.useRef<HTMLDivElement | null>(null);
  const sent = React.useRef({ at: 0, timer: 0 as unknown as ReturnType<typeof setTimeout> | 0, last: value });

  // a new value from the script (a save, a nav) moves the box and the wheel to it
  React.useEffect(() => {
    setText(value);
    const next = parseHex(value);
    if (next) setC((old) => ({ ...next, h: next.s === 0 ? old.h : next.h }));
    sent.current.last = value;
  }, [value]);

  const send = (hex: string) => {
    const s = sent.current;
    if (hex.toLowerCase() === s.last.toLowerCase()) return;
    const go = () => { s.at = performance.now(); s.last = hex; onChange(hex); };
    if (s.timer) clearTimeout(s.timer);
    const wait = 120 - (performance.now() - s.at);
    if (wait <= 0) go();
    else s.timer = setTimeout(() => { s.timer = 0; go(); }, wait);
  };

  const put = (next: HSVA) => {
    setC(next);
    const hex = toHex(next);
    setText(hex);
    send(hex);
  };

  const typed = (v: string) => {
    setText(v);
    const t = v.trim().replace(/^([0-9a-f])/i, '#$1');
    const next = parseHex(t);
    if (next) { setC(next); send(t.toLowerCase()); }
  };

  // the pop-up's CSS is in design px (ui-scale): its width and the gaps here follow the screen too
  const s = wsScale();
  const W = 236 * s;
  const keepIn = (left: number, top: number) => ({
    left: Math.max(0, Math.min(window.innerWidth - W, left)),
    top: Math.max(0, Math.min(window.innerHeight - 40 * s, top)),
  });

  const place = () => {
    if (dragged) { setBox(keepIn(dragged.left, dragged.top)); return; }
    const r = btn.current?.getBoundingClientRect();
    if (!r) return;
    const H = 330 * s;
    const left = Math.max(8 * s, Math.min(window.innerWidth - W - 8 * s, r.right - W));
    setBox(r.top > H + 12 * s || r.top > window.innerHeight - r.bottom
      ? { left, bottom: window.innerHeight - r.top + 6 * s }     // up, as the arrow says (when there is room)
      : { left, top: r.bottom + 6 * s });
  };

  React.useEffect(() => {
    if (!open) return;
    const down = (e: MouseEvent) => {
      if (btn.current?.contains(e.target as Node) || pop.current?.contains(e.target as Node)) return;
      setOpen(false);
    };
    const key = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.preventDefault(); e.stopImmediatePropagation(); setOpen(false); } };
    const away = (e: Event) => { if (!pop.current?.contains(e.target as Node)) setOpen(false); };
    const resized = () => setOpen(false);
    document.addEventListener('mousedown', down, true);
    window.addEventListener('keydown', key, true);
    window.addEventListener('scroll', away, true);
    window.addEventListener('resize', resized);
    return () => {
      document.removeEventListener('mousedown', down, true);
      window.removeEventListener('keydown', key, true);
      window.removeEventListener('scroll', away, true);
      window.removeEventListener('resize', resized);
    };
  }, [open]);

  /* the grab bar: drag the window anywhere on the screen (kept inside it); remembered for the next opening */
  const grab = React.useRef<{ dx: number; dy: number } | null>(null);
  const startDrag = (e: React.PointerEvent<HTMLDivElement>) => {
    const r = pop.current?.getBoundingClientRect();
    if (!r || e.button !== 0) return;
    e.preventDefault();
    e.currentTarget.setPointerCapture(e.pointerId);
    grab.current = { dx: e.clientX - r.left, dy: e.clientY - r.top };
  };
  const moveDrag = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!grab.current) return;
    const at = keepIn(e.clientX - grab.current.dx, e.clientY - grab.current.dy);
    dragged = at;
    setBox(at);
  };
  const endDrag = () => { grab.current = null; };

  const pick = (e: React.PointerEvent<HTMLDivElement>) => {
    const r = disc.current?.getBoundingClientRect();
    if (!r) return;
    const dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
    const h = ((Math.atan2(dy, dx) * 180) / Math.PI + 450) % 360;      // 0 at the top, clockwise
    put({ ...c, h, s: Math.min(1, Math.hypot(dx, dy) / (r.width / 2)) });
  };

  const angle = ((c.h - 90) * Math.PI) / 180;
  const [r, g, b] = hsvToRgb(c.h, c.s, c.v);
  const swatch = `rgba(${r | 0}, ${g | 0}, ${b | 0}, ${c.a})`;

  return (
    <span className="w-hex">
      <span className="w-hex-chip" style={{ background: parseHex(text) ? swatch : 'transparent' }} aria-hidden="true" />
      <input
        type="text"
        dir="ltr"
        spellCheck={false}
        maxLength={9}
        value={text}
        placeholder={placeholder ?? '#rrggbb'}
        disabled={disabled}
        aria-label={ariaLabel}
        onChange={(e) => typed(e.target.value)}
      />
      <button
        type="button"
        ref={btn}
        className={`w-hex-open${open ? ' is-open' : ''}`}
        disabled={disabled}
        aria-expanded={open}
        aria-label={labels?.wheel ?? 'Colour wheel'}
        title={labels?.wheel ?? 'Colour wheel'}
        onClick={() => { if (!open) place(); setOpen(!open); }}
      >
        <span aria-hidden="true" />
      </button>
      {open && box && createPortal(
        <div ref={pop} className="w-hex-pop" style={{ left: box.left, top: box.top, bottom: box.bottom }}>
          <div
            className="w-hex-grab"
            title={labels?.move ?? 'Drag to move'}
            onPointerDown={startDrag}
            onPointerMove={moveDrag}
            onPointerUp={endDrag}
            onPointerCancel={endDrag}
          >
            <span>{labels?.wheel ?? 'Colour wheel'}</span>
            <i aria-hidden="true" />
          </div>
          <div
            ref={disc}
            className="w-hex-disc"
            style={{ filter: `brightness(${Math.max(0.08, c.v)})` }}
            onPointerDown={(e) => { e.currentTarget.setPointerCapture(e.pointerId); pick(e); }}
            onPointerMove={(e) => { if (e.buttons & 1) pick(e); }}
          >
            <i className="w-hex-dot" style={{ left: `${50 + Math.cos(angle) * c.s * 50}%`, top: `${50 + Math.sin(angle) * c.s * 50}%` }} />
          </div>
          <label className="w-hex-slider">
            <span>{labels?.brightness ?? 'Brightness'} · {Math.round(c.v * 100)}%</span>
            <input type="range" min={0} max={100} value={Math.round(c.v * 100)} onChange={(e) => put({ ...c, v: Number(e.target.value) / 100 })} />
          </label>
          <label className="w-hex-slider">
            <span>{labels?.opacity ?? 'Opacity'} · {Math.round(c.a * 100)}%</span>
            <input type="range" min={0} max={100} value={Math.round(c.a * 100)} onChange={(e) => put({ ...c, a: Number(e.target.value) / 100 })} />
          </label>
          <div className="w-hex-preview"><span style={{ background: swatch }} /><b dir="ltr">{toHex(c)}</b></div>
        </div>,
        document.body,
      )}
    </span>
  );
};

export default HexColourField;
