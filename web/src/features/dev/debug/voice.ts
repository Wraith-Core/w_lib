import { debugData } from '../../../utils/debugData';

/**
 * The voice interface, played out as one short exchange.
 *
 * ★ Timed rather than static, because the three subtitle states only mean anything in sequence:
 *   a line goes up white while it is being heard, turns green when it lands, and the next one
 *   turns red when it does not. Three separate screenshots would not show that.
 *
 * ⚠️ Browser only -- the bubbles are placed here at fixed fractions of the viewport. In game
 *    Lua projects them from a ped's head every frame (resource/interface/client/voice.lua).
 */
export const debugVoice = () => {
  debugData([
    {
      action: 'voiceHint',
      data: {
        id: 'barkeep',
        x: 0.32,
        y: 0.44,
        title: 'Barkeep',
        icon: 'blip_campfire',
        commands: ['A whiskey', 'What is on tonight?', 'Any work around here?'],
      },
    },
  ], 0);

  debugData([
    {
      action: 'voiceHint',
      data: { id: 'stranger', x: 0.68, y: 0.5, title: 'Stranger', icon: 'blip_camp', commands: ['Howdy', 'Move along'] },
    },
  ], 200);

  // ★ The 2D panel: everything sayable right now, grouped the way the layer system groups it.
  debugData([
    {
      action: 'voicePanel',
      data: {
        title: 'You can say',
        // ★ The barkeep's own head point and hint id, so the frame folds this list into HIS card
        //   instead of drawing a second plate beside it. In game Lua projects his head bone; the
        //   preview has no game to ask, so the point is fixed here.
        x: 0.32,
        y: 0.44,
        id: 'barkeep',
        speaker: 'Barkeep',
        talkKey: 'G',
        groups: [
          // ★ {slots} are the script's own phrase syntax -- see api/action: phrases = { "buy {item}" }.
          {
            label: 'Saloon',
            commands: ['the usual', 'give me {item}', 'what {category} do you have', 'buy {quantity} {item}'],
          },
          { label: 'Always', commands: ['do you have {item}', 'howdy'] },
        ],
      },
    },
  ], 400);

  debugData([{ action: 'voiceListening', data: { active: true, levels: [18, 34, 52, 41, 26, 12, 8, 15, 22], label: 'Listening' } }], 400);
  debugData([{ action: 'voiceSubtitle', data: { text: 'A whiskey...', state: 'listening', hold: true } }], 700);

  debugData([{ action: 'voiceListening', data: { active: true, levels: [44, 71, 92, 78, 55, 63, 39, 28, 47], label: 'Listening' } }], 1400);
  debugData([{ action: 'voiceSubtitle', data: { text: 'A whiskey, and keep it coming', state: 'matched' } }], 2000);

  // ★ The reply goes into the barkeep's OWN balloon, not into a caption with his name on it.
  debugData([
    {
      action: 'voiceHint',
      data: { id: 'barkeep', x: 0.32, y: 0.44, title: 'Barkeep', icon: 'blip_campfire', says: 'Comin\u2019 right up.' },
    },
  ], 3200);

  debugData([{ action: 'voiceSubtitle', data: false }], 3200);

  debugData([{ action: 'voiceSubtitle', data: { text: 'Saddle me a horse', state: 'unknown' } }], 5000);
  debugData([{ action: 'voiceListening', data: false }], 6400);
  debugData([{ action: 'voicePanel', data: false }], 6400);
};

export const debugVoiceHide = () => {
  debugData([{ action: 'voiceHintRemove', data: {} }], 0);
  debugData([{ action: 'voiceListening', data: false }], 0);
  debugData([{ action: 'voiceSubtitle', data: false }], 0);
  debugData([{ action: 'voicePanel', data: false }], 0);
};
