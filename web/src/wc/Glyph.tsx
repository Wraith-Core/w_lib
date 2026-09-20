import React, { CSSProperties } from 'react';

/**
 * A white-on-transparent RDR2 texture, painted through a CSS mask so it takes the surrounding
 * `color` rather than the colour it was drawn in.
 *
 * ★ Masked, not an <img>. The art ships white; a mask lets one file serve a dim label, a red
 *   warning and a cream heading without three copies of the picture.
 *
 * `tex` is the texture's name as registered by bootstrapWcAssets -- `lock`, `tick`, `cross`,
 * `star`, `menu_icon_rank`, and the blips.
 */
export default function Glyph({
  tex,
  className,
  style,
}: {
  tex: string;
  className?: string;
  style?: CSSProperties;
}) {
  /* ⚠️ The fallback is not decoration. .wc-glyph paints `background-color: currentColor` and
     relies on the mask to cut a shape out of it, so an unregistered name -- `palette`,
     `warehouse`, any FontAwesome word a consumer passes through -- left the mask undefined and
     drew a solid filled square. Falling back to menu_bar, the same mark the context menu gives
     a row with no icon, turns an unknown icon into a quiet placeholder instead of a blot. */
  const image = `var(--tex-${tex}, var(--tex-menu_bar))`;

  const mask: CSSProperties = {
    WebkitMaskImage: image,
    maskImage: image,
    ...style,
  };

  return <span className={`wc-glyph${className ? ` ${className}` : ''}`} style={mask} aria-hidden="true" />;
}
