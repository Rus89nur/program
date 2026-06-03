/**
 * Мобильная оболочка (≤900px): блокировка .main при модалках, высота visualViewport для модалок.
 */
const GazpromMobileOverlay = (() => {
  const mq = window.matchMedia('(max-width: 900px)');
  let depth = 0;

  const mainEl = () => document.querySelector('.main');

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

  const syncMobileShellClass = () => {
    document.body.classList.toggle('gazprom-mobile-shell', mq.matches);
    syncVisualViewport();
    if (mq.matches) {
      window.scrollTo(0, window.scrollY);
      document.documentElement.scrollLeft = 0;
      document.body.scrollLeft = 0;
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

  const handleTouchStart = (e) => {
    if (!mq.matches || e.touches.length !== 1) return;
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
    clampScrollX();
  };

  const allowHorizontalScroll = (target) =>
    !!target?.closest('.list-table, .wizard-stepper, .toolbar-filters--pills');

  const handleTouchMove = (e) => {
    if (!mq.matches || e.touches.length !== 1) return;
    const dx = e.touches[0].clientX - touchStartX;
    const dy = e.touches[0].clientY - touchStartY;
    if (Math.abs(dx) > 4 && Math.abs(dx) >= Math.abs(dy) * 0.45) {
      if (!allowHorizontalScroll(e.target)) {
        e.preventDefault();
      }
      return;
    }
    clampScrollX();
  };

  const handleTouchEnd = () => {
    clampScrollX();
  };

  syncMobileShellClass();
  mq.addEventListener('change', syncMobileShellClass);

  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', syncVisualViewport);
    window.visualViewport.addEventListener('scroll', syncVisualViewport);
  }
  window.addEventListener('resize', syncVisualViewport);
  window.addEventListener('orientationchange', () => {
    setTimeout(syncVisualViewport, 80);
    setTimeout(syncVisualViewport, 320);
  });
  document.addEventListener('touchstart', handleTouchStart, { passive: true });
  document.addEventListener('touchmove', handleTouchMove, { passive: false });
  document.addEventListener('touchend', handleTouchEnd, { passive: true });
  document.addEventListener('touchcancel', handleTouchEnd, { passive: true });
  window.addEventListener('scroll', clampScrollX, { passive: true });

  return { lock, unlock, syncVisualViewport };
})();
