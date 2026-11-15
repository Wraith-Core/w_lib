/* ════════════════════════════════════════════════════════════════════════════
 * w_lib · features/jomenu -- w.menu (jo.menu), drawn in the board kit.
 *
 * ★ The whole jo_libs menu API keeps working (w.menu.create, :addItem, :push, w.menu.show, sliders,
 *   prices, statistics, child menus, tiles ...): modules/menu/client.lua is unchanged in what it sends.
 *   What changed is WHERE it draws -- here, in w_lib's own frame -- so a resource using it needs
 *   no ui_page at all. State lives in model.ts; this file only draws it and turns keys into actions.
 *
 * ★ The look is the library's, not jo's: the torn card, the paper band under the cursor, the kit's
 *   stepper and figures. Red is a mark only (the card's ribbon, a penalty in a statistic).
 * ════════════════════════════════════════════════════════════════════════════ */

import React, { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, useSyncExternalStore } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { postNui } from '../../utils/postNui';
import { wcAsset } from '../../wc/bootstrap';
import { Card, cls, Gauge, GlyphNext, GlyphPrev, HeadControl, Txt, useKit } from '../../kit/ui';
import { hub, normPrice, OwnerStore, paletteName, toArray, type Any, type JoItem, type JoSlider, type JoStat } from './model';
import './jomenu.css';

/* ── assets ── */

const isUrl = (x: string) => x.includes('://');
const iconSrc = (x: string) => (isUrl(x) ? x : wcAsset(`jomenu/icons/${x}.webp`));
const spriteSrc = (x: string) => (isUrl(x) ? x : wcAsset(`jomenu/${x}.webp`));
const GOLD = () => wcAsset('jomenu/gold.webp');

/* ── text from a script: plain, or a little safe markup (jo allowed HTML in titles) ── */

const SAFE_TAGS = new Set(['B', 'I', 'U', 'S', 'STRONG', 'EM', 'BR', 'SPAN', 'SMALL', 'SUP', 'SUB']);
const AR = /[؀-ۿݐ-ݿࡰ-ࣿﭐ-﷿ﹰ-﻿]/;
const htmlCache = new Map<string, string>();

/** Only a few inline tags survive, and no attribute but a plain class: no style, no handler, no link. */
function safeHtml(html: string): string {
  const hit = htmlCache.get(html);
  if (hit !== undefined) return hit;
  const t = document.createElement('template');
  t.innerHTML = html;
  const walk = (node: Node) => {
    for (const child of Array.from(node.childNodes)) {
      if (child.nodeType === Node.ELEMENT_NODE) {
        const el = child as Element;
        if (!SAFE_TAGS.has(el.tagName)) {
          // a tag we do not keep leaves its text behind (a <script>/<style> leaves nothing)
          if (el.tagName === 'SCRIPT' || el.tagName === 'STYLE') el.remove();
          else {
            walk(el);
            el.replaceWith(...Array.from(el.childNodes));
          }
          continue;
        }
        for (const a of Array.from(el.attributes)) {
          if (a.name !== 'class' || !/^[\w\s-]*$/.test(a.value)) el.removeAttribute(a.name);
        }
        walk(el);
      } else if (child.nodeType !== Node.TEXT_NODE) child.remove();
    }
  };
  walk(t.content);
  const out = t.innerHTML;
  if (htmlCache.size > 300) htmlCache.clear();
  htmlCache.set(html, out);
  return out;
}

const Rich: React.FC<{ s: unknown }> = ({ s }) => {
  if (s === undefined || s === null || s === false || s === '') return null;
  const v = String(s);
  if (!v.includes('<')) return <Txt s={v} />;
  return <bdi className={AR.test(v) ? 'wf-ar' : undefined} dangerouslySetInnerHTML={{ __html: safeHtml(v) }} />;
};

/* ── palettes: a strip of the game's tints, read once per name ── */

const paletteCache = new Map<string, Promise<string[]>>();

function loadPalette(name: string): Promise<string[]> {
  let p = paletteCache.get(name);
  if (!p) {
    p = new Promise<string[]>((resolve) => {
      const img = new Image();
      img.onload = () => {
        try {
          const c = document.createElement('canvas');
          c.width = img.naturalWidth;
          c.height = img.naturalHeight;
          const ctx = c.getContext('2d');
          if (!ctx) return resolve([]);
          ctx.drawImage(img, 0, 0);
          const row = Math.floor((c.height - 1) / 2);
          const data = ctx.getImageData(0, row, c.width, 1).data;
          const out: string[] = [];
          for (let x = 0; x < c.width; x++) {
            const i = x * 4;
            out.push('#' + [data[i], data[i + 1], data[i + 2]].map((v) => v.toString(16).padStart(2, '0')).join(''));
          }
          resolve(out);
        } catch {
          resolve([]);
        }
      };
      img.onerror = () => resolve([]);
      img.src = wcAsset(`jomenu/palettes/${name}.png`);
    });
    paletteCache.set(name, p);
  }
  return p;
}

