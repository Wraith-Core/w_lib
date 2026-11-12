/* ════════════════════════════════════════════════════════════════════════════
 * w_lib · kit/ui.tsx (4.4.0) - the board kit's small React parts, shared by every component of this frame
 *
 *   cls      class names, falsy parts dropped
 *   Txt      text from a script or a player: isolated (<bdi>), Arabic marked .wf-ar so the Latin small caps
 *            and letter-spacing of its box never reach Arabic letters (w_train/web/src/i18n.tsx)
 *   Card     the torn-paper card (.wf-wrap > .wf-card > .wf-card-body), with the red tick ribbon when focused
 *   Gauge    a thin track with a paper fill; red only when the CALLER says the value is critical
 *   glyphs   the kit's line glyphs (w_farming/web/src/kit/icons.tsx: one 24-unit grid, one stroke, round ends)
 *
 * The classes are the kit's (kit/kit.css, a copy of w_train's) or this frame's own parts (kit/kit-lib.css, wk-*).
 * ⚠️ Never an lb-* / wc-* / wst-* class here: nui/assets/store-theme-bridge.js adds the store theme's classes to
 *    those by a MutationObserver, and the store theme is not part of this design.
 * ════════════════════════════════════════════════════════════════════════════ */

import React, { CSSProperties } from 'react';
import { findIconDefinition, IconName, IconPrefix } from '@fortawesome/fontawesome-svg-core';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import Icon, { IconLike, texName } from '../wc/Icon';
import { texturePath } from '../wc/bootstrap';
import { isIconUrl } from '../utils/isIconUrl';
import { useLocales } from '../providers/LocaleProvider';

export const cls = (...parts: Array<string | false | null | undefined>) => parts.filter(Boolean).join(' ');

const AR_RE = /[؀-ۿݐ-ݿࡰ-ࣿﭐ-﷿ﹰ-﻿]/;

/** Arabic-Indic and Persian digits as Latin ones: the kit's figures are Latin everywhere (owner, 2026-11-08). */
export const latinDigits = (s: string) =>
  s.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660)).replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0));

export function Txt({ s }: { s: React.ReactNode }) {
  if (s === undefined || s === null || s === '' || s === false) return null;
  if (typeof s !== 'string' && typeof s !== 'number') return <>{s}</>;
  const v = latinDigits(String(s));
  return AR_RE.test(v) ? <bdi lang="ar" className="wf-ar">{v}</bdi> : <bdi>{v}</bdi>;
}

/** A figure: EB Garamond lining, tabular, left to right inside Arabic. */
export const Num: React.FC<{ v: React.ReactNode; className?: string }> = ({ v, className }) =>
  v === undefined || v === null || v === '' ? null : (
    <b className={cls('wf-num', className)}>{typeof v === 'string' ? latinDigits(v) : v}</b>
  );

export const Card: React.FC<{
  className?: string;
  bodyClass?: string;
  focus?: boolean;
  i?: number;
  style?: CSSProperties;
  children: React.ReactNode;
}> = ({ className, bodyClass, focus, i = 0, style, children }) => (
  <div className={cls('wf-wrap', 'wf-in', focus && 'is-focus', className)} style={{ ['--i' as string]: i, ...style }}>
    {focus && <div className="wf-tick" />}
    <div className="wf-card">
      <div className={cls('wf-card-body', bodyClass)}>{children}</div>
    </div>
  </div>
);

/**
 * A gauge: the value as a paper fill on a thin rule track.
 * ★ Red only when `critical` -- what is critical (a heavy bag, a broken tool, low health) is the caller's to say;
 *   the library never guesses it from the number.
 */
export const Gauge: React.FC<{ value?: number; critical?: boolean; className?: string }> = ({ value, critical, className }) => {
  const pct = Math.max(0, Math.min(100, Number(value) || 0));
  return (
    <span className={cls('wk-gauge', critical && 'is-critical', className)} role="meter" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100}>
      <span className="wk-gauge-fill" style={{ width: `${pct}%` }} />
    </span>
  );
};

/** ox_lib's `colorScheme` names a caller's warning colour: red / orange / yellow mean "critical" here. */
export const isCriticalScheme = (scheme?: unknown) =>
  typeof scheme === 'string' && /^(red|blood|orange|yellow|danger|bad)$/i.test(scheme.trim());

/* ── the glyphs ── */

const glyph = {
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.5,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  'aria-hidden': true,
  className: 'wf-glyph',
};

