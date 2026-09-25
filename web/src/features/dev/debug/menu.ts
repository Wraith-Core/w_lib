import { debugData } from '../../../utils/debugData';
import { MenuSettings } from '../../../typings';

/**
 * ★ Icons are this resource's own art. 'heart', 'basket-shopping', 'tag', 'wheat-awn' and
 *   'horse-head' are FontAwesome names, and nothing registers them, so every row drew an
 *   empty slot.
 */
export const debugMenu = () => {
  debugData<MenuSettings>([
    {
      action: 'setMenu',
      data: {
        //   position: "bottom-left",
        title: 'Stables',
        items: [
          { label: 'Option 1', icon: 'star' },
          {
            label: 'Option 2',
            icon: 'blip_ammo_bullets',
            description: 'Tooltip description 1',
            checked: true,
          },
          {
            label: 'Horse breed',
            values: ['Arabian', 'Tennessee Walker', { label: 'Andalusian', description: 'Calm and sure-footed' }],
            icon: 'menu_icon_rank',
            description: 'Side scroll general description',
          },
          {
            label: 'Feed',
            progress: 30,
            icon: 'blip_camp_tent',
            description: 'Feed left: 30%',
          },
          {
            label: 'Condition',
            progress: 80,
            icon: 'blip_campfire',
            description: 'Condition: 80%',
            colorScheme: 'blue',
            iconColor: '#B9AF9C',
          },
          { label: 'Option 1' },
          { label: 'Option 2' },
          {
            label: 'Horse breed',
            values: ['Nice', 'Super nice', 'Extra nice'],
            defaultIndex: 1,
          },
          { label: 'Option 1' },
          { label: 'Option 2' },
          {
            label: 'Horse breed',
            values: ['Nice', 'Super nice', 'Extra nice'],
          },
        ],
      },
    },
  ]);
};
