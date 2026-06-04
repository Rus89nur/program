/**
 * Мобильная оболочка: узкий портрет ≤900px или landscape на телефоне (низкий viewport, touch).
 * Без второго условия на Plus/Max в альбомной ширина >900px — включается десктоп и ломается вёрстка.
 */
const GazpromMobileOverlay = (() => {
  const PHONE_LAYOUT_MQ =
    window.GAZPROM_PHONE_LAYOUT_MQ ||
    '(max-width: 900px), (max-width: 1280px) and (max-height: 520px) and (hover: none)';
  window.GAZPROM_PHONE_LAYOUT_MQ = PHONE_LAYOUT_MQ;

  const mq = window.matchMedia(PHONE_LAYOUT_MQ);
  let depth = 0;

  const mainEl = () => document.querySelector('.main');

  // #region agent log
  const isDebugScrollMode = () => {
    try {
      if (localStorage.getItem('gazpromDebugScroll') === '1') return true;
    } catch (_) {}
    const q = window.location.search || '';
    const h = window.location.hash || '';
    return (
      q.includes('debug=1') ||
      q.includes('debug=scroll') ||
      q.includes('debug=2c2db0') ||
      h.includes('debug')
    );
  };

  const refreshDebugPanel = () => {
    if (!isDebugScrollMode()) return;
    const panel = document.getElementById('gazpromScrollDebug');
    const pre = document.getElementById('gazpromScrollDebugPre');
    if (!panel || !pre) return;
    try {
      const logs = JSON.parse(sessionStorage.getItem('gazpromDebugLogs') || '[]');
      const last = logs.slice(-6);
      pre.textContent = last.length
        ? last.map((e) => `${e.message} ${JSON.stringify(e.data)}`).join('\n\n')
        : 'Логов пока нет — откройте вкладку и прокрутите вниз.';
    } catch (_) {
      pre.textContent = 'Ошибка чтения логов';
    }
  };

  const initDebugPanel = () => {
    if (!isDebugScrollMode()) return;
    if (!document.body) return;
    if (document.getElementById('gazpromScrollDebug')) return;
    const wrap = document.createElement('div');
    wrap.id = 'gazpromScrollDebug';
    wrap.setAttribute('role', 'region');
    wrap.setAttribute('aria-label', 'Отладка прокрутки');
    wrap.style.cssText =
      'position:fixed;left:8px;right:8px;top:max(8px, env(safe-area-inset-top));z-index:100000;' +
      'font:12px/1.4 -apple-system,BlinkMacSystemFont,sans-serif;background:#1a1a2e;color:#b8f0c8;' +
      'border:2px solid #26c6da;border-radius:10px;padding:10px;max-height:38vh;overflow:auto;' +
      'box-shadow:0 8px 32px rgba(0,0,0,.45);pointer-events:auto;';
    wrap.innerHTML =
      '<div style="color:#fff;font-weight:700;margin-bottom:4px">Отладка прокрутки (web-103)</div>' +
      '<div style="color:#8cf;font-size:11px;margin-bottom:8px">Сверните панель — кнопка DEBUG внизу справа</div>' +
      '<pre id="gazpromScrollDebugPre" style="margin:0 0 8px;white-space:pre-wrap;word-break:break-word;font:inherit;font-size:11px"></pre>' +
      '<button type="button" id="gazpromScrollDebugCopy" style="width:100%;padding:12px;font-size:15px;font-weight:700;border-radius:8px;border:none;background:#26c6da;color:#003">Скопировать все логи</button>' +
      '<button type="button" id="gazpromScrollDebugHide" style="width:100%;margin-top:6px;padding:8px;font-size:13px;border-radius:8px;border:1px solid #555;background:transparent;color:#ccc">Скрыть панель</button>';
    document.body.appendChild(wrap);
    const fab = document.createElement('button');
    fab.type = 'button';
    fab.id = 'gazpromScrollDebugFab';
    fab.textContent = 'DEBUG';
    fab.setAttribute('aria-label', 'Показать отладку прокрутки');
    fab.style.cssText =
      'position:fixed;right:10px;bottom:calc(100px + env(safe-area-inset-bottom));z-index:100001;' +
      'padding:10px 14px;font-size:13px;font-weight:800;border-radius:999px;border:none;' +
      'background:#e65100;color:#fff;box-shadow:0 4px 16px rgba(0,0,0,.35);pointer-events:auto;';
    document.body.appendChild(fab);
    fab.addEventListener('click', () => {
      wrap.style.display = wrap.style.display === 'none' ? 'block' : 'none';
    });
    document.getElementById('gazpromScrollDebugHide')?.addEventListener('click', () => {
      wrap.style.display = 'none';
    });
    document.getElementById('gazpromScrollDebugCopy')?.addEventListener('click', async () => {
      try {
        const text = sessionStorage.getItem('gazpromDebugLogs') || '[]';
        if (navigator.clipboard?.writeText) {
          await navigator.clipboard.writeText(text);
          alert('Логи скопированы. Вставьте в чат Cursor.');
        } else {
          prompt('Скопируйте логи:', text);
        }
      } catch (err) {
        alert('Не удалось скопировать: ' + (err?.message || err));
      }
    });
    refreshDebugPanel();
    agentLog('UI', 'mobile-overlay.js:initDebugPanel', 'debug panel mounted', {
      href: window.location.href,
      search: window.location.search,
    });
  };

  const scheduleInitDebugPanel = () => {
    if (!isDebugScrollMode()) return;
    if (document.body) initDebugPanel();
    else document.addEventListener('DOMContentLoaded', initDebugPanel, { once: true });
  };

  const agentLog = (hypothesisId, logAt, message, data) => {
    const payload = {
      sessionId: '2c2db0',
      runId: 'post-fix-v3',
      hypothesisId,
      location: logAt,
      message,
      data,
      timestamp: Date.now(),
    };
    fetch('http://127.0.0.1:7931/ingest/e73f326d-990a-4349-ab2b-115a1dec68c8', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Debug-Session-Id': '2c2db0' },
      body: JSON.stringify(payload),
    }).catch(() => {});
    try {
      const key = 'gazpromDebugLogs';
      const prev = JSON.parse(sessionStorage.getItem(key) || '[]');
      prev.push(payload);
      if (prev.length > 50) prev.shift();
      sessionStorage.setItem(key, JSON.stringify(prev));
    } catch (_) {}
    refreshDebugPanel();
  };
  // #endregion

  const positionBottomNav = () => {
    const nav = document.querySelector('.bottom-nav');
    if (!nav || !mq.matches) {
      nav?.style.removeProperty('bottom');
      document.body.style.removeProperty('--gazprom-safari-bottom-inset');
      return 0;
    }
    const vv = window.visualViewport;
    const inset = vv ? Math.max(0, Math.round(window.innerHeight - vv.height - vv.offsetTop)) : 0;
    document.body.style.setProperty('--gazprom-safari-bottom-inset', `${inset}px`);
    nav.style.bottom = `${inset}px`;
    return inset;
  };

  /** Полосы с overflow-x: auto — свайп не блокируем (см. MOBILE_PHONE_MODE §3.8, web-82). */
  const HORIZONTAL_SCROLL_SELECTOR = [
    '.list-table',
    '.wizard-stepper',
    '.pred-filter-row',
    '.toolbar-filters--pills',
    '.history-list-toolbar',
    '#screen-history .toolbar-filters',
    '#screen-history .toolbar-filters--pills',
    '#screen-history .toolbar-history__body',
    '#screen-history .toolbar--history',
    '#screen-history .history-list-toolbar',
  ].join(', ');

  const syncVisualViewport = () => {
    const root = document.documentElement;
    if (!mq.matches || !window.visualViewport) {
      root.style.removeProperty('--vv-height');
      return;
    }
    root.style.setProperty('--vv-height', `${window.visualViewport.height}px`);
    if (window.scrollX !== 0) {
      window.scrollTo(0, window.scrollY);
    }
  };

  const findScreenBottomElement = (screen) => {
    if (!screen) return null;
    return (
      screen.querySelector('.wizard-footer') ||
      screen.querySelector('#historyList .history-list-item:last-child') ||
      screen.querySelector('#eliminationCardList .elimination-act-card:last-child') ||
      screen.querySelector('.settings-grid .settings-tile:last-child') ||
      screen.querySelector('#wizardPanels .wizard-panel-active') ||
      screen.querySelector('.screen.active .card:last-child') ||
      screen.lastElementChild
    );
  };

  /** Кэш нижнего отступа по экрану. */
  const navBlockByScreen = new Map();

  const getScreenScrollHost = (screen) => {
    if (!screen) return null;
    if (screen.id === 'screen-history') return screen.querySelector('#historyList');
    if (screen.id === 'screen-elimination') return screen.querySelector('#eliminationCardList');
    if (screen.id === 'screen-settings') return screen.querySelector('.settings-grid');
    if (screen.id === 'screen-wizard') return screen.querySelector('.wizard-layout');
    return screen;
  };

  const applyPaddingToHost = (screen, px) => {
    const host = getScreenScrollHost(screen);
    if (!host) return;
    host.style.paddingBottom = px;
  };

  const computeNavBlockPx = () => {
    const nav = document.querySelector('.bottom-nav');
    if (!nav) return 80;
    const gap = 20;
    const rect = nav.getBoundingClientRect();
    return Math.max(80, Math.ceil(Math.max(rect.height, window.innerHeight - rect.top) + gap));
  };

  const capScreenBlockPx = (blockPx) => {
    const base = computeNavBlockPx();
    return Math.min(Math.ceil(blockPx), base + 160);
  };

  const clampMainScrollTop = (main) => {
    const maxTop = Math.max(0, main.scrollHeight - main.clientHeight);
    if (main.scrollTop > maxTop) main.scrollTop = maxTop;
    return maxTop;
  };

  /** Логи: contentBottom 1176 при viewport ~695 давал ложный overlap 524. */
  const measureContentOverlap = (bottomEl, navR) => {
    if (!bottomEl || !navR) return 0;
    const rect = bottomEl.getBoundingClientRect();
    const viewH = window.innerHeight || document.documentElement.clientHeight;
    if (rect.bottom > viewH + 12) return 0;
    if (rect.top >= navR.bottom) return 0;
    return Math.round(rect.bottom - navR.top);
  };

  const flushMainLayout = () => {
    const main = mainEl();
    if (!main) return;
    void main.offsetHeight;
    void main.scrollHeight;
  };

  /** Отступ на host списка/сетки (логи: padding на .screen не двигал settings-tile). */
  const applyScrollClearance = (blockPx) => {
    const px = `${blockPx}px`;
    document.body.style.setProperty('--gazprom-nav-block', px);
    const spacer = document.querySelector('.gazprom-scroll-bottom-spacer');
    if (spacer) spacer.style.height = px;
    const main = mainEl();
    if (main) {
      main.style.removeProperty('padding-bottom');
      main.style.removeProperty('scroll-padding-bottom');
    }
    document.querySelectorAll('.main > .screen').forEach((screen) => {
      screen.style.removeProperty('padding-bottom');
      getScreenScrollHost(screen)?.style.removeProperty('padding-bottom');
    });
    const active = document.querySelector('.screen.active');
    if (active) applyPaddingToHost(active, px);
  };

  const clearMainScrollPadding = () => {
    navBlockByScreen.clear();
    document.body.style.removeProperty('--gazprom-nav-block');
    document.body.style.removeProperty('--gazprom-safari-bottom-inset');
    document.querySelector('.bottom-nav')?.style.removeProperty('bottom');
    document.querySelector('.gazprom-scroll-bottom-spacer')?.style.removeProperty('height');
    document.querySelectorAll('.main > .screen').forEach((screen) => {
      screen.style.removeProperty('padding-bottom');
      const host = getScreenScrollHost(screen);
      if (host) host.style.removeProperty('padding-bottom');
    });
    const main = mainEl();
    if (!main) return;
    main.style.removeProperty('padding-bottom');
    main.style.removeProperty('scroll-padding-bottom');
  };

  const readOverlapAtScrollEnd = () => {
    const main = mainEl();
    const nav = document.querySelector('.bottom-nav');
    const active = document.querySelector('.screen.active');
    if (!main || !nav || !active) return { overlapPx: 0, maxTop: 0 };
    flushMainLayout();
    const maxTop = Math.max(0, main.scrollHeight - main.clientHeight);
    main.scrollTop = maxTop;
    clampMainScrollTop(main);
    flushMainLayout();
    const navR = nav.getBoundingClientRect();
    const bottomEl = findScreenBottomElement(active);
    const contentBottom = Math.round(bottomEl?.getBoundingClientRect?.()?.bottom ?? 0);
    const overlapPx = measureContentOverlap(bottomEl, navR);
    return {
      overlapPx,
      maxTop: Math.round(maxTop),
      scrollHeight: main.scrollHeight,
      screenId: active.id,
      contentBottom,
      navTop: Math.round(navR.top),
      bottomClass: bottomEl?.className?.slice?.(0, 80) ?? null,
      hostPaddingBottom: getComputedStyle(getScreenScrollHost(active) || active).paddingBottom,
      mainPaddingBottom: getComputedStyle(main).paddingBottom,
    };
  };

  /** Цикл: padding на scroll-host → scroll end → замер (логи v6: 80px оставляли overlap 20/9 на списках). */
  const resolveScrollClearance = (trigger, options = {}) => {
    if (!mq.matches) return 0;
    const main = mainEl();
    if (!main) return 0;
    const savedTop = main.scrollTop;
    const gap = 20;
    positionBottomNav();
    const active = document.querySelector('.screen.active');
    const sid = active?.id || '';
    const baseMin = computeNavBlockPx();

    if (trigger.startsWith('goTo-')) {
      navBlockByScreen.delete(sid);
    }

    let blockPx = capScreenBlockPx(Math.max(navBlockByScreen.get(sid) || 0, baseMin));
    applyScrollClearance(blockPx);

    let overlapPx = 0;
    let last = null;

    for (let attempt = 0; attempt < 6; attempt++) {
      flushMainLayout();
      last = readOverlapAtScrollEnd();
      overlapPx = last.overlapPx;
      // #region agent log
      agentLog('E', 'mobile-overlay.js:resolveScrollClearance', 'attempt', {
        runId: 'post-fix-v7',
        trigger,
        attempt,
        overlapPx,
        blockPx,
        cachedBlockPx: navBlockByScreen.get(sid) || 0,
        ...last,
      });
      // #endregion
      if (overlapPx <= 0) break;
      const nextBlock = capScreenBlockPx(blockPx + overlapPx + gap);
      if (nextBlock <= blockPx) break;
      blockPx = nextBlock;
      applyScrollClearance(blockPx);
    }

    navBlockByScreen.set(sid, blockPx);
    applyScrollClearance(blockPx);
    const maxTop = clampMainScrollTop(main);
    if (options.scrollToBottom) main.scrollTop = maxTop;
    else if (trigger.startsWith('goTo-')) main.scrollTop = 0;
    else main.scrollTop = Math.min(savedTop, maxTop);
    clampMainScrollTop(main);

    // #region agent log
    agentLog('E', 'mobile-overlay.js:resolveScrollClearance', 'done', {
      runId: 'post-fix-v7',
      trigger,
      finalOverlapPx: overlapPx,
      blockPx,
      screenId: sid,
      restoredScrollTop: main.scrollTop,
    });
    // #endregion
    return overlapPx;
  };

  const ensureScrollClearance = (trigger) => {
    resolveScrollClearance(trigger, { scrollToBottom: false });
  };

  /** Нижний отступ прокрутки .main: зона под fixed bottom-nav. */
  const syncNavScrollInset = () => {
    if (!mq.matches) {
      clearMainScrollPadding();
      return;
    }
    const nav = document.querySelector('.bottom-nav');
    if (!nav) return;
    positionBottomNav();
    const rect = nav.getBoundingClientRect();
    const active = document.querySelector('.screen.active');
    const sid = active?.id || '';
    const baseMin = computeNavBlockPx();
    const blockPx = capScreenBlockPx(Math.max(navBlockByScreen.get(sid) || 0, baseMin));
    applyScrollClearance(blockPx);
    // #region agent log
    agentLog('A,F', 'mobile-overlay.js:syncNavScrollInset', 'nav inset computed', {
      runId: 'post-fix-v7',
      blockPx,
      screenId: sid,
      innerHeight: window.innerHeight,
      navTop: Math.round(rect.top),
      navBottom: Math.round(rect.bottom),
      overlayZone: Math.round(window.innerHeight - rect.top),
    });
    // #endregion
  };

  const measureScrollOverlap = (trigger) => {
    if (!mq.matches) return 0;
    const main = mainEl();
    const nav = document.querySelector('.bottom-nav');
    const active = document.querySelector('.screen.active');
    if (!main || !nav || !active) return 0;
    const navR = nav.getBoundingClientRect();
    const mainStyle = getComputedStyle(main);
    const scrollMax = clampMainScrollTop(main);
    const scrollTop = main.scrollTop;
    const atBottom = scrollMax <= 0 || scrollTop >= scrollMax - 3;
    const bottomEl = findScreenBottomElement(active);
    const contentBottom = Math.round(bottomEl?.getBoundingClientRect?.()?.bottom ?? 0);
    const overlapPx = atBottom ? measureContentOverlap(bottomEl, navR) : 0;
    // #region agent log
    agentLog('E', 'mobile-overlay.js:measureScrollOverlap', 'scroll clearance', {
      runId: 'post-fix-v7',
      trigger,
      screenId: active.id,
      atBottom,
      overlapPx,
      scrollTop: Math.round(scrollTop),
      scrollMax: Math.round(scrollMax),
      scrollTopClamped: scrollTop !== main.scrollTop,
      mainPaddingBottom: mainStyle.paddingBottom,
      hostPaddingBottom: getComputedStyle(getScreenScrollHost(active) || active).paddingBottom,
      contentBottom: Math.round(contentBottom),
      navTop: Math.round(navR.top),
    });
    // #endregion
    return atBottom ? overlapPx : 0;
  };

  const adjustNavScrollInsetIfOverlap = (trigger) => {
    const overlapPx = measureScrollOverlap(trigger);
    if (overlapPx <= 0) return;
    resolveScrollClearance(trigger, { scrollToBottom: true });
  };

  const hasOpenOverlay = () =>
    !!document.querySelector(
      '.modal-root.show, .catalog-editor-root:not([hidden]), .catalog-form-overlay:not([hidden]), ' +
        '.photo-lightbox.show, .vr-form-overlay:not([hidden]), .confirm-overlay:not([hidden]), ' +
        '.schedule-form-overlay:not([hidden]), .elimination-detail-overlay:not([hidden])'
    );

  const clearStaleScrollLock = () => {
    if (hasOpenOverlay()) return;
    depth = 0;
    document.documentElement.classList.remove('gazprom-scroll-lock');
    mainEl()?.classList.remove('gazprom-main-scroll-lock');
  };

  const syncMobileShellClass = () => {
    document.body.classList.toggle('gazprom-mobile-shell', mq.matches);
    syncVisualViewport();
    syncNavScrollInset();
    if (mq.matches) {
      window.scrollTo(0, window.scrollY);
      document.documentElement.scrollLeft = 0;
      document.body.scrollLeft = 0;
    } else {
      document.documentElement.style.removeProperty('--vv-height');
      clearMainScrollPadding();
    }
  };

  const recoverViewportLayout = () => {
    syncMobileShellClass();
    syncNavScrollInset();
    clampScrollX();
    clearStaleScrollLock();
    const main = mainEl();
    if (main) {
      main.scrollLeft = 0;
      void main.offsetHeight;
    }
    requestAnimationFrame(() => ensureScrollClearance('recoverViewportLayout'));
  };

  const lock = () => {
    if (!mq.matches) return;
    if (depth === 0) {
      document.documentElement.classList.add('gazprom-scroll-lock');
      mainEl()?.classList.add('gazprom-main-scroll-lock');
      syncVisualViewport();
    }
    depth += 1;
  };

  const unlock = () => {
    if (!mq.matches) return;
    depth = Math.max(0, depth - 1);
    if (depth === 0) {
      document.documentElement.classList.remove('gazprom-scroll-lock');
      mainEl()?.classList.remove('gazprom-main-scroll-lock');
    }
  };

  let touchStartX = 0;
  let touchStartY = 0;

  const clampScrollX = () => {
    if (!mq.matches) return;
    if (window.scrollX !== 0) {
      window.scrollTo(0, window.scrollY);
    }
    const main = mainEl();
    if (main && main.scrollLeft !== 0) {
      main.scrollLeft = 0;
    }
  };

  const findHorizontalScrollContainer = (target) => {
    const node = target?.closest?.(HORIZONTAL_SCROLL_SELECTOR);
    if (!node) return null;
    if (node.scrollWidth > node.clientWidth + 2) return node;
    const inner = node.querySelector?.(
      '.toolbar-filters--pills, .history-list-toolbar, .toolbar-filters'
    );
    if (inner && inner.scrollWidth > inner.clientWidth + 2) return inner;
    return node;
  };

  const allowHorizontalScroll = (target) => !!findHorizontalScrollContainer(target);

  const isHorizontalGesture = (dx, dy) =>
    Math.abs(dx) > 4 && Math.abs(dx) >= Math.abs(dy) * 0.45;

  const NON_TEXT_INPUT_TYPES = new Set([
    'button',
    'checkbox',
    'radio',
    'file',
    'submit',
    'reset',
    'hidden',
    'image',
    'range',
    'color',
  ]);

  const isTextEditingTarget = (target) => {
    const el = target?.closest?.('textarea, select, [contenteditable="true"]');
    if (el) return true;
    const input = target?.closest?.('input');
    if (!input) return false;
    const type = (input.getAttribute('type') || 'text').toLowerCase();
    return !NON_TEXT_INPUT_TYPES.has(type);
  };

  const isFocusedTextField = () => isTextEditingTarget(document.activeElement);

  const shouldAllowNativeTextGesture = (target) =>
    hasOpenOverlay() || isTextEditingTarget(target) || isFocusedTextField();

  const handleTouchStart = (e) => {
    if (!mq.matches || e.touches.length !== 1) return;
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
    clampScrollX();
  };

  /** Не даём document touchmove глушить свайп по полосам Истории (кнопки pills на iOS). */
  const shieldHistoryHorizontalTouch = (e) => {
    if (!mq.matches || e.touches.length !== 1) return;
    if (!allowHorizontalScroll(e.target)) return;
    const dx = e.touches[0].clientX - touchStartX;
    const dy = e.touches[0].clientY - touchStartY;
    if (!isHorizontalGesture(dx, dy)) return;
    e.stopPropagation();
  };

  const handleTouchMove = (e) => {
    if (!mq.matches || e.touches.length !== 1) return;
    if (shouldAllowNativeTextGesture(e.target)) return;
    const dx = e.touches[0].clientX - touchStartX;
    const dy = e.touches[0].clientY - touchStartY;
    if (isHorizontalGesture(dx, dy)) {
      if (allowHorizontalScroll(e.target)) return;
      e.preventDefault();
      return;
    }
    if (!allowHorizontalScroll(e.target)) {
      clampScrollX();
    }
  };

  const handleTouchEnd = () => {
    clampScrollX();
  };

  let scrollLogTimer = 0;
  const handleMainScroll = () => {
    if (!mq.matches) return;
    if (scrollLogTimer) return;
    scrollLogTimer = window.setTimeout(() => {
      scrollLogTimer = 0;
      adjustNavScrollInsetIfOverlap('main-scroll');
    }, 200);
  };

  syncMobileShellClass();
  scheduleInitDebugPanel();
  requestAnimationFrame(() => ensureScrollClearance('boot'));
  mq.addEventListener('change', recoverViewportLayout);

  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', () => {
      syncVisualViewport();
      syncNavScrollInset();
      clampScrollX();
    });
    window.visualViewport.addEventListener('scroll', () => {
      syncVisualViewport();
      syncNavScrollInset();
    });
  }
  window.addEventListener('resize', recoverViewportLayout);
  window.addEventListener('orientationchange', () => {
    recoverViewportLayout();
    [80, 200, 400, 700].forEach((ms) => {
      setTimeout(recoverViewportLayout, ms);
    });
  });
  document.addEventListener('touchstart', handleTouchStart, { passive: true });
  document.addEventListener('touchmove', shieldHistoryHorizontalTouch, {
    capture: true,
    passive: true,
  });
  document.addEventListener('touchmove', handleTouchMove, { passive: false });
  document.addEventListener('touchend', handleTouchEnd, { passive: true });
  document.addEventListener('touchcancel', handleTouchEnd, { passive: true });
  window.addEventListener('scroll', clampScrollX, { passive: true });
  mainEl()?.addEventListener('scroll', handleMainScroll, { passive: true });

  return {
    lock,
    unlock,
    syncVisualViewport,
    syncNavScrollInset,
    measureScrollOverlap,
    adjustNavScrollInsetIfOverlap,
    ensureScrollClearance,
    recoverViewportLayout,
  };
})();