function usePalette(name: string | undefined): string[] | null {
  const [colours, setColours] = useState<string[] | null>(null);
  useEffect(() => {
    let live = true;
    setColours(null);
    if (name) void loadPalette(name).then((c) => live && setColours(c));
    return () => {
      live = false;
    };
  }, [name]);
  return colours;
}

/* ── the store of the menu on screen ── */

function useActive(): OwnerStore | undefined {
  useSyncExternalStore(hub.subscribe, hub.getVersion);
  return hub.active();
}

/* ── prices ── */

const fmtGold = (m: number) => (m % 1 === 0 ? String(m) : m.toFixed(2));

const Money: React.FC<{ n: number; s: OwnerStore }> = ({ n, s }) => {
  if (!n) return <span className="wjm-free">{s.lang('free')}</span>;
  const cents = n % 1 === 0 ? '' : (n % 1).toFixed(2).substring(2);
  return (
    <span className="wjm-money">
      <small>{s.lang('devise')}</small>
      <b className="wf-num">{Math.trunc(n)}</b>
      {cents ? <small className="wjm-cents">{cents}</small> : null}
    </span>
  );
};

const Gold: React.FC<{ n: number }> = ({ n }) => (
  <span className="wjm-gold">
    <img src={GOLD()} alt="" />
    <b className="wf-num">{fmtGold(n)}</b>
  </span>
);

const Price: React.FC<{ p: Any; s: OwnerStore }> = ({ p, s }) => {
  if (p === undefined || p === false || p === null) return null;
  if (Array.isArray(p)) {
    if (p.length === 1 && p[0]?.money === 0) return <span className="wjm-free">{s.lang('free')}</span>;
    const rank = (e: Any) => (e?.item ? 0 : e?.gold ? 1 : e?.money ? 2 : 3);
    const list = [...p].filter((e) => e && typeof e === 'object').sort((a, b) => rank(a) - rank(b));
    return (
      <span className="wjm-cost">
        {list.map((e, i) => (
          <React.Fragment key={i}>
            {i > 0 && <span className="wjm-plus">+</span>}
            {e.gold ? (
              <Gold n={Number(e.gold)} />
            ) : e.money && e.money > 0 ? (
              <Money n={Number(e.money)} s={s} />
            ) : e.item ? (
              <span className="wjm-cost-item">
                <b className="wf-num">{e.quantity || 1}</b>
                <span className="wjm-x">×</span>
                {e.image ? <img src={iconSrc(String(e.image))} alt="" /> : null}
                {!e.tooltip || !e.image ? <Rich s={e.label ?? e.item} /> : null}
              </span>
            ) : null}
          </React.Fragment>
        ))}
      </span>
    );
  }
  const n = typeof p === 'number' ? p : 'money' in p ? Number(p.money) : null;
  return (
    <span className="wjm-cost">
      {p.gold ? <Gold n={Number(p.gold)} /> : null}
      {n !== null ? <Money n={n} s={s} /> : null}
    </span>
  );
};

/* ── colour swatches (palette sliders, sprite / colour values, the row preview) ── */

const ColorBox: React.FC<{ c: Any }> = ({ c }) => {
  const rgb = c?.rgb;
  const pal = rgb ? undefined : paletteName(c?.palette);
  const colours = usePalette(pal);
  let tints: Any[];
  if (rgb) tints = typeof rgb === 'string' ? rgb.split(',') : toArray(rgb);
  else if (c?.tints) tints = toArray(c.tints);
  else tints = [c?.tint0, Number.isInteger(c?.tint1) ? c.tint1 : undefined, Number.isInteger(c?.tint2) ? c.tint2 : undefined].filter((v) => v !== undefined && v !== false);
  tints = tints.slice(0, 3);
  const colour = (k: number) => (rgb ? String(tints[k]).trim() : colours?.[Number(tints[k])] || '#000');
  return (
    <span className={cls('wjm-swatch', `n${Math.max(1, tints.length)}`, c?.style === 'vertical-lines' && 'is-lines')}>
      {tints.map((_, k) => (
        <i key={k} style={{ background: colour(k) }} />
      ))}
    </span>
  );
};

