import React, { useState } from 'react';
import { useNuiType } from '../../hooks/useNuiType';
import KeyboardKey from './KeyboardKey';
import PromptRow from './PromptRow';
import { monoHtml } from '../../utils/palette';
import './prompt.css';
import {
  ForceHideData,
  KeyData,
  PromptGroupState,
  SetGroupData,
  UpdateGroupData,
  UpdatePromptData,
} from './types';

const EMPTY: PromptGroupState = {
  title: undefined,
  position: 'bottom-right',
  prompts: [],
  nextPageKey: 'A',
  currentPageIndex: 0,
  forcedHide: false,
  pressedKeys: {},
};

/**
 * The RDR prompt group -- ported from the Prompt source (Vue) to React, structure and stylesheet
 * intact. It keeps its own look rather than taking the w_crafting one: this is the game's own
 * prompt furniture, and four resources already teach players to read it as it is.
 *
 * ⚠️ It listens on `type`, not `action` -- see useNuiType for why the two contracts coexist.
 */
const Prompt: React.FC = () => {
  const [group, setGroup] = useState<PromptGroupState>(EMPTY);

  useNuiType<SetGroupData>('setGroup', (data) => {
    setGroup((prev) => ({
      ...prev,
      title: data.title,
      position: data.position ?? prev.position,
      prompts: data.prompts ?? [],
      nextPageKey: data.nextPageKey ?? prev.nextPageKey,
      // Lua counts pages from 1 and this counts from 0. The conversion lives here, once.
      currentPageIndex: data.currentPage ? data.currentPage - 1 : 0,
    }));
  });

  useNuiType<KeyData>('keyDown', (data) =>
    setGroup((prev) => ({ ...prev, pressedKeys: { ...prev.pressedKeys, [data.key]: true } }))
  );

  useNuiType<KeyData>('keyUp', (data) =>
    setGroup((prev) => {
      const pressedKeys = { ...prev.pressedKeys };
      delete pressedKeys[data.key];
      return { ...prev, pressedKeys };
    })
  );

  useNuiType<void>('nextPage', () =>
    setGroup((prev) => ({
      ...prev,
      currentPageIndex: prev.prompts[prev.currentPageIndex + 1] !== undefined ? prev.currentPageIndex + 1 : 0,
      // ★ Cleared with the page: a key held while paging would otherwise stay lit on the new
      //   page, on a row the player never touched.
      pressedKeys: {},
    }))
  );

  useNuiType<UpdatePromptData>('updatePrompt', (data) =>
    setGroup((prev) => {
      const page = data.page - 1;
      const position = data.position - 1;
      const row = prev.prompts[page]?.[position];

      if (!row) return prev;

      // Copied down to the row being changed, and shared above it: React needs new objects on
      // the path it must redraw, and rebuilding every page on every label edit is wasteful.
      const prompts = [...prev.prompts];
      prompts[page] = [...prompts[page]];
      prompts[page][position] = { ...row, [data.property]: data.value };

      return { ...prev, prompts };
    })
  );

  useNuiType<UpdateGroupData>('updateGroup', (data) =>
    setGroup((prev) => ({ ...prev, [data.property]: data.value }))
  );

  useNuiType<ForceHideData>('forceHide', (data) => setGroup((prev) => ({ ...prev, forcedHide: data.value })));

  /**
   * The mouse path.
   *
   * ★ Some places raise a prompt while a menu holds the cursor, and there the player expects to
   *   click it; elsewhere there is no cursor at all and only the key exists. Both work now,
   *   because the pointer sets exactly the state a key press sets -- nothing is special-cased on
   *   'is a cursor visible', which is not a question the page can answer reliably anyway.
   *
   *   With no cursor the frame receives no mouse events, so the pointer path simply never fires.
   */
  const pressFromPointer = (keys: string[], down: boolean) =>
    setGroup((prev) => {
      const pressedKeys = { ...prev.pressedKeys };

      for (const key of keys) {
        if (down) pressedKeys[key] = true;
        else delete pressedKeys[key];
      }

      return { ...prev, pressedKeys };
    });

  if (group.forcedHide || group.prompts.length === 0) return null;

  const page = group.prompts[group.currentPageIndex] ?? [];
  const isLeft = group.position.includes('left');
  const multiPage = group.prompts.length > 1;

  return (
    <div className="wl-prompt-root">
      {/* ⚠️ The position class comes FIRST, and that is not cosmetic: the shipped rules select
          on [class^="top-"] / [class^="bottom-"], which reads the START of the class attribute.
          Written the other way round the attribute begins with "wl-prompt-group" and every
          position variant silently stops matching. */}
      <div className={`${group.position} wl-prompt-group`}>
        <div className="prompts">
          {page.map((prompt, index) => (
            <PromptRow key={index} prompt={prompt} isLeft={isLeft} pressedKeys={group.pressedKeys} onPress={pressFromPointer} />
          ))}
        </div>

        {group.title !== false && <img className="line" src="./assets/images/ilo_title_line.webp" alt="" />}

        {group.title && (
          <div className="groupTitle crock">
            <span dangerouslySetInnerHTML={{ __html: monoHtml(String(group.title)) }} />
            {multiPage && <KeyboardKey kkey={group.nextPageKey} isNextPage pressed={Boolean(group.pressedKeys[group.nextPageKey])} />}
          </div>
        )}

        {multiPage && (
          <div className="dots">
            {group.prompts.map((_, index) => (
              <div key={index} className={`dot${group.currentPageIndex === index ? ' active' : ''}`} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default Prompt;