export const GlyphSearch = () => (
  <svg {...glyph}>
    <path d="M16.4 10.2c0 3.5-2.8 6.3-6.25 6.3S3.9 13.7 3.9 10.2 6.7 3.9 10.15 3.9s6.25 2.8 6.25 6.3Z" />
    <path d="M14.85 14.95l5.3 5.25" strokeWidth={2} />
  </svg>
);
export const GlyphCross = () => (
  <svg {...glyph}><path d="M5.6 5.4l12.9 13.1M18.4 5.5L5.5 18.45" strokeWidth={2} /></svg>
);
export const GlyphTick = () => (
  <svg {...glyph}><path d="M4.9 12.6l4.45 4.35 9.8-10.1" strokeWidth={2.4} /></svg>
);
/** Forward along the line: turns with the language (wrap it in .wf-flip). */
export const GlyphNext = () => (
  <svg {...glyph}><path d="M9.1 4.9l7.2 7.05-7.15 7.1" strokeWidth={2} /></svg>
);
export const GlyphPrev = () => (
  <svg {...glyph}><path d="M14.9 4.9l-7.2 7.05 7.15 7.1" strokeWidth={2} /></svg>
);
export const GlyphDown = () => (
  <svg {...glyph}><path d="M5.1 9.4l6.95 7.15 7.05-7.2" strokeWidth={2} /></svg>
);
export const GlyphDots = () => (
  <svg {...glyph}><path d="M5.9 12.05h.1M12 11.95h.1M18.05 12.05h.1" strokeWidth={2.8} /></svg>
);
/** A padlock: a private (job-only) section */
export const GlyphLock = () => (
  <svg {...glyph}>
    <path d="M6.1 10.6c3.95-.15 7.9-.15 11.85.05l-.1 8.85c-3.9.15-7.8.15-11.7-.05Z" />
    <path d="M8.55 10.5l.05-2.3c.05-2 1.55-3.55 3.45-3.5 1.9 0 3.4 1.6 3.35 3.55l-.05 2.3" />
    <path d="M12.05 14.2v2.1" strokeWidth={1.9} />
  </svg>
);

/** The close / back control at the end of a head: a cross, or the back arrow when there is a way up. */
export const HeadControl: React.FC<{ back?: boolean; label: string; onClick: () => void }> = ({ back, label, onClick }) => (
  <button type="button" className="wk-x" aria-label={label} title={label} onClick={onClick}>
    {back ? <span className="wf-flip"><GlyphPrev /></span> : <GlyphCross />}
  </button>
);

/* ── the icon of a row: bare, no box ──
 * A url or one of the frame's textures draws as it always did (wc/Icon). A FontAwesome name that is not one
 * of our textures (most scripts send 'fa-solid fa-user-check', 'users', 'chart') used to fall back to the
 * menu_bar dash; it is drawn now as the FontAwesome glyph it names (the library is registered in main.tsx).
 * Nothing at all for a name neither knows: an empty slot, never a placeholder blot. */
export const KitIcon: React.FC<{ icon?: unknown; className?: string }> = ({ icon, className }) => {
  if (icon === undefined || icon === null || icon === '') return null;
  const asIcon = icon as IconLike;
  const raw = typeof icon === 'string' ? icon : undefined;
  if (raw && isIconUrl(raw) && !texturePath(raw)) return <Icon icon={asIcon} className={className} />;
  const name = texName(asIcon);
  if (name && texturePath(name)) return <Icon icon={asIcon} className={className} />;
  if (name) {
    const prefix = Array.isArray(icon) ? (icon[0] as IconPrefix) : typeof icon === 'string' && /^fa-?r\b|fa-regular/.test(icon) ? 'far' : typeof icon === 'string' && /^fa-?b\b|fa-brands/.test(icon) ? 'fab' : 'fas';
    const def = findIconDefinition({ prefix, iconName: name as IconName }) ?? findIconDefinition({ prefix: 'fas', iconName: name as IconName });
    if (def) return <FontAwesomeIcon icon={def} className={className} />;
  }
  return null;
};

/* ── the frame's own words ──
 * The page gets locales/<lang>.json as `setLocale` (init.lua sendUiLocale), so ui.* keys added there arrive by
 * themselves. These are the fallbacks while one is missing (the other twelve locale files, the dev page). */
