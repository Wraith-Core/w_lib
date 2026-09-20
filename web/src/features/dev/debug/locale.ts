/**
 * The direction switch the drawer was missing.
 *
 * ⚠️ It sets the document direction the way the LocaleProvider does — from a locale — rather
 *    than poking `documentElement.dir` behind its back. Testing the switch has to test the real
 *    path, or it proves the CSS works and nothing about the wiring that drives it.
 */
import { debugData } from '../../../utils/debugData';

const setLocale = (language: string, dir: 'rtl' | 'ltr') =>
  debugData([{ action: 'setLocale', data: { language, dir, ui: { cancel: dir === 'rtl' ? 'إلغاء' : 'Cancel', confirm: dir === 'rtl' ? 'تأكيد' : 'Confirm', back: dir === 'rtl' ? 'رجوع' : 'Back', close: dir === 'rtl' ? 'إغلاق' : 'Close', more: dir === 'rtl' ? 'المزيد...' : 'More...', move_select: dir === 'rtl' ? 'حرّك للاختيار' : 'Move to Select' } } }], 0);

export const debugArabic = () => setLocale('ar', 'rtl');
export const debugEnglish = () => setLocale('en', 'ltr');

/** What the switch actually decides, so a wrong flip is obvious rather than subtle. */
export const debugToggleDir = () =>
  document.documentElement.dir === 'rtl' ? debugEnglish() : debugArabic();
