import React, { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { useLocales } from '../../providers/LocaleProvider';
import './voice.css';

/**
 * ============================================================================
 * Voice interaction -- the interface only.
 *
 * ★ WHAT THIS IS: the three things a speak-to-play system has to put on screen -- what you may
 *   say, that it is listening, and what it heard. The recognition itself is not here and should
 *   not be: matching speech is the script's job, drawing the conversation is the library's.
 *
 * ★ The messages, unchanged since the first version (resource/interface/client/voice.lua):
 *
 *     voiceHint / voiceHintRemove   a person, and what they answer to or are saying now
 *     voicePanel                    everything sayable right now, grouped
 *     voiceListening                the microphone state, with a live level or spectrum
 *     voiceSubtitle                 one line of what was heard, in one of three states
 *
 * ★ ONE CARD PER PERSON. A script that talks to someone sends BOTH a hint and an anchored panel
 *   for the same head -- w_voiceintract does exactly that. They used to be drawn as two
 *   independent plates on the same point: the balloon centred above the head, the panel pinned
 *   to its right, and the two overlapped whenever the name or a phrase was long. Here the panel
 *   is folded into the card of the hint it belongs to (by `id` when Lua sends one, otherwise by
 *   the projected point -- both are projected from the same coordinates on the same frame, so
 *   the match is exact), and the card is the only thing drawn for that person.
 *
 * ★ The card sits BESIDE the head, never over it. Its start edge faces the speaker (left of them
 *   in Arabic, right of them in English), it flips to the other side only when it would not fit,
 *   and it is clamped to the screen. See placeCard.
 *
 * ★ A MINIMAL hint (`minimal`, and nothing being said) is not a card at all: one line ABOVE the
 *   head -- the talk key as a small cap and "Talk to <name>" -- with no plate, no border and no
 *   rule, kept legible over a bright sky or a dark room by an ink halo on the letters alone. The
 *   owner asked for exactly that in place of the five example phrases beside every face. When
 *   the person speaks (`says`), the same id is drawn as the normal card with their line. See
 *   HailView / placeHail.
 *
 * ⚠️ The positions are fractions of the viewport that LUA has already projected -- exactly as
 *    drawText3D in wnotify does. No world maths happens in this frame, and it must not: the
 *    projection needs the camera, and the camera lives in the game.
 *
 * ⚠️ The class names are deliberately NOT .wv-panel / .wv-bubble any more. The store theme's
 *    bridge (nui/assets/store-theme-bridge.js) decorates those two with a textured frame and a
 *    masked plate; that frame was the scratchy white border around the old list. This card
 *    carries its own quiet edge and must not be re-skinned from outside.
 * ============================================================================
 */

type Heard = 'listening' | 'matched' | 'unknown';

interface Subtitle {
  text?: string;
  state?: Heard;
  /** Who is speaking -- when set, the line is an NPC's and is labelled with their name. */
  speaker?: string;
}

interface Listening {
  active?: boolean;
  /** 0-100. A single loudness reading -- the simple case. */
  level?: number;
  /** A spectrum, one value per band, 0-100. Takes precedence over `level`. */
  levels?: number[];
  label?: string;
}

interface Group {
  label?: string;
  commands: string[];
}

/** What the player may say right now. */
interface CommandPanel {
  title?: string;
  /** Where it sits when it is NOT anchored to anyone. */
  position?: string;
  groups?: Group[];
  /** Projected head point, when the list belongs to a particular person. */
  x?: number;
  y?: number;
  /** Optional: whose list this is -- used as the card's name when no hint carries one. */
  speaker?: string;
  /** Optional: the push-to-talk key, shown once as a key cap. */
  talkKey?: string;
  /** Optional: the hint id this list belongs to. Without it the card is matched by position. */
  id?: string;
  /** Optional: metres from the camera to the anchor -- sizes the gap beside the head. */
  d?: number;
}

interface Hint {
  id: string;
  /** Fractions of the viewport, already projected by Lua. */
  x: number;
  y: number;
  title?: string;
  /** Accepted for compatibility; the card draws no emblem. */
  icon?: string;
  /** The phrases this person answers to. */
  commands?: string[];
  /** What this person is saying RIGHT NOW -- shown under their name while it is set. */
  says?: string;
  /** Optional: metres from the camera. */
  d?: number;
  /** Optional: draw the bare line above the head instead of a card (while nothing is said). */
  minimal?: boolean;
  /** Optional: the push-to-talk key, the minimal line's key cap. */
  talkKey?: string;
  /** Optional: the person alone. Set apart inside `title`, and the card's name while they speak. */
  name?: string;
}

/** One card on screen: a person (hint), their list (panel), or both folded together. */
interface Card {
  key: string;
  x?: number;
  y?: number;
  d?: number;
  position?: string;
  name?: string;
  says?: string;
  title?: string;
  groups: Group[];
  talkKey?: string;
  /** The card that carries the push-to-talk row -- the one with the panel in it. */
  talks: boolean;
}

/* ── language ─────────────────────────────────────────────────────────────── */

/** Any Arabic-script character -- decides the face, the size step and the letter-spacing. */
const ARABIC = /[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]/;
const isArabic = (text?: string) => !!text && ARABIC.test(text);
const script = (text?: string) => (isArabic(text) ? ' is-ar' : '');

/**
 * The card's own few words. Everything a script says arrives from the script; these are the
 * labels the library adds around it, in the frame's language.
 */
const STRINGS = {
  ar: { hold: 'اضغط مطوّلًا وتكلّم', listening: 'ينصت', heard: { listening: 'يسمع', matched: 'فُهِم', unknown: 'لم يُفهم' } },
  en: { hold: 'Hold to speak', listening: 'Listening', heard: { listening: 'Hearing', matched: 'Understood', unknown: 'Not understood' } },
};

/** Key names as the keybind reports them, as a player reads them. Anything else is shown as sent. */
const KEY_NAMES: Record<string, string> = {
  LMENU: 'Alt', RMENU: 'Alt', LCONTROL: 'Ctrl', RCONTROL: 'Ctrl', LSHIFT: 'Shift', RSHIFT: 'Shift',
  SPACE: 'Space', RETURN: 'Enter', CAPITAL: 'Caps', TAB: 'Tab', BACK: 'Back',
  MOUSE_LEFT: 'LMB', MOUSE_RIGHT: 'RMB', MOUSE_MIDDLE: 'MMB', MOUSE_EXTRABTN1: 'M4', MOUSE_EXTRABTN2: 'M5',
};

const keyName = (key?: string) => {
  if (!key) return '';
  const raw = String(key).trim();
  const upper = raw.toUpperCase().replace(/^(IOM_|KEY_)/, '');
  return KEY_NAMES[upper] ?? (upper.length <= 2 ? upper : raw.slice(0, 10));
};

/* ── the microphone ───────────────────────────────────────────────────────── */

/** Seven bars off one level, each with its own threshold, so the meter fills from the middle. */
const BARS = [0.28, 0.52, 0.74, 0.9, 0.74, 0.52, 0.28];

const Meter: React.FC<{ level?: number; levels?: number[] }> = ({ level, levels }) => {
  const bands = levels?.length
    ? levels.slice(0, 12).map((v) => Math.min(1, Math.max(0, Number(v) / 100)))
    : BARS.map((peak) => ((level ?? 0) / 100 >= 1 - peak ? peak : peak * 0.28));

  return (
    <span className="wv-meter" aria-hidden="true">
      {bands.map((height, i) => (
        <span key={i} className="wv-bar" style={{ transform: `scaleY(${Math.max(0.14, height)})` }} />
      ))}
    </span>
  );
};

/* ── a phrase ─────────────────────────────────────────────────────────────── */

/**
 * Split a phrase on its {variable} slots -- the script's own syntax (`phrases = { "buy {item}" }`),
 * read as written. A slot is a blank the player fills, so it is drawn as one: the name, dimmed
 * and underlined, in the line's own face. No colour per name -- one accent budget, one treatment.
 */
const Phrase: React.FC<{ text: string }> = ({ text }) => (
  <>
    {String(text)
      .split(/(\{[^}]+\})/g)
      .filter(Boolean)
      .map((part, i) => {
        const slot = part.match(/^\{([^}]+)\}$/);
        return slot ? (
          <span key={i} className="wv-slot">
            {slot[1]}
          </span>
        ) : (
          <React.Fragment key={i}>{part}</React.Fragment>
        );
      })}
  </>
);

