import { IconProp } from '@fortawesome/fontawesome-svg-core';
import { IconAnimation } from '../components/LibIcon';

export interface Option {
  menu?: string;
  title?: string;
  description?: string;
  arrow?: boolean;
  image?: string;
  icon?: IconProp | string;
  iconColor?: string;
  iconAnimation?: IconAnimation;
  progress?: number;
  colorScheme?: string;
  readOnly?: boolean;
  metadata?:
    | string[]
    | { [key: string]: any }
    | { label: string; value: any; progress?: number; colorScheme?: string }[];
  disabled?: boolean;
  /** 4.5.0: a place line under the row ("فالنتاين · 12 م منك"); whereMiss draws it as missing. */
  where?: string;
  whereMiss?: boolean;
  event?: string;
  serverEvent?: string;
  args?: any;
}

export interface Options {
  [key: string]: Option;
}

export interface ContextMenuProps {
  title: string;
  menu?: string;
  canClose?: boolean;
  options: Options | Option[];
  /** 4.5.0: a quiet line at the top of the card. */
  subtitle?: string;
  /** 4.5.0: the keys row, [{ key, label }]. */
  keys?: Array<{ key: string; label?: string }>;
}
