import { debugData } from '../../../utils/debugData';
import { wcAsset } from '../../../wc/bootstrap';
import type { RadialMenuItem } from '../../../typings';

/**
 * ★ Every icon here is art this resource actually ships -- the RDR blips in tex/blips and the
 *   mask art in tex/ui. The mock used to ask for 'palette' and 'warehouse', FontAwesome names
 *   with nothing behind them, so the preview drew a filled square in every bubble and told us
 *   nothing about the wheel. The one remote image it also carried was, of all things, a white
 *   square from an icon site.
 */
export const debugRadial = () => {
  debugData<{ items: RadialMenuItem[]; sub?: boolean }>([
    {
      action: 'openRadialMenu',
      data: {
        items: [
          // Carries a submenu, so it wears the gold ring.
          { icon: 'blip_camp', label: 'Camp', menu: 'camp' },
          { icon: 'blip_campfire', label: 'Campfire' },
          { icon: 'blip_shop_blacksmith', label: 'Blacksmith' },
          { icon: 'blip_shop_gunsmith', label: 'Gunsmith' },
          { icon: 'blip_ammo_bullets', label: 'Ammunition' },
          // A plain image url, which is how a consumer passes its own art.
          { icon: wcAsset('assets/images/icons/item.png'), label: 'Hand mirror' },
          { icon: 'star', label: 'Honour' },
          { icon: 'blip_camp_tent', label: 'A label long enough to show how the centre wraps it' },
        ],
      },
    },
  ]);
};

/**
 * The same wheel one level down: `sub` puts the back arrow in the centre instead of the cross,
 * and `option` names the seat we came from so it is highlighted on arrival.
 */
export const debugRadialSub = () => {
  debugData<{ items: RadialMenuItem[]; sub?: boolean; option?: string }>([
    {
      action: 'openRadialMenu',
      data: {
        sub: true,
        option: 'camp',
        items: [
          { icon: 'blip_camp_tent', label: 'Pitch the tent' },
          { icon: 'blip_campfire', label: 'Light the fire' },
          { icon: 'blip_time_of_day', label: 'Rest until morning' },
          { icon: 'lock', label: 'Lock the chest' },
          { icon: 'menu_icon_rank', label: 'Camp standing' },
        ],
      },
    },
  ]);
};

/** Closes whichever wheel is open, the way Lua does when the menu is dismissed. */
export const debugRadialHide = () => {
  debugData([{ action: 'openRadialMenu', data: false }]);
};
