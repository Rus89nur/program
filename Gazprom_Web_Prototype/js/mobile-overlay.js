/**
 * Фиксация фона и блокировка горизонтального сдвига при открытых окнах на телефоне (≤900px).
 * На широком экране (десктопный браузер) не активируется.
 */
const GazpromMobileOverlay = (() => {
  const mq = window.matchMedia('(max-width: 900px)');
  let depth = 0;
  let scrollY = 0;

  const lock = () => {
    if (!mq.matches) return;
    if (depth === 0) {
      scrollY = window.scrollY;
      document.documentElement.classList.add('gazprom-scroll-lock');
      document.body.classList.add('gazprom-scroll-lock');
      document.body.style.top = `-${scrollY}px`;
    }
    depth += 1;
  };

  const unlock = () => {
    if (!mq.matches) return;
    depth = Math.max(0, depth - 1);
    if (depth === 0) {
      document.documentElement.classList.remove('gazprom-scroll-lock');
      document.body.classList.remove('gazprom-scroll-lock');
      document.body.style.top = '';
      window.scrollTo(0, scrollY);
    }
  };

  return { lock, unlock };
})();
