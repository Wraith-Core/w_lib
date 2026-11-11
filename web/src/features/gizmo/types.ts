/** The gizmo's wire format -- fixed by modules/gizmo/client.lua. */

export interface GizmoVector {
  x: number;
  y: number;
  z: number;
}

export type GizmoMode = 'translate' | 'rotate';

/**
 * What `SetupGizmo` carries.
 *
 * ⚠️ `handle` is the switch: the module sends `{ handle = nil }` to close (gizmo/client.lua),
 *    so a missing handle is not an error -- it is the documented way to say 'nothing selected'.
 */
export interface GizmoEntity {
  handle?: number | null;
  position: GizmoVector;
  rotation: GizmoVector;
  gizmoMode?: GizmoMode;
  allowTranslateX?: boolean;
  allowTranslateY?: boolean;
  allowTranslateZ?: boolean;
  allowRotateX?: boolean;
  allowRotateY?: boolean;
  allowRotateZ?: boolean;
  rotationSnap?: number;
  allowSnapToGround?: boolean;
  /** The buttons on the screen, in the player's language (gizmo/client.lua uiLabels). */
  labels?: { move?: string; rotate?: string; confirm?: string; cancel?: string };
}

export interface CameraData {
  position: GizmoVector;
  rotation?: GizmoVector;
}