/* ── placement ────────────────────────────────────────────────────────────── */

const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), Math.max(lo, hi));

/**
 * Put an anchored card beside the head it belongs to.
 *
 * ★ The gap is the head's half-width plus air. With the camera distance (`d`, optional) it is
 *   sized to the head as the game draws it -- 0.17 of the viewport height at one metre falls off
 *   as 1/d -- so a close NPC's face is cleared and a far one's list does not float away from
 *   them. Without it, a fixed 7.5vh that suits the usual two-to-three metres of a conversation.
 *
 * ★ The side sticks. A card that re-picks its side every frame would jump across the face as the
 *   player turns past the middle of the screen; it only flips when the side it is on stops fitting.
 */
const placeCard = (el: HTMLElement, card: Card, rtl: boolean, sideRef: React.MutableRefObject<'l' | 'r' | null>) => {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const w = el.offsetWidth;
  const h = el.offsetHeight;
  const margin = Math.max(12, Math.round(vh * 0.024));

  const ax = (card.x ?? 0.5) * vw;
  const ay = (card.y ?? 0.5) * vh;
  const d = Number(card.d);
  const gap = d > 0 ? clamp((0.17 / d) * vh, 0.035 * vh, 0.2 * vh) : 0.075 * vh;

  const rightX = ax + gap;
  const leftX = ax - gap - w;
  const fitsRight = rightX + w <= vw - margin;
  const fitsLeft = leftX >= margin;

  // Start edge toward the speaker: an Arabic card reads from its right, so it sits to their left.
  const preferred = rtl ? 'l' : 'r';
  let side = sideRef.current ?? preferred;
  if (side === 'r' && !fitsRight && fitsLeft) side = 'l';
  else if (side === 'l' && !fitsLeft && fitsRight) side = 'r';
  // Back to the reading side only once it fits with room to spare -- the slack is the hysteresis
  // that keeps a card on the edge of fitting from flickering between the two.
  else if (side !== preferred) {
    const slack = 0.12 * vw;
    if (preferred === 'l' ? leftX - slack >= margin : rightX + w + slack <= vw - margin) side = preferred;
  }
  sideRef.current = side;

  const left = clamp(side === 'r' ? rightX : leftX, margin, vw - margin - w);
  // The name level with the eyes, the list running down beside the shoulder.
  let top = clamp(ay - Math.min(34, h * 0.2), margin, vh - margin - h);

  // ⚠️ Nor over the heard line. A tall card beside a low head at 720p reaches the dock at the
  //    bottom centre; when the two would meet, the card is lifted clear of it (it is still beside
  //    the head, so lifting it cannot put it over the face).
  //    What is drawn in the dock, not the dock: the dock is a wide centring column and its empty
  //    sides must not push away a card that sits beside a short line.
  const dockEl = document.querySelector('.wv-dock');
  if (dockEl) {
    for (const piece of Array.from(dockEl.children).reverse()) {
      const r = piece.getBoundingClientRect();
      // 12px of air, which also absorbs the line's 6px rise-in while it is still animating.
      if (left < r.right && left + w > r.left && top + h > r.top - 12 && top < r.bottom) {
        top = Math.max(margin, r.top - 12 - h);
      }
    }
  }

  el.style.transform = `translate3d(${Math.round(left)}px, ${Math.round(top)}px, 0)`;
  el.dataset.side = side;
  // Read back by separateCards, which runs after every card has been placed like this.
  el.dataset.ax = String(ax);
  el.dataset.ay = String(ay);
  el.dataset.gap = String(gap);
  el.dataset.left = String(Math.round(left));
  el.dataset.top = String(Math.round(top));
};

