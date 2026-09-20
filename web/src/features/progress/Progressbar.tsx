import React, { useEffect, useRef, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';

interface ProgressbarProps {
  label: string;
  duration: number;
  position?: 'middle' | 'bottom';
  /**
   * ★ The script owns the clock.
   *
   *   Set, the ring stops timing itself and moves only when Lua sends `progressValue`. This is
   *   for work whose length the FRAME cannot know: a craft that a bench is timing, a download
   *   reporting bytes, a queue reporting position. Driving it from `duration` instead would put
   *   a second clock beside the real one -- started a frame later and drifting from it -- and
   *   the ring would empty before, or after, the thing it claims to be measuring.
   *
   *   `duration` is ignored while this is set, and `progressComplete` is never fired: the script
   *   that owns the clock decides when it is over, and takes the bar down itself.
   */
  driven?: boolean;
}

/**
 * The progress bar, drawn as an RDR core -- the same ring the HUD uses for health and stamina.
 *
 * ★ Geometry carried over exactly, not approximated: radius 44 with a stroke of 8, so the ring's
 *   inner edge sits at 40 -- meaning the disc must end at 10%. It is set to 9% so the two
 *   overlap: an exact meeting leaves a transparent thread from the antialiasing, and the
 *   overlap swallows it. Change one of those numbers and the other has to move with it.
 *
 * ★ And the sweep starts at the top and runs clockwise (the -90° rotation in CSS), as the
 *   game's own cores do.
 */
const R = 44;
const C = 2 * Math.PI * R;

const Progressbar: React.FC = () => {
  const [data, setData] = useState<ProgressbarProps | null>(null);

  const fillRef = useRef<SVGCircleElement>(null);
  const valueRef = useRef<HTMLElement>(null);
  const frame = useRef<number | null>(null);

  const stop = () => {
    if (frame.current !== null) {
      cancelAnimationFrame(frame.current);
      frame.current = null;
    }
  };

  useNuiEvent('progressCancel', () => {
    stop();
    setData(null);
  });

  useNuiEvent<ProgressbarProps>('progress', (payload) => {
    stop();
    setData(payload);
  });

  /** Move the ring and its readout. Shared so both clocks draw identically. */
  const paint = (ratio: number) => {
    const clamped = Math.min(1, Math.max(0, ratio));

    // Written straight to the nodes: the ring moves every frame and React need not know.
    fillRef.current?.setAttribute('stroke-dashoffset', String(C * (1 - clamped)));
    if (valueRef.current) valueRef.current.textContent = `${Math.round(clamped * 100)}%`;
  };

  /**
   * ⚠️ Arrives many times a second while a craft runs, and must NOT go through state -- a
   *    setState per tick would re-render the whole bar and, on a busy frame, drop the very
   *    updates it is meant to show. It paints the same two nodes the animation loop does.
   */
  useNuiEvent<number>('progressValue', (value) => {
    paint((Number(value) || 0) / 100);
  });

  useEffect(() => {
    if (!data) return;

    // The script is timing this one; nothing to animate. It paints on each progressValue.
    if (data.driven) {
      paint(0);
      return;
    }

    const duration = Number(data.duration) || 1000;
    const start = performance.now();

    const step = (now: number) => {
      const ratio = Math.min(1, (now - start) / duration);

      paint(ratio);

      if (ratio < 1) {
        frame.current = requestAnimationFrame(step);
      } else {
        frame.current = null;
        setData(null);
        fetchNui('progressComplete');
      }
    };

    frame.current = requestAnimationFrame(step);
    return stop;
  }, [data]);

  if (!data) return null;

  return (
    <div className="lb-layer" data-layer="progress">
      <div className={`lb-core ${data.position === 'middle' ? 'is-middle' : 'is-bottom'}`}>
        <span className="lb-core-ring">
          <svg viewBox="0 0 100 100">
            <circle className="lb-core-track" cx="50" cy="50" r={R} />
            <circle ref={fillRef} className="lb-core-fill" cx="50" cy="50" r={R} strokeDasharray={C} strokeDashoffset={C} />
          </svg>

          <span className="lb-core-disc">
            <b ref={valueRef} className="lb-core-value" dir="ltr">
              0%
            </b>
          </span>
        </span>

        {data.label && <span className="lb-core-label">{data.label}</span>}
      </div>
    </div>
  );
};

export default Progressbar;