const SpriteBox: React.FC<{ v: Any }> = ({ v }) => {
  if (!v || typeof v !== 'object') return <span className="wjm-sprite-box" />;
  let body: React.ReactNode;
  if (v.sprite) body = <img className={v.class} src={spriteSrc(String(v.sprite))} alt="" />;
  else if (v.rgb) body = <ColorBox c={v} />;
  else if (v.palette && typeof v.palette === 'object') body = <ColorBox c={v.palette} />;
  else body = <ColorBox c={v} />;
  return (
    <span className="wjm-sprite-box">
      {body}
      {(v.tagColor || v.tagText) && (
        <span className="wjm-tag" style={{ background: v.tagColor || '#F2F2F2', color: v.tagTextColor || '#0B0A0A' }}>
          {v.tagText}
        </span>
      )}
      {v.icon && <img className="wjm-sprite-icon" src={iconSrc(String(v.icon))} alt="" />}
    </span>
  );
};

/** The little square at the end of a row: the colour (or sprite) its sliders are on now. */
const RowPreview: React.FC<{ it: JoItem }> = ({ it }) => {
  const palettes = it.sliders.filter((s) => s.type === 'palette');
  for (const s of it.sliders) {
    if (s.type === 'switch' && s.values.length > 1) return null;
    if (s.type === 'palette') {
      const c = { palette: s.palette || s.tint, tint0: palettes[0]?.current, tint1: palettes[1]?.current, tint2: palettes[2]?.current };
      return (
        <span className="wjm-preview">
          <ColorBox c={c} />
        </span>
      );
    }
    if ((s.type === 'sprite' || s.type === 'color') && s.values.length) {
      return (
        <span className="wjm-preview">
          <SpriteBox v={s.values[Number(s.current) - 1]} />
        </span>
      );
    }
  }
  return null;
};

/* ── statistics ── */

const Stat: React.FC<{ st: JoStat; s: OwnerStore }> = ({ st, s }) => {
  const label = st.translateLabel ? s.lang(st.label) : st.label;
  const v = st.value;
  let body: React.ReactNode = null;
  if (typeof v !== 'object' || v === null) {
    body = (
      <span className="wjm-stat-value">
        <Rich s={st.translateValue ? s.lang(v) : v} />
      </span>
    );
  } else if (st.type === 'bar') {
    const arr = toArray<number>(v).map(Number);
    body = (
      <span className={cls('wjm-bars', st.class)}>
        {Array.from({ length: 10 }, (_, g) => {
          const k = g + 1;
          const on = k <= arr[0];
          const maybe = !on && arr.length !== 1 && k <= arr[1];
          return <i key={k} className={cls(on && 'is-on', maybe && 'is-maybe')} />;
        })}
      </span>
    );
  } else if (st.type === 'bar-style') {
    body = (
      <span className={cls('wjm-bars', st.class)}>
        {toArray<string>(v).map((c, k) => (
          <i key={k} className={cls(c === 'active' && 'is-on', c === 'possible' && 'is-maybe', c)} />
        ))}
      </span>
    );
  } else if (st.type === 'weapon-bar') {
    const arr = toArray<number>(v).map(Number);
    body = <Gauge className="wjm-stat-gauge" value={arr[1] ? (arr[0] / arr[1]) * 100 : 0} critical={/penalty/.test(st.class)} />;
  } else if (st.type === 'icon') {
    body = (
      <span className="wjm-stat-icons">
        {toArray(v).map((e: Any, k) => (
          <img key={k} src={iconSrc(String(typeof e === 'string' ? e : e?.icon))} style={typeof e === 'object' && e?.opacity != null ? { opacity: e.opacity } : undefined} alt="" />
        ))}
      </span>
    );
  }
  return (
    <div className="wjm-stat">
      <span className="wjm-stat-label">
        <Rich s={label} />
      </span>
      {body}
    </div>
  );
};

/* ── sliders ── */

const Stepper: React.FC<{ text: React.ReactNode; onLeft: () => void; onRight: () => void; disL?: boolean; disR?: boolean; here?: boolean }> = ({
  text,
  onLeft,
  onRight,
  disL,
  disR,
  here,
}) => (
  <span className={cls('wf-stepper', 'wjm-stepper', here && 'is-here')}>
    <span className={cls('wf-stepper-arrow', disL && 'is-dis')} onClick={onLeft} role="button">
      <GlyphPrev />
    </span>
    <span className="wf-stepper-value">{text}</span>
    <span className={cls('wf-stepper-arrow', disR && 'is-dis')} onClick={onRight} role="button">
      <GlyphNext />
    </span>
  </span>
);

const valueLabel = (s: JoSlider, store: OwnerStore) => {
  const v = s.values[Number(s.current) - 1];
  const label = v && typeof v === 'object' ? v.label : v;
  if (label === undefined || label === null || label === '') return null;
  return s.translate ? store.lang(label) : label;
};

