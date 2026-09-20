import { ContextMenuProps } from '../../../typings';
import { debugData } from '../../../utils/debugData';
import { wcAsset } from '../../../wc/bootstrap';

/**
 * ★ Icons and images come from this resource's own art.
 *
 *   The upstream mock asked for FontAwesome names -- inbox, wheat-awn, horse-head, bars, check
 *   -- and pulled its two pictures from Discord and imgur. None of the five names resolve to a
 *   texture we ship, and neither remote image loads, so the menu was a column of blank slots.
 */
export const debugContext = () => {
  debugData<ContextMenuProps>([
    {
      action: 'showContext',
      data: {
        title: 'Stables',
        options: [
          { title: 'Empty button' },
          {
            title: 'Kentucky Saddler',
            image: wcAsset('assets/images/icons/item.png'),
            arrow: true,
            metadata: [
              { ['label']: 'Coat', ['value']: '55%', ['progress']: 55 },
              { ['label']: 'Stamina', ['value']: '100%', ['progress']: 100 },
              { ['label']: 'Feed', ['progress']: 11 },
              { ['label']: 'Water', ['progress']: 87 },
            ],
          },
          {
            title: 'Example button',
            description: 'Example button description',
            icon: 'blip_ammo_bullets',
            metadata: [{ label: 'Value 1', value: 300 }],
            disabled: true,
          },
          {
            title: 'Feed',
            description: 'Saddle wear',
            progress: 30,
            icon: 'blip_camp_tent',
            metadata: [{ label: 'Feed left', value: '30%' }],
            arrow: true,
          },
          {
            title: 'Condition',
            progress: 80,
            icon: 'menu_icon_rank',
            metadata: [{ label: 'Condition', value: '80%' }],
          },
          {
            title: 'Menu button',
            icon: 'blip_camp',
            menu: 'other_example_menu',
            arrow: false,
            description: 'Takes you to another menu',
            metadata: ['It also has metadata support'],
          },
          {
            title: 'Event button',
            description: 'Open a menu and send event data',
            icon: 'tick',
            arrow: true,
            event: 'some_event',
            args: { value1: 300, value2: 'Other value' },
          },
        ],
      },
    },
  ]);
};

/**
 * The same menu one level down.
 *
 * ★ `menu` is what puts the back arrow in the header -- it names the parent to return to. A
 *   context menu with no `menu` is a root, and draws no arrow at all, which is why the root
 *   demo above could never show what the header looks like with one.
 */
export const debugContextSub = () => {
  debugData<ContextMenuProps>([
    {
      action: 'showContext',
      data: {
        title: 'Kentucky Saddler',
        menu: 'stables',
        options: [
          {
            title: 'Brush the coat',
            description: 'Raises the coat back towards full',
            icon: 'blip_camp',
            progress: 55,
            metadata: [{ label: 'Coat', value: '55%' }],
          },
          {
            title: 'Feed the horse',
            description: 'Costs one bale of hay',
            icon: 'blip_camp_tent',
            progress: 11,
            metadata: [{ label: 'Feed left', value: '11%' }],
          },
          {
            title: 'Water the horse',
            icon: 'blip_time_of_day',
            progress: 87,
          },
          {
            title: 'Saddlebags',
            description: 'Takes you to another menu',
            icon: 'lock',
            menu: 'saddlebags',
          },
          {
            title: 'Sell the horse',
            description: 'This cannot be undone',
            icon: 'cross',
            disabled: true,
          },
        ],
      },
    },
  ]);
};
