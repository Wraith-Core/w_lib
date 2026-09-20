/* ============================================================
 * Radial geometry -- the same module w_wheel uses, reduced to what a menu needs.
 *
 * Angles are degrees from the top of the screen, clockwise. SVG starts its angle at the +x
 * axis and turns anticlockwise, hence:
 *
 *     x = sin(a)   ·   y = -cos(a)
 *
 * That one equation is the whole difference. Everything below uses it and never re-derives it.
 * ============================================================ */

/** The surface is drawn on a 200-unit box, so every radius below is a percentage doubled. */
export const R_OUT = 100;

/** The ring the bubbles sit on. */
export const R_ICON = 85;

/**
 * ⚠️ The deadzone is the centre disc's own radius, not the wheel's inner edge.
 *
 *    w_wheel can use a smaller one because its centre is a readout and nothing else. Ours is
 *    the way out of the menu, so the cursor must be able to rest on it without the wheel
 *    quietly selecting whatever lies beyond -- a click meant for "close" would fire an option.
 */
export const R_DEAD = 58;

/** A point on a circle of radius r at angle a in degrees (0 = top). */
export function polar(a: number, r: number): [number, number] {
  const rad = (a * Math.PI) / 180;
  return [Math.sin(rad) * r, -Math.cos(rad) * r];
}

/** The angle of a vector from the centre, normalised to [0,360). */
export function angleOf(dx: number, dy: number): number {
  const deg = (Math.atan2(dx, -dy) * 180) / Math.PI;
  return (deg + 360) % 360;
}

/**
 * Which seat lies in the given direction.
 *
 * ★ Selection is by angle, not by hovering the bubble. RDR2's wheel picks whatever sector the
 *   cursor points at however far out it is; making each bubble a hover target would force the
 *   player to land on a small disc, which is slow and fussy in a way nobody expects.
 */
export function seatAt(count: number, angle: number): number {
  if (count < 1) return -1;
  return Math.round(angle / (360 / count)) % count;
}

/** The centre of seat i, as percentages of the surface box. */
export function seatStyle(i: number, count: number): { left: string; top: string } {
  const [x, y] = polar((i / Math.max(1, count)) * 360, R_ICON);

  return {
    left: `${50 + (x / R_OUT) * 50}%`,
    top: `${50 + (y / R_OUT) * 50}%`,
  };
}
