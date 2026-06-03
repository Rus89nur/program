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

  const handleTouchStart = (e) => {
    if (!mq.matches || e.touches.length !== 1) return;
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
  };

  const handleTouchMove = (e) => {
    if (!mq.matches || e.touches.length !== 1) return;
    const scrollable = e.target.closest(
      '.main, .modal-body, .catalog-editor-body, .catalog-form-dialog, .backup-modal-dialog, .vr-form-dialog, .wizard-stepper, .list-table, .toolbar-filters--pills, .history-list'
    );
    if (scrollable) return;
    const dx = Math.abs(e.touches[0].clientX - touchStartX);
    const dy = Math.abs(e.touches[0].clientY - touchStartY);
    if (dx > dy && dx > 6) {
      e.preventDefault();
    }
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

  return { lock, unlock, syncVisualViewport };
})();
