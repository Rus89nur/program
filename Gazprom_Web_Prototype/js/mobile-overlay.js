/**
 * Блокировка прокрутки .main при модалках на телефоне (≤900px).
 * Скролл страницы на мобильных идёт только внутри .main (см. CSS mobile-shell).
 */
const GazpromMobileOverlay = (() => {
  const mq = window.matchMedia('(max-width: 900px)');
  let depth = 0;

  const mainEl = () => document.querySelector('.main');

  const lock = () => {
    if (!mq.matches) return;
    if (depth === 0) {
      document.documentElement.classList.add('gazprom-scroll-lock');
      mainEl()?.classList.add('gazprom-main-scroll-lock');
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

  const syncMobileShellClass = () => {
    document.body.classList.toggle('gazprom-mobile-shell', mq.matches);
  };

  syncMobileShellClass();
  mq.addEventListener('change', syncMobileShellClass);

  return { lock, unlock };
})();
