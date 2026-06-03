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
    if (mq.matches) {
      window.scrollTo(0, window.scrollY);
      document.documentElement.scrollLeft = 0;
      document.body.scrollLeft = 0;
    } else {
      document.documentElement.style.removeProperty('--vv-height');
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

  syncMobileShellClass();
  mq.addEventListener('change', recoverViewportLayout);

  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', () => {
      syncVisualViewport();
      clampScrollX();
    });
    window.visualViewport.addEventListener('scroll', syncVisualViewport);
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

  return { lock, unlock, syncVisualViewport, recoverViewportLayout };
})();
