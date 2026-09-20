import React from 'react';
import { Canvas, useThree } from '@react-three/fiber';
import { PerspectiveCamera } from '@react-three/drei';
import { MathUtils } from 'three';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { Transform } from './Transform';
import { CameraData, GizmoEntity } from './types';

/**
 * The game's camera, mirrored into the scene so the handles line up with what the player sees.
 *
 * ★ zRot is carried over from the Gizmo source unchanged. RDR3 reports a pitch and a yaw that
 *   need the yaw's sign flipped in two of the four quadrants; the expression below is that rule.
 *   It looks arbitrary because it is empirical -- do not 'simplify' it without a camera to test.
 */
const zRot = (pitch: number, yaw: number) =>
  pitch > 0 && pitch < 90 ? yaw : (pitch > -180 && pitch < -90) || pitch > 0 ? -yaw : yaw;

const GameCamera: React.FC = () => {
  const { camera } = useThree();

  useNuiEvent<CameraData>('SetCameraPosition', ({ position, rotation }) => {
    camera.position.set(position.x, position.z, -position.y);
    camera.rotation.order = 'YZX';

    if (rotation) {
      camera.rotation.set(
        MathUtils.degToRad(rotation.x),
        MathUtils.degToRad(zRot(rotation.x, rotation.z)),
        MathUtils.degToRad(rotation.y)
      );
    }

    camera.updateProjectionMatrix();
  });

  return <PerspectiveCamera position={[0, 0, 10]} makeDefault onUpdate={(self) => self.updateProjectionMatrix()} />;
};

/**
 * The 3D transform gizmo, ported from the Gizmo source. Its look is unchanged -- the handles are
 * three.js's own TransformControls, which is what the source drew too.
 *
 * ⚠️ THE CANVAS IS MOUNTED ONLY WHILE AN ENTITY IS SELECTED, which the source did not do.
 *    It could afford a permanent <Canvas> because it owned its own frame and that frame was
 *    loaded on demand. This frame is always loaded, so a permanent canvas would hold a WebGL
 *    context open for every player for the whole session -- to draw nothing, since the gizmo is
 *    a mapping tool. `handle` is the game's own open/close signal, so it gates the mount.
 */
const GizmoCanvas: React.FC<{ entity: GizmoEntity }> = ({ entity }) => (
  <div className="wl-gizmo-root">
    <Canvas>
      <GameCamera />
      <Transform entity={entity} />
    </Canvas>
  </div>
);

export default GizmoCanvas;