/**
 * Put a minimal line above the head it belongs to, centred on it.
 *
 * ★ The head bone is the middle of the skull. The crown, and the brim of the hat most people in
 *   1899 wear, sit about a quarter of a metre above it, so the line's foot is lifted 0.27 m as
 *   the game draws it: the same 1/d fall-off placeCard uses for the side gap, at the scale where
 *   one metre at one metre is about the viewport's height. Without `d`, a fixed 8.5vh that
 *   suits the two-to-four metres of a conversation.
 *
 * ★ Clamped to the screen like the card, so a person at the edge keeps a readable line instead
 *   of half of one; and lifted clear of the heard line in the dock, like the card.
 */
const placeHail = (el: HTMLElement, hint: Hint) => {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const w = el.offsetWidth;
  const h = el.offsetHeight;
  const margin = Math.max(12, Math.round(vh * 0.024));

  const ax = hint.x * vw;
  const ay = hint.y * vh;
  const d = Number(hint.d);
  const lift = d > 0 ? clamp((0.27 / d) * vh, 0.03 * vh, 0.2 * vh) : 0.085 * vh;
  // The side gap placeCard would leave: separateCards sizes this person's head from it.
  const gap = d > 0 ? clamp((0.17 / d) * vh, 0.035 * vh, 0.2 * vh) : 0.075 * vh;

  const left = clamp(ax - w / 2, margin, vw - margin - w);
  let top = clamp(ay - lift - h, margin, vh - margin - h);

  // The same test as placeCard: what is drawn in the dock, 12px of air.
  const dockEl = document.querySelector('.wv-dock');
  if (dockEl) {
    for (const piece of Array.from(dockEl.children).reverse()) {
      const r = piece.getBoundingClientRect();
      if (left < r.right && left + w > r.left && top + h > r.top - 12 && top < r.bottom) {
        top = Math.max(margin, r.top - 12 - h);
      }
    }
  }

  el.style.transform = `translate3d(${Math.round(left)}px, ${Math.round(top)}px, 0)`;
  el.dataset.ax = String(ax);
  el.dataset.ay = String(ay);
  el.dataset.gap = String(gap);
  el.dataset.d = String(d > 0 ? d : '');
  el.dataset.left = String(Math.round(left));
  el.dataset.top = String(Math.round(top));
};

