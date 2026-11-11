import React, { useEffect, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { postNui } from '../../utils/postNui';
import { GizmoEntity, GizmoMode } from './types';

/**
 * The gizmo's buttons on the screen: Move / Rotate (which handles the gizmo shows), Confirm, Cancel.
 *
 * ★ The mouse is free while the gizmo is open (it drags the handles), so the choice the key cards offer is also a
 *   click here -- the owner asked for a button to turn the arrows into rings. Each click is a `gizmo:Action` the
 *   game runs as if its key were pressed; the mode comes back as SetGizmoMode, so the buttons and the key cards
 *   always show the same thing.
 * ⚠️ Above the canvas (z-index), and only the bar takes the pointer: the rest of the screen stays the canvas's.
 */
export const Toolbar: React.FC<{ entity: GizmoEntity }> = ({ entity }) => {
  const [mode, setMode] = useState<GizmoMode>(entity.gizmoMode ?? 'translate');
  const L = entity.labels ?? {};

  useEffect(() => {
    if (entity.gizmoMode) setMode(entity.gizmoMode);
  }, [entity]);

  useNuiEvent<GizmoMode>('SetGizmoMode', (value) => setMode(value));

  const send = (action: string, extra?: Record<string, unknown>) => postNui('gizmo:Action', { action, ...extra });

  return (
    <div className="wl-gizmo-bar" onPointerDown={(e) => e.stopPropagation()}>
      <button
        type="button"
        className={`wl-gizmo-btn${mode === 'translate' ? ' is-on' : ''}`}
        onClick={() => send('mode', { mode: 'translate' })}
      >
        {L.move ?? 'Move'}
      </button>
      <button
        type="button"
        className={`wl-gizmo-btn${mode === 'rotate' ? ' is-on' : ''}`}
        onClick={() => send('mode', { mode: 'rotate' })}
      >
        {L.rotate ?? 'Rotate'}
      </button>
      <span className="wl-gizmo-sep" />
      <button type="button" className="wl-gizmo-btn is-primary" onClick={() => send('confirm')}>
        {L.confirm ?? 'Confirm'}
      </button>
      <button type="button" className="wl-gizmo-btn" onClick={() => send('cancel')}>
        {L.cancel ?? 'Cancel'}
      </button>
    </div>
  );
};
