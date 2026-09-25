import React, { Suspense, useEffect, useRef, useState } from 'react';
import { TransformControls } from '@react-three/drei';
import { Color, MathUtils, Mesh, Object3D } from 'three';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { postNui } from '../../utils/postNui';
import { GizmoEntity, GizmoMode, GizmoVector } from './types';

/**
 * ★ Ink, paper and one red on every interface (w_lib/nui/theme/tokens.css). three's
 *   TransformControls paints its handles in pure red, green and blue, its planes in yellow, cyan
 *   and magenta. Here each handle takes a paper step instead, so the three axes are still told
 *   apart -- by tone, as well as by the direction they point:
 *     X (red) -> paper, three's Y = the game's Z, up (green) -> paper-dim,
 *     three's Z = the game's Y (blue) -> paper-faint; the planes and the view ring follow the
 *     same steps, white and grey go to paper and paper-faint.
 *   The hover highlight is the control's own (full opacity, lerped toward white, the others
 *   faded), so it now brightens a paper step instead of a hue.
 *
 * ⚠️ The control caches each material's first colour in `tempColor` on its first frame and resets
 *    to it every frame after. Both are written, so the tone holds whichever of the two ran first.
 */
const PAPER = '#EDE6D6';
const PAPER_DIM = '#B9AF9C';
const PAPER_FAINT = '#7D7466';

const toneFor = (c: Color): string => {
  const { r, g, b } = c;
  const hi = (v: number) => v > 0.5;
  if (Math.max(r, g, b) - Math.min(r, g, b) < 0.1) return Math.max(r, g, b) > 0.5 ? PAPER : PAPER_FAINT;
  if (hi(r) && hi(g)) return PAPER; // yellow: the XY plane, the view ring
  if (hi(g) && hi(b)) return PAPER_DIM; // cyan: the YZ plane
  if (hi(r) && hi(b)) return PAPER_FAINT; // magenta: the XZ plane
  if (hi(r)) return PAPER; // X
  if (hi(g)) return PAPER_DIM; // three's Y, the game's Z
  return PAPER_FAINT; // three's Z, the game's Y
};

type TintedMaterial = { color?: Color; tempColor?: Color; wMono?: boolean };

const monoGizmo = (root: Object3D | null) => {
  root?.traverse((object) => {
    const material = (object as Mesh).material as TintedMaterial | TintedMaterial[] | undefined;
    for (const m of Array.isArray(material) ? material : material ? [material] : []) {
      if (!m?.color || m.wMono) continue;
      const tone = toneFor(m.tempColor ?? m.color);
      m.color.set(tone);
      m.tempColor?.set(tone);
      m.wMono = true;
    }
  });
};

/**
 * RDR3 is Z-up and left-handed; three.js is Y-up and right-handed. The whole conversion is
 * these two functions, and every position in this file goes through one of them.
 *
 *     game (x, y, z)  ->  three (x, z, -y)
 *     three (x, y, z) ->  game  (x, -z, y)
 *
 * ⚠️ Rotation carries the same swap but NOT the sign on the way in -- the game's rotation is
 *    already expressed about its own axes, so only the mapping changes, and the order must be
 *    set to YZX before the angles are written or they compose in the wrong sequence.
 */
const toThreePosition = (v: GizmoVector): [number, number, number] => [v.x, v.z, -v.y];
const toGamePosition = (mesh: Mesh): GizmoVector => ({
  x: mesh.position.x,
  y: -mesh.position.z,
  z: mesh.position.y,
});

const toThreeRotation = (v: GizmoVector): [number, number, number] => [
  MathUtils.degToRad(v.x),
  MathUtils.degToRad(v.z),
  MathUtils.degToRad(v.y),
];
const toGameRotation = (mesh: Mesh): GizmoVector => ({
  x: MathUtils.radToDeg(mesh.rotation.x),
  y: MathUtils.radToDeg(-mesh.rotation.z),
  z: MathUtils.radToDeg(mesh.rotation.y),
});

interface Props {
  entity: GizmoEntity;
}

export const Transform: React.FC<Props> = ({ entity }) => {
  const mesh = useRef<Mesh>(null!);

  const [mode, setMode] = useState<GizmoMode>(entity.gizmoMode ?? 'translate');
  const [snapEnabled, setSnapEnabled] = useState(false);

  const allow = {
    translateX: entity.allowTranslateX ?? true,
    translateY: entity.allowTranslateY ?? true,
    translateZ: entity.allowTranslateZ ?? true,
    rotateX: entity.allowRotateX ?? true,
    rotateY: entity.allowRotateY ?? true,
    rotateZ: entity.allowRotateZ ?? true,
  };

  const snap = entity.rotationSnap ?? 5;

  /* Seat the mesh wherever the game says the entity is, on every fresh SetupGizmo. */
  useEffect(() => {
    if (!mesh.current) return;

    mesh.current.position.set(...toThreePosition(entity.position));
    mesh.current.rotation.order = 'YZX';
    mesh.current.rotation.set(...toThreeRotation(entity.rotation));

    if (entity.gizmoMode) setMode(entity.gizmoMode);
  }, [entity]);

  useNuiEvent<GizmoMode>('SetGizmoMode', (value) => setMode(value));
  useNuiEvent<boolean>('EnableRotationSnap', (value) => setSnapEnabled(value ?? false));

  /**
   * Every drag reports the new transform and the game answers.
   *
   * ★ A reply that is not 'ok' is a refusal -- the game moved the entity somewhere else, or
   *   nowhere -- and it carries the position it actually settled on. So the mesh is snapped
   *   back to that, or the handle would sit where the player dragged it while the entity is
   *   elsewhere, and every later drag would be measured from a lie.
   */
  const onObjectChange = async () => {
    if (!mesh.current) return;

    const response = await postNui<{ status?: string; position: GizmoVector; rotation: GizmoVector }>(
      'gizmo:UpdateEntity',
      {
        handle: entity.handle,
        position: toGamePosition(mesh.current),
        rotation: toGameRotation(mesh.current),
      }
    );

    if (response?.status === 'ok' || !response?.position) return;

    mesh.current.position.set(...toThreePosition(response.position));
    mesh.current.rotation.order = 'YZX';
    mesh.current.rotation.set(
      MathUtils.degToRad(response.rotation.x),
      MathUtils.degToRad(response.rotation.z),
      MathUtils.degToRad(response.rotation.y)
    );
  };

  /* ⚠️ showY is the game's Z and showZ is the game's Y -- the same axis swap as the vectors.
     Reading these as the letters they spell is the easiest way to break this file. */
  return (
    <Suspense fallback={null}>
      <TransformControls
        ref={monoGizmo}
        size={0.5}
        object={mesh}
        mode={mode}
        onObjectChange={onObjectChange}
        showX={mode === 'translate' ? allow.translateX : allow.rotateX}
        showY={mode === 'translate' ? allow.translateZ : allow.rotateZ}
        showZ={mode === 'translate' ? allow.translateY : allow.rotateY}
        rotationSnap={snapEnabled ? snap : null}
      />
      <mesh ref={mesh} />
    </Suspense>
  );
};
