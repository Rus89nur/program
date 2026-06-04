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
  const agentLog = (hypothesisId, location, message, data) => {
    const payload = {
      sessionId: '2c2db0',
      runId: 'pre-fix',
      hypothesisId,
      location,
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
      if (prev.length > 40) prev.shift();
      sessionStorage.setItem(key, JSON.stringify(prev));
    } catch (_) {}
    if (typeof location !== 'undefined' && String(location.search || '').includes('debug=2c2db0')) {
      let el = document.getElementById('gazpromScrollDebug');
      if (!el) {
        el = document.createElement('div');
        el.id = 'gazpromScrollDebug';
        el.style.cssText =
          'position:fixed;left:4px;right:4px;bottom:72px;z-index:99999;font:10px/1.3 monospace;' +
          'background:rgba(0,0,0,.82);color:#0f0;padding:6px;max-height:28vh;overflow:auto;pointer-events:none;';
        document.body.appendChild(el);
      }
      el.textContent = `${message} ${JSON.stringify(data)}`;
    }
  };
  // #endregion

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

  const applyMainScrollPadding = (blockPx) => {
    const main = mainEl();
    const body = document.body;
    const px = `${blockPx}px`;
    body.style.setProperty('--gazprom-nav-block', px);
    const spacer = document.querySelector('.gazprom-scroll-bottom-spacer');
    if (spacer) spacer.style.height = px;
    if (!main) return;
    const basePad =
      window.matchMedia(
        '(max-width: 900px), (max-width: 1280px) and (max-height: 520px) and (hover: none) and (orientation: landscape)'
      ).matches
        ? 6
        : 12;
    main.style.paddingBottom = `calc(${basePad}px + ${blockPx}px)`;
    main.style.scrollPaddingBottom = `calc(${basePad}px + ${blockPx}px)`;
  };

  const clearMainScrollPadding = () => {
    document.body.style.removeProperty('--gazprom-nav-block');
    document.querySelector('.gazprom-scroll-bottom-spacer')?.style.removeProperty('height');
    const main = mainEl();
    if (!main) return;
    main.style.removeProperty('padding-bottom');
    main.style.removeProperty('scroll-padding-bottom');
  };

  /** Прокрутка в конец, замер overlap (для автокоррекции). */
  const measureOverlapAtScrollEnd = (trigger) => {
    const main = mainEl();
    const nav = document.querySelector('.bottom-nav');
    const active = document.querySelector('.screen.active');
    if (!main || !nav || !active) return 0;
    const maxTop = Math.max(0, main.scrollHeight - main.clientHeight);
    main.scrollTop = maxTop;
    void main.offsetHeight;
    const navR = nav.getBoundingClientRect();
    const bottomEl = findScreenBottomElement(active);
    const contentBottom = bottomEl?.getBoundingClientRect?.()?.bottom ?? 0;
    const overlapPx = Math.round(contentBottom - navR.top);
    // #region agent log
    agentLog('E', 'mobile-overlay.js:measureOverlapAtScrollEnd', 'forced end measure', {
      runId: 'post-fix-v2',
      trigger,
      overlapPx,
      maxTop: Math.round(maxTop),
      screenId: active.id,
      bottomSelector: bottomEl?.className?.slice?.(0, 80) ?? null,
      contentBottom: Math.round(contentBottom),
      navTop: Math.round(navR.top),
      mainPaddingBottom: getComputedStyle(main).paddingBottom,
    });
    // #endregion
    return overlapPx;
  };

  const ensureScrollClearance = (trigger) => {
    if (!mq.matches) return;
    const main = mainEl();
    if (!main) return;
    const savedTop = main.scrollTop;
    syncNavScrollInset();
    const overlapPx = measureOverlapAtScrollEnd(trigger);
    if (overlapPx > 0) {
      const current = parseFloat(getComputedStyle(document.body).getPropertyValue('--gazprom-nav-block')) || 72;
      applyMainScrollPadding(Math.ceil(current + overlapPx + 16));
    }
    const maxTop = Math.max(0, main.scrollHeight - main.clientHeight);
    main.scrollTop = trigger.startsWith('goTo-') ? 0 : Math.min(savedTop, maxTop);
    // #region agent log
    agentLog('E', 'mobile-overlay.js:ensureScrollClearance', 'done', {
      runId: 'post-fix-v2',
      trigger,
      overlapPx,
      restoredScrollTop: main.scrollTop,
      navBlock: getComputedStyle(document.body).getPropertyValue('--gazprom-nav-block').trim(),
    });
    // #endregion
  };

  /** Нижний отступ прокрутки .main: bottom-nav + панель Safari (visualViewport). */
  const syncNavScrollInset = () => {
    if (!mq.matches) {
      clearMainScrollPadding();
      return;
    }
    const nav = document.querySelector('.bottom-nav');
    const gap = 16;
    if (!nav) return;
    const rect = nav.getBoundingClientRect();
    const vv = window.visualViewport;
    const visibleBottom = vv ? vv.offsetTop + vv.height : window.innerHeight;
    const browserChromeBelow = Math.max(0, window.innerHeight - visibleBottom);
    const fromNavTop = window.innerHeight - rect.top + gap;
    const fromNavInView = Math.max(0, visibleBottom - rect.top) + gap;
    const fromChrome = rect.height + browserChromeBelow + gap;
    const blockPx = Math.max(72, Math.ceil(Math.max(fromNavTop, fromNavInView, fromChrome)));
    applyMainScrollPadding(blockPx);
    // #region agent log
    agentLog('A,D', 'mobile-overlay.js:syncNavScrollInset', 'nav inset computed', {
      runId: 'post-fix',
      blockPx,
      fromNavTop: Math.ceil(fromNavTop),
      fromNavInView: Math.ceil(fromNavInView),
      fromChrome: Math.ceil(fromChrome),
      browserChromeBelow: Math.round(browserChromeBelow),
      innerHeight: window.innerHeight,
      vvHeight: vv?.height ?? null,
      visibleBottom: Math.round(visibleBottom),
      navTop: Math.round(rect.top),
      navBottom: Math.round(rect.bottom),
      navHeight: Math.round(rect.height),
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
    const scrollMax = main.scrollHeight - main.clientHeight;
    const atBottom = scrollMax <= 0 || main.scrollTop >= scrollMax - 3;
    const bottomEl = findScreenBottomElement(active);
    const contentBottom = bottomEl?.getBoundingClientRect?.()?.bottom ?? 0;
    const overlapPx = Math.round(contentBottom - navR.top);
    // #region agent log
    agentLog('E', 'mobile-overlay.js:measureScrollOverlap', 'scroll clearance', {
      runId: 'post-fix',
      trigger,
      screenId: active.id,
      atBottom,
      overlapPx,
      scrollTop: Math.round(main.scrollTop),
      scrollMax: Math.round(scrollMax),
      mainPaddingBottom: mainStyle.paddingBottom,
      contentBottom: Math.round(contentBottom),
      navTop: Math.round(navR.top),
    });
    // #endregion
    return atBottom ? overlapPx : 0;
  };

  const adjustNavScrollInsetIfOverlap = (trigger) => {
    const overlapPx = measureScrollOverlap(trigger);
    if (overlapPx <= 0) return;
    const body = document.body;
    const current = parseFloat(getComputedStyle(body).getPropertyValue('--gazprom-nav-block')) || 72;
    const blockPx = Math.ceil(current + overlapPx + 12);
    applyMainScrollPadding(blockPx);
    // #region agent log
    agentLog('E', 'mobile-overlay.js:adjustNavScrollInsetIfOverlap', 'auto bump nav block', {
      runId: 'post-fix',
      trigger,
      overlapPx,
      blockPx,
    });
    // #endregion
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
