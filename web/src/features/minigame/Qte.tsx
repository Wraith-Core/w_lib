import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { configNumber, finishMinigame, MinigameStatus, randomBetween, useEscapeCancel, useUiScaler } from './shared';

interface Range {
  min: number;
  max: number;
}

interface Step {
  key: string;
  targetStartAngle: number;
  targetArcSize: number;
  targetEnd: number;
  rotationDuration: number;
}

const DEFAULT_KEYS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

/** One of eight entry flips, picked per round -- the board never arrives the same way twice. */
const ENTRY_ANIMATIONS = [
  'flip-in-hor-bottom',
  'flip-in-hor-top',
  'flip-in-ver-right',
  'flip-in-ver-left',
  'flip-in-diag-1-tr',
  'flip-in-diag-1-bl',
  'flip-in-diag-2-br',
  'flip-in-diag-2-tl',
];

const randomItem = <T,>(items: T[]) => items[Math.floor(Math.random() * items.length)];

interface Props {
  config: Record<string, unknown>;
  onDone: () => void;
}

/**
 * The QTE ring, ported from the Minigame source (Vue) to React. Same geometry, same timings,
 * same entry animations.
 *
 * ★ The indicator runs on requestAnimationFrame and writes its rotation straight to the DOM,
 *   as the lockpick does with its pin: the angle changes every frame, and re-rendering React
 *   sixty times a second to turn one element would cost far more than it draws.
 */
