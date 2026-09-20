import { IconProp } from '@fortawesome/fontawesome-svg-core';
import React from 'react';
import { IconAnimation } from '../components/LibIcon';

export type TextUiPosition = 'right-center' | 'left-center' | 'top-center' | 'bottom-center';

export interface TextUiProps {
  text: string;
  position?: TextUiPosition;
  /* ★ `| string` so a texture name is accepted alongside a FontAwesome one. Icons resolve
     against this resource's own art now -- see wc/Icon -- and IconProp is a closed union of
     FontAwesome's names, which would reject every RDR texture we ship. context, menu and
     radial were already widened; these three were not, and the difference was arbitrary. */
  icon?: IconProp | string;
  iconColor?: string;
  iconAnimation?: IconAnimation;
  style?: React.CSSProperties;
  alignIcon?: 'top' | 'center';
}