const ends = (s: JoSlider) => {
  const len = s.values.length;
  const cur = Number(s.current);
  return { disL: len <= 1 || (!s.looped && cur === 1), disR: len <= 1 || (!s.looped && cur === len) };
};

const SliderHead: React.FC<{ s: JoSlider; store: OwnerStore }> = ({ s, store }) =>
  s.title ? (
    <div className="wjm-sl-title">
      <Rich s={s.translate ? store.lang(s.title) : s.title} />
    </div>
  ) : null;

const SliderDesc: React.FC<{ s: JoSlider }> = ({ s }) =>
  s.description ? (
    <div className="wjm-sl-desc">
      <Rich s={s.description} />
    </div>
  ) : null;

const DefaultSlider: React.FC<{ s: JoSlider; i: number; store: OwnerStore }> = ({ s, i, store }) => {
  if (!(s.values.length > 1 || s.forceDisplay)) return null;
  const cur = Number(s.current);
  const len = s.values.length;
  const label = valueLabel(s, store);
  const count = store.sprintf(store.lang('of'), cur, len);
  return (
    <div className="wjm-slider" data-slider={i}>
      <SliderHead s={s} store={store} />
      <Stepper
        here
        text={label !== null ? <><Rich s={label} /><small className="wjm-of">{count}</small></> : <Txt s={count} />}
        onLeft={() => store.sliderLeft(i)}
        onRight={() => store.sliderRight(i)}
        {...ends(s)}
      />
      {len <= 40 ? (
        <span className="wjm-boxes">
          {s.values.map((v: Any, k) => (
            <i
              key={k}
              className={cls(k + 1 < cur && 'is-on', k + 1 === cur && 'is-here', v && typeof v === 'object' && typeof v.class === 'string' && v.class)}
              onClick={() => store.setSliderCurrent(i, k + 1)}
            />
          ))}
        </span>
      ) : (
        <Gauge className="wjm-boxes-gauge" value={(cur / len) * 100} />
      )}
      <SliderDesc s={s} />
    </div>
  );
};

/** A palette slider: the strip of the game's tints, the cursor on the chosen one; drag or click to pick. */
const PaletteSlider: React.FC<{ s: JoSlider; i: number; store: OwnerStore }> = ({ s, i, store }) => {
  const name = paletteName(s.palette ?? s.tint);
  const colours = usePalette(name);
  const strip = useRef<HTMLDivElement | null>(null);

  // jo normalises the slider once its strip is known: min / max inside the strip, current inside them
  useEffect(() => {
    if (!colours) return;
    const N = colours.length - 1;
    if (s.min == null) s.min = 0;
    if (s.current == null) s.current = s.min;
    if (N < 0) {
      s.max = -1;
      return;
    }
    if (s.max == null || s.max > N) s.max = N;
    if ((s.min ?? 0) > s.max) s.min = 0;
    s.current = Math.max(s.min ?? 0, Math.min(Number(s.current), s.max));
    const off = new Set(toArray<number>(s.disabledTints).map(Number));
    if (off.has(s.current)) {
      for (let k = s.min ?? 0; k <= s.max; k++) {
        if (!off.has(k)) {
          s.current = k;
          break;
        }
      }
    }
    hub.bump();
  }, [colours, s]);

  const enabled = useMemo(() => {
    if (!colours || s.max == null || s.max < 0) return [] as number[];
    const off = new Set(toArray<number>(s.disabledTints).map(Number));
    const out: number[] = [];
    for (let k = s.min ?? 0; k <= s.max; k++) if (!off.has(k)) out.push(k);
    return out;
  }, [colours, s.min, s.max, s.disabledTints]);

  const pos = Math.max(0, enabled.indexOf(Number(s.current)));
  const len = enabled.length;

  const pickAt = useCallback(
    (clientX: number) => {
      const el = strip.current;
      if (!el || !len) return;
      const r = el.getBoundingClientRect();
      let f = (clientX - r.left) / r.width;
      if (document.documentElement.dir === 'rtl') f = 1 - f;
      const k = Math.min(Math.max(Math.floor(f * len), 0), len - 1);
      store.setSliderCurrent(i, enabled[k]);
    },
    [enabled, len, i, store]
  );

  const onDown = (e: React.MouseEvent) => {
    pickAt(e.clientX);
    let raf = 0;
    const move = (ev: MouseEvent) => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => pickAt(ev.clientX));
    };
    const up = () => {
      window.removeEventListener('mousemove', move);
      window.removeEventListener('mouseup', up);
    };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
  };

  return (
    <div className="wjm-slider" data-slider={i}>
      <SliderHead s={s} store={store} />
      <Stepper
        here
        text={<Txt s={len ? store.sprintf(store.lang('of'), pos + 1, len) : '…'} />}
        onLeft={() => store.sliderLeft(i)}
        onRight={() => store.sliderRight(i)}
        disL={!len || pos === 0}
        disR={!len || pos === len - 1}
      />
      <div className="wjm-strip" ref={strip} onMouseDown={onDown}>
        {enabled.map((k) => (
          <i key={k} style={{ background: colours?.[k] }} />
        ))}
        {len > 0 && <span className="wjm-strip-cursor" style={{ insetInlineStart: `${((pos + 0.5) / len) * 100}%` }} />}
      </div>
      <SliderDesc s={s} />
    </div>
  );
};

