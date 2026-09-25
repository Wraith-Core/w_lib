import Notifications from './features/notifications/NotificationWrapper';
import Progressbar from './features/progress/Progressbar';
import TextUI from './features/textui/TextUI';
import InputDialog from './features/dialog/InputDialog';
import ContextMenu from './features/menu/context/ContextMenu';
import Panel from './features/panel';
import { useNuiEvent } from './hooks/useNuiEvent';
import { setClipboard } from './utils/setClipboard';
import { play, type Sfx } from './wc/sound';
import { postNui } from './utils/postNui';
import AlertDialog from './features/dialog/AlertDialog';
import ListMenu from './features/menu/list';
import Dev from './features/dev';
import { isEnvBrowser } from './utils/misc';
import Prompt from './features/prompt';
import Gizmo from './features/gizmo';
import Minigame from './features/minigame';
import WNotify from './features/wnotify';
import Voice from './features/voice';
import RadialMenu from './features/menu/radial';
import { theme } from './theme';
import { MantineProvider } from '@mantine/core';
import { useConfig } from './providers/ConfigProvider';
import { useLocales } from './providers/LocaleProvider';
import { useEffect, useMemo } from 'react';

const App: React.FC = () => {
  const { config } = useConfig();
  const { rtl } = useLocales();

  /**
   * ⚠️ Not a plain spread of the config over the theme. That let the server's convar replace
   *    primaryColor outright, so a name Mantine has no ramp for -- a typo, or a colour removed
   *    from the palette -- left every accented control unstyled. Here the config is only
   *    allowed to pick from ramps the theme actually defines; anything else keeps ours.
   */
  const themeWithConfig = useMemo(
    () => ({
      ...theme,
      // ★ Red is the theme's mark, not an accent: a convar naming it keeps the paper ramp.
      primaryColor:
        theme.colors?.[config.primaryColor] && config.primaryColor !== 'red' && config.primaryColor !== 'blood'
          ? config.primaryColor
          : theme.primaryColor,
      primaryShade: config.primaryShade ?? theme.primaryShade,

      /* ★ Mantine reads dir for the components that decide a side in JavaScript rather than in
         CSS. The stylesheets flip on their own because document.documentElement.dir is set and
         flexbox follows the inherited direction; this is for the handful that do not. */
      dir: (rtl ? 'rtl' : 'ltr') as 'rtl' | 'ltr',
    }),
    [config, rtl]
  );

  useNuiEvent('setClipboard', (data: string) => {
    setClipboard(data);
  });

  /**
   * ★ The frame's own SFX, on request.
   *
   *   The library's interfaces ring these themselves -- a menu opening, a row picked. A resource
   *   DRIVING the library's frame has no way to, and w_crafting has cues of its own for moments
   *   the panel knows nothing about: a craft starting, a craft completing. Rather than have it
   *   ship a second audio layer over the same five files, it names one.
   *
   * ⚠️ Names only, never a URL. The bundle's own sounds are the whole vocabulary; letting a
   *    message name a file would let any resource play anything into the player's ears.
   */
  useNuiEvent<Sfx>('playSound', (name) => {
    play(name);
  });

  /**
   * The clipboard module speaks its own shape: { type: 'copy', value } with the text at the top
   * level rather than under `data`.
   *
   * ⚠️ Which is why neither useNuiEvent (keyed on `action`) nor useNuiType (which hands over
   *    `event.data.data`) can carry it -- the value would arrive undefined and the copy would
   *    silently put an empty string on the clipboard. So it is read straight off the message.
   */
  useEffect(() => {
    const onMessage = (event: MessageEvent<{ type?: string; value?: string }>) => {
      if (event.data?.type === 'copy' && typeof event.data.value === 'string') {
        setClipboard(event.data.value);
      }
    };

    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, []);

  /**
   * The frame announcing itself: Lua answers by pushing the active locale down.
   *
   * ⚠️ In an effect, and once. This used to sit in the render body, so every re-render -- the
   *    config arriving, the locale flipping direction -- fired it again, and each one made Lua
   *    re-read locales/<key>.json off disk and re-broadcast the whole file. Mount is the only
   *    moment the announcement means anything.
   *
   * ★ postNui rather than fetchNui, because a resource that borrows this frame through its own
   *   ui_page registers no 'init' of its own. A bootstrap ping nobody answers leaves the app on
   *   its defaults; it must not surface as an uncaught rejection.
   */
  useEffect(() => {
    void postNui('init');
  }, []);

  return (
    <MantineProvider withNormalizeCSS theme={themeWithConfig}>
      {/* The preview scene, browser only -- see .wl-preview-bg in index.css for why it is an
          element rather than a background. */}
      {isEnvBrowser() && <div className="wl-preview-bg" />}
      <Progressbar />
      <Notifications />
      <TextUI />
      <InputDialog />
      <AlertDialog />
      <ContextMenu />
      <Panel />
      <ListMenu />
      <RadialMenu />
      <Prompt />
      <Gizmo />
      <Minigame />
      <WNotify />
      <Voice />
      {isEnvBrowser() && <Dev />}
    </MantineProvider>
  );
};

export default App;
