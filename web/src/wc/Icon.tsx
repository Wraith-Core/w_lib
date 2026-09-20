import React, { CSSProperties } from 'react';
import Glyph from './Glyph';
import { isImageTexture, texturePath, wcAsset } from './bootstrap';
import { isIconUrl } from '../utils/isIconUrl';

/**
 * One icon slot for every menu, which decides for itself whether the art should be masked or
 * drawn.
 *
 * ★ Three ways an icon reaches us, and they cannot share one path:
 *
 *     a url            -- from Lua, or an http image  -> <img>
 *     a filled texture -- the RDR blips               -> <img>, they carry their own colour
 *     mask art         -- cross, tick, star, lock ... -> <Glyph>, tinted by currentColor
 *
 * ⚠️ Sending a filled blip through <Glyph> is what turned every wheel icon into a solid shape:
 *    the mask keeps a pixel wherever the art is opaque, and a blip's disc is opaque all the way
 *    across, so the whole disc came out painted in the text colour with the drawing inside it
 *    lost. The art was never wrong; the way it was being painted was.
 */

/**
 * Every shape an icon is allowed to arrive in.
 *
 * ⚠️ Kept structural rather than importing FontAwesome's IconProp: wc/ is the design layer and
 *    must not depend on an icon library. The `{ iconName }` member is IconLookup, which is the
 *    third form the context menu's typings permit.
 */
export type IconLike = string | [string, string] | { iconName?: string } | null;

/** FontAwesome arrives as `fa-solid fa-x`, a tuple, or a lookup; the texture is the last word. */
export const texName = (icon?: IconLike): string | undefined => {
  const raw =
    typeof icon === 'string'
      ? icon
      : Array.isArray(icon)
        ? icon[1]
        : icon && typeof icon === 'object'
          ? icon.iconName
          : undefined;

  return raw?.replace(/^fa[srlbd]?[- ]/, '').toLowerCase();
};

const Icon: React.FC<{
  icon?: IconLike;
  /** Drawn when there is no icon at all. Menus pass menu_bar to keep their column aligned. */
  fallback?: string;
  className?: string;
  style?: CSSProperties;
}> = ({ icon, fallback, className, style }) => {
  const raw = typeof icon === 'string' ? icon : undefined;

  // A url goes straight through, whatever it points at.
  if (raw && isIconUrl(raw) && !texturePath(raw)) {
    return <img src={raw} alt="" className={className} style={style} />;
  }

  const name = texName(icon);

  if (name && isImageTexture(name)) {
    const path = texturePath(name);
    if (path) return <img src={wcAsset(path)} alt="" className={className} style={style} />;
  }

  if (name) return <Glyph tex={name} className={className} style={style} />;
  if (fallback) return <Glyph tex={fallback} className={className} style={style} />;

  return null;
};

export default Icon;
