import { wcAsset } from './bootstrap';

/**
 * ============================================================================
 * The RDR menu sound layer -- ported from w_crafting/lib/sound.ts.
 *
 * ★ Same five files, same volumes, same throttle, so the library's dialogs sound like the
 *   crafting bench rather than merely looking like it. Sound is half of what makes an
 *   interface feel like the game's own.
 * ============================================================================
 */

export type Sfx = 'open' | 'close' | 'hover' | 'select' | 'deny' | 'finish';

const FILE: Record<Sfx, string> = {
  open: 'sounds/menu_open.mp3',
  close: 'sounds/menu_close.mp3',
  hover: 'sounds/button.mp3',
  select: 'sounds/selected.mp3',
  // ⚠️ Refusal borrows the button click rather than inventing a buzzer: RDR has no error tone,
  //    and a foreign sound is louder than no sound.
  deny: 'sounds/button.mp3',

  // ★ The one cue that is not a click: something was COMPLETED -- a craft finished, a purchase
  //   settled. It was already in the bundle (w_crafting rings it at the end of a craft) and only
  //   lacked a name here, so a script driving the library's frame could not ask for it.
  finish: 'sounds/coins.mp3',
};

const VOL: Record<Sfx, number> = {
  open: 0.6,
  close: 0.55,
  hover: 0.26,
  select: 0.5,
  deny: 0.3,
  finish: 0.65,
};

let muted = false;

export function setMuted(value: boolean): void {
  muted = value;
}

/* ★ The frame's focus, as the Lua side reports it (lib.setNuiFocus / lib.resetNuiFocus -> 'wl:focus').
     Every window of the library takes focus while it is open, so no focus means no window: the clicks
     (hover, select, deny) are silent then, whatever the pointer crosses - an alt-tabbed game window, or
     another resource's page on top. The lifecycle cues (open, close, finish) still sound: they are rung as
     a window opens or closes, around the moment its focus changes. */
let focused = false;
const LIFECYCLE: ReadonlySet<Sfx> = new Set<Sfx>(['open', 'close', 'finish']);

if (typeof window !== 'undefined') {
  window.addEventListener('message', (event: MessageEvent) => {
    const msg = event.data as { action?: string; data?: unknown } | null;
    if (msg && msg.action === 'wl:focus') focused = msg.data === true;
  });
}

/* One warm element per sound, cloned on play so rapid repeats overlap instead of cutting each
   other off -- a list navigated quickly should tick per row, not stutter on one. */
const cache: Partial<Record<Sfx, HTMLAudioElement>> = {};

function warm(name: Sfx): HTMLAudioElement | null {
  if (typeof Audio === 'undefined') return null;

  let audio = cache[name];

  if (!audio) {
    audio = new Audio(wcAsset(FILE[name]));
    audio.preload = 'auto';
    cache[name] = audio;
  }

  return audio;
}

let lastHover = 0;

/** `gain` scales the cue's own volume (w.menu.updateVolume); 1 = as designed. */
export function play(name: Sfx, gain = 1): void {
  if (muted) return;
  if (!focused && !LIFECYCLE.has(name)) return;

  const source = warm(name);
  if (!source) return;

  // Sweeping a pointer across a list fires dozens of hovers a second; they overlap into noise.
  if (name === 'hover') {
    const now = typeof performance !== 'undefined' ? performance.now() : Date.now();
    if (now - lastHover < 70) return;
    lastHover = now;
  }

  try {
    const node = source.cloneNode(true) as HTMLAudioElement;
    node.volume = Math.max(0, Math.min(1, VOL[name] * (Number.isFinite(gain) ? gain : 1)));
    void node.play().catch(() => {});
  } catch {
    /* Sound is a luxury -- it never takes the interface down. */
  }
}

export function preloadSfx(): void {
  (Object.keys(FILE) as Sfx[]).forEach(warm);
}

let wired = false;

/**
 * Hover feedback for every button in the frame, from one delegated listener.
 *
 * ★ Delegated rather than per-component: the ox_lib features render buttons from half a dozen
 *   files, and wiring each would mean remembering to wire the next one. This way a button added
 *   tomorrow ticks without being told to.
 */
export function initButtonSfx(): void {
  if (wired || typeof document === 'undefined') return;
  wired = true;

  document.addEventListener(
    'pointerover',
    (event) => {
      const el = event.target as HTMLElement | null;
      if (el && typeof el.closest === 'function' && el.closest('button:not([disabled]), [role="button"]:not([disabled])')) {
        play('hover');
      }
    },
    true
  );
}
