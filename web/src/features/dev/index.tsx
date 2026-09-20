import { Button, Divider, Drawer, ScrollArea, Stack, Tooltip } from '@mantine/core';
import { useMemo, useState } from 'react';
import LibIcon from '../../components/LibIcon';
import { useLocales } from '../../providers/LocaleProvider';
import { devText } from './strings';

import { debugAlert } from './debug/alert';
import { debugContext, debugContextSub } from './debug/context';
import { debugInput } from './debug/input';
import { debugMenu } from './debug/menu';
import {
  debugPanelAdmin,
  debugPanelBusy,
  debugPanelCrafting,
  debugPanelHide,
  debugPanelShop,
  debugPanelTrade,
  debugPanelBlackMarket,
  debugPanelAuction,
  debugPanelConsole,
  debugPanelMarketplace,
  debugPanelCinema,
  debugPanelKingdom,
  debugPanelCraftAdmin,
} from './debug/panel';
import { debugArabic, debugEnglish } from './debug/locale';
import { debugCustomNotification, debugNotificationPositions, debugNotificationShapes } from './debug/notification';
import { debugProgressbar } from './debug/progress';
import { debugRadial, debugRadialHide, debugRadialSub } from './debug/radial';
import { debugTextUI } from './debug/textui';
import { debugVoice, debugVoiceHide } from './debug/voice';
import { debugPrompt, debugPromptHide } from './debug/prompt';
import { debugLockpick, debugMinigameHide, debugQte } from './debug/minigame';
import { debugGizmo, debugGizmoHide, debugGizmoRotate, debugGizmoTranslate } from './debug/gizmo';
import {
  debugWNotify,
  debugWNotifyLaw,
  debugWNotifyText,
  debugWNotifyTextHide,
  debugWNotifyVariants,
} from './debug/wnotify';

/**
 * The developer drawer.
 *
 * ★ Grouped by WHAT A THING IS, not by where it came from. The RDR floating notice used to sit
 *   under a heading that said "the three merged in from their own frames" -- true, and useless:
 *   it grouped by this project's history rather than by anything a person opening the drawer is
 *   looking for. It is a notification, so it is under Notifications; the 2D/3D world text is
 *   screen text, so it sits with TextUI.
 *
 * ★ Within a group: the plain case first, then its variants, then the hide or close last, so
 *   every group reads top to bottom in the order you would actually try them.
 */

interface Item {
  label: string;
  run: () => void;
  /** Variants and teardowns are drawn lighter, so the primary case leads each group. */
  quiet?: boolean;
}

interface Group {
  label: string;
  /** One colour per group -- it is the grouping again, for the eye rather than the reader. */
  color?: string;
  items: Item[];
}

