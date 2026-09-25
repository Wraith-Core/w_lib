import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import Icon from '../../wc/Icon';
import { monoHtml, READING_TONES, textStyle } from '../../utils/palette';
import './wnotify.css';

/**
 * ============================================================================
 * The RDR-style floating notice, and the world/screen text that travels with it.
 *
 * ⚠️ THIS WAS BROKEN BY THE FRAME CONSOLIDATION AND IS RESTORED HERE. It used to be drawn by
 *    the `wnotify` frame under nui/, which was deleted along with the rest of the shell -- but
 *    resource/wnotify/client.lua kept sending to it, so `RK-text:send` and every
 *    exports.w_lib:Notify quietly stopped appearing. Nothing errored; the messages simply had
 *    no frame left to reach.
 *
 * ★ Its whole point is `useBackground: false` -- text and an icon over the world with no plate
 *   behind them, which is how RDR2 states things it does not want to interrupt you for. The
 *   plate is the option, not the default.
 *
 * The contract is resource/wnotify/client.lua's, unchanged:
 *   showNotification · drawText2D · removeText2D · drawText3D · removeText3D
 * ============================================================================
 */

interface NotifyData {
  title?: string;
  description?: string;
  icon?: string;
  placement?: string;
  duration?: number;
  useBackground?: boolean;
  contentAlignment?: string;
  isRTL?: boolean;
  /** 'law' is the wanted/witness banner -- the name in paper over the red rule. */
  variant?: string;
  /**
   * The third line -- the clock, the temperature, the wind.
   *
   * ★ A plain string, or PARTS with their own colours. A script colours that line piece by
   *   piece (the clock after ten at night, the temperature when it is warm). The colours are
   *   drawn on the palette (utils/palette): each part takes the paper step nearest to the colour
   *   it was sent -- a night clock reads fainter than a noon one -- and a red one keeps the red
   *   mark as an underline. One flat string cannot say that, and a second field for the colours
   *   would be a second name for the same line.
   */
  meta?: string | MetaPart[];
  titleColor?: string;
  descriptionColor?: string;
}

interface MetaPart {
  text: string;
  /** Any CSS colour, drawn as its nearest paper step. Left out, it takes the line's own. */
  color?: string;
}

interface Toast extends NotifyData {
  key: number;
  leaving?: boolean;
}

interface Text3D {
  id: string;
  x: number;
  y: number;
  text: string;
}

/**
 * Only letters and dashes reach the class name -- placement comes from Lua.
 *
 * ★ The law banner ignores it. A bounty or a witness always appears at the top of the screen in
 *   RDR2, and it is not a per-call decision: a WANTED notice in the corner would read as a
 *   passing remark rather than as the law taking an interest in you.
 *
 * ⚠️ Enforced HERE and not in Lua, so there is one place that decides it. Two enforcement
 *    points would eventually disagree, and a consumer passing `placement` would get different
 *    answers depending on which path its notice took.
 */
const placementClass = (placement?: string, variant?: string) =>
  (variant === 'law' ? 'top-center' : placement || 'middle-right').replace(/[^a-z-]/g, '');

/** Which edge a placement sits against, so the notice can arrive from off that edge. */
const sideOf = (place: string) => (place.endsWith('-right') ? 'right' : place.endsWith('-left') ? 'left' : 'center');

/** Does the notice carry Arabic words? Then nothing in it is letter-spaced or cased (wnotify.css). */
const ARABIC = /[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]/;
const hasArabic = (toast: NotifyData) => ARABIC.test(`${toast.title ?? ''}${toast.description ?? ''}`);

/**
 * The lengths this markup may be cut to without splitting anything.
 *
 * ⚠️ The description is HTML -- Lua sends line breaks as <br> and consumers send inline
 *    markup. rakan_notify's typewriter appends one CHARACTER at a time into innerHTML, which
 *    walks straight through a tag and hands the parser '<b' and then '<br' -- the browser
 *    silently repairs it and the effect stutters or the tag is lost. Tags and entities are
 *    stepped over whole here, so every frame is valid markup and the effect looks the same.
 */
function cutPoints(html: string): number[] {
  const stops: number[] = [];
  let i = 0;

  while (i < html.length) {
    if (html[i] === '<') {
      const end = html.indexOf('>', i);
      i = end === -1 ? html.length : end + 1;
    } else if (html[i] === '&') {
      const end = html.indexOf(';', i);
      i = end !== -1 && end - i <= 10 ? end + 1 : i + 1;
    } else {
      i += 1;
    }

    stops.push(i);
  }

  return stops;
}

/** rakan_notify's typewriter, at its own 20ms a character. */
const Typed: React.FC<{ html: string; className?: string; style?: React.CSSProperties }> = ({
  html,
  className,
  style,
}) => {
  const stops = useMemo(() => cutPoints(html), [html]);
  const [shown, setShown] = useState(0);

  useEffect(() => {
    setShown(0);
    if (!stops.length) return;

    let at = 0;
    const id = setInterval(() => {
      at += 1;
      setShown(at);
      if (at >= stops.length) clearInterval(id);
    }, 20);

    return () => clearInterval(id);
  }, [stops]);

  const cut = shown > 0 ? stops[Math.min(shown, stops.length) - 1] : 0;

  return <span className={className} style={style} dangerouslySetInnerHTML={{ __html: html.slice(0, cut) }} />;
};

