import React, { useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { cls, Txt, useKit } from '../../kit/ui';

/**
 * World pins (4.5.0): numbered labels over the world (lib.setPins, resource/interface/client/pins.lua).
 *
 * The builders' pins, shared: a paper tag with its step number and a stem down to the spot. Lua projects every spot
 * ~25 times a second and sends the screen points (0..1); the page only places the tags.
 *   st 'cur'    the step being built: the red band
 *   st 'miss'   a place still missing: dashed, soft red (it floats in front of the camera)
 *   aim         the pin the camera looks at ("J on a pin"): outlined
 *   far         past the set's `near`: faded
 */
interface Pin {
  k: string;
  x: number;
  y: number;
  n?: number;
  label?: string;
  sub?: string;
  st?: 'cur' | 'miss';
  aim?: boolean;
  far?: boolean;
}

const Pins: React.FC = () => {
  const { rtl } = useKit();
  const [pins, setPins] = useState<Pin[]>([]);

  useNuiEvent<{ pins?: Pin[] }>('wl:pins', (data) => setPins(Array.isArray(data?.pins) ? data.pins : []));

  if (!pins.length) return null;

  return (
    <div className={cls('wf', 'wk-pins', rtl && 'is-rtl')} dir={rtl ? 'rtl' : 'ltr'} aria-hidden="true">
      {pins.map((p) => (
        <div
          key={p.k}
          className={cls('wk-pin', p.st === 'cur' && 'is-cur', p.st === 'miss' && 'is-miss', p.aim && 'is-aim', p.far && 'is-far')}
          style={{ left: `${(Number(p.x) || 0) * 100}%`, top: `${(Number(p.y) || 0) * 100}%` }}
        >
          {typeof p.n === 'number' ? <b className="wk-pin-n">{p.n}</b> : <i className="wk-pin-dot" />}
          {p.label ? <span className="wk-pin-text"><Txt s={p.label} /></span> : null}
          {p.sub ? <span className="wk-pin-sub"><Txt s={p.sub} /></span> : null}
        </div>
      ))}
    </div>
  );
};

export default Pins;
