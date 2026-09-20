import { useEffect, useRef } from 'react';
import { postNui } from '../../utils/postNui';

export { postNui };

export type MinigameName = 'lockpick' | 'qte';
export type MinigameStatus = 'success' | 'failed' | 'canceled';

export interface MinigameShowData {
  game?: MinigameName;
  config?: Record<string, unknown>;
}

/**
 * ⚠️ The names are w_lib's, not the upstream project's. The Minigame source posts
 *    `jo_minigame:*`; modules/minigame/client.lua registers `w_minigame:*`. Porting the
 *    upstream names across would compile, run, and silently never reach Lua.
 */
export const MINIGAME_FINISHED = 'w_minigame:finished';
export const MINIGAME_PIN_BROKEN = 'w_minigame:lockpick:pinBroken';

/** Read a number out of the config the game sent, falling back when it is absent or junk. */
export const configNumber = (config: Record<string, unknown>, key: string, fallback: number): number => {
  const value = config[key];
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
};

export const clamp = (value: number, min: number, max: number) => Math.min(Math.max(value, min), max);

/** Map a value from one range onto another. */
export const convertRanges = (value: number, oldMin: number, oldMax: number, newMin: number, newMax: number) =>
  ((value - oldMin) * (newMax - newMin)) / (oldMax - oldMin) + newMin;

export const randomBetween = (min: number, max: number) => Math.random() * (max - min) + min;

/**
 * The art is drawn at a fixed pixel size for a 1024px-tall screen, so it is scaled to whatever
 * the player actually has. Ported from the upstream `v-ui-scaler` directive.
 *
 * ⚠️ outerHeight, not innerHeight -- the game's NUI reports the window, and innerHeight would
 *    shrink the whole board whenever a browser chrome appeared during development.
 */
export const useUiScaler = <T extends HTMLElement>(origin = 'center center') => {
  const ref = useRef<T>(null);

  useEffect(() => {
    const apply = () => {
      const el = ref.current;
      if (!el) return;

      el.style.transformOrigin = origin;
      el.style.transform = `scale(${window.outerHeight / 1024})`;
    };

    apply();
    window.addEventListener('resize', apply);
    return () => window.removeEventListener('resize', apply);
  }, [origin]);

  return ref;
};

/** Escape cancels any minigame. */
export const useEscapeCancel = (cancel: () => void) => {
  const saved = useRef(cancel);

  useEffect(() => {
    saved.current = cancel;
  }, [cancel]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      event.preventDefault();
      saved.current();
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);
};

export const finishMinigame = (game: MinigameName, status: MinigameStatus) =>
  postNui(MINIGAME_FINISHED, { game, status });