/** A grid slider: one axis (a line) or two (a square); drag the marker, or W A S D. */
const GridSlider: React.FC<{ s: JoSlider; i: number; store: OwnerStore }> = ({ s, i, store }) => {
  const box = useRef<HTMLDivElement | null>(null);
  const axes = s.values.filter(Boolean);
  const labels = toArray<string>(s.labels).map((l) => (l == null ? '' : s.translate ? store.lang(l) : l));
  const frac = (ax: Any) => {
    const min = Number(ax?.min ?? 0);
    const max = Number(ax?.max ?? 1);
    return max === min ? 0 : (Number(ax?.current ?? min) - min) / (max - min);
  };
  const x = frac(s.values[0]);
  const y = s.values[1] ? frac(s.values[1]) : 0.5;

  const pickAt = (cx: number, cy: number) => {
    const el = box.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    const fx = Math.max(0, Math.min(1, (cx - r.left) / r.width));
    const fy = Math.max(0, Math.min(1, (cy - r.top) / r.height));
    store.setSliderCurrent(i, [fx, fy]);
  };

  const onDown = (e: React.MouseEvent) => {
    pickAt(e.clientX, e.clientY);
    let raf = 0;
    const move = (ev: MouseEvent) => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => pickAt(ev.clientX, ev.clientY));
    };
    const up = () => {
      window.removeEventListener('mousemove', move);
      window.removeEventListener('mouseup', up);
    };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
  };

  return (
    <div className="wjm-slider" data-slider={i}>
      <SliderHead s={s} store={store} />
      <div className={cls('wjm-grid', axes.length >= 2 ? 'is-2d' : 'is-1d')}>
        <span className="wjm-grid-l">
          <Rich s={labels[0]} />
        </span>
        <div className="wjm-grid-mid">
          {axes.length >= 2 && labels[2] ? (
            <span className="wjm-grid-t">
              <Rich s={labels[2]} />
            </span>
          ) : null}
          <div className="wjm-grid-box" ref={box} onMouseDown={onDown} dir="ltr">
            <span className="wjm-grid-marker" style={{ left: `${x * 100}%`, top: `${y * 100}%` }} />
          </div>
          {axes.length >= 2 && labels[3] ? (
            <span className="wjm-grid-t">
              <Rich s={labels[3]} />
            </span>
          ) : null}
        </div>
        <span className="wjm-grid-r">
          <Rich s={labels[1]} />
        </span>
      </div>
      <SliderDesc s={s} />
    </div>
  );
};

/** A sprite / colour slider: a strip of swatches, the chosen one framed. */
const SpriteSlider: React.FC<{ s: JoSlider; i: number; store: OwnerStore }> = ({ s, i, store }) => {
  const strip = useRef<HTMLDivElement | null>(null);
  const cur = Number(s.current);
  useEffect(() => {
    const t = setTimeout(() => strip.current?.querySelector<HTMLElement>(`[data-k="${cur}"]`)?.scrollIntoView({ block: 'nearest', inline: 'nearest' }), 50);
    return () => clearTimeout(t);
  }, [cur]);
  if (!(s.values.length > 1 || s.forceDisplay)) return null;
  return (
    <div className="wjm-slider" data-slider={i}>
      <SliderHead s={s} store={store} />
      <Stepper
        here
        text={<Txt s={store.sprintf(store.lang('of'), cur, s.values.length)} />}
        onLeft={() => store.sliderLeft(i)}
        onRight={() => store.sliderRight(i)}
        {...ends(s)}
      />
      <div className={cls('wjm-sprites', s.values.length <= 8 && 'is-center')} ref={strip}>
        {s.values.map((v: Any, k) => {
          const n = k + 1;
          const near = Math.abs(n - cur) <= 10;
          return (
            <span key={k} data-k={n} className={cls('wjm-sprite', n === cur && 'is-here')} onClick={() => store.setSliderCurrent(i, n)}>
              {near && <SpriteBox v={v} />}
              {near && s.displayTick && s.tickIndex === k && <span className="wjm-sprite-tick" />}
            </span>
          );
        })}
      </div>
      <SliderDesc s={s} />
    </div>
  );
};