const Dev: React.FC = () => {
  const { rtl } = useLocales();
  const [opened, setOpened] = useState(false);

  const t = devText(rtl);

  const groups = useMemo<Group[]>(
    () => [
      {
        label: t.gDirection,
        color: 'yellow',
        items: [
          { label: t.arabic, run: debugArabic },
          { label: t.english, run: debugEnglish, quiet: true },
        ],
      },
      {
        label: t.gPanel,
        color: 'lime',
        items: [
          { label: t.panelConsole, run: debugPanelConsole },
          { label: t.panelMarketplace, run: debugPanelMarketplace },
          { label: t.panelCinema, run: debugPanelCinema },
          { label: t.panelKingdom, run: debugPanelKingdom },
          { label: t.panelAdmin, run: debugPanelAdmin, quiet: true },
          { label: t.panelCrafting, run: debugPanelCrafting },
          { label: t.panelCraftAdmin, run: debugPanelCraftAdmin },
          { label: t.panelBusy, run: debugPanelBusy, quiet: true },
          { label: t.panelShop, run: debugPanelShop },
          { label: t.panelTrade, run: debugPanelTrade },
          { label: t.panelMarket, run: debugPanelBlackMarket },
          { label: t.panelAuction, run: debugPanelAuction },
          { label: t.panelClose, run: debugPanelHide, quiet: true },
        ],
      },
      {
        label: t.gDialogs,
        items: [
          { label: t.inputDialog, run: debugInput },
          { label: t.alertDialog, run: debugAlert },
        ],
      },
      {
        label: t.gMenus,
        items: [
          { label: t.contextMenu, run: debugContext },
          { label: t.contextSub, run: debugContextSub, quiet: true },
          { label: t.listMenu, run: debugMenu },
          { label: t.radial, run: debugRadial },
          { label: t.radialSub, run: debugRadialSub, quiet: true },
          { label: t.radialHide, run: debugRadialHide, quiet: true },
        ],
      },
      {
        label: t.gNotices,
        color: 'cyan',
        items: [
          { label: t.notifyKinds, run: debugCustomNotification },
          { label: t.notifyPositions, run: debugNotificationPositions, quiet: true },
          { label: t.notifyShapes, run: debugNotificationShapes, quiet: true },
          { label: t.noticePlain, run: debugWNotify },
          { label: t.noticeVariants, run: debugWNotifyVariants, quiet: true },
          { label: t.noticeLaw, run: debugWNotifyLaw },
        ],
      },
      {
        label: t.gScreenText,
        color: 'indigo',
        items: [
          { label: t.textui, run: debugTextUI },
          { label: t.noticeText, run: debugWNotifyText },
          { label: t.noticeClear, run: debugWNotifyTextHide, quiet: true },
        ],
      },
      {
        label: t.gVoice,
        color: 'pink',
        items: [
          { label: t.voicePlay, run: debugVoice },
          { label: t.voiceHide, run: debugVoiceHide, quiet: true },
        ],
      },
      {
        label: t.gProgress,
        items: [{ label: t.progressBar, run: debugProgressbar }],
      },
      {
        label: t.gPrompt,
        color: 'grape',
        items: [
          { label: t.promptShow, run: debugPrompt },
          { label: t.promptHide, run: debugPromptHide, quiet: true },
        ],
      },
      {
        label: t.gMinigames,
        color: 'teal',
        items: [
          { label: t.lockpick, run: debugLockpick },
          { label: t.qte, run: debugQte },
          { label: t.minigameHide, run: debugMinigameHide, quiet: true },
        ],
      },
      {
        label: t.gGizmo,
        color: 'orange',
        items: [
          { label: t.gizmoOpen, run: debugGizmo },
          { label: t.gizmoTranslate, run: debugGizmoTranslate, quiet: true },
          { label: t.gizmoRotate, run: debugGizmoRotate, quiet: true },
          { label: t.gizmoClose, run: debugGizmoHide, quiet: true },
        ],
      },
    ],
    [t]
  );

  return (
    <>
      {/* ★ The prompt's key badge, reused: a white plate with black lettering and the same
          1px offset shadow. It was a peach Mantine circle, which was the one thing on screen
          that belonged to no design at all. */}
      <Tooltip label={t.drawer} position={rtl ? 'right' : 'left'}>
        <button type="button" className="wl-dev-key" onClick={() => setOpened(true)} aria-label={t.drawer}>
          <LibIcon icon="wrench" fontSize={16} />
        </button>
      </Tooltip>

      {/* ⚠️ position is physical, so it does not follow the document direction on its own --
          left in an RTL layout puts the drawer where the reading ends. */}
      <Drawer
        position={rtl ? 'right' : 'left'}
        onClose={() => setOpened(false)}
        opened={opened}
        title={t.drawer}
        /* ⚠️ No padding on the drawer -- it is moved onto the header and onto the list inside
              the scroller. With it here the scroll area started INSIDE the padding, so its bar
              floated in the middle of the button column instead of riding the panel edge. */
        padding={0}
        /* ⚠️ Three declarations, and all three are needed -- the first attempt used only the
              first and still would not scroll.

              `drawer` becomes a flex column so the header keeps its size and the rest is left
              over. `body` is Mantine v5's own wrapper around these children and ships with an
              EMPTY style block, so it had no height at all; flex:1 gives it the remainder and
              `minHeight: 0` is what actually lets it shrink -- a flex item defaults to
              min-height:auto, which refuses to go below its content and is exactly why a tall
              list overflows instead of scrolling. `overflow: hidden` on the drawer stops
              anything spilling past the panel edge if a child mis-measures. */
        styles={{
          drawer: { display: 'flex', flexDirection: 'column', overflow: 'hidden' },
          header: { padding: '1.25rem 1.5rem 0.75rem', marginBottom: 0 },
          body: { flex: 1, minHeight: 0 },
        }}
      >
        {/* ⚠️ Mantine's ScrollArea, not overflow:auto. index.css hides the native scrollbar
            everywhere (::-webkit-scrollbar { width: 0 }) so the game frame never shows one --
            a plain overflow container would scroll with no visible bar and no way to tell there
            was more below. ScrollArea draws its own.

            ★ The bar overlays the edge rather than reserving a column of its own
            (offsetScrollbars is gone): the padding now lives on the Stack, so there is already
            a gutter for it to sit in and the buttons never shift when it appears. And it is
            restyled -- Mantine's default is a fat grey pill with rounded ends, which is the one
            web control left in a drawer full of RDR plates. */}
        <ScrollArea
          style={{ height: '100%' }}
          type="auto"
          styles={{
            scrollbar: {
              background: 'transparent',
              padding: 3,
              '&:hover': { background: 'transparent' },
            },
            thumb: {
              borderRadius: 0,
              background: 'rgba(255, 255, 255, 0.22)',
              '&:hover': { background: 'rgba(255, 255, 255, 0.38)' },
            },
          }}
        >
          <Stack spacing="xs" px="xl" pb="xl">
            {groups.map((group) => (
              <Stack spacing="xs" key={group.label}>
                <Divider label={group.label} labelPosition="center" />

                {group.items.map((item) => (
                  <Button
                    fullWidth
                    key={item.label}
                    color={group.color}
                    variant={item.quiet ? 'light' : 'filled'}
                    onClick={item.run}
                  >
                    {item.label}
                  </Button>
                ))}
              </Stack>
            ))}
          </Stack>
        </ScrollArea>
      </Drawer>
    </>
  );
};

export default Dev;
