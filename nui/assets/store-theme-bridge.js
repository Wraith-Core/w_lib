/* Visual adapters for shipped/legacy UI bundles whose source is unavailable.
   Adds decoration and semantic skin classes only. No NUI messages or handlers
   are intercepted, and image content, values, visibility and layout are owned
   by the original application. Mutation work is coalesced to one frame. */
(() => {
  'use strict';
  const profiles = {
    library: {
      panel: '.lb-panel,.lb-dialog,.wv-panel,.wl-qte-panel',
      /* ⚠️ .wn-title and .wn-desc are deliberately NOT listed. wst-title forces a SINGLE
            text-shadow (store-theme.css .wst-title) in place of the notice's doubled one, and wst-sub
            forces the dim --wst-text-dim (.wst-sub). On a notice that still had a black plate
            neither mattered; on one that is bare text over the world, the first thins the only
            thing keeping a 46px town name readable and the second is the exact "باهت" the
            floating notice was fixed for once already. wnotify.css owns them now. */
      header: '.lb-head,.wv-panel-group-name', title: '.lb-title,.wv-panel-title',
      sub: '.lb-item-description,.lb-description', rule: '.wc-hr,.wc-hr-thin,.wc-title-divider,.wl-prompt-group .line',
      button: '.lb-btn,.lb-btn-ghost,.wc-craft-btn,.wc-manage-btn,.wc-cancel-btn',
      close: '.wc-close,.lb-close-tab', tab: '.wl-panel-chip',
      card: '.lb-item,.lb-menu-item,.wc-card', row: '.wl-panel-trow,.wc-manage-row',
      /* ⚠️ .lb-toast and .wn-note.has-plate are NOT plates any more. wst-plate::before paints a
            masked ink plate (--w-ink-3) with !important, so leaving them here put the black plate straight
            back on the toast and the town banner after the stylesheet had dropped it -- and no
            edit to lib-ui.css / wnotify.css could win against it. .lb-textui left for the same
            reason: the walk-up hint is bare text now too. What still keeps a plate is what stands
            still and holds a reading -- the progress bar and the meta tiles. */
      plate: '.lb-progress,.wc-meta-tile,.wv-bubble',
      field: '.lb-input', input: '.lb-input input:not([type=range]):not([type=checkbox]),.lb-input textarea,.lb-input select,.wl-panel-row-input',
      num: '.wc-numeral,.wc-meta-value,.lb-progress-value',
      primary: '.lb-btn:not(.is-danger),.wc-craft-btn:not(.is-ghost)', danger: '.lb-btn.is-danger,.wc-manage-delete',
    },
    menu: {
      panel: '.menu .container', header: '.menu header', title: '.menu header h1,.article h2#title',
      card: '.list .item:not(.disabled)', rule: '.divider', input: 'input[type=text],input[type=number]',
      button: 'button', sub: '.description', num: '.amount,.price',
    },
    input: {
      panel: '.input-container', header: '.input-header', title: '.entry-title',
      button: '.entry-button,.price-type-button,.price-icon-button',
      field: '.entry-field', input: '.entry-input,.entry-field__control:not([type=checkbox]):not([type=range]),.dp__input',
      primary: '.entry-button.success', danger: '.entry-button.danger',
      sub: '.entry-label',
    },
    prompt: { title: '#groupTitle,.groupTitle', rule: '.promptSeparator,#line', plate: '.keyboardKey .text' },
    notify: { plate: '.notification.useBackground', title: '.notification .content h3', sub: '.notification .content p' },
    minigame: { panel: '.qte-panel,.debug-panel', header: '.debug-header', button: '.icon-button' },
    gizmo: { plate: '#controls,.controls', button: 'button' },
    chat: {
      panel: '.chat-input-wrapper,.suggestions-box', header: '.suggestions-header', title: '.suggestions-title',
      field: '.input-plate', input: '.chat-input', button: '.chat-submit-btn', primary: '.chat-submit-btn',
      row: '.chat-message', card: '.suggestion-item', sub: '.suggestion-help,.chat-time',
    },
    /* The level-up and XP-boost notices are notices: no plate, and their own stylesheet keeps
       the doubled shadow and the Arabic face that wst-title / wst-sub would overwrite. Only the
       numerals are still skinned. */
    level: { num: '.wl-num,.wl-level,.wl-xptext,.wl-gain' },
    kingdom: {
      panel: '.dock,.pal', header: '.dock-head', title: '.dock-title h1,.grp-name',
      close: '.dock-head .x', tab: '.tabs .tab', field: '.find', input: '.find input,.fld,.edit input,.edit select',
      button: '.btn,.mini,.pal-clear', card: '.pl,.kd', rule: '.grp-rule',
    },
    baloot: {
      panel: '#bid', plate: '#status .chip,#banner,#showcase', card: '#players .player',
      title: '#bid-title,#mode-text', rule: '.rule', button: '.btn', num: '.count b,#us,#them,#match,#qahwa-score',
    },
    cinema: {
      panel: '.wcn-shell,.wcn-modal,.wcn-programme', header: '.wc-header,.wcn-modal-head',
      title: '.wc-title,.wcn-modal-title,.wcn-board-title', sub: '.wc-subtitle,.wcn-muted,.wcn-hint',
      button: '.wcn-btn,.wc-craft-btn', primary: '.wcn-btn-primary', danger: '.wcn-btn.is-danger',
      close: '.wc-close', tab: '.wc-scope-tab', card: '.wcn-cinema', plate: '.wcn-card,.wc-meta-tile,.wcn-toast',
      rule: '.wc-hr,.wc-hr-thin', input: '.wcn-input,.wcn-textarea,.wcn-select', num: '.wcn-num,.wc-meta-value',
    },
  };
  const run = () => {
    const profile = profiles[document.body?.dataset.storeTheme];
    if (!profile) return;
    document.body.classList.add('wst-root');
    for (const [kind, selector] of Object.entries(profile)) {
      const token = kind === 'primary' || kind === 'danger' ? kind : `wst-${kind}`;
      for (const node of document.querySelectorAll(selector)) if (!node.classList.contains(token)) node.classList.add(token);
    }
    for (const plate of document.querySelectorAll('.wst-plate,.wst-close')) {
      if (getComputedStyle(plate).position === 'static') plate.classList.add('wst-positioned');
    }
    for (const panel of document.querySelectorAll('.wst-panel')) {
      if (getComputedStyle(panel).position === 'static') panel.classList.add('wst-positioned');
      let frame = Array.from(panel.children).find(node => node.matches('.wst-frame,.wc-frame,.ws-frame'));
      if (!frame) {
        frame = document.createElement('span'); frame.className = 'wst-frame';
        frame.setAttribute('aria-hidden', 'true'); frame.dataset.storeDecoration = 'frame';
        for (const piece of ['t','b','l','r','tl','tr','bl','br']) {
          const edge = document.createElement('span'); edge.className = `wst-fr-${piece}`; frame.appendChild(edge);
        }
        panel.appendChild(frame);
      } else {
        frame.classList.add('wst-frame');
        for (const edge of frame.children) {
          const piece = [...edge.classList].map(c => /^(?:wc|ws|wst)-fr-(t|b|l|r|tl|tr|bl|br)$/.exec(c)).find(Boolean);
          if (piece) edge.classList.add(`wst-fr-${piece[1]}`);
        }
      }
    }
  };
  let queued = false;
  const schedule = () => { if (!queued) { queued = true; requestAnimationFrame(() => { queued = false; run(); }); } };
  const start = () => {
    run();
    new MutationObserver(records => {
      if (records.some(r => r.type === 'childList' || r.oldValue !== r.target.getAttribute('class'))) schedule();
    }).observe(document.body, { childList:true, subtree:true, attributes:true, attributeFilter:['class'], attributeOldValue:true });
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once:true }); else start();
  /* A frame on a panel that scrolls stays over the visible part (store-frame.js, the same lines). */
  if (!window.__wstFrameFollow) {
    window.__wstFrameFollow = true;
    document.addEventListener('scroll', (event) => {
      const panel = event.target;
      if (!(panel instanceof Element)) return;
      for (const node of panel.children) {
        if (node.matches('.wst-frame,.wc-frame,.ws-frame')) node.style.transform = panel.scrollTop ? `translateY(${panel.scrollTop}px)` : '';
      }
    }, { capture: true, passive: true });
  }
})();
