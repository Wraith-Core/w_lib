import { debugData } from '../../../utils/debugData';

/**
 * The RDR floating notice — the one w_lib sends through `RK-text:send` and
 * `exports.w_lib:Notify`, drawn by resource/wnotify/client.lua.
 *
 * ★ Its default is `useBackground: false`: text and an icon over the world with nothing behind
 *   them. The plated variant is the exception, so both are here.
 */

const show = (data: Record<string, unknown>, delay = 0) =>
  debugData([{ action: 'showNotification', data }], delay);

/** How it actually arrives in play: no plate, middle-right, an icon and two lines. */
export const debugWNotify = () => {
  show({
    title: 'Contraband sorted',
    description: '25 × weed_raw',
    icon: 'tick',
    placement: 'middle-right',
    duration: 5000,
    useBackground: false,
    titleColor: '#F2F2F2',
  });
};

/**
 * The plated variant, and a right-to-left one, so both layouts get looked at.
 *
 * ★ The plate is the banner the game shows on entering a place, so the demo shows a place
 *   being entered. It used to read 'With a plate' over 'useBackground: true' -- the name of the
 *   flag that switches it on, which tells you how to turn it on and nothing about what it is
 *   for or whether it looks right.
 */
export const debugWNotifyVariants = () => {
  // ★ meta is filled in by Lua in game (the clock and the temperature); the browser preview
  //   has no game to ask, so the demo supplies one.
  show({ title: 'Valentine', description: 'The Heartlands, New Hanover', meta: [
          { text: '09:40AM', color: '#F2F2F2' },
          { text: '20°C', color: '#B4B4B4' },
          { text: '1KPH', color: '#7A7A7A' },
        ], placement: 'top-center', useBackground: true }, 0);
  show({ title: 'إشعار عربي', description: 'من اليمين إلى اليسار', icon: 'lock', placement: 'middle-left', isRTL: true }, 300);
  show({ title: 'Refused', description: 'Not enough on you.', icon: 'cross', placement: 'bottom-center', titleColor: '#CB0101' }, 600);
  show({ description: 'No title, no icon — description only.', placement: 'top-left' }, 900);
};

/**
 * The law banner, in both the shapes the game uses it in.
 *
 * ★ Plated like the town banner, because it IS the town banner's plate -- the sheriff's
 *   vocabulary is set on the same brush stroke, only louder.
 */
export const debugWNotifyLaw = () => {
  // ★ No placement passed: the law banner pins itself to the top whatever is sent.
  show({ title: 'Wanted', description: 'Bounty $10.00', useBackground: true, variant: 'law' }, 0);
  // ...and it overrides one that IS sent -- this asks for the bottom and still lands on top.
  show({ title: 'Witness', description: 'Unarmed Assault', placement: 'bottom-left', useBackground: true, variant: 'law' }, 2600);
};

/** The screen and world text that share this feature. */
export const debugWNotifyText = () => {
  debugData([{ action: 'drawText2D', data: { text: 'Screen text — drawText2D' } }], 0);
  debugData([{ action: 'drawText3D', data: { id: 'demo', x: 0.5, y: 0.62, text: 'World text — drawText3D' } }], 0);
};

export const debugWNotifyTextHide = () => {
  debugData([{ action: 'removeText2D', data: {} }], 0);
  debugData([{ action: 'removeText3D', data: { id: 'demo' } }], 0);
};
