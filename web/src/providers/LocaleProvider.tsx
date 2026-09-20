import { Context, createContext, useContext, useEffect, useMemo, useState } from 'react';
import { useNuiEvent } from '../hooks/useNuiEvent';
import { debugData } from '../utils/debugData';

debugData([
  {
    action: 'loadLocales',
    data: ['en', 'fr', 'de', 'it', 'es', 'pt-BR', 'pl', 'ru', 'ko', 'zh-TW', 'ja', 'es-MX', 'zh-CN'],
  },
]);

debugData([
  {
    action: 'setLocale',
    data: {
      language: 'English',
      ui: {
        cancel: 'Cancel',
        close: 'Close',
        confirm: 'Confirm',
        more: 'More...',
        back: 'Back',
        move_select: 'Move to Select',
      },
    },
  },
]);

interface Locale {
  language: string;
  ui: {
    cancel: string;
    close: string;
    confirm: string;
    more: string;
    /* ★ Optional: only en and ar carry them so far, and every use site falls back to English.
       Declaring them as required would make the other twelve locale files a type error for a
       string the interface can perfectly well do without. */
    back?: string;
    move_select?: string;
  };
}

interface LocaleContextValue {
  locale: Locale;
  setLocale: (locales: Locale) => void;
  /**
   * Whether the interface reads right-to-left.
   *
   * ★ Exposed rather than left for each consumer to re-derive from document.dir. Two callers
   *   already need it -- the developer drawer flips the side it opens from -- and a second
   *   copy of this test is a second place for it to drift.
   */
  rtl: boolean;
}

const LocaleCtx = createContext<LocaleContextValue | null>(null);

const LocaleProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [locale, setLocale] = useState<Locale>({
    language: '',
    ui: {
      cancel: '',
      close: '',
      confirm: '',
      more: '',
    },
  });

  useNuiEvent('setLocale', async (data: Locale) => setLocale(data));

  /**
   * ⚠️ The document direction, driven by the locale — and it was never being set at all.
   *
   *    lib-ui.css is written RTL-FIRST: its defaults assume right-to-left and a [dir="ltr"]
   *    block flips the arrow textures and the title casing. With no dir attribute anywhere,
   *    [dir="ltr"] matched nothing, so the page laid out left-to-right while wearing the
   *    right-to-left artwork. That is why the menu arrows pointed the wrong way, and patching
   *    them in the component only hid it for one direction.
   *
   * ★ Read from the locale's own `dir` when Lua sends one, and inferred from the language
   *   otherwise, so an Arabic locale flips the interface without needing an extra field.
   */
  const rtl = useMemo(() => {
    const explicit = (locale as { dir?: string }).dir;
    const language = String((locale as { language?: string }).language ?? '').toLowerCase();

    return explicit === 'rtl' || /^(ar|he|fa|ur)/.test(language);
  }, [locale]);

  useEffect(() => {
    document.documentElement.dir = rtl ? 'rtl' : 'ltr';
  }, [rtl]);

  return <LocaleCtx.Provider value={{ locale, setLocale, rtl }}>{children}</LocaleCtx.Provider>;
};

export default LocaleProvider;

export const useLocales = () => useContext<LocaleContextValue>(LocaleCtx as Context<LocaleContextValue>);
