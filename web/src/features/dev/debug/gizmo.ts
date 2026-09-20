import { debugData } from '../../../utils/debugData';

/**
 * The gizmo is on the `action` contract, so it uses debugData rather than debugType.
 *
 * ⚠️ A camera is sent first and separately. Without SetCameraPosition the scene keeps the
 *    default camera at z=10 looking at the origin, and an entity placed at real world
 *    coordinates sits kilometres off screen -- the tool looks broken when it is merely aimed
 *    somewhere else. Here both are put near the origin so the handles are in view.
 */
export const debugGizmo = () => {
  debugData(
    [
      {
        action: 'SetCameraPosition',
        data: {
          position: { x: 0, y: -6, z: 3 },
          rotation: { x: -20, y: 0, z: 0 },
        },
      },
    ],
    0
  );

  debugData(
    [
      {
        action: 'SetupGizmo',
        data: {
          handle: 1,
          position: { x: 0, y: 0, z: 0 },
          rotation: { x: 0, y: 0, z: 0 },
          gizmoMode: 'translate',
          rotationSnap: 5,
        },
      },
    ],
    50
  );
};

export const debugGizmoRotate = () => debugData([{ action: 'SetGizmoMode', data: 'rotate' }], 0);
export const debugGizmoTranslate = () => debugData([{ action: 'SetGizmoMode', data: 'translate' }], 0);

/** handle: null is the module's own way of saying 'nothing selected' -- it closes the tool. */
export const debugGizmoHide = () => debugData([{ action: 'SetupGizmo', data: { handle: null } }], 0);
