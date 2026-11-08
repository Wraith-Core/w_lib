import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  clamp,
  configNumber,
  convertRanges,
  finishMinigame,
  MINIGAME_PIN_BROKEN,
  MinigameStatus,
  postNui,
  useEscapeCancel,
  useUiScaler,
} from './shared';
import { cls, useKit } from '../../kit/ui';

const MIN_ROT = -90;
const MAX_ROT = 90;
const KEY_REPEAT_RATE = 25;
const MOUSE_SMOOTHING = 2;
const PUSH_KEYS = new Set(['w', 'a', 's', 'd', 'arrowleft', 'arrowright']);

interface Props {
  config: Record<string, unknown>;
  onDone: () => void;
}

/**
 * The RDR2 lockpick, ported from the Minigame source (Vue) to React. Look and feel are unchanged:
 * same art, same pixel geometry, same timings.
 *
 * ★ Nearly all of the state here is in refs rather than useState, and deliberately. The cylinder
 *   ticks every 25ms and the pin follows the mouse; routing those through React state would
 *   re-render the tree a hundred times a second to move two transforms. So the loop writes to
 *   refs and pushes the transform straight onto the DOM node, and useState is reserved for the
 *   things that really do change the tree -- the pin count and the damaged/broken classes.
 */
const Lockpick: React.FC<Props> = ({ config, onDone }) => {
  const stage = useUiScaler<HTMLElement>('center center');

  const pinEl = useRef<HTMLDivElement>(null);
  const cylinderEl = useRef<HTMLDivElement>(null);
  const driverEl = useRef<HTMLDivElement>(null);

  const { rtl, t } = useKit();
  const [pinsTotal] = useState(() => Math.max(1, Math.floor(configNumber(config, 'pins', 1))));
  const [pinsRemaining, setPinsRemaining] = useState(pinsTotal);
  const [damaged, setDamaged] = useState(false);
  const [broken, setBroken] = useState(false);

  const pinRot = useRef(0);
  const cylRot = useRef(0);
  const solveDeg = useRef(Math.random() * 180 - 90);
  const pinHealth = useRef(configNumber(config, 'pinHealth', 100));
  const lastMousePos = useRef<number | null>(null);
  const pinLastDamaged = useRef(0);
  const pushing = useRef(false);
  const gameOver = useRef(false);
  const paused = useRef(false);

  const cylTimer = useRef<ReturnType<typeof setInterval> | null>(null);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const cfg = {
    solvePadding: configNumber(config, 'solvePadding', 4),
    maxDistFromSolve: configNumber(config, 'maxDistFromSolve', 45),
    pinDamage: configNumber(config, 'pinDamage', 20),
    pinDamageInterval: configNumber(config, 'pinDamageInterval', 150),
    cylRotSpeed: configNumber(config, 'cylRotSpeed', 3),
    pinHealth: configNumber(config, 'pinHealth', 100),
  };

  const cfgRef = useRef(cfg);
  cfgRef.current = cfg;

  /* ── the two transforms, written straight to the DOM ─────────────────── */

  const drawPin = () => {
    if (pinEl.current) pinEl.current.style.transform = `rotateZ(${pinRot.current}deg)`;
  };

  const drawCylinder = () => {
    const t = `rotateZ(${cylRot.current}deg)`;
    if (cylinderEl.current) cylinderEl.current.style.transform = t;
    if (driverEl.current) driverEl.current.style.transform = t;
  };

  const clearCyl = () => {
    if (cylTimer.current) {
      clearInterval(cylTimer.current);
      cylTimer.current = null;
    }
  };

  const clearReset = () => {
    if (resetTimer.current) {
      clearTimeout(resetTimer.current);
      resetTimer.current = null;
    }
  };

  const finish = useCallback(
    async (status: MinigameStatus) => {
      if (gameOver.current) return;

      gameOver.current = true;
      paused.current = true;
      pushing.current = false;
      clearCyl();
      clearReset();

      await finishMinigame('lockpick', status);
      onDone();
    },
    [onDone]
  );

  useEscapeCancel(() => void finish('canceled'));

  /* ── the pin breaking ─────────────────────────────────────────────────── */

  const resetPin = () => {
    cylRot.current = 0;
    pinRot.current = 0;
    pinHealth.current = cfgRef.current.pinHealth;
    lastMousePos.current = null;
    pinLastDamaged.current = 0;

    setDamaged(false);
    setBroken(false);
    drawPin();
    drawCylinder();
  };

  const breakPin = () => {
    if (paused.current || gameOver.current) return;

    paused.current = true;
    pushing.current = false;
    setBroken(true);
    clearCyl();

    void postNui(MINIGAME_PIN_BROKEN, {});

    setPinsRemaining((remaining) => {
      const left = remaining - 1;

      // ⚠️ Scheduled from inside the updater so the decision reads the count that will actually
      //    be on screen. Reading `pinsRemaining` here would see the value from this render and
      //    hand the player a spare pin they no longer have.
      resetTimer.current = setTimeout(() => {
        if (left > 0) {
          resetPin();
          paused.current = false;
        } else {
          void finish('failed');
        }
      }, 700);

      return left;
    });
  };

  const damagePin = () => {
    const now = Date.now();
    if (pinLastDamaged.current && now - pinLastDamaged.current <= cfgRef.current.pinDamageInterval) return;

    pinHealth.current -= cfgRef.current.pinDamage;
    pinLastDamaged.current = now;

    // Retriggered on the next frame so the jiggle animation restarts rather than being ignored
    // for already being on the element.
    setDamaged(false);
    requestAnimationFrame(() => setDamaged(true));

    if (pinHealth.current <= 0) breakPin();
  };

  /* ── pushing the cylinder ─────────────────────────────────────────────── */

  const pushCylinder = () => {
    clearCyl();
    pushing.current = true;

    // How far the cylinder may turn: all the way at the sweet spot, almost nothing far from it.
    const distFromSolve = clamp(
      Math.abs(pinRot.current - solveDeg.current) - cfgRef.current.solvePadding,
      0,
      cfgRef.current.maxDistFromSolve
    );

    const allowance = convertRanges(distFromSolve, 0, cfgRef.current.maxDistFromSolve, 1, 0.02) * MAX_ROT;

    cylTimer.current = setInterval(() => {
      cylRot.current += cfgRef.current.cylRotSpeed;

      if (cylRot.current >= MAX_ROT) {
        cylRot.current = MAX_ROT;
        drawCylinder();
        clearCyl();
        void finish('success');
        return;
      }

      if (cylRot.current >= allowance) {
        cylRot.current = allowance;
        damagePin();
      }

      drawCylinder();
    }, KEY_REPEAT_RATE);
  };

  const releaseCylinder = () => {
    pushing.current = false;
    clearCyl();

    cylTimer.current = setInterval(() => {
      cylRot.current = Math.max(cylRot.current - cfgRef.current.cylRotSpeed, 0);
      drawCylinder();

      if (cylRot.current <= 0) {
        cylRot.current = 0;
        clearCyl();
      }
    }, KEY_REPEAT_RATE);
  };

  /* ── input ────────────────────────────────────────────────────────────── */

  useEffect(() => {
    const onMouseMove = (event: MouseEvent) => {
      if (lastMousePos.current !== null && !gameOver.current && !paused.current) {
        pinRot.current = clamp(
          pinRot.current + (event.clientX - lastMousePos.current) / MOUSE_SMOOTHING,
          MIN_ROT,
          MAX_ROT
        );
        drawPin();
      }

      lastMousePos.current = event.clientX;
    };

    const onMouseLeave = () => {
      lastMousePos.current = null;
    };

    const onKeyDown = (event: KeyboardEvent) => {
      if (!PUSH_KEYS.has(event.key.toLowerCase())) return;
      event.preventDefault();

      if (pushing.current || gameOver.current || paused.current) return;
      pushCylinder();
    };

    const onKeyUp = (event: KeyboardEvent) => {
      if (!PUSH_KEYS.has(event.key.toLowerCase())) return;
      event.preventDefault();

      if (gameOver.current) return;
      releaseCylinder();
    };

    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('mouseleave', onMouseLeave);
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);

    return () => {
      clearCyl();
      clearReset();
      window.removeEventListener('mousemove', onMouseMove);
      window.removeEventListener('mouseleave', onMouseLeave);
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <main className="wl-lockpick">
      {/* ★ 4.4.0: ONE frame, the heists' paper note (w_heists' lockpick): the title, the lock on the paper, the picks
          left as squares, the hint and the keys. The game art and its geometry are untouched; the tools may lie
          across the note's edge, as they would on a table. */}
      <div className="wk-pick-veil" />
      <div className="wk-pick-shadow">
        <div className={cls('wk-pick-note', rtl && 'is-rtl')} dir={rtl ? 'rtl' : 'ltr'}>
          <div className="wk-pick-head">
            <div className="wf-note-q">{t('lockpick')}</div>
            <i className="wk-pick-rule" />
          </div>
          <div className="wk-pick-foot">
            <div className="wk-pick-pins" aria-label={`${t('pins')}: ${pinsRemaining}`}>
              {Array.from({ length: pinsTotal }, (_, i) => (
                <span key={i} className={cls('wk-pick-pin', i < pinsRemaining && 'is-done', i === pinsRemaining - 1 && broken && 'is-now')} />
              ))}
            </div>
            <div className="wk-pick-hint">{t('lockpick_hint')}</div>
            <div className="wk-pick-keys">
              <span><b className="wk-key">{t('mouse')}</b>{t('pick')}</span>
              <span><b className="wk-key">W A S D</b>{t('turn')}</span>
              <span><b className="wk-key">Esc</b>{t('leave')}</span>
            </div>
          </div>
        </div>
      </div>

      <section ref={stage} className="wl-lockpick-stage fade-in-bottom">
        <img className="wl-lockpick-collar" src="./img/lockpick/collar.webp" alt="" draggable={false} />

        <div ref={cylinderEl} className="wl-lockpick-cylinder" />
        <div ref={driverEl} className="wl-lockpick-driver" />

        <div ref={pinEl} className={`wl-lockpick-pin${damaged ? ' damaged' : ''}${broken ? ' broken' : ''}`}>
          <div className="wl-lockpick-pin-top" />
          <div className="wl-lockpick-pin-bottom" />
        </div>
      </section>
    </main>
  );
};

export default Lockpick;
