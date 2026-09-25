import React, { useCallback, useEffect, useRef, useState } from 'react';
import { postNui } from '../../utils/postNui';
import { keymaps } from './keymaps';

/**
 * The five sides of the hold indicator, as fractions of each edge.
 *
 * ★ The border is drawn as four gradients (top / right / bottom / left) and filled in sequence
 *   from the top centre, clockwise, back to the top centre. That is why the top edge needs two
 *   numbers: the run out to the right corner (`rTop`, which starts at 50 because the fill
 *   begins in the middle) and the run home from the left (`lTop`, which finishes at 50).
 */
interface Fill {
  rTop: number;
  lTop: number;
  right: number;
  bottom: number;
  left: number;
}

const EMPTY: Fill = { rTop: 50, lTop: 0, right: 0, bottom: 0, left: 0 };

/**
 * The fill at a given fraction of the hold, 0 to 1.
 *
 * ★ One function for both directions. The original ran the same five-branch ladder twice --
 *   once against elapsed/duration going forward, once against a computed ratio coming back --
 *   and the two copies had to be kept identical by hand. Taking the ratio as the argument makes
 *   them the same code, so a change to the shape cannot apply to only one direction.
 *
 * The segment boundaries (12.5 / 37.5 / 62.5 / 87.5) are the corners: half the top edge, then
 * a quarter of the perimeter per side, then the last half of the top edge.
 */
function fillAt(ratio: number): Fill {
  const p = Math.min(1, Math.max(0, ratio));

  if (p <= 0) return EMPTY;

  if (p <= 0.125) return { ...EMPTY, rTop: 50 + (p / 0.125) * 50 };
  if (p <= 0.375) return { ...EMPTY, rTop: 100, right: ((p - 0.125) / 0.25) * 100 };
  if (p <= 0.625) return { ...EMPTY, rTop: 100, right: 100, bottom: ((p - 0.375) / 0.25) * 100 };
  if (p <= 0.875)
    return { ...EMPTY, rTop: 100, right: 100, bottom: 100, left: ((p - 0.625) / 0.25) * 100 };

  return { rTop: 100, right: 100, bottom: 100, left: 100, lTop: ((p - 0.875) / 0.125) * 50 };
}

interface Props {
  kkey: string;
  holdTime?: number | false;
  isNextPage?: boolean;
  disabled?: boolean;
  /** Is the key held right now? Driven by keyDown/keyUp from the game. */
  pressed?: boolean;
}

const KeyboardKey: React.FC<Props> = ({ kkey, holdTime, isNextPage = false, disabled = false, pressed = false }) => {
  const keymap = keymaps[kkey];
  const holdable = Boolean(holdTime);
  const durationMs = holdTime || 1000;

  const [fill, setFill] = useState<Fill>(EMPTY);
  const [active, setActive] = useState(false);

  /* Refs, not state: these are read and written inside the timer and must not re-render it. */
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);
  const startPressed = useRef(0);
  const endPressed = useRef(0);
  const completedSent = useRef(false);

  const stopTimer = () => {
    if (timer.current) {
      clearInterval(timer.current);
      timer.current = null;
    }
  };

  /**
   * ⚠️ The body carries `kkey` because that is the field the Lua reads
   *    (`data.kkey:lower()` in modules/prompt-nui/client.lua). Renaming it here silently stops
   *    every prompt on the server from ever completing.
   */
  const send = useCallback(
    (event: 'keyCompleted' | 'keyUp') => {
      if (disabled) return;
      void postNui(event, { kkey, holdTime, isNextPage, disabled });
    },
    [kkey, holdTime, isNextPage, disabled]
  );

  /* ── held ─────────────────────────────────────────────────────────────── */

  const onDown = useCallback(() => {
    if (disabled) return;

    setActive(true);

    if (!holdable) {
      // A tap: it completes the moment it is pressed, once.
      if (!completedSent.current) {
        completedSent.current = true;
        send('keyCompleted');
      }
      return;
    }

    stopTimer();

    // ★ Resuming, not restarting: a key let go and pressed again within the hold window picks
    //   up where it stopped, because the release animation is still unwinding. Without this the
    //   player who stutters on the key never finishes a hold no matter how long they press.
    const offset = endPressed.current > 0 ? Math.max(durationMs - (Date.now() - endPressed.current), 0) : 0;

    startPressed.current = Date.now() - offset;
    setFill(offset > 0 ? fillAt(offset / durationMs) : EMPTY);

    timer.current = setInterval(() => {
      const elapsed = Date.now() - startPressed.current;

      if (elapsed >= durationMs) {
        setFill(fillAt(1));
        stopTimer();
        send('keyCompleted');
      } else {
        setFill(fillAt(elapsed / durationMs));
      }
    }, 16);
  }, [disabled, holdable, durationMs, send]);

  /* ── released ─────────────────────────────────────────────────────────── */

  const onUp = useCallback(() => {
    setActive(false);
    completedSent.current = false;

    if (!holdable) return;

    // No timer left means the hold had already completed: nothing to unwind, so it clears at once.
    const wasCompleted = !timer.current;
    stopTimer();

    if (wasCompleted) {
      setFill(EMPTY);
      endPressed.current = 0;
      return;
    }

    const progress = Math.min(Date.now() - startPressed.current, durationMs);

    endPressed.current = Date.now() - (durationMs - progress);
    startPressed.current = Date.now();

    const forward = Math.min(1, progress / durationMs);

    // The unwind takes as long as the hold lasted, so letting go halfway rewinds over that half.
    timer.current = setInterval(() => {
      const reversed = Math.min(1, (Date.now() - startPressed.current) / progress);
      const effective = forward * (1 - reversed);

      setFill(fillAt(effective));

      if (reversed >= 1 || effective <= 0) {
        stopTimer();
        setFill(EMPTY);
      }
    }, 16);
  }, [holdable, durationMs]);

  /* The game drives the press: keyDown / keyUp arrive as messages, never from the browser. */
  useEffect(() => {
    if (pressed) onDown();
    else onUp();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pressed]);

  useEffect(() => stopTimer, []);

  return (
    <div
      className={`keyboardKey bebas${holdable ? ' holdable' : ''}${active ? ' active' : ''}${
        !keymap?.text && keymap?.image ? ' is-image' : ''
      }`}
    >
      {holdable && (
        <div className="progressContainer">
          <div
            className="progress"
            style={
              {
                '--scale-r-top': fill.rTop,
                '--scale-l-top': fill.lTop,
                '--scale-right': fill.right,
                '--scale-bottom': fill.bottom,
                '--scale-left': fill.left,
              } as React.CSSProperties
            }
          />
        </div>
      )}

      <div className="activeIndicator" />

      {keymap?.text ? (
        <div className="text">{keymap.text}</div>
      ) : keymap?.image ? (
        <img src={keymap.image} className="image" alt={kkey} />
      ) : (
        <div className="text">{kkey}</div>
      )}
    </div>
  );
};

export default KeyboardKey;
