import { ToastPosition } from 'react-hot-toast';
import { IconProp } from '@fortawesome/fontawesome-svg-core';
import { Sx } from '@mantine/core';
import { IconAnimation } from '../components/LibIcon';

export interface NotificationProps {
  style?: Sx;
  description?: string;
  title?: string;
  duration?: number;
  showDuration?: boolean;
  /* ★ `| string` so a texture name is accepted alongside a FontAwesome one. Icons resolve
     against this resource's own art now -- see wc/Icon -- and IconProp is a closed union of
     FontAwesome's names, which would reject every RDR texture we ship. context, menu and
     radial were already widened; these three were not, and the difference was arbitrary. */
  icon?: IconProp | string;
  iconColor?: string;
  iconAnimation?: IconAnimation;
  /**
   * ⚠️ Wider than react-hot-toast's ToastPosition, and deliberately: the stylesheet carries
   *    pos-center-left and pos-center-right, and Lua may send either. The type was the only
   *    thing that disagreed -- narrower than both the CSS and the caller, which made a working
   *    position look like a mistake.
   */
  position?: ToastPosition | 'top' | 'bottom' | 'center-left' | 'center-right';
  id?: number | string;
  type?: string;
  alignIcon?: 'top' | 'center';
}