const FALLBACK = {
  en: { on: 'On', off: 'Off', search: 'Search…', nothing: 'Nothing here', amount: 'Amount', choose: '— Choose —', of: 'of', lockpick: 'Pick the lock', lockpick_hint: 'Move the pick with the mouse until it sits right, then turn the lock.', pins: 'Picks left', turn: 'Turn the lock', pick: 'Move the pick', mouse: 'Mouse', leave: 'Leave', key_move: 'Move', key_change: 'Change', key_pick: 'Choose', key_click: 'Click to choose', key_tick: 'Tick', fix: 'Fix it', ready: 'Ready', missing: 'Still missing: %s', missing_more: 'Still missing: %s and %d more', advanced: 'Advanced options' },
  ar: { on: 'نعم', off: 'لا', search: 'ابحث…', nothing: 'لا شيء هنا', amount: 'الكمية', choose: '— اختر —', of: 'من', lockpick: 'افتح القفل', lockpick_hint: 'حرّك الأداة بالفأرة حتى تستقر في مكانها، ثم أدر القفل.', pins: 'المحاولات الباقية', turn: 'أدر القفل', pick: 'حرّك الأداة', mouse: 'الفأرة', leave: 'اترك', key_move: 'تنقّل', key_change: 'غيّر', key_pick: 'اختر', key_click: 'اضغط للاختيار', key_tick: 'علّم', fix: 'أصلحه', ready: 'جاهز', missing: 'ينقصه: %s', missing_more: 'ينقصه: %s و%d غيره', advanced: 'خيارات متقدمة' },
} as const;
export type KitWord = keyof typeof FALLBACK.en;

export function useKit() {
  const { locale, rtl } = useLocales();
  const ui = (locale?.ui ?? {}) as Record<string, unknown>;
  const t = (key: KitWord | 'close' | 'back' | 'confirm' | 'cancel'): string => {
    const v = ui[key];
    if (typeof v === 'string' && v !== '') return v;
    if (key === 'close') return rtl ? 'إغلاق' : 'Close';
    if (key === 'back') return rtl ? 'رجوع' : 'Back';
    if (key === 'confirm') return rtl ? 'تأكيد' : 'Confirm';
    if (key === 'cancel') return rtl ? 'إلغاء' : 'Cancel';
    return (rtl ? FALLBACK.ar : FALLBACK.en)[key];
  };
  return { rtl, t };
}

/* ── the notebook's small parts (4.5.0, the builders' column look) ── */

/** A map pin: a place line's glyph. */
export const GlyphPin = () => (
  <svg {...glyph}>
    <path d="M12 21c-3.6-4.3-5.6-7.4-5.6-10.1a5.6 5.6 0 0 1 11.2 0c0 2.7-2 5.8-5.6 10.1z" />
    <circle cx="12" cy="10.6" r="1.9" />
  </svg>
);

export type KeyHint = { key: string; label?: string };

/** Key hints from a script: [{ key, label }] (or 'KEY label' strings), at most 8, short words only. */
export const keyList = (raw: unknown): KeyHint[] | null => {
  if (!Array.isArray(raw)) return null;
  const out: KeyHint[] = [];
  for (const k of raw) {
    if (out.length >= 8) break;
    if (k && typeof k === 'object' && typeof (k as KeyHint).key === 'string') {
      out.push({ key: String((k as KeyHint).key).slice(0, 16), label: (k as KeyHint).label != null ? String((k as KeyHint).label).slice(0, 48) : undefined });
    }
  }
  return out;
};

/** The keys row: the keys that work on this screen, a chip and a word each. `foot` = with a rule above it. */
export const Keys: React.FC<{ keys: KeyHint[]; foot?: boolean; className?: string }> = ({ keys, foot, className }) =>
  keys.length ? (
    <div className={cls('wk-keys', foot && 'is-foot', className)} aria-hidden="true">
      {keys.map((k, i) => (
        <span key={i}>
          <span className="wk-key">{k.key}</span>
          {k.label ? <Txt s={k.label} /> : null}
        </span>
      ))}
    </div>
  ) : null;

/** A place line: the pin glyph and the words ("فالنتاين · 12 م منك"); `miss` draws it as missing. */
export const Where: React.FC<{ text?: unknown; miss?: boolean }> = ({ text, miss }) =>
  typeof text === 'string' && text !== '' ? (
    <span className="wk-where">
      <span className={miss ? 'is-miss' : undefined}>
        <GlyphPin />
        <Txt s={text} />
      </span>
    </span>
  ) : null;

/** The ready line: a dot, the words, and «أصلحه» when there is something to go to. */
export const Ready: React.FC<{ ok?: boolean; text: React.ReactNode; fixLabel?: string; onFix?: () => void }> = ({ ok, text, fixLabel, onFix }) => (
  <div className={cls('wk-ready', ok && 'is-ok')} role="status">
    <i className="wk-ready-dot" aria-hidden="true" />
    <span className="wk-ready-text">{typeof text === 'string' ? <Txt s={text} /> : text}</span>
    {!ok && onFix && fixLabel ? (
      <button type="button" className="wf-btn" onClick={onFix}>
        <Txt s={fixLabel} />
      </button>
    ) : null}
  </div>
);