const PanelSlider: React.FC<{ s: JoSlider; i: number; store: OwnerStore }> = (p) => {
  switch (p.s.type) {
    case 'switch':
      return null;
    case 'palette':
      return <PaletteSlider {...p} />;
    case 'grid':
      return <GridSlider {...p} />;
    case 'sprite':
    case 'color':
      return <SpriteSlider {...p} />;
    default:
      return <DefaultSlider {...p} />;
  }
};

/* ── rows and tiles ── */

const RowSwitch: React.FC<{ s: JoSlider; i: number; here: boolean; store: OwnerStore }> = ({ s, i, here, store }) => {
  const label = valueLabel(s, store);
  const { disL, disR } = ends(s);
  return (
    <span className={cls('wjm-switch', here && 'is-here')} onClick={(e) => e.stopPropagation()} data-slider={i}>
      {here && (
        <span className={cls('wjm-switch-arrow', disL && 'is-dis')} onClick={() => store.sliderLeft(i)} role="button">
          <GlyphPrev />
        </span>
      )}
      <span className="wjm-switch-value">
        <Rich s={label} />
      </span>
      {here && (
        <span className={cls('wjm-switch-arrow', disR && 'is-dis')} onClick={() => store.sliderRight(i)} role="button">
          <GlyphNext />
        </span>
      )}
    </span>
  );
};

const Row: React.FC<{ it: JoItem; pos: number; here: boolean; withIcons: boolean; store: OwnerStore }> = ({ it, pos, here, withIcons, store }) => {
  const [lit, setLit] = useState(false);
  const title = it.translate ? store.lang(it.title) : it.title;
  const right = it.priceRight === true ? store.itemPrice(it) : it.priceRight !== false && it.priceRight != null ? normPrice(it.priceRight) : false;
  return (
    <div
      role="button"
      data-pos={pos}
      className={cls('wf-row', 'wk-row', 'wjm-row', (here || lit) && 'is-here', here && 'is-cursor', it.disabled && 'is-off', withIcons && it.iconSize !== 'small' && 'is-tall')}
      onMouseEnter={() => setLit(true)}
      onMouseLeave={() => setLit(false)}
      onClick={() => store.pick(pos)}
    >
      {withIcons && (
        <span className={cls('wjm-ico', !it.icon && 'is-empty', it.disabled && 'is-grey', it.iconClass)}>{it.icon ? <img src={iconSrc(String(it.icon))} alt="" /> : null}</span>
      )}
      <span className="wf-row-main">
        <span className="wf-row-name">
          {it.prefix ? <img className={cls('wjm-prefix', it.disabled && 'is-grey')} src={iconSrc(String(it.prefix))} alt="" /> : null}
          <Rich s={title} />
        </span>
        {it.subtitle ? (
          <span className="wk-desc">
            <Rich s={it.subtitle} />
          </span>
        ) : null}
      </span>
      {!it.disabled && it.sliders.map((s, i) => (s.type === 'switch' ? <RowSwitch key={i} s={s} i={i} here={here} store={store} /> : null))}
      {it.previewSlider && <RowPreview it={it} />}
      {it.textRight ? (
        <span className={cls('wjm-text-right', it.textRightClass)}>
          <Rich s={it.translateTextRight ? store.lang(it.textRight) : it.textRight} />
        </span>
      ) : null}
      {!it.iconRight && right !== false ? (
        <span className="wjm-price-right">
          <Price p={right} s={store} />
        </span>
      ) : null}
      {it.iconRight ? (
        <span className="wjm-icon-right">
          <img src={iconSrc(String(it.iconRight))} alt="" />
        </span>
      ) : null}
    </div>
  );
};

const Tile: React.FC<{ it: JoItem; pos: number; here: boolean; store: OwnerStore }> = ({ it, pos, here, store }) => (
  <div role="button" data-pos={pos} className={cls('wjm-tile', here && 'is-here', it.disabled && 'is-off')} onClick={() => store.pick(pos)}>
    {it.icon ? <img className={cls('wjm-tile-img', it.iconClass)} src={iconSrc(String(it.icon))} alt="" /> : null}
    {it.iconRight ? <img className="wjm-tile-corner" src={iconSrc(String(it.iconRight))} alt="" /> : null}
    {typeof it.quantity !== 'boolean' && it.quantity != null ? (
      <span className={cls('wjm-tile-qty', it.quantityCircleClass)}>
        <b className="wf-num">{it.quantity}</b>
      </span>
    ) : null}
    {it.quality !== false && it.quality > 0 ? (
      <span className={cls('wjm-tile-stars', it.qualityClass)}>
        {[1, 2, 3].map((k) => (
          <i key={k} className={cls(k > (it.quality as number) && 'is-off')} />
        ))}
      </span>
    ) : null}
    {it.stars ? (
      <span className={cls('wjm-tile-stars', it.starsClass)}>
        {Array.from({ length: Number(it.stars[1]) || 0 }, (_, k) => (
          <i key={k} className={cls(k + 1 > Number(it.stars?.[0]) && 'is-off')} />
        ))}
      </span>
    ) : null}
  </div>
);

