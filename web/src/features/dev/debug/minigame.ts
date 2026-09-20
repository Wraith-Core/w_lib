import { debugType } from '../../../utils/debugType';

/**
 * The lockpick, with the module's own defaults (modules/minigame/client.lua).
 * Three pins so a broken one can be seen replaced rather than ending the game.
 */
export const debugLockpick = () => {
  debugType([
    {
      type: 'w_minigame:show',
      data: {
        game: 'lockpick',
        config: {
          pins: 3,
          pinHealth: 100,
          pinDamage: 20,
          pinDamageInterval: 150,
          solvePadding: 4,
          maxDistFromSolve: 45,
          cylRotSpeed: 3,
        },
      },
    },
  ]);
};

/** The QTE, four rounds, on the module's defaults. */
export const debugQte = () => {
  debugType([
    {
      type: 'w_minigame:show',
      data: {
        game: 'qte',
        config: {
          roundCount: 4,
          rotationCount: 1,
          targetStartAngle: { min: 100, max: 300 },
          targetArcSize: { min: 50, max: 60 },
          rotationDuration: { min: 2000, max: 3000 },
          introDelay: 200,
          successDelay: 450,
          failureDelay: 550,
          roundDelay: 100,
        },
      },
    },
  ]);
};

export const debugMinigameHide = () => debugType([{ type: 'w_minigame:hide' }]);