const WNotify: React.FC = () => {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [text2D, setText2D] = useState<string | null>(null);
  const [texts3D, setTexts3D] = useState<Record<string, Text3D>>({});

  const nextKey = useRef(0);
  const timers = useRef<Array<ReturnType<typeof setTimeout>>>([]);

  const dismiss = useCallback((key: number) => {
    setToasts((list) => list.map((t) => (t.key === key ? { ...t, leaving: true } : t)));
    timers.current.push(setTimeout(() => setToasts((list) => list.filter((t) => t.key !== key)), 260));
  }, []);

  useNuiEvent<NotifyData>('showNotification', (data) => {
    const key = nextKey.current++;
    /* ⚠️ No sound here. The chime is RDR2's own and is played by the GAME, from
       resource/wnotify/client.lua -- see the note there for why it cannot live in the frame. */
    setToasts((list) => [...list, { ...data, key }]);
    timers.current.push(setTimeout(() => dismiss(key), Number(data?.duration) || 5000));
  });

  useNuiEvent<{ text: string }>('drawText2D', (data) => setText2D(data?.text ?? null));
  useNuiEvent('removeText2D', () => setText2D(null));

  /**
   * ⚠️ The 3D text arrives already projected to screen coordinates by the Lua
   *    (GetScreenCoordFromWorldCoord), as fractions of the viewport. So it is positioned in
   *    percentages and never re-projected here -- this component does no world maths at all.
   */
  useNuiEvent<Text3D>('drawText3D', (data) => {
    if (!data?.id) return;
    setTexts3D((prev) => ({ ...prev, [data.id]: data }));
  });

  useNuiEvent<{ id: string }>('removeText3D', (data) =>
    setTexts3D((prev) => {
      if (!data?.id || !(data.id in prev)) return prev;
      const next = { ...prev };
      delete next[data.id];
      return next;
    })
  );

  useEffect(() => () => timers.current.forEach(clearTimeout), []);

  const list3D = Object.values(texts3D);

  if (!toasts.length && !text2D && !list3D.length) return null;

  /* Grouped by placement so several corners can hold notices at once. */
  const groups = toasts.reduce<Record<string, Toast[]>>((acc, toast) => {
    const place = placementClass(toast.placement, toast.variant);
    (acc[place] ||= []).push(toast);
    return acc;
  }, {});

  return (
    <div className="wn-root">
      {Object.entries(groups).map(([place, list]) => (
        <div key={place} className={`wn-stack wn-at-${place}`}>
          {list.map((toast) => (
            /* ★ dir and text-align belong to the BODY, not to the notice. On the notice they
               also flipped its flex row, which is what carried the icon from one side to the
               other; the row's layout is not a language question. */
            <div
              key={toast.key}
              className={`wn-note from-${sideOf(place)}${toast.useBackground ? ' has-plate' : ''}${
                toast.variant ? ` is-${String(toast.variant).replace(/[^a-z]/g, '')}` : ''
              }${hasArabic(toast) ? ' has-ar' : ''}${toast.leaving ? ' is-out' : ''}`}
            >
              <span
                className="wn-body"
                dir={toast.isRTL ? 'rtl' : 'ltr'}
                style={{ textAlign: (toast.contentAlignment as React.CSSProperties['textAlign']) || 'center' }}
              >
                {/* ⚠️ The colour is set inline ONLY when Lua names one -- a default belongs in the
                    stylesheet, the inline value is for the override. And the override is drawn
                    on the palette (utils/palette): the paper step nearest to what the script sent,
                    with the red mark underneath when it sent red. Never a hue, never red words. */}
                {toast.title && (
                  <span className="wn-title" style={toast.titleColor ? textStyle(toast.titleColor) : undefined}>
                    {toast.title}
                  </span>
                )}
                {toast.description && (
                  <Typed
                    className="wn-desc"
                    style={toast.descriptionColor ? textStyle(toast.descriptionColor) : undefined}
                    html={monoHtml(String(toast.description).replace(/\n/g, '<br>'))}
                  />
                )}

                {/* ⚠️ dir="ltr" is not optional here. '2:52PM | 51°F' is digits, a pipe and a
                    degree sign -- every one of them bidi-neutral -- so in an Arabic banner they
                    are reordered and the clock comes out as '51°F | 2:52PM'. This is a reading,
                    not a sentence; it reads the same way in every language. */}
                {toast.meta && (
                  <span className="wn-meta" dir="ltr">
                    {typeof toast.meta === 'string'
                      ? toast.meta
                      : toast.meta.map((part, i) => (
                          <React.Fragment key={i}>
                            {/* ★ The separator is drawn HERE rather than carried in the parts, so a
                                script sends three readings and never has to think about the bars
                                between them -- and they cannot end up a different colour. */}
                            {i > 0 && <span className="wn-meta-sep">|</span>}
                            <span style={part.color ? textStyle(part.color, READING_TONES) : undefined}>{part.text}</span>
                          </React.Fragment>
                        ))}
                  </span>
                )}
              </span>

              {toast.icon && <Icon icon={toast.icon} className="wn-icon" />}
            </div>
          ))}
        </div>
      ))}

      {text2D && <div className="wn-text2d" dangerouslySetInnerHTML={{ __html: monoHtml(text2D) }} />}

      {list3D.map((t) => (
        <div
          key={t.id}
          className="wn-text3d"
          style={{ left: `${t.x * 100}%`, top: `${t.y * 100}%` }}
          dangerouslySetInnerHTML={{ __html: monoHtml(t.text) }}
        />
      ))}
    </div>
  );
};

export default WNotify;
