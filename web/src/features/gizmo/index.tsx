import React, { Suspense, lazy, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { GizmoEntity } from './types';

/**
 * The canvas is a separate chunk, fetched the first time a gizmo opens.
 *
 * ⚠️ three.js and drei are 865 kB of the bundle -- more than a third of it -- for a mapping tool
 *    that no resource on this server calls. Imported normally they would ride in the main chunk
 *    and every player would download them, every session, to draw nothing. A dynamic import
 *    leaves them in their own file that the frame asks for only when the tool is actually used.
 *
 * ★ Which costs nothing at the moment of use: the request is local (nui:// off disk), and the
 *   gizmo is opened deliberately by someone editing the map, not in the middle of play.
 */
const GizmoCanvas = lazy(() => import('./GizmoCanvas'));

/**
 * The gizmo's mount gate.
 *
 * `handle` is the game's own open/close signal -- modules/gizmo/client.lua sends
 * `SetupGizmo { handle = nil }` to close -- so it decides both the chunk load and the WebGL
 * context, and neither exists while the tool is shut.
 */
const Gizmo: React.FC = () => {
  const [entity, setEntity] = useState<GizmoEntity | null>(null);

  useNuiEvent<GizmoEntity>('SetupGizmo', (data) => {
    setEntity(data?.handle ? data : null);
  });

  if (!entity) return null;

  return (
    <Suspense fallback={null}>
      <GizmoCanvas entity={entity} />
    </Suspense>
  );
};

export default Gizmo;
