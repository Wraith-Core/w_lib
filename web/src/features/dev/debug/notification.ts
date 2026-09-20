import { NotificationProps } from '../../../typings';
import { debugData } from '../../../utils/debugData';

/**
 * ⚠️ Only ONE of w_lib's three notification paths can be exercised here, and it is worth knowing
 *    which before hunting for the others in this drawer:
 *
 *      lib.notify            -> the `notify` NUI action -> the toasts below.   TESTABLE HERE
 *      w.notif.left/right    -> the GAME's own scaleform notifications, drawn by
 *                               modules/notification via CreateVarString and dataview structs.
 *                               No NUI is involved, so a browser has nothing to draw.
 *      exports.w_lib:Notify  -> forwards to the RK-text resource. Another resource's UI.
 *
 *    The last two can only be seen in game. That is not a gap in this panel -- they are not
 *    part of this frame at all.
 */

const notify = (data: NotificationProps, delay = 0) =>
  debugData<NotificationProps>([{ action: 'notify', data }], delay);

/** The four kinds, staggered so they stack rather than land on top of each other. */
export const debugCustomNotification = () => {
  notify({ title: 'Success', description: 'The batch was collected.', type: 'success' }, 0);
  notify({ title: 'Error', description: 'Not enough on you for that.', type: 'error' }, 250);
  notify({ title: 'Warning', description: 'The lock is holding.', type: 'warning' }, 500);
  notify({ title: 'Inform', description: 'Sorting started.', type: 'inform' }, 750);
};

/**
 * Every position at once -- the fastest way to see a rule that stopped matching.
 *
 * ⚠️ 'top' and 'bottom' are included because those are the names the SETTINGS menu writes
 *    (resource/settings.lua), while this list only ever tried 'top-center' and 'bottom-center'.
 *    So the two positions a player could actually pick were the two never tested, and both were
 *    missing a CSS rule -- they fell back to the top-left corner and nobody saw it here.
 */
export const debugNotificationPositions = () => {
  (
    [
      'top-left', 'top', 'top-center', 'top-right',
      'center-left', 'center-right',
      'bottom-left', 'bottom', 'bottom-center', 'bottom-right',
    ] as const
  ).forEach((position, i) => notify({ title: position, description: 'position', type: 'inform', position }, i * 120));
};

/** The shapes that break layouts: no title, no description, a long line, a custom icon. */
export const debugNotificationShapes = () => {
  notify({ description: 'Description only, no title.', type: 'inform' }, 0);
  notify({ title: 'Title only', type: 'success' }, 200);
  notify({ title: 'Custom icon', description: 'Uses a named icon rather than the type default.', type: 'success', icon: 'star' }, 400);
  notify(
    {
      title: 'A long one',
      description:
        'Long enough to wrap more than once, so the toast has to grow downwards and keep the icon aligned to the first line rather than to the middle of the block.',
      type: 'warning',
      duration: 8000,
    },
    600
  );
};