/* ── several people at once ───────────────────────────────────────────────── */

interface Box {
  l: number;
  t: number;
  r: number;
  b: number;
}

const overlap = (a: Box, b: Box) =>
  Math.max(0, Math.min(a.r, b.r) - Math.max(a.l, b.l)) * Math.max(0, Math.min(a.b, b.b) - Math.max(a.t, b.t));

/**
 * ★ Two people close together must not get two cards on top of each other, nor one card over the
 *   other person's face. placeCard places each card as if it were alone; this pass, run after all
 *   of them, moves the ones that collide. The card with the "you can say" list in it (the person
 *   being talked to) keeps its place; the others make way, trying their own side first, then the
 *   other side, each level with the head or just clear of whatever they hit -- and take the
 *   candidate that covers least, nearest to where they were. Heads count as obstacles, and so does
 *   what is drawn in the dock.
 *
 * ★ Minimal lines take part too. They go after the talked-to card and before the other cards
 *   (nearest person first), and they only ever move UP or DOWN: a line that slid sideways would
 *   no longer be over the head it names. The cards placed after them then route around them.
 *
 * ⚠️ w_voiceintract only ever talks to one person, so this is idle there. It is for a script that
 *    puts hints over several people (the dev preview does), and it costs nothing with one card.
 */
