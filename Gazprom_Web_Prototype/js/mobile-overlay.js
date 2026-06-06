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

  const hasOpenOverlay = () =>
    !!document.querySelector(
      '#wizardModalRoot.show, .modal-root.show, .catalog-editor-root:not([hidden]), ' +
        '.catalog-form-overlay:not([hidden]), .photo-lightbox.show, .vr-form-overlay:not([hidden]), ' +
        '.confirm-overlay:not([hidden]), .schedule-form-overlay:not([hidden]), ' +
        '.elimination-detail-overlay:not([hidden])'
    );

  const positionBottomNav = () => {
    const nav = document.querySelector('.bottom-nav');
    if (!nav || !mq.matches) {
      nav?.style.removeProperty('bottom');
      document.body.style.removeProperty('--gazprom-safari-bottom-inset');
      return 0;
    }
    /* При открытом оверлее бар не поднимаем — иначе «прыгает» за модалкой (web-123). */
    if (hasOpenOverlay()) {
      nav.style.removeProperty('bottom');
      document.body.style.setProperty('--gazprom-safari-bottom-inset', '0px');
      return 0;
    }
    const vv = window.visualViewport;
    const inset = vv ? Math.max(0, Math.round(window.innerHeight - vv.height - vv.offsetTop)) : 0;
    document.body.style.setProperty('--gazprom-safari-bottom-inset', `${inset}px`);
    nav.style.bottom = `${inset}px`;
    return inset;
  };

  const isWizardModalKeyboardOpen = () => {
    const vv = window.visualViewport;
    if (!vv) return false;
    return Math.max(0, window.innerHeight - vv.height - vv.offsetTop) > 80;
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
      root.style.removeProperty('--vv-offset-top');
      root.style.removeProperty('--vv-offset-left');
      root.style.removeProperty('--vv-width');
      syncWizardModalViewport();
      return;
    }
    const vv = window.visualViewport;
    root.style.setProperty('--vv-height', `${vv.height}px`);
    root.style.setProperty('--vv-offset-top', `${vv.offsetTop}px`);
    root.style.setProperty('--vv-offset-left', `${vv.offsetLeft}px`);
    root.style.setProperty('--vv-width', `${vv.width}px`);
    if (window.scrollX !== 0) {
      window.scrollTo(0, window.scrollY);
    }
    syncWizardModalViewport();
  };

  const isWizardModalTextareaFocused = (modal) => {
    const active = document.activeElement;
    return (
      !!active &&
      modal.contains(active) &&
      active.matches('textarea')
    );
  };

  /** Fullscreen модалка нарушения: клавиатура / фокус в textarea — футер скрыт, высота по vv (§3.11, web-126). */
  const syncWizardModalViewport = () => {
    const modal = document.getElementById('wizardModalRoot');
    if (!modal?.classList.contains('show') || !mq.matches) {
      modal?.classList.remove('wizard-modal--keyboard');
      return;
    }
    const keyboardOpen =
      isWizardModalKeyboardOpen() || isWizardModalTextareaFocused(modal);
    modal.classList.toggle('wizard-modal--keyboard', keyboardOpen);
  };

  const scrollWizardModalFieldIntoView = (target) => {
    const modal = document.getElementById('wizardModalRoot');
    if (!modal?.classList.contains('show') || !mq.matches) return;
    if (!target?.matches?.('input, select')) return;
    if (target.matches('textarea')) return;
    if (!modal.contains(target)) return;
    const body = modal.querySelector('.modal-body');
    if (!body) return;
    requestAnimationFrame(() => {
      const vv = window.visualViewport;
      const visibleTop = vv ? vv.offsetTop : 0;
      const visibleBottom = vv ? vv.offsetTop + vv.height : window.innerHeight;
      const header = modal.querySelector('.modal-header');
      const headerBottom = header ? header.getBoundingClientRect().bottom : visibleTop;
      const minTop = Math.max(visibleTop, headerBottom) + 12;
      const maxBottom = visibleBottom - 16;
      const fieldRect = target.getBoundingClientRect();
      if (fieldRect.bottom > maxBottom) {
        body.scrollTop += fieldRect.bottom - maxBottom;
      } else if (fieldRect.top < minTop) {
        body.scrollTop -= minTop - fieldRect.top;
      }
    });
  };

  const findScreenBottomElement = (screen) => {
    if (!screen) return null;
    if (screen.id === 'screen-home') {
      return screen.lastElementChild;
    }
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
  const syncNavBarHeight = () => {
    const nav = document.querySelector('.bottom-nav');
    if (!nav || !mq.matches) {
      document.body.style.removeProperty('--gazprom-nav-bar-height');
      return;
    }
    const h = Math.ceil(nav.getBoundingClientRect().height);
    document.body.style.setProperty('--gazprom-nav-bar-height', `${h}px`);
  };

  const applyScrollClearance = (blockPx) => {
    const px = `${blockPx}px`;
    document.body.style.setProperty('--gazprom-nav-block', px);
    syncNavBarHeight();
    const spacer = document.querySelector('.gazprom-scroll-bottom-spacer');
    if (spacer) spacer.style.height = px;
    const main = mainEl();
    if (main) {
      main.style.removeProperty('padding-bottom');
      main.style.removeProperty('scroll-padding-bottom');
    }
    document.querySelectorAll('.main > .screen').forEach((screen) => {
      screen.style.removeProperty('padding-bottom');
      const host = getScreenScrollHost(screen);
      if (!host || host === screen) return;
      host.style.removeProperty('padding-bottom');
    });
    const active = document.querySelector('.screen.active');
    const host = getScreenScrollHost(active);
    if (host) host.style.paddingBottom = px;
  };

  const clearMainScrollPadding = () => {
    navBlockByScreen.clear();
    document.body.style.removeProperty('--gazprom-nav-block');
    document.body.style.removeProperty('--gazprom-nav-bar-height');
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

  const applyBaselineScrollClearance = (sid) => {
    const baseMin = computeNavBlockPx();
    const blockPx = capScreenBlockPx(Math.max(navBlockByScreen.get(sid) || 0, baseMin));
    applyScrollClearance(blockPx);
    navBlockByScreen.set(sid, blockPx);
    return blockPx;
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
    const isBootLayout = trigger === 'boot' || trigger === 'recoverViewportLayout';
    const isWizardPanelRender =
      trigger === 'wizard-render' || trigger.startsWith('wizard-step-');

    if (trigger.startsWith('goTo-') || trigger.startsWith('wizard-step-')) {
      navBlockByScreen.delete(sid);
    }

    if (isBootLayout) {
      applyBaselineScrollClearance(sid);
      return 0;
    }

    /* Шаг «Нарушения»: без цикла scroll-to-bottom — на iPhone «выкидывает» из мастера. */
    if (isWizardPanelRender) {
      applyBaselineScrollClearance(sid);
      if (trigger.startsWith('wizard-step-')) {
        main.scrollTop = 0;
      } else {
        main.scrollTop = Math.min(savedTop, Math.max(0, main.scrollHeight - main.clientHeight));
      }
      clampMainScrollTop(main);
      return 0;
    }

    let blockPx = capScreenBlockPx(Math.max(navBlockByScreen.get(sid) || 0, baseMin));
    applyScrollClearance(blockPx);

    let overlapPx = 0;
    let last = null;

    for (let attempt = 0; attempt < 6; attempt++) {
      flushMainLayout();
      last = readOverlapAtScrollEnd();
      overlapPx = last.overlapPx;
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
    const active = document.querySelector('.screen.active');
    const sid = active?.id || '';
    const baseMin = computeNavBlockPx();
    const blockPx = capScreenBlockPx(Math.max(navBlockByScreen.get(sid) || 0, baseMin));
    applyScrollClearance(blockPx);
  };

  const measureScrollOverlap = () => {
    if (!mq.matches) return 0;
    const main = mainEl();
    const nav = document.querySelector('.bottom-nav');
    const active = document.querySelector('.screen.active');
    if (!main || !nav || !active) return 0;
    const navR = nav.getBoundingClientRect();
    const scrollMax = clampMainScrollTop(main);
    const scrollTop = main.scrollTop;
    const atBottom = scrollMax <= 0 || scrollTop >= scrollMax - 3;
    const bottomEl = findScreenBottomElement(active);
    return atBottom ? measureContentOverlap(bottomEl, navR) : 0;
  };

  /** Тихая подстройка padding после остановки скролла — без принудительного scrollTop в цикле. */
  const bumpScrollClearanceAtRest = () => {
    const overlapPx = measureScrollOverlap();
    if (overlapPx <= 0) return 0;
    const main = mainEl();
    if (!main) return 0;
    const active = document.querySelector('.screen.active');
    const sid = active?.id || '';
    const gap = 20;
    const baseMin = computeNavBlockPx();
    const cached = navBlockByScreen.get(sid) || baseMin;
    const nextBlock = capScreenBlockPx(cached + overlapPx + gap);
    if (nextBlock <= cached) return 0;

    const prevTop = main.scrollTop;
    const prevMax = Math.max(0, main.scrollHeight - main.clientHeight);
    const wasAtBottom = prevMax <= 0 || prevTop >= prevMax - 5;

    positionBottomNav();
    navBlockByScreen.set(sid, nextBlock);
    applyScrollClearance(nextBlock);
    flushMainLayout();

    const newMax = Math.max(0, main.scrollHeight - main.clientHeight);
    if (wasAtBottom) {
      requestAnimationFrame(() => {
        main.scrollTop = newMax;
        clampMainScrollTop(main);
      });
    } else {
      main.scrollTop = Math.min(prevTop, newMax);
    }
    return overlapPx;
  };

  const adjustNavScrollInsetIfOverlap = () => {
    bumpScrollClearanceAtRest();
  };

  const clearStaleScrollLock = () => {
    if (hasOpenOverlay()) return;
    depth = 0;
    document.documentElement.classList.remove('gazprom-scroll-lock');
    mainEl()?.classList.remove('gazprom-main-scroll-lock');
    const modal = document.getElementById('wizardModalRoot');
    modal?.classList.remove('wizard-modal--keyboard');
  };

  const syncMobileShellClass = () => {
    document.body.classList.toggle('gazprom-mobile-shell', mq.matches);
    syncVisualViewport();
    syncNavScrollInset();
    if (mq.matches) {
      document.documentElement.scrollLeft = 0;
      document.body.scrollLeft = 0;
    } else {
      document.documentElement.style.removeProperty('--vv-height');
      clearMainScrollPadding();
    }
  };

  const recoverViewportLayout = () => {
    syncMobileShellClass();
    clampScrollX();
    clearStaleScrollLock();
    const main = mainEl();
    if (main) {
      main.scrollLeft = 0;
      void main.offsetHeight;
    }
    applyBaselineScrollClearance(
      document.querySelector('.screen.active')?.id || ''
    );
  };

  /** После модалки/клавиатуры на iPhone — vv и zoom сходятся не сразу. */
  const scheduleRecoverViewportLayout = () => {
    recoverViewportLayout();
    [80, 200, 450, 700].forEach((ms) => {
      window.setTimeout(recoverViewportLayout, ms);
    });
  };

  const lock = () => {
    if (!mq.matches) return;
    if (depth === 0) {
      document.documentElement.classList.add('gazprom-scroll-lock');
      mainEl()?.classList.add('gazprom-main-scroll-lock');
      syncVisualViewport();
      positionBottomNav();
    }
    depth += 1;
  };

  const unlock = () => {
    if (!mq.matches) return;
    depth = Math.max(0, depth - 1);
    if (depth === 0) {
      document.documentElement.classList.remove('gazprom-scroll-lock');
      mainEl()?.classList.remove('gazprom-main-scroll-lock');
      positionBottomNav();
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
    if (hasOpenOverlay()) return;
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

  let scrollSettleTimer = 0;
  let navInsetSyncTimer = 0;
  const SCROLL_SETTLE_MS = 450;

  const scheduleNavInsetSync = () => {
    if (!mq.matches) return;
    positionBottomNav();
    if (navInsetSyncTimer) clearTimeout(navInsetSyncTimer);
    navInsetSyncTimer = window.setTimeout(() => {
      navInsetSyncTimer = 0;
      syncNavScrollInset();
    }, 150);
  };

  const handleMainScroll = () => {
    if (!mq.matches) return;
    if (scrollSettleTimer) clearTimeout(scrollSettleTimer);
    scrollSettleTimer = window.setTimeout(() => {
      scrollSettleTimer = 0;
      bumpScrollClearanceAtRest('main-scroll-end');
    }, SCROLL_SETTLE_MS);
  };

  syncMobileShellClass();
  applyBaselineScrollClearance(
    document.querySelector('.screen.active')?.id || 'screen-home'
  );
  mq.addEventListener('change', recoverViewportLayout);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      clearStaleScrollLock();
      recoverViewportLayout();
    }
  });

  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', () => {
      syncVisualViewport();
      scheduleNavInsetSync();
      clampScrollX();
    });
    window.visualViewport.addEventListener('scroll', () => {
      syncVisualViewport();
      positionBottomNav();
    });
  }

  const mainScrollEl = mainEl();
  if (mainScrollEl && 'onscrollend' in mainScrollEl) {
    mainScrollEl.addEventListener(
      'scrollend',
      () => bumpScrollClearanceAtRest('main-scrollend'),
      { passive: true }
    );
  }
  window.addEventListener('resize', recoverViewportLayout);
  window.addEventListener('orientationchange', () => {
    recoverViewportLayout();
    [80, 200, 400, 700].forEach((ms) => {
      setTimeout(recoverViewportLayout, ms);
    });
  });
  document.addEventListener(
    'focusin',
    (e) => {
      scrollWizardModalFieldIntoView(e.target);
      if (document.getElementById('wizardModalRoot')?.contains(e.target)) {
        syncWizardModalViewport();
      }
    },
    true
  );

  document.addEventListener(
    'focusout',
    () => {
      window.setTimeout(syncWizardModalViewport, 120);
    },
    true
  );

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
    syncWizardModalViewport,
    syncNavScrollInset,
    measureScrollOverlap,
    adjustNavScrollInsetIfOverlap,
    ensureScrollClearance,
    recoverViewportLayout,
    scheduleRecoverViewportLayout,
  };
})();