const Qte: React.FC<Props> = ({ config, onDone }) => {
  const panel = useUiScaler<HTMLElement>('center center');

  const indicatorEl = useRef<HTMLDivElement>(null);
  const progressEl = useRef<HTMLDivElement>(null);

  const cfg = useMemo(() => {
    const range = (key: string, fallback: Range): Range => {
      const value = config[key];
      if (!value || typeof value !== 'object') return fallback;

      const r = value as Partial<Range>;
      const min = typeof r.min === 'number' && Number.isFinite(r.min) ? r.min : fallback.min;
      const max = typeof r.max === 'number' && Number.isFinite(r.max) ? r.max : fallback.max;

      return { min: Math.min(min, max), max: Math.max(min, max) };
    };

    const delay = (key: string, fallback: number) => Math.max(0, Math.floor(configNumber(config, key, fallback)));

    const allowed = Array.isArray(config.allowedKeys)
      ? (config.allowedKeys as unknown[])
          .filter((k): k is string => typeof k === 'string' && k.trim().length > 0)
          .map((k) => k.trim().toUpperCase())
      : [];

    return {
      totalRounds: Math.max(1, Math.floor(configNumber(config, 'roundCount', 4))),
      rotationCount: Math.max(1, Math.floor(configNumber(config, 'rotationCount', 1))),
      introDelay: delay('introDelay', 300),
      successDelay: delay('successDelay', 450),
      failureDelay: delay('failureDelay', 550),
      roundDelay: delay('roundDelay', 100),
      keys: allowed.length > 0 ? allowed : DEFAULT_KEYS,
      targetStartAngle: range('targetStartAngle', { min: 100, max: 300 }),
      targetArcSize: range('targetArcSize', { min: 50, max: 60 }),
      rotationDuration: range('rotationDuration', { min: 2000, max: 3000 }),
    };
  }, [config]);

  const createStep = useCallback((): Step => {
    const targetStartAngle = Math.min(
      Math.max(randomBetween(cfg.targetStartAngle.min, cfg.targetStartAngle.max), 0),
      359
    );

    // ⚠️ Clamped so the arc cannot run past 360: the mask is a conic gradient and an end angle
    //    beyond a full turn silently draws nothing, giving a round that cannot be won.
    const maxArc = Math.max(1, 360 - targetStartAngle);
    const targetArcSize = Math.min(Math.max(randomBetween(cfg.targetArcSize.min, cfg.targetArcSize.max), 1), maxArc);

    return {
      key: randomItem(cfg.keys),
      targetStartAngle,
      targetArcSize,
      targetEnd: targetStartAngle + targetArcSize,
      rotationDuration: Math.max(100, randomBetween(cfg.rotationDuration.min, cfg.rotationDuration.max)),
    };
  }, [cfg]);

  const [step, setStep] = useState<Step>(() => createStep());
  const [round, setRound] = useState(1);
  const [feedback, setFeedback] = useState<'success' | 'failure' | null>(null);
  const [feedbackKey, setFeedbackKey] = useState(0);
  const [entryAnimation, setEntryAnimation] = useState(() => randomItem(ENTRY_ANIMATIONS));
  const [entryKey, setEntryKey] = useState(0);

  const stepRef = useRef(step);
  stepRef.current = step;

  const angle = useRef(0);
  const finished = useRef(false);
  const roundWon = useRef(false);
  const introPlaying = useRef(true);
  const feedbackPlaying = useRef(false);
  const roundStart = useRef(0);

  const frame = useRef<number | null>(null);
  const introTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const feedbackTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const roundTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  /** The angle at which the round is lost: the allowed turns, plus the far edge of the target. */
  const failureAngle = () => (cfg.rotationCount - 1) * 360 + stepRef.current.targetEnd;

  const clearFrame = () => {
    if (frame.current !== null) {
      cancelAnimationFrame(frame.current);
      frame.current = null;
    }
  };

  const clearTimer = (t: React.MutableRefObject<ReturnType<typeof setTimeout> | null>) => {
    if (t.current) {
      clearTimeout(t.current);
      t.current = null;
    }
  };

  const draw = () => {
    if (indicatorEl.current) {
      indicatorEl.current.style.transform = `translateX(-50%) rotate(${angle.current % 360}deg)`;
    }

    if (progressEl.current) {
      const progress = Math.min(Math.max(angle.current / failureAngle(), 0), 1) * 360;
      progressEl.current.style.background = `conic-gradient(from 0deg, rgb(242 242 242) 0deg, rgb(242 242 242) ${progress}deg, transparent ${progress}deg, transparent 360deg)`;
    }
  };

  const finish = useCallback(
    async (status: MinigameStatus) => {
      if (finished.current) return;

      finished.current = true;
      clearFrame();
      clearTimer(introTimer);
      clearTimer(feedbackTimer);
      clearTimer(roundTimer);

      await finishMinigame('qte', status);
      onDone();
    },
    [onDone]
  );

  useEscapeCancel(() => void finish('canceled'));

  const playFeedback = useCallback(
    (state: 'success' | 'failure', onComplete: () => void) => {
      clearTimer(feedbackTimer);

      feedbackPlaying.current = true;
      setFeedback(state);
      setFeedbackKey((k) => k + 1);

      feedbackTimer.current = setTimeout(
        () => {
          feedbackTimer.current = null;
          feedbackPlaying.current = false;
          setFeedback(null);
          onComplete();
        },
        state === 'success' ? cfg.successDelay : cfg.failureDelay
      );
    },
    [cfg.successDelay, cfg.failureDelay]
  );

  const tick = useCallback((time: number) => {
    if (finished.current || roundWon.current || feedbackPlaying.current) return;

    angle.current = ((time - roundStart.current) / stepRef.current.rotationDuration) * 360;
    draw();

    if (angle.current > failureAngle()) {
      clearFrame();
      playFeedbackRef.current('failure', () => void finishRef.current('failed'));
      return;
    }

    frame.current = requestAnimationFrame(tick);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /* The loop is started from timers that outlive a render, so it reaches the newest callbacks
     through refs instead of being rebuilt -- rebuilding it would restart the round. */
  const playFeedbackRef = useRef(playFeedback);
  const finishRef = useRef(finish);
  playFeedbackRef.current = playFeedback;
  finishRef.current = finish;

  const playRoundIntro = useCallback(
    (makeStep = true) => {
      clearFrame();
      clearTimer(introTimer);
      clearTimer(feedbackTimer);

      angle.current = 0;
      roundWon.current = false;
      feedbackPlaying.current = false;
      introPlaying.current = true;

      setFeedback(null);
      if (makeStep) setStep(createStep());
      setEntryAnimation(randomItem(ENTRY_ANIMATIONS));
      setEntryKey((k) => k + 1);

      draw();

      introTimer.current = setTimeout(() => {
        introTimer.current = null;
        introPlaying.current = false;
        roundStart.current = performance.now();
        frame.current = requestAnimationFrame(tick);
      }, cfg.introDelay);
    },
    [createStep, cfg.introDelay, tick]
  );

  const playRoundIntroRef = useRef(playRoundIntro);
  playRoundIntroRef.current = playRoundIntro;

  /* ── input ────────────────────────────────────────────────────────────── */

  useEffect(() => {
    /** The pressed letter, however the keyboard layout reports it. */
    const pressedLetter = (event: KeyboardEvent): string | null => {
      const key = event.key?.trim().toUpperCase();
      if (key && /^[A-Z]$/.test(key)) return key;

      const code = event.code?.match(/^Key([A-Z])$/);
      if (code) return code[1];

      if (event.keyCode >= 65 && event.keyCode <= 90) return String.fromCharCode(event.keyCode);

      return null;
    };

    const onKeyDown = (event: KeyboardEvent) => {
      if (finished.current || roundWon.current || introPlaying.current || feedbackPlaying.current) return;

      const pressed = pressedLetter(event);
      if (!pressed) return;

      event.preventDefault();

      const current = stepRef.current;
      const at = angle.current % 360;
      const inTarget = at >= current.targetStartAngle && at <= current.targetEnd;

      if (pressed !== current.key || !inTarget) {
        clearFrame();
        playFeedbackRef.current('failure', () => void finishRef.current('failed'));
        return;
      }

      roundWon.current = true;
      clearFrame();

      playFeedbackRef.current('success', () => {
        setRound((r) => {
          if (r >= cfg.totalRounds) {
            void finishRef.current('success');
            return r;
          }

          roundTimer.current = setTimeout(() => {
            roundTimer.current = null;
            playRoundIntroRef.current();
          }, cfg.roundDelay);

          return r + 1;
        });
      });
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [cfg.totalRounds, cfg.roundDelay]);

  /* The first round reuses the step made in useState, so it is not rerolled on mount. */
  useEffect(() => {
    playRoundIntroRef.current(false);

    return () => {
      clearFrame();
      clearTimer(introTimer);
      clearTimer(feedbackTimer);
      clearTimer(roundTimer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const mask = `conic-gradient(from 0deg, transparent 0deg, transparent ${step.targetStartAngle}deg, #000 ${step.targetStartAngle}deg, #000 ${step.targetEnd}deg, transparent ${step.targetEnd}deg, transparent 360deg)`;

  return (
    <main className="wl-qte">
      <section ref={panel} className="wl-qte-panel">
        <div
          key={`counter-${feedbackKey}`}
          className={`wl-qte-counter${feedback ? ` wl-qte-counter-${feedback}` : ''}`}
        >
          {round} / {cfg.totalRounds}
        </div>

        <div key={entryKey} className={`wl-qte-entry ${entryAnimation}`}>
          <div className={`wl-qte-circle${feedback ? ` wl-qte-feedback-${feedback}` : ''}`}>
            <div ref={progressEl} className="wl-qte-progress" />

            {feedback && <div key={feedbackKey} className={`wl-qte-halo wl-qte-halo-${feedback}`} />}
            {feedback && <div key={`${feedbackKey}-ripple`} className={`wl-qte-ripple wl-qte-ripple-${feedback}`} />}

            <div className="wl-qte-track" style={{ maskImage: mask, WebkitMaskImage: mask }} />

            <div className="wl-qte-inner">
              <span>{step.key}</span>
            </div>

            <div ref={indicatorEl} className="wl-qte-indicator" />
          </div>
        </div>
      </section>
    </main>
  );
};

export default Qte;