/* ── the menu ── */

const JoMenu: React.FC = () => {
  const store = useActive();
  const { rtl, t } = useKit();
  const rowsRef = useRef<HTMLDivElement | null>(null);

  useNuiEvent<{ owner?: string; msg?: Any }>('wmenu', (data) => hub.receive(data?.owner, data?.msg));
  // The host asks until the frame answers; from then on it stops queueing (modules/menu/g_client.lua).
  useNuiEvent('wmenu:ping', () => void postNui('wmenu:ready'));

  /* keys: one listener, reading the store of the menu on screen at the moment of the press */
  useEffect(() => {
    const held: Record<string, boolean> = {};
    const once: Record<string, boolean> = {};

    const onDown = (e: KeyboardEvent) => {
      const s = hub.active();
      if (!s) return;
      const m = s.cMenu;
      const tile = m?.type === 'tile';
      held[e.code] = true;

      if (e.key === 'Enter' || e.key === 'Backspace' || e.key === 'Escape') {
        e.preventDefault();
        if (once[e.key]) return; // one action per press, never the key's auto-repeat
        once[e.key] = true;
        if (performance.now() - s.shownAt < 100) return; // the press that opened the menu
        if (e.key === 'Enter') s.menuEnter();
        else s.menuBack();
        return;
      }

      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault();
          s.menuDown();
          break;
        case 'ArrowUp':
          e.preventDefault();
          s.menuUp();
          break;
        case 'ArrowLeft':
          e.preventDefault();
          if (tile) s.menuLeft();
          else s.sliderLeft();
          break;
        case 'ArrowRight':
          e.preventDefault();
          if (tile) s.menuRight();
          else s.sliderRight();
          break;
      }
      switch (e.code) {
        case 'KeyQ':
          if (tile) s.sliderLeft();
          else s.sliderLeft(1);
          break;
        case 'KeyE':
          if (tile) s.sliderRight();
          else s.sliderRight(1);
          break;
        case 'Numpad4':
        case 'Digit4':
          s.sliderLeft(tile ? 1 : 2);
          break;
        case 'Numpad6':
        case 'Digit6':
          s.sliderRight(tile ? 1 : 2);
          break;
      }
      if (held.KeyW) s.gridUp();
      if (held.KeyA) s.gridLeft();
      if (held.KeyS) s.gridDown();
      if (held.KeyD) s.gridRight();
    };

    const onUp = (e: KeyboardEvent) => {
      delete held[e.code];
      delete once[e.key];
    };

    const onWheel = (e: WheelEvent) => {
      const s = hub.active();
      if (!s) return;
      const target = e.target as HTMLElement | null;
      const sl = target?.closest?.('[data-slider]') as HTMLElement | null;
      if (sl) {
        const i = Number(sl.dataset.slider);
        if (e.deltaY < 0) s.sliderLeft(i);
        else s.sliderRight(i);
        return;
      }
      const tile = s.cMenu?.type === 'tile';
      if (e.deltaY < 0) {
        if (tile) s.menuLeft();
        else s.menuUp();
      } else if (tile) s.menuRight();
      else s.menuDown();
    };

    window.addEventListener('keydown', onDown);
    window.addEventListener('keyup', onUp);
    window.addEventListener('wheel', onWheel, { passive: true });
    return () => {
      window.removeEventListener('keydown', onDown);
      window.removeEventListener('keyup', onUp);
      window.removeEventListener('wheel', onWheel);
    };
  }, []);

  const m = store?.cMenu;
  const cIndex = store?.cIndex ?? 0;

  /* whole rows only: when the card is short of room (a long detail under the list), the list ends at the
     last row that fits instead of showing half a row */
  useLayoutEffect(() => {
    const el = rowsRef.current;
    if (!el || !el.classList.contains('wjm-rows')) return;
    el.style.maxHeight = '';
    const room = el.clientHeight;
    let used = 0;
    for (const row of Array.from(el.children) as HTMLElement[]) {
      const h = row.offsetHeight;
      if (used + h > room + 1) break;
      used += h;
    }
    if (used > 0 && used < el.scrollHeight - 1) el.style.maxHeight = `${used}px`;
  });

  /* the cursor row stays in view: the window moves only when the cursor would leave it */
  useEffect(() => {
    rowsRef.current?.querySelector<HTMLElement>(`[data-pos="${cIndex}"]`)?.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  }, [cIndex, m?.id, m?.key]);

  if (!store || !m) return null;

  const items = store.cItems;
  const it = store.cItem;
  const n = items.length;
  const tile = m.type === 'tile';
  const withIcons = !tile && items.some((x) => x.icon);
  const tall = withIcons && items.some((x) => x.icon && x.iconSize !== 'small');
  const hasBack = store.parentTree.length > 0 || m.displayBackButton;
  const title = m.translateTitle ? store.lang(m.title) : m.title;
  const subtitle = m.translateSubtitle ? store.lang(m.subtitle) : m.subtitle;
  const content = !store.showLoader && n > 0;

  const itemPrice = store.itemPrice(it);
  const price = itemPrice !== false ? itemPrice : m.price;
  const priceTitle = (it && it.priceTitle) || m.priceTitle || store.lang('price');
  const description = it && it.description ? (it.translateDescription ? store.lang(it.description) : it.description) : '';
  const panel = it && !it.disabled ? it.sliders.map((s, i) => ({ s, i })).filter(({ s }) => s.type !== 'switch') : [];

  return (
    <div className={cls('wf', 'wk-menu', 'wjm', rtl && 'is-rtl')}>
      <div className={cls('wk-side-scrim', store.right && 'is-end')} />
      <div className={cls('wk-dock', 'wjm-dock', store.right && 'is-end')}>
        <header className="wf-mast wf-in">
          <span className="wf-mark">
            <Rich s={title} />
          </span>
          <span className="wf-mast-rule" />
          {hasBack && <HeadControl back label={t('back')} onClick={() => store.menuBack()} />}
        </header>

        <Card focus i={1} bodyClass="wjm-body">
          {subtitle ? (
            <div className="wk-kick">
              <Rich s={subtitle} />
            </div>
          ) : null}

          {!content ? (
            store.showLoader || (n === 0 && !tile) ? (
              <div className="wjm-loading" aria-label="…">
                <i />
                <i />
                <i />
              </div>
            ) : null
          ) : tile ? (
            <div
              className="wjm-tiles"
              ref={rowsRef}
              style={{ ['--wjm-cols' as string]: m.numberOnLine, ['--wjm-lines' as string]: m.numberLineOnScreen }}
            >
              {items.map((x, pos) => (
                <Tile key={x.key} it={x} pos={pos} here={pos === cIndex} store={store} />
              ))}
            </div>
          ) : (
            <div className={cls('wjm-rows', tall && 'is-tall')} ref={rowsRef} style={{ ['--wjm-on-screen' as string]: m.numberOnScreen }}>
              {items.map((x, pos) => (
                <Row key={x.key} it={x} pos={pos} here={pos === cIndex} withIcons={withIcons} store={store} />
              ))}
            </div>
          )}

          {content && n > 1 ? (
            <div className="wjm-count">
              <Txt s={store.sprintf(store.lang('of'), cIndex + 1, n)} />
            </div>
          ) : null}

          {content && it ? (
            <div className="wjm-detail" key={`${m.key}:${it.key}`}>
              {tile && it.title ? (
                <div className="wjm-detail-title">
                  <Rich s={it.translate ? store.lang(it.title) : it.title} />
                  {it.subtitle ? (
                    <span className="wk-desc">
                      <Rich s={it.subtitle} />
                    </span>
                  ) : null}
                </div>
              ) : null}
              {description ? (
                <div className="wjm-desc">
                  <Rich s={description} />
                </div>
              ) : null}
              {it.statistics.length > 0 ? (
                <div className="wjm-stats">
                  {it.statistics.map((st, k) => (
                    <Stat key={k} st={st} s={store} />
                  ))}
                </div>
              ) : null}
              {panel.length > 0 ? (
                <div className="wjm-sliders">
                  {panel.map(({ s, i }) => (
                    <PanelSlider key={i} s={s} i={i} store={store} />
                  ))}
                </div>
              ) : null}
            </div>
          ) : null}

          {content && price !== false && price !== undefined ? (
            <div className="wjm-price">
              <span className="wjm-price-title">
                <Rich s={priceTitle} />
              </span>
              <span className="wjm-price-amount">
                <Price p={price} s={store} />
              </span>
            </div>
          ) : null}

          {content && it && typeof it.footer === 'string' && it.footer !== '' ? (
            <div className="wjm-foot">
              <Rich s={it.footer} />
            </div>
          ) : null}
        </Card>
      </div>
    </div>
  );
};

export default JoMenu;