const separateCards = (root: HTMLElement) => {
  const els = Array.from(root.querySelectorAll<HTMLElement>('.wv-card.is-anchored, .wv-hail'));
  if (els.length < 2) return;

  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const margin = Math.max(12, Math.round(vh * 0.024));
  const air = 10;

  const items = els
    .map((el) => ({
      el,
      ax: Number(el.dataset.ax),
      ay: Number(el.dataset.ay),
      gap: Number(el.dataset.gap),
      left: Number(el.dataset.left),
      top: Number(el.dataset.top),
      w: el.offsetWidth,
      h: el.offsetHeight,
      talks: el.classList.contains('is-talks'),
      hail: el.classList.contains('wv-hail'),
      d: Number(el.dataset.d) || Infinity,
    }))
    .filter((it) => [it.ax, it.ay, it.gap, it.left, it.top].every(Number.isFinite));
  if (items.length < 2) return;

  // Stable: the talked-to card first, then the minimal lines nearest first, then the other cards
  // in the order they arrived.
  const rank = (it: { talks: boolean; hail: boolean }) => (it.talks ? 0 : it.hail ? 1 : 2);
  // (Compared, not subtracted: two lines with no distance are Infinity each, and Infinity minus
  // Infinity is NaN.)
  const nearer = (a: number, b: number) => (a === b ? 0 : a < b ? -1 : 1);
  items.sort((a, b) => rank(a) - rank(b) || (a.hail && b.hail ? nearer(a.d, b.d) : 0));

  // A head is about as wide as the gap placeCard leaves beside it, and a little taller.
  const heads: Box[] = items.map((it) => ({ l: it.ax - it.gap * 0.6, r: it.ax + it.gap * 0.6, t: it.ay - it.gap * 0.8, b: it.ay + it.gap * 0.8 }));

  const dock: Box[] = [];
  const dockEl = root.querySelector('.wv-dock');
  if (dockEl) {
    for (const piece of Array.from(dockEl.children)) {
      const r = piece.getBoundingClientRect();
      dock.push({ l: r.left, t: r.top, r: r.right, b: r.bottom });
    }
  }

  const placed: Box[] = [];

  items.forEach((it, i) => {
    const obstacles = [...placed, ...heads.filter((_, j) => j !== i), ...dock];
    const at = (l: number, t: number): Box => ({ l, t, r: l + it.w, b: t + it.h });
    const cost = (box: Box) => obstacles.reduce((n, o) => n + overlap(box, o), 0);

    let best = at(it.left, it.top);

    if (!it.talks && cost(best) > 0) {
      const onRight = it.left >= it.ax;
      const sides = it.hail
        ? [it.left]
        : [it.left, onRight ? it.ax - it.gap - it.w : it.ax + it.gap].map((x) => clamp(x, margin, vw - margin - it.w));
      const tops = [it.top, ...obstacles.flatMap((o) => [o.b + air, o.t - air - it.h])];

      let bestScore = Infinity;
      for (const l of sides) {
        for (const t of tops) {
          const box = at(l, t);
          if (box.t < margin || box.b > vh - margin) continue;
          // Covering anything outweighs any distance moved; among equals, the nearest wins.
          const score = cost(box) * 1000 + Math.hypot(l - it.left, t - it.top);
          if (score < bestScore) {
            bestScore = score;
            best = box;
          }
        }
      }

      it.el.style.transform = `translate3d(${Math.round(best.l)}px, ${Math.round(best.t)}px, 0)`;
      if (!it.hail) it.el.dataset.side = best.l >= it.ax ? 'r' : 'l';
    }

    placed.push(best);
  });
};

/* ── the card ─────────────────────────────────────────────────────────────── */

