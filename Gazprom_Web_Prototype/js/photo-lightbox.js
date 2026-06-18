/**
 * Полноэкранный просмотр фото (акт, справка, модалки нарушений).
 */
const PhotoLightbox = (() => {
  function attachLightboxZoom(viewport, stageEl) {
    const MIN_SCALE = 1;
    const MAX_SCALE = 4;
    const SNAP_THRESHOLD = 1.08;

    let scale = 1;
    let tx = 0;
    let ty = 0;
    let pinchDist0 = 0;
    let pinchScale0 = 1;
    let pinchTx0 = 0;
    let pinchTy0 = 0;
    let panX0 = 0;
    let panY0 = 0;
    let panTx0 = 0;
    let panTy0 = 0;
    let multiTouchGesture = false;
    let lastTapAt = 0;

    const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
    const touchDist = (a, b) => Math.hypot(b.clientX - a.clientX, b.clientY - a.clientY);

    const viewportCenter = () => {
      const r = viewport.getBoundingClientRect();
      return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
    };

    const paint = () => {
      if (scale <= 1) {
        scale = 1;
        tx = 0;
        ty = 0;
        stageEl.style.transform = '';
        return;
      }
      stageEl.style.transform = `translate3d(${tx}px, ${ty}px, 0) scale(${scale})`;
    };

    const resetZoom = () => {
      scale = 1;
      tx = 0;
      ty = 0;
      pinchDist0 = 0;
      multiTouchGesture = false;
      stageEl.style.transform = '';
    };

    const beginPinch = (t0, t1) => {
      multiTouchGesture = true;
      pinchDist0 = Math.max(touchDist(t0, t1), 8);
      pinchScale0 = scale;
      pinchTx0 = tx;
      pinchTy0 = ty;
    };

    const updatePinch = (t0, t1) => {
      const dist = touchDist(t0, t1);
      const midX = (t0.clientX + t1.clientX) / 2;
      const midY = (t0.clientY + t1.clientY) / 2;
      const c = viewportCenter();
      const nextScale = clamp(pinchScale0 * (dist / pinchDist0), MIN_SCALE, MAX_SCALE);
      const ratio = nextScale / pinchScale0;

      scale = nextScale;
      tx = pinchTx0 + (midX - c.x) * (1 - ratio);
      ty = pinchTy0 + (midY - c.y) * (1 - ratio);
      paint();
    };

    const beginPan = (t) => {
      panX0 = t.clientX;
      panY0 = t.clientY;
      panTx0 = tx;
      panTy0 = ty;
    };

    const updatePan = (t) => {
      tx = panTx0 + (t.clientX - panX0);
      ty = panTy0 + (t.clientY - panY0);
      paint();
    };

    const stopTouch = (e) => {
      e.stopPropagation();
    };

    const onTouchStart = (e) => {
      stopTouch(e);
      if (e.touches.length >= 2) {
        e.preventDefault();
        beginPinch(e.touches[0], e.touches[1]);
        return;
      }
      if (e.touches.length === 1 && scale > 1) beginPan(e.touches[0]);
    };

    const onTouchMove = (e) => {
      stopTouch(e);
      if (e.touches.length >= 2) {
        e.preventDefault();
        if (pinchDist0 <= 0) beginPinch(e.touches[0], e.touches[1]);
        updatePinch(e.touches[0], e.touches[1]);
        return;
      }
      if (e.touches.length === 1 && scale > 1 && pinchDist0 <= 0) {
        e.preventDefault();
        updatePan(e.touches[0]);
      }
    };

    const onTouchEnd = (e) => {
      stopTouch(e);
      const remaining = e.touches.length;
      const wasMulti = multiTouchGesture;

      if (remaining === 1) {
        pinchDist0 = 0;
        if (scale > 1) beginPan(e.touches[0]);
        return;
      }

      if (remaining !== 0) return;

      pinchDist0 = 0;
      if (scale < SNAP_THRESHOLD) resetZoom();

      if (!wasMulti && e.changedTouches.length === 1) {
        const now = Date.now();
        if (now - lastTapAt < 280) {
          lastTapAt = 0;
          if (scale > 1) resetZoom();
          else {
            scale = 2.5;
            paint();
          }
        } else {
          lastTapAt = now;
        }
      }

      window.setTimeout(() => {
        if (!viewport.ownerDocument?.defaultView) return;
        multiTouchGesture = false;
      }, 400);
    };

    const onWheel = (e) => {
      e.preventDefault();
      e.stopPropagation();
      const step = e.deltaY < 0 ? 0.1 : -0.1;
      scale = clamp(scale + step, MIN_SCALE, MAX_SCALE);
      if (scale <= 1) resetZoom();
      else paint();
    };

    const touchOpts = { passive: false, capture: true };
    viewport.addEventListener('touchstart', onTouchStart, touchOpts);
    viewport.addEventListener('touchmove', onTouchMove, touchOpts);
    viewport.addEventListener('touchend', onTouchEnd, touchOpts);
    viewport.addEventListener('touchcancel', onTouchEnd, touchOpts);
    viewport.addEventListener('wheel', onWheel, { passive: false });

    return { resetZoom };
  }

  function open(src, gallery) {
    let box = document.getElementById('photoLightbox');
    if (
      box &&
      (!box.querySelector(':scope > .photo-lightbox-close') ||
        !box.querySelector('.photo-lightbox-chip') ||
        !box.querySelector('.photo-lightbox-viewport') ||
        !box.querySelector('.photo-lightbox-stage'))
    ) {
      box.remove();
      box = null;
    }
    if (!box) {
      box = document.createElement('div');
      box.id = 'photoLightbox';
      box.className = 'photo-lightbox';
      box.innerHTML = `
        <button type="button" class="photo-lightbox-close" aria-label="Закрыть">×</button>
        <div class="photo-lightbox-inner">
          <div class="photo-lightbox-viewport" aria-label="Фото, жестами можно увеличить">
            <div class="photo-lightbox-stage">
              <img class="photo-lightbox-img" alt="" draggable="false">
            </div>
          </div>
          <div class="photo-lightbox-controls">
            <button type="button" class="photo-lightbox-nav photo-lightbox-prev photo-lightbox-chip photo-lightbox-nav-btn" aria-label="Предыдущее фото">‹</button>
            <span class="photo-lightbox-counter photo-lightbox-chip" aria-live="polite"></span>
            <button type="button" class="photo-lightbox-nav photo-lightbox-next photo-lightbox-chip photo-lightbox-nav-btn" aria-label="Следующее фото">›</button>
          </div>
        </div>
      `;
      document.body.appendChild(box);
      const viewport = box.querySelector('.photo-lightbox-viewport');
      const stageEl = box.querySelector('.photo-lightbox-stage');
      box._lightboxZoom = attachLightboxZoom(viewport, stageEl);
      const hideLightbox = () => {
        if (!box.classList.contains('show')) return;
        box._lightboxZoom?.resetZoom?.();
        box.classList.remove('show');
        GazpromMobileOverlay.unlock();
        GazpromMobileOverlay.scheduleRecoverViewportLayout?.();
      };
      box.querySelector('.photo-lightbox-close').onclick = hideLightbox;
      box.onclick = (e) => {
        if (e.target === box) hideLightbox();
      };
    }
    const imgs = gallery?.length ? gallery : [src];
    let idx = src ? imgs.indexOf(src) : 0;
    if (idx < 0) idx = 0;
    const imgEl = box.querySelector('.photo-lightbox-img');
    const counterEl = box.querySelector('.photo-lightbox-counter');
    const prevBtn = box.querySelector('.photo-lightbox-prev');
    const nextBtn = box.querySelector('.photo-lightbox-next');
    const show = (i) => {
      idx = (i + imgs.length) % imgs.length;
      box._lightboxZoom?.resetZoom?.();
      imgEl.src = imgs[idx];
      const multi = imgs.length > 1;
      if (counterEl) counterEl.textContent = multi ? `${idx + 1} / ${imgs.length}` : '';
      if (prevBtn) prevBtn.style.visibility = multi ? 'visible' : 'hidden';
      if (nextBtn) nextBtn.style.visibility = multi ? 'visible' : 'hidden';
    };
    show(idx);
    prevBtn.onclick = (e) => {
      e.stopPropagation();
      show(idx - 1);
    };
    nextBtn.onclick = (e) => {
      e.stopPropagation();
      show(idx + 1);
    };
    if (!box.classList.contains('show')) {
      GazpromMobileOverlay.lock();
    }
    box.classList.add('show');
  }

  return { open };
})();
