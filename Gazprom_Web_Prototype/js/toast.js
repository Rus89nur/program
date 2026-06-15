/** Toast-уведомления (замена alert для информационных сообщений). */
const GazpromToast = (() => {
  let container = null;

  function ensureContainer() {
    if (container) return container;
    container = document.createElement('div');
    container.id = 'toastContainer';
    container.className = 'toast-container';
    container.setAttribute('aria-live', 'polite');
    document.body.appendChild(container);
    return container;
  }

  function show(message, type = 'info', durationMs = 4000) {
    const root = ensureContainer();
    const el = document.createElement('div');
    el.className = `toast toast--${type}`;
    el.textContent = message;
    root.appendChild(el);
    requestAnimationFrame(() => el.classList.add('toast--visible'));
    setTimeout(() => {
      el.classList.remove('toast--visible');
      setTimeout(() => el.remove(), 300);
    }, durationMs);
  }

  function success(msg) {
    show(msg, 'success');
  }
  function error(msg) {
    show(msg, 'error', 6000);
  }
  function info(msg) {
    show(msg, 'info');
  }

  function confirm(message, { title = 'Подтверждение', confirmLabel = 'Да', cancelLabel = 'Отмена' } = {}) {
    return new Promise((resolve) => {
      const root = document.createElement('div');
      root.className = 'confirm-overlay';
      root.innerHTML = `
        <div class="confirm-dialog" role="alertdialog" aria-modal="true">
          <h3>${title}</h3>
          <p>${message}</p>
          <div class="confirm-actions">
            <button type="button" class="btn-ghost" data-cancel>${cancelLabel}</button>
            <button type="button" class="btn-primary" data-ok>${confirmLabel}</button>
          </div>
        </div>
      `;
      document.body.appendChild(root);
      GazpromMobileOverlay.lock();
      const close = (val) => {
        root.remove();
        GazpromMobileOverlay.unlock();
        resolve(val);
      };
      root.querySelector('[data-cancel]').onclick = () => close(false);
      root.querySelector('[data-ok]').onclick = () => close(true);
      root.addEventListener('click', (e) => {
        if (e.target === root) close(false);
      });
    });
  }

  function prompt(message, defaultValue = '', { title = 'Ввод', confirmLabel = 'OK', cancelLabel = 'Отмена' } = {}) {
    return new Promise((resolve) => {
      const root = document.createElement('div');
      root.className = 'confirm-overlay';
      root.innerHTML = `
        <div class="confirm-dialog" role="dialog" aria-modal="true">
          <h3>${title}</h3>
          <p>${message}</p>
          <input type="text" class="form-control" data-prompt-input value="${String(defaultValue).replace(/"/g, '&quot;')}" style="margin-top:12px;">
          <div class="confirm-actions">
            <button type="button" class="btn-ghost" data-cancel>${cancelLabel}</button>
            <button type="button" class="btn-primary" data-ok>${confirmLabel}</button>
          </div>
        </div>
      `;
      document.body.appendChild(root);
      GazpromMobileOverlay.lock();
      const input = root.querySelector('[data-prompt-input]');
      const close = (val) => {
        root.remove();
        GazpromMobileOverlay.unlock();
        resolve(val);
      };
      input?.focus();
      input?.select();
      root.querySelector('[data-cancel]').onclick = () => close(null);
      root.querySelector('[data-ok]').onclick = () => close(input?.value ?? '');
      input?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          close(input.value);
        }
      });
      root.addEventListener('click', (e) => {
        if (e.target === root) close(null);
      });
    });
  }

  return { show, success, error, info, confirm, prompt };
})();