const CardView: React.FC<{ card: Card; listening: Listening | null; rtl: boolean }> = ({ card, listening, rtl }) => {
  const ref = useRef<HTMLDivElement>(null);
  const side = useRef<'l' | 'r' | null>(null);
  const anchored = typeof card.x === 'number' && typeof card.y === 'number';
  const t = rtl ? STRINGS.ar : STRINGS.en;
  const live = !!listening?.active && card.talks;

  // ⚠️ Layout effect, not a plain effect: the card is measured and moved before the browser
  //    paints, so it never shows for a frame at the corner it was created in.
  useLayoutEffect(() => {
    if (anchored && ref.current) placeCard(ref.current, card, rtl, side);
  });

  // ★ And again when the frame changes size (a resolution or window-mode switch), straight on the
  //   element rather than through a render -- the next message from Lua may be a frame away, and a
  //   card clamped against the old viewport would sit off-screen until it arrived.
  const latest = useRef({ card, rtl });
  latest.current = { card, rtl };
  useEffect(() => {
    if (!anchored) return;
    const onResize = () => ref.current && placeCard(ref.current, latest.current.card, latest.current.rtl, side);
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, [anchored]);

  const key = keyName(card.talkKey);
  const talkLabel = live ? listening?.label || t.listening : card.title || t.hold;
  const lines = card.groups.reduce((n, g) => n + (g.commands?.length || 0), 0);
  let index = 0;

  const classes = [
    'wv-card',
    anchored ? 'is-anchored' : `wv-at-${(card.position || 'bottom-left').replace(/[^a-z-]/g, '')}`,
    card.talks ? 'is-talks' : '',
    card.says ? 'is-speaking' : '',
    live ? 'is-live' : '',
  ].filter(Boolean).join(' ');

  return (
    <div ref={ref} className={classes} dir={rtl ? 'rtl' : 'ltr'}>
      <div className="wv-card-in">
        {card.name && (
          <div className="wv-head">
            <span className={`wv-name${script(card.name)}`} dir="auto">
              {card.name}
            </span>
          </div>
        )}

        {card.says && (
          <p className={`wv-says${script(card.says)}`} dir="auto" key={card.says}>
            {card.says}
          </p>
        )}

        {(card.talks || card.title) && lines > 0 && (
          <div className="wv-talk">
            <span className={`wv-talk-label${script(talkLabel)}`}>{talkLabel}</span>
            {live && <Meter level={listening?.level} levels={listening?.levels} />}
            {key && (
              <kbd className="wv-key" dir="ltr" title={t.hold}>
                {key}
              </kbd>
            )}
          </div>
        )}

        {/* ★ While they talk the list folds away and only the key row stays: someone who is
            speaking is not offering a menu, and a card that grew by a paragraph AND kept eight
            lines would reach half-way down a 720p screen. It comes back when the line ends. */}
        {lines > 0 && !card.says && (
          <div className="wv-list">
            {card.groups.map((group, gi) =>
              group.commands?.length ? (
                <div className="wv-group" key={`${gi}:${group.label ?? ''}`}>
                  {/* No dir="auto": the label runs the card's way, so its rule always trails it
                      toward the far edge, whatever script a script's label happens to be in. */}
                  {group.label && <span className={`wv-group-label${script(group.label)}`}>{group.label}</span>}
                  <ol className="wv-lines">
                    {group.commands.map((command, i) => {
                      index += 1;
                      return (
                        <li className="wv-line" key={i}>
                          <span className="wv-num" dir="ltr" aria-hidden="true">
                            {index}
                          </span>
                          <span className={`wv-phrase${script(command)}`} dir="auto">
                            <Phrase text={command} />
                          </span>
                        </li>
                      );
                    })}
                  </ol>
                </div>
              ) : null
            )}
          </div>
        )}
      </div>
    </div>
  );
};

/* ── the minimal line ─────────────────────────────────────────────────────── */

/**
 * "Talk to <name>" as the script wrote it, cut around the name so the name can be set apart.
 * The verb comes from the script's own dictionary, so its words and their order are the
 * script's: the name is found inside the sentence, never glued on. A title that does not contain
 * the name (or no name at all) is drawn whole.
 */
const splitTitle = (title?: string, name?: string): [string, string, string] => {
  const text = String(title ?? '');
  const who = String(name ?? '').trim();
  if (!text) return ['', who, ''];

  const at = who ? text.indexOf(who) : -1;
  if (at < 0) return [text, '', ''];

  return [text.slice(0, at), who, text.slice(at + who.length)];
};

/**
 * ★ The whole prompt for someone you can talk to: the key, then the words, on one line above the
 *   head. No plate, no border, no header rule, no list -- the owner wanted it transparent. What
 *   keeps it readable over a white sky or a dark saloon is an ink halo on the letters and on the
 *   key's edge (voice.css), not a box.
 *
 * ★ While the microphone is open for this person the key cap gives way to the level meter, in
 *   the same place: the line itself shows that you are being heard.
 */
const HailView: React.FC<{ hint: Hint; listening: Listening | null; rtl: boolean }> = ({ hint, listening, rtl }) => {
  const ref = useRef<HTMLDivElement>(null);
  const live = !!listening?.active;
  const t = rtl ? STRINGS.ar : STRINGS.en;

  // ⚠️ Layout effect, as for the card: placed before the browser paints, never seen at 0,0.
  useLayoutEffect(() => {
    if (ref.current) placeHail(ref.current, hint);
  });

  // And again on a resize, straight on the element (see CardView).
  const latest = useRef(hint);
  latest.current = hint;
  useEffect(() => {
    const onResize = () => ref.current && placeHail(ref.current, latest.current);
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  const [before, name, after] = splitTitle(hint.title, hint.name);
  const text = `${before}${name}${after}`;
  const key = keyName(hint.talkKey);

  return (
    <div ref={ref} className={`wv-hail${live ? ' is-live' : ''}`} dir={rtl ? 'rtl' : 'ltr'}>
      <div className="wv-hail-in">
        {live ? (
          <span className="wv-hail-mark" role="img" aria-label={listening?.label || t.listening}>
            <Meter level={listening?.level} levels={listening?.levels} />
          </span>
        ) : (
          key && (
            <kbd className="wv-hail-key" dir="ltr" title={t.hold}>
              {key}
            </kbd>
          )
        )}

        {text && (
          <span className={`wv-hail-text${script(text)}`} dir="auto">
            {before}
            {name && <span className="wv-hail-name">{name}</span>}
            {after}
          </span>
        )}
      </div>
    </div>
  );
};

/* ── matching a panel to its person ───────────────────────────────────────── */

/**
 * The hint an anchored panel belongs to: by id when Lua sent one, otherwise the nearest hint
 * within a small radius. w_voiceintract projects both from the same head on the same frame, so
 * the distance is zero for the right one; the radius only keeps a panel for someone with no
 * balloon from swallowing a stranger's.
 */
const ownerOf = (panel: CommandPanel, hints: Hint[]) => {
  if (panel.id) {
    const byId = hints.find((h) => h.id === panel.id);
    if (byId) return byId;
  }

  let best: Hint | undefined;
  let bestDist = 0.09;
  for (const hint of hints) {
    const dist = Math.hypot(hint.x - (panel.x as number), hint.y - (panel.y as number));
    if (dist < bestDist) {
      best = hint;
      bestDist = dist;
    }
  }
  return best;
};

/**
 * A minimal hint's title is the whole prompt ("Talk to Clara Morgan"); as a card's heading it
 * would read as her name. Its `name` is the person alone, so that is what a card shows.
 */
const nameOf = (hint: Hint) => (hint.minimal ? hint.name || hint.title : hint.title);

const buildCards = (hints: Hint[], panel: CommandPanel | null): { cards: Card[]; hails: Hint[] } => {
  const groups = (panel?.groups || []).filter((g) => g && Array.isArray(g.commands));
  const hasPanel = !!panel && groups.length > 0;
  const anchored = hasPanel && typeof panel!.x === 'number' && typeof panel!.y === 'number';
  const owner = anchored ? ownerOf(panel!, hints) : undefined;

  // ★ The minimal line: asked for, and nothing to say. A line being spoken needs the card (the
  //   words have to go somewhere), and so does a list a script pinned to the same person -- it
  //   asked for that list explicitly, and a one-line prompt has no room for it.
  const isHail = (hint: Hint) => !!hint.minimal && !hint.says && hint !== owner;
  const hails = hints.filter(isHail);

  const cards: Card[] = hints.filter((hint) => !isHail(hint)).map((hint) =>
    hint === owner
      ? {
          key: hint.id,
          x: hint.x,
          y: hint.y,
          d: hint.d ?? panel!.d,
          name: nameOf(hint) || panel!.speaker,
          says: hint.says,
          title: panel!.title,
          groups,
          talkKey: panel!.talkKey,
          talks: true,
        }
      : {
          key: hint.id,
          x: hint.x,
          y: hint.y,
          d: hint.d,
          name: nameOf(hint),
          says: hint.says,
          groups: !hint.says && hint.commands?.length ? [{ commands: hint.commands }] : [],
          talks: false,
        }
  );

  if (hasPanel && !owner) {
    cards.push({
      // ⚠️ Keyed by the hint it belongs to when it names one. Lua drops the hint and then the list
      //    (w_voiceintract's hideHint + hidePanel); between the two messages the list is alone, and
      //    under a key of its own it would mount as a new card -- a one-frame card sliding in over
      //    the person as they are dismissed. Under the hint's key it is the same card, one frame on.
      key: panel!.id || '__panel',
      x: anchored ? panel!.x : undefined,
      y: anchored ? panel!.y : undefined,
      d: panel!.d,
      position: anchored ? undefined : panel!.position,
      name: panel!.speaker,
      title: panel!.title,
      groups,
      talkKey: panel!.talkKey,
      talks: true,
    });
  }

  return { cards, hails };
};

/**
 * The minimal line that carries the microphone while it is open: the nearest person's, since
 * that is who a push-to-talk is aimed at (w_voiceintract only ever shows the one it addresses).
 * Lines without a distance count as far, and the first of equals wins.
 */
const liveHailOf = (hails: Hint[]) => {
  let best: Hint | undefined;
  let bestD = Infinity;
  for (const hint of hails) {
    const d = Number(hint.d) > 0 ? Number(hint.d) : Infinity;
    if (!best || d < bestD) {
      best = hint;
      bestD = d;
    }
  }
  return best;
};

/* ── the frame ────────────────────────────────────────────────────────────── */

const Voice: React.FC = () => {
  const { rtl } = useLocales();
  const [listening, setListening] = useState<Listening | null>(null);
  const [subtitle, setSubtitle] = useState<Subtitle | null>(null);
  const [hints, setHints] = useState<Record<string, Hint>>({});
  const [panel, setPanel] = useState<CommandPanel | null>(null);

  const timer = useRef<ReturnType<typeof setTimeout>>();

  useNuiEvent<Listening | false>('voiceListening', (data) => setListening(data || null));

  /**
   * ⚠️ The line clears itself unless `hold` is true. A subtitle that stays until the script
   *    remembers to remove it is a subtitle still on screen three minutes after the conversation
   *    ended -- and the tidy-up is the one thing a script writing a voice system will forget.
   */
  useNuiEvent<(Subtitle & { duration?: number; hold?: boolean }) | false>('voiceSubtitle', (data) => {
    clearTimeout(timer.current);

    if (!data) return setSubtitle(null);

    setSubtitle(data);
    if (data.hold !== true) timer.current = setTimeout(() => setSubtitle(null), Number(data.duration) || 4000);
  });

  useNuiEvent<CommandPanel | false>('voicePanel', (data) => setPanel(data || null));

  useNuiEvent<Hint>('voiceHint', (data) => {
    if (!data?.id) return;
    setHints((prev) => ({ ...prev, [data.id]: data }));
  });

  useNuiEvent<{ id?: string }>('voiceHintRemove', (data) =>
    setHints((prev) => {
      if (!data?.id) return {};
      if (!(data.id in prev)) return prev;

      const next = { ...prev };
      delete next[data.id];
      return next;
    })
  );

  useEffect(() => () => clearTimeout(timer.current), []);

  // ★ After every card has placed itself (children's layout effects run first), move apart the
  //   ones that collide -- and again on a resize, after the cards' own resize handlers.
  const rootRef = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    if (rootRef.current) separateCards(rootRef.current);
  });
  useEffect(() => {
    const onResize = () => rootRef.current && separateCards(rootRef.current);
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  const { cards, hails } = buildCards(Object.values(hints), panel);
  // ★ The open microphone is drawn ONCE: in the talked-to card when there is one, else in the
  //   nearest minimal line (in place of its key), else in the dock.
  const liveHail = listening?.active && !cards.some((c) => c.talks) ? liveHailOf(hails) : undefined;
  const talking = cards.some((c) => c.talks) || !!liveHail;
  const t = rtl ? STRINGS.ar : STRINGS.en;

  /**
   * ★ ONE place for a line an NPC is saying. w_voiceintract sends it twice -- into the person's
   *   card (voiceHint `says`) and as a subtitle with a `speaker` -- and drawn twice it is the same
   *   paragraph beside the head and again at the foot of the screen, under two different names
   *   (the character's on the card, the kind's on the subtitle). While a card on screen is showing
   *   that very line, the card IS the subtitle. When the person is off-screen their card is gone,
   *   and the subtitle comes back on its own.
   */
  const spoken = subtitle?.speaker && subtitle.text ? String(subtitle.text).trim() : '';
  const onCard = !!spoken && cards.some((c) => !!c.says && String(c.says).trim() === spoken);
  const heardLine = !!subtitle?.text && !onCard;

  if (!listening?.active && !heardLine && !cards.length && !hails.length) return null;

  const state: Heard = subtitle?.state === 'matched' || subtitle?.state === 'unknown' ? subtitle.state : 'listening';
  const tag = subtitle?.speaker || t.heard[state];

  return (
    <div className="wv-root" ref={rootRef}>
      {cards.map((card) => (
        <CardView key={card.key} card={card} listening={listening} rtl={rtl} />
      ))}

      {hails.map((hint) => (
        <HailView key={`hail:${hint.id}`} hint={hint} listening={hint === liveHail ? listening : null} rtl={rtl} />
      ))}

      {/* ── the dock: the microphone when no card carries it, and what was heard ── */}
      {((listening?.active && !talking) || heardLine) && (
        <div className="wv-dock" dir={rtl ? 'rtl' : 'ltr'}>
          {listening?.active && !talking && (
            <div className="wv-mic">
              <Meter level={listening.level} levels={listening.levels} />
              <span className={`wv-mic-label${script(listening.label || t.listening)}`}>{listening.label || t.listening}</span>
            </div>
          )}

          {heardLine && subtitle?.text && (
            <div
              className={`wv-sub is-${subtitle.speaker ? 'speech' : state}`}
              role="status"
              aria-live="polite"
              key={`${state}:${subtitle.speaker ?? ''}`}
            >
              <span className={`wv-sub-tag${script(tag)}`} dir="auto">
                {tag}
              </span>
              <span className={`wv-sub-text${script(subtitle.text)}`} dir="auto">
                {subtitle.text}
              </span>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default Voice;
