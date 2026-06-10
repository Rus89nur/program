/**
 * Модальные окна мастера: нарушение, быстрое добавление в справочник.
 */
const WizardModals = (() => {
  const SAVE_TIMEOUT_MS = 60000;

  let ctx = null;
  let editingViolationId = null;
  let modalPhotos = [];
  let savingViolation = false;
  let violationFormInitial = null;

  const isSavingViolation = () => savingViolation;

  const withSaveTimeout = (promise, message) =>
    Promise.race([
      promise,
      new Promise((_, reject) => {
        window.setTimeout(
          () =>
            reject(
              new Error(
                message ||
                  'Сохранение заняло слишком много времени. Проверьте соединение и попробуйте снова.'
              )
            ),
          SAVE_TIMEOUT_MS
        );
      }),
    ]);

  function ensureModalRoot() {
    let root = document.getElementById('wizardModalRoot');
    if (root) return root;
    root = document.createElement('div');
    root.id = 'wizardModalRoot';
    root.className = 'modal-root';
    root.hidden = true;
    root.innerHTML = `
      <div class="modal-backdrop" data-close></div>
      <div class="modal-dialog" role="dialog" aria-modal="true">
        <div class="modal-header">
          <h3 id="modalTitle">—</h3>
          <div class="modal-header-actions">
            <button type="button" class="btn-ghost btn-sm modal-header-cancel" id="modalHeaderCancel" hidden>Отмена</button>
            <button type="button" class="btn-primary btn-sm modal-header-save" id="modalHeaderSave" hidden>Сохранить</button>
            <button type="button" class="modal-close" data-close aria-label="Закрыть">×</button>
          </div>
        </div>
        <div class="modal-body" id="modalBody"></div>
        <div class="modal-footer" id="modalFooter"></div>
      </div>
    `;
    document.body.appendChild(root);
    if (!root.dataset.closeBound) {
      root.dataset.closeBound = '1';
      root.addEventListener('click', (e) => {
        if (e.target.closest('[data-close]')) {
          e.preventDefault();
          void requestClose();
        }
      });
    }
    return root;
  }

  function open(title, bodyHtml, footerHtml) {
    const root = ensureModalRoot();
    root.hidden = false;
    root.classList.add('show');
    GazpromMobileOverlay.lock();
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalBody').innerHTML = bodyHtml;
    document.getElementById('modalFooter').innerHTML = footerHtml || '';
    const headerSave = document.getElementById('modalHeaderSave');
    const headerCancel = document.getElementById('modalHeaderCancel');
    const footerPrimary = document.getElementById('modalFooter')?.querySelector('.btn-primary');
    if (headerSave) {
      headerSave.hidden = !footerPrimary;
      headerSave.disabled = false;
      headerSave.onclick = footerPrimary ? () => footerPrimary.click() : null;
    }
    if (headerCancel) {
      headerCancel.hidden = false;
      headerCancel.disabled = false;
      headerCancel.onclick = () => {
        void requestClose();
      };
    }
    GazpromMobileOverlay.syncWizardModalViewport?.();
  }

  function readFieldRaw(id) {
    return document.getElementById(id)?.value ?? '';
  }

  function isBlankText(text) {
    return !String(text ?? '').trim();
  }

  function readViolationFormSnapshot() {
    return {
      title: readFieldRaw('mvTitle'),
      mesto: readFieldRaw('mvMesto'),
      subTitle: readFieldRaw('mvUrl'),
      vid: document.getElementById('mvVid')?.value || '',
      formulaFromRules: readFieldRaw('mvFormula'),
      photoCount: modalPhotos.length,
    };
  }

  function isViolationFormDirty() {
    if (!violationFormInitial) return false;
    const current = readViolationFormSnapshot();
    return (
      current.title !== violationFormInitial.title ||
      current.mesto !== violationFormInitial.mesto ||
      current.subTitle !== violationFormInitial.subTitle ||
      current.vid !== violationFormInitial.vid ||
      current.formulaFromRules !== violationFormInitial.formulaFromRules ||
      current.photoCount !== violationFormInitial.photoCount
    );
  }

  async function requestClose(options = {}) {
    if (savingViolation) {
      GazpromToast.info('Дождитесь завершения сохранения…');
      return;
    }
    if (!options.skipConfirm && isViolationFormDirty()) {
      const ok = await GazpromToast.confirm('Закрыть без сохранения?', {
        confirmLabel: 'Закрыть',
        danger: true,
      });
      if (!ok) return;
    }
    close(options);
  }

  function close(options = {}) {
    const root = document.getElementById('wizardModalRoot');
    const active = document.activeElement;
    if (active && root?.contains(active)) {
      active.blur();
    }
    if (root) {
      root.classList.remove('show', 'wizard-modal--keyboard');
      root.hidden = true;
    }
    GazpromMobileOverlay.unlock();
    GazpromMobileOverlay.syncWizardModalViewport?.();
    if (!options.deferRecover) {
      GazpromMobileOverlay.scheduleRecoverViewportLayout?.();
    }
    editingViolationId = null;
    modalPhotos = [];
    savingViolation = false;
    violationFormInitial = null;
    window.__gazpromSavingViolation = false;
  }

  function setSaveButtonsBusy(busy, label = 'Сохранение…') {
    const saveBtn = document.getElementById('mvSave');
    const headerSave = document.getElementById('modalHeaderSave');
    if (saveBtn) {
      saveBtn.disabled = busy;
      if (busy) saveBtn.textContent = label;
      else if (saveBtn.dataset.defaultLabel) saveBtn.textContent = saveBtn.dataset.defaultLabel;
    }
    if (headerSave) headerSave.disabled = busy;
  }

  async function finalizePhotoRefs(photos) {
    if (!photos?.length) return [];
    if (typeof PhotoStore?.ingestPhotoRefs === 'function') {
      return PhotoStore.ingestPhotoRefs(photos);
    }
    if (typeof PhotoStore?.ingestPhotoRef !== 'function') return [...photos];
    const out = [];
    for (const p of photos) {
      if (!p) continue;
      if (PhotoStore.isPhotoId(p)) {
        out.push(p);
        continue;
      }
      const result = await PhotoStore.ingestPhotoRef(p);
      if (result?.id) out.push(result.id);
    }
    return out;
  }

  function finishViolationSave(onUpdate) {
    close({ deferRecover: true });
    window.__gazpromSavingViolation = false;
    onUpdate?.();
    requestAnimationFrame(() => {
      GazpromMobileOverlay?.scheduleRecoverViewportLayout?.();
    });
  }

  function init(context) {
    ctx = context;
  }

  /** Одна строка: line-height + padding + border (пустое поле). */
  function getSingleLineTextareaHeight(el) {
    if (!el) return 48;
    const cs = window.getComputedStyle(el);
    const lineHeight = parseFloat(cs.lineHeight);
    const paddingTop = parseFloat(cs.paddingTop) || 0;
    const paddingBottom = parseFloat(cs.paddingBottom) || 0;
    const borderTop = parseFloat(cs.borderTopWidth) || 0;
    const borderBottom = parseFloat(cs.borderBottomWidth) || 0;
    const line = Number.isFinite(lineHeight) ? lineHeight : 24;
    return Math.ceil(line + paddingTop + paddingBottom + borderTop + borderBottom);
  }

  /** Высота под весь текст: сначала одна строка, затем scrollHeight — без обрезки. */
  function autoResize(el) {
    if (!el) return;
    const singleLine = getSingleLineTextareaHeight(el);
    el.style.overflow = 'hidden';
    el.style.overflowY = 'hidden';
    el.style.height = `${singleLine}px`;
    const h = Math.max(el.scrollHeight, singleLine);
    el.style.height = `${h}px`;
  }

  function resizeViolationTextareas() {
    ['mvTitle', 'mvUrl', 'mvFormula'].forEach((id) => {
      autoResize(document.getElementById(id));
    });
  }

  function scheduleViolationTextareaResize() {
    requestAnimationFrame(() => {
      resizeViolationTextareas();
      requestAnimationFrame(() => {
        resizeViolationTextareas();
        GazpromMobileOverlay.syncWizardModalViewport?.();
      });
    });
  }

  function bindAutoResize(el) {
    if (!el) return;
    el.addEventListener('input', () => autoResize(el));
    el.addEventListener('focus', () => {
      autoResize(el);
      if (el.id === 'mvTitle') {
        GazpromMobileOverlay.syncWizardModalViewport?.();
      }
    });
  }

  async function fileToBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const r = reader.result;
        resolve(typeof r === 'string' && r.includes(',') ? r.split(',')[1] : r);
      };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  function objectOptions(objects, selectedTitle) {
    const opts = (objects || [])
      .map(
        (o) =>
          `<option value="${AktUtils.escapeHtml(o.title)}" ${o.title === selectedTitle ? 'selected' : ''}>${AktUtils.escapeHtml(o.title)}${o.subTitle ? ' — ' + AktUtils.escapeHtml(o.subTitle) : ''}</option>`
      )
      .join('');
    return `<option value="">— выберите объект —</option>${opts}`;
  }

  function openViolationEditor(violationId) {
    const draft = ctx.getDraft();
    const catalog = ctx.getCatalog();
    editingViolationId = violationId;
    const v =
      violationId != null
        ? (draft.violations || []).find((x) => x.id === violationId)
        : null;

    modalPhotos = v?.photo ? [...v.photo] : [];

    const registryItems = catalog?.violationRegistry || [];

    // Места нарушений только из текущего акта (другие пункты этого же акта)
    const mestoSuggestions = [
      ...new Set(
        (draft.violations || [])
          .filter((x) => x.id !== violationId)
          .map((x) => x.mesto)
          .filter(Boolean)
      ),
    ];

    function renderMestoSuggestions(query) {
      const q = query.trim().toLowerCase();
      if (!q) return '';
      const items = mestoSuggestions.filter((m) => m.toLowerCase().includes(q));
      if (!items.length) return '';
      return items
        .slice(0, 15)
        .map(
          (m) =>
            `<button type="button" class="mesto-suggestion-item" data-mesto="${AktUtils.escapeHtml(m)}">${AktUtils.escapeHtml(m)}</button>`
        )
        .join('');
    }

    const vidOpts = ViolationTemplates.VIOLATION_TYPES.map(
      (t) =>
        `<option value="${AktUtils.escapeHtml(t)}" ${v?.vid === t ? 'selected' : ''}>${AktUtils.escapeHtml(t)}</option>`
    ).join('');

    function renderRegistryResults(query) {
      const q = query.trim();
      const items = ViolationSearch.filterRegistry(registryItems, q);
      if (!items.length && !q) {
        return `<div class="viol-registry-empty">Реестр нарушений пуст</div>`;
      }
      if (!items.length && q) {
        return `
          <div class="viol-registry-empty">
            Ничего не найдено
            <br>
            <button type="button" class="btn-ghost btn-sm" id="mvAddToRegistry" style="margin-top:10px">
              + Добавить «${AktUtils.escapeHtml(q.slice(0, 60))}» в реестр
            </button>
          </div>`;
      }
      return items
        .map(
          (r, i) => `
          <div class="viol-registry-result-item" data-reg-id="${AktUtils.escapeHtml(r.id)}">
            <span class="vr-result-num">${r.number || i + 1}</span>
            <div class="vr-result-body">
              <div class="vr-result-title">${AktUtils.escapeHtml(r.title)}</div>
              ${r.subTitle ? `<div class="vr-result-sub">📄 ${AktUtils.escapeHtml(r.subTitle)}</div>` : ''}
              ${r.vid ? `<span class="vr-result-vid">${AktUtils.escapeHtml(r.vid)}</span>` : ''}
            </div>
          </div>`
        )
        .join('');
    }

    const body = `
      <div class="form-group mv-mesto-block">
        <label class="form-label">Место нарушения</label>
        <input class="form-control" id="mvMesto"
          value="${AktUtils.escapeHtml(v?.mesto || '')}"
          placeholder="Введите место нарушения…"
          role="combobox"
          aria-expanded="false"
          aria-controls="mvMestoSuggestions"
          aria-autocomplete="list"
          autocomplete="off">
        <div class="mesto-suggestions" id="mvMestoSuggestions" hidden></div>
      </div>

      <div class="mv-search-block form-group">
        <label class="form-label">Нарушение</label>
        <input type="search"
          class="mv-search-block-input"
          id="mvRegistrySearch"
          placeholder="Начните вводить формулировку нарушения…"
          autocomplete="off"
          value="">
        <div class="viol-registry-results" id="mvRegistryResults">
          ${renderRegistryResults('')}
        </div>
      </div>

      <div class="form-group">
        <label class="form-label">Формулировка нарушения <span style="color:var(--danger)">*</span></label>
        <textarea class="form-control mv-auto-textarea" id="mvTitle" rows="1" data-no-capitalize placeholder="Не проведён инструктаж по охране труда…">${AktUtils.escapeHtml(v?.title || '')}</textarea>
      </div>
      <div class="form-group">
        <label class="form-label">Вид нарушения</label>
        <select class="form-control" id="mvVid"><option value="">— не выбрано —</option>${vidOpts}</select>
      </div>
      <div class="form-group">
        <label class="form-label">Пункт / ссылка на правило</label>
        <textarea class="form-control mv-auto-textarea" id="mvUrl" rows="1" data-no-capitalize placeholder="п. 4.1 СП 12-135-2003">${AktUtils.escapeHtml(v?.urlToPravilo || '')}</textarea>
      </div>
      <div class="form-group">
        <label class="form-label">Формулировка из правил</label>
        <textarea class="form-control mv-auto-textarea" id="mvFormula" rows="1" data-no-capitalize placeholder="Согласно п. …">${AktUtils.escapeHtml(v?.formulaFromRules || '')}</textarea>
      </div>
      <div class="form-group">
        <label class="form-label">Фотофиксация</label>
        <input type="file" id="mvPhotoInput" accept="image/*" multiple hidden>
        <div class="photo-grid" id="mvPhotoGrid">${renderModalPhotos()}</div>
      </div>
    `;

    const footer = `
      ${violationId ? '<button type="button" class="btn-ghost modal-btn-danger" id="mvDelete">Удалить</button>' : ''}
      <button type="button" class="btn-primary" id="mvSave">Сохранить</button>
      <button type="button" class="btn-ghost" data-close>Отмена</button>
    `;

    open(violationId ? 'Редактирование нарушения' : 'Новое нарушение', body, footer);
    violationFormInitial = readViolationFormSnapshot();

    // Track the registry item that was last selected to detect manual edits
    let selectedRegistryItem = null;

    function getFormSnapshot() {
      return {
        title:            readFieldRaw('mvTitle'),
        subTitle:         readFieldRaw('mvUrl'),
        vid:              document.getElementById('mvVid')?.value || '',
        formulaFromRules: readFieldRaw('mvFormula'),
      };
    }

    function isModifiedFromRegistry() {
      if (!selectedRegistryItem) return false;
      const s = getFormSnapshot();
      return (
        s.title            !== (selectedRegistryItem.title            || '') ||
        s.subTitle         !== (selectedRegistryItem.subTitle         || '') ||
        s.vid              !== (selectedRegistryItem.vid              || '') ||
        s.formulaFromRules !== (selectedRegistryItem.formulaFromRules || '')
      );
    }

    function updateSaveToRegistryHint() {
      let hint = document.getElementById('mvSaveToRegistryHint');
      if (isModifiedFromRegistry()) {
        if (!hint) {
          hint = document.createElement('div');
          hint.id = 'mvSaveToRegistryHint';
          hint.className = 'mv-save-registry-hint';
          hint.innerHTML = `
            <p class="mv-save-registry-hint-text">Данные отличаются от реестра</p>
            <button type="button" class="btn-ghost btn-sm" id="mvSaveNewToRegistry">+ Сохранить как новое нарушение в реестр</button>
          `;
          const modalBody = document.getElementById('modalBody');
          modalBody?.appendChild(hint);
          document.getElementById('mvSaveNewToRegistry')?.addEventListener('click', saveCurrentToRegistry);
        }
      } else {
        hint?.remove();
      }
    }

    async function saveCurrentToRegistry() {
      const s = getFormSnapshot();
      if (!s.title) { GazpromToast.error('Заполните формулировку нарушения'); return; }
      await ViolationRegistry.addItem(s);
      GazpromToast.success('Сохранено в реестр нарушений');
      selectedRegistryItem = null;
      document.getElementById('mvSaveToRegistryHint')?.remove();
      await ctx.reloadCatalog();
    }

    function bindFieldChangeWatchers() {
      ['mvTitle', 'mvUrl', 'mvVid', 'mvFormula'].forEach((id) => {
        document.getElementById(id)?.addEventListener('input', updateSaveToRegistryHint);
        document.getElementById(id)?.addEventListener('change', updateSaveToRegistryHint);
      });
    }

    const mestoInput = document.getElementById('mvMesto');
    const mestoList = document.getElementById('mvMestoSuggestions');
    let mestoTimer = null;

    function showMestoSuggestions() {
      if (!mestoInput || !mestoList) return;
      mestoList.hidden = false;
      mestoInput.setAttribute('aria-expanded', 'true');
    }

    function hideMestoSuggestions() {
      if (!mestoInput || !mestoList) return;
      mestoList.hidden = true;
      mestoInput.setAttribute('aria-expanded', 'false');
    }

    function refreshMestoSuggestions() {
      if (!mestoInput || !mestoList) return;
      const html = renderMestoSuggestions(mestoInput.value);
      if (!html) {
        mestoList.innerHTML = '';
        hideMestoSuggestions();
        return;
      }
      mestoList.innerHTML = html;
      bindMestoSuggestionClicks();
      showMestoSuggestions();
    }

    function bindMestoSuggestionClicks() {
      mestoList?.querySelectorAll('.mesto-suggestion-item').forEach((btn) => {
        btn.addEventListener('mousedown', (e) => e.preventDefault());
        btn.addEventListener('click', () => {
          if (mestoInput) mestoInput.value = btn.dataset.mesto || '';
          hideMestoSuggestions();
        });
      });
    }

    if (mestoInput && mestoList) {
      mestoInput.addEventListener('input', () => {
        clearTimeout(mestoTimer);
        mestoTimer = setTimeout(refreshMestoSuggestions, 120);
      });
      mestoInput.addEventListener('blur', () => {
        setTimeout(hideMestoSuggestions, 150);
      });
    }

    // Registry search
    let searchTimer = null;
    document.getElementById('mvRegistrySearch')?.addEventListener('input', (e) => {
      clearTimeout(searchTimer);
      searchTimer = setTimeout(() => {
        const results = document.getElementById('mvRegistryResults');
        if (results) results.innerHTML = renderRegistryResults(e.target.value);
        bindRegistryResultClicks();
        bindAddToRegistry();
      }, 200);
    });

    function bindRegistryResultClicks() {
      document.querySelectorAll('#mvRegistryResults .viol-registry-result-item').forEach((el) => {
        el.addEventListener('click', () => {
          const item = registryItems.find((r) => r.id === el.dataset.regId);
          if (!item) return;

          if (document.activeElement instanceof HTMLElement) {
            document.activeElement.blur();
          }

          const titleEl   = document.getElementById('mvTitle');
          const urlEl     = document.getElementById('mvUrl');
          const formulaEl = document.getElementById('mvFormula');
          if (titleEl)   titleEl.value   = item.title            || '';
          if (urlEl)     urlEl.value     = item.subTitle         || '';
          document.getElementById('mvVid').value = item.vid || '';
          if (formulaEl) formulaEl.value = item.formulaFromRules || '';

          // Store snapshot for change detection
          selectedRegistryItem = { ...item };

          document.querySelectorAll('#mvRegistryResults .viol-registry-result-item').forEach((x) =>
            x.classList.remove('selected')
          );
          el.classList.add('selected');

          // Remove the hint since values now match registry
          document.getElementById('mvSaveToRegistryHint')?.remove();

          // Clear search and show full list again
          const searchEl = document.getElementById('mvRegistrySearch');
          if (searchEl) searchEl.value = '';
          const results = document.getElementById('mvRegistryResults');
          if (results) results.innerHTML = renderRegistryResults('');
          bindRegistryResultClicks();
          scheduleViolationTextareaResize();
        });
      });
    }

    function bindAddToRegistry() {
      document.getElementById('mvAddToRegistry')?.addEventListener('click', () => {
        const q = document.getElementById('mvRegistrySearch')?.value?.trim() || '';
        openAddToRegistryForm(q, renderRegistryResults, bindRegistryResultClicks);
      });
    }

    bindRegistryResultClicks();
    bindAddToRegistry();
    bindFieldChangeWatchers();

    // Bind input listeners
    ['mvTitle', 'mvUrl', 'mvFormula'].forEach((id) => {
      bindAutoResize(document.getElementById(id));
    });

    // After layout — resize all textareas to fit pre-filled content
    setTimeout(scheduleViolationTextareaResize, 50);

    document.getElementById('mvSave')?.addEventListener('click', saveViolation);
    document.getElementById('mvDelete')?.addEventListener('click', deleteViolation);
    document.getElementById('mvPhotoInput')?.addEventListener('change', onPhotoPick);
    bindModalPhotoClicks();
    hydrateModalPhotoThumbs();
  }

  function renderModalPhotos() {
    const thumbs = modalPhotos
      .map(
        (p, i) => `
      <div class="photo-slot filled wizard-photo-thumb mv-photo-item" data-pidx="${i}">
        <img src="" data-photo-idx="${i}" alt="">
        <button type="button" class="photo-remove" data-rm="${i}">×</button>
      </div>`
      )
      .join('');
    // Always append the "add" slot at the end
    const addSlot = `<div class="photo-slot wizard-photo-add mv-photo-add-slot" title="Добавить фото">+</div>`;
    return thumbs + addSlot;
  }

  function bindModalPhotoClicks() {
    document.querySelectorAll('#mvPhotoGrid .photo-remove').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        modalPhotos.splice(parseInt(btn.dataset.rm, 10), 1);
        document.getElementById('mvPhotoGrid').innerHTML = renderModalPhotos();
        bindModalPhotoClicks();
        hydrateModalPhotoThumbs();
      });
    });
    document.querySelectorAll('#mvPhotoGrid .mv-photo-item').forEach((el) => {
      el.addEventListener('click', (e) => {
        if (e.target.classList.contains('photo-remove')) return;
        const i = parseInt(el.dataset.pidx, 10);
        if (modalPhotos[i]) {
          Promise.all(modalPhotos.map((p) => AktUtils.photoSrcAsync(p))).then((urls) => {
            const g = urls.filter(Boolean);
            if (g.length) ctx.openLightbox(g[i], g);
          });
        }
      });
    });
    document.querySelector('#mvPhotoGrid .mv-photo-add-slot')?.addEventListener('click', () => {
      document.getElementById('mvPhotoInput')?.click();
    });
  }

  async function onPhotoPick(e) {
    const files = [...(e.target.files || [])];
    const maxInputBytes = 40 * 1024 * 1024;
    for (const file of files) {
      if (!file.type.startsWith('image/')) continue;
      if (file.size > maxInputBytes) {
        GazpromToast.error(`Файл ${file.name} слишком большой (макс. 40 МБ)`);
        continue;
      }
      try {
        if (file.size > 2 * 1024 * 1024) {
          GazpromToast.show('Сжимаем фото…', 'info', 2000);
        }
        const b64 =
          typeof PhotoStore?.fileToViolationBase64 === 'function'
            ? await PhotoStore.fileToViolationBase64(file)
            : await fileToBase64(file);
        if (!b64) continue;
        if (typeof PhotoStore?.ingestPhotoRef === 'function') {
          const result = await PhotoStore.ingestPhotoRef(b64);
          if (result?.id) modalPhotos.push(result.id);
          else GazpromToast.error(`Не удалось сохранить фото ${file.name}`);
        } else {
          modalPhotos.push(b64);
        }
      } catch {
        GazpromToast.error(`Не удалось обработать ${file.name}`);
      }
    }
    document.getElementById('mvPhotoGrid').innerHTML = renderModalPhotos();
    bindModalPhotoClicks();
    hydrateModalPhotoThumbs();
    e.target.value = '';
  }

  async function hydrateModalPhotoThumbs() {
    document.querySelectorAll('#mvPhotoGrid img[data-photo-idx]').forEach(async (img) => {
      const i = parseInt(img.dataset.photoIdx, 10);
      const src = await AktUtils.photoSrcAsync(modalPhotos[i]);
      if (src) img.src = src;
    });
  }

  async function saveViolation() {
    if (savingViolation) {
      GazpromToast.info('Сохранение уже выполняется…');
      return;
    }

    const title = readFieldRaw('mvTitle');
    if (isBlankText(title)) {
      GazpromToast.error('Укажите формулировку нарушения');
      return;
    }

    const saveBtn = document.getElementById('mvSave');
    if (saveBtn && !saveBtn.dataset.defaultLabel) {
      saveBtn.dataset.defaultLabel = saveBtn.textContent || 'Сохранить';
    }

    savingViolation = true;
    window.__gazpromSavingViolation = true;
    setSaveButtonsBusy(true);

    const violationId = editingViolationId || AktUtils.uuid();
    const prevCount = (ctx.getDraft()?.violations || []).length;
    const wasEditing = !!editingViolationId;

    try {
      await withSaveTimeout((async () => {
        const mesto = readFieldRaw('mvMesto');
        const vid = document.getElementById('mvVid')?.value || '';
        const urlToPravilo = readFieldRaw('mvUrl');
        const formulaRaw = readFieldRaw('mvFormula');
        const formulaFromRules = formulaRaw !== '' ? formulaRaw : null;

        const photoRefs = await finalizePhotoRefs(modalPhotos);

        const draft = ctx.getDraft();
        if (!draft) throw new Error('Черновик акта недоступен');

        const payload = {
          id: violationId,
          title,
          mesto,
          urlToPravilo,
          photo: photoRefs,
          vid,
          formulaFromRules: formulaFromRules || null,
        };

        if (editingViolationId) {
          draft.violations = (draft.violations || []).map((x) =>
            x.id === editingViolationId ? payload : x
          );
        } else {
          draft.violations = [...(draft.violations || []), payload];
        }

        ctx.setDraft(draft);
        await ctx.saveDraft();

        const saved = (ctx.getDraft()?.violations || []).find((x) => x.id === violationId);
        if (!saved) {
          throw new Error('Нарушение не записалось в черновик');
        }
        if (!editingViolationId && (ctx.getDraft()?.violations || []).length <= prevCount) {
          throw new Error('Нарушение не добавилось в список');
        }
      })());

      const onUpdate = ctx.onUpdate;
      finishViolationSave(onUpdate);
      GazpromToast.success(wasEditing ? 'Нарушение сохранено' : 'Нарушение добавлено');
    } catch (err) {
      console.error(err);
      GazpromToast.error(
        err?.message || 'Не удалось сохранить нарушение. Попробуйте ещё раз.'
      );
    } finally {
      if (document.getElementById('wizardModalRoot')?.classList.contains('show')) {
        savingViolation = false;
        window.__gazpromSavingViolation = false;
        setSaveButtonsBusy(false);
      }
    }
  }

  function deleteViolation() {
    if (!editingViolationId) return;
    GazpromToast.confirm('Удалить это нарушение?').then((ok) => {
      if (!ok) return;
      doDeleteViolation();
    });
    return;
  }

  async function doDeleteViolation() {
    try {
      const draft = ctx.getDraft();
      draft.violations = (draft.violations || []).filter((x) => x.id !== editingViolationId);
      ctx.setDraft(draft);
      await ctx.saveDraft();
      finishViolationSave(ctx.onUpdate);
    } catch (err) {
      console.error(err);
      GazpromToast.error(err?.message || 'Не удалось удалить нарушение');
    }
  }

  function openQuickAdd(type) {
    const forms = {
      org: {
        title: 'Новая организация',
        html: `
          <div class="form-group"><label>Наименование</label><input class="form-control" id="qaTitle" placeholder="Например: ООО «Газпром трансгаз»"></div>
          <div class="form-group"><label>Краткое название</label><input class="form-control" id="qaSub" placeholder="Например: КДТГ"></div>
        `,
        save: async () => {
          const title = document.getElementById('qaTitle')?.value?.trim();
          if (!title) { GazpromToast.error('Укажите наименование'); return; }
          const sub = document.getElementById('qaSub')?.value?.trim();
          return CatalogService.addOrganization(title, sub);
        },
      },
      object: {
        title: 'Новый объект',
        html: `
          <div class="form-group"><label>Название объекта</label><input class="form-control" id="qaTitle" placeholder="Например: КС Краснодарская"></div>
          <div class="form-group"><label>Адрес / примечание</label><input class="form-control" id="qaSub" placeholder="Например: ул. Ленина, 1"></div>
        `,
        save: async () => {
          const title = document.getElementById('qaTitle')?.value?.trim();
          if (!title) { GazpromToast.error('Укажите название'); return; }
          const sub = document.getElementById('qaSub')?.value?.trim();
          return CatalogService.addObject(title, sub);
        },
      },
      commission: {
        title: 'Новый член комиссии',
        html: `
          <div class="form-group"><label>ФИО</label><input class="form-control" id="qaTitle" placeholder="Например: Иванов Иван Иванович"></div>
          <div class="form-group"><label>Должность</label><input class="form-control" id="qaSub" placeholder="Например: Начальник участка"></div>
        `,
        save: async () => {
          const fio = document.getElementById('qaTitle')?.value?.trim();
          if (!fio) { GazpromToast.error('Укажите ФИО'); return; }
          const job = document.getElementById('qaSub')?.value?.trim();
          return CatalogService.addCommissionPerson(fio, job);
        },
      },
      pred: {
        title: 'Новый представитель',
        html: `
          <div class="form-group"><label>ФИО</label><input class="form-control" id="qaTitle" placeholder="Например: Петров Пётр Петрович"></div>
          <div class="form-group"><label>Должность</label><input class="form-control" id="qaSub" placeholder="Например: Главный инженер"></div>
          <div class="form-group"><label>Организация</label><input class="form-control" id="qaOrg" value="${AktUtils.escapeHtml(ctx.getDraft().organization?.title || '')}"></div>
        `,
        save: async () => {
          const fio = document.getElementById('qaTitle')?.value?.trim();
          if (!fio) { GazpromToast.error('Укажите ФИО'); return; }
          const job = document.getElementById('qaSub')?.value?.trim();
          const org = document.getElementById('qaOrg')?.value?.trim();
          return CatalogService.addPredstavitely(fio, job, org);
        },
      },
    };

    const f = forms[type];
    if (!f) return;

    open(
      f.title,
      f.html,
      `<button type="button" class="btn-ghost" data-close>Отмена</button>
       <button type="button" class="btn-primary" id="qaSave">Добавить</button>`
    );

    document.getElementById('qaSave')?.addEventListener('click', async () => {
      const item = await f.save();
      if (!item) return;
      await ctx.reloadCatalog();
      close();
      ctx.onQuickAdd(type, item);
    });
  }

  function openAddToRegistryForm(prefillTitle, renderRegistryResults, bindRegistryResultClicks) {
    const catalog = ctx.getCatalog();
    const registryItems = catalog?.violationRegistry || [];
    const maxNum = Math.max(0, ...registryItems.map((x) => x.number || 0));
    const nextNum = maxNum + 1;

    // Unique subTitle values for datalist autocomplete
    const uniqueSubTitles = [...new Set(registryItems.map((x) => x.subTitle).filter(Boolean))];
    const subTitleDatalist = uniqueSubTitles
      .map((s) => `<option value="${AktUtils.escapeHtml(s)}">`)
      .join('');

    const vidOpts = ViolationTemplates.VIOLATION_TYPES.map(
      (t) => `<option value="${AktUtils.escapeHtml(t)}">${AktUtils.escapeHtml(t)}</option>`
    ).join('');

    // Registry items for the rule picker — unique subTitle entries, show only пункт правила
    const seenSubTitles = new Set();
    const rulePickerItems = registryItems
      .filter((r) => r.subTitle && !seenSubTitles.has(r.subTitle) && seenSubTitles.add(r.subTitle))
      .map(
        (r) => `
        <div class="arv-rule-pick-item"
          data-rule-subtitle="${AktUtils.escapeHtml(r.subTitle || '')}"
          data-rule-formula="${AktUtils.escapeHtml(r.formulaFromRules || '')}"
          data-rule-vid="${AktUtils.escapeHtml(r.vid || '')}">
          <div class="arv-rule-sub">📄 ${AktUtils.escapeHtml(r.subTitle)}</div>
          ${r.formulaFromRules ? `<div class="arv-rule-formula">${AktUtils.escapeHtml(r.formulaFromRules.slice(0, 80))}${r.formulaFromRules.length > 80 ? '…' : ''}</div>` : ''}
        </div>`
      )
      .join('');

    const overlay = document.createElement('div');
    overlay.className = 'vr-form-overlay';
    overlay.innerHTML = `
      <div class="vr-form-dialog card">
        <h3>Добавить нарушение в реестр</h3>

        <div class="form-group">
          <label class="form-label">Номер нарушения</label>
          <input class="form-control" id="arvNumber" type="number" min="1" value="${nextNum}" style="max-width:120px">
        </div>

        <div class="form-group">
          <label class="form-label">Формулировка нарушения <span style="color:var(--danger)">*</span></label>
          <textarea class="form-control" id="arvTitle" rows="3"
            placeholder="Не проведён инструктаж по охране труда…">${AktUtils.escapeHtml(prefillTitle)}</textarea>
        </div>

        <div class="form-group">
          <label class="form-label">Пункт / ссылка на правило</label>
          <input class="form-control" id="arvSubTitle" list="arvSubTitleList"
            placeholder="п. 4.1 СП 12-135-2003" autocomplete="off" data-no-capitalize>
          <datalist id="arvSubTitleList">${subTitleDatalist}</datalist>
          ${rulePickerItems ? `
          <button type="button" class="btn-ghost btn-sm arv-pick-btn" id="arvPickRule"
            style="margin-top:6px;width:100%;text-align:left;">
            📋 Выбрать из реестра
          </button>
          <div id="arvRulePicker" hidden class="arv-rule-picker">
            <input type="search" class="form-control arv-rule-search" placeholder="Поиск по пункту правила…"
              style="margin-bottom:6px" autocomplete="off">
            <div class="arv-rule-picker-list">${rulePickerItems}</div>
          </div>` : ''}
        </div>

        <div class="form-group">
          <label class="form-label">Формулировка из правил</label>
          <textarea class="form-control" id="arvFormulaFromRules" rows="2"
            placeholder="Согласно п. …"></textarea>
        </div>

        <div class="form-group">
          <label class="form-label">Примечание</label>
          <input class="form-control" id="arvDescription" placeholder="Доп. информация">
        </div>

        <div class="form-group">
          <label class="form-label">Вид нарушения</label>
          <select class="form-control" id="arvVid">
            <option value="">— не выбрано —</option>
            ${vidOpts}
          </select>
        </div>

        <div class="catalog-form-actions">
          <button type="button" class="btn-ghost" id="arvCancel">Отмена</button>
          <button type="button" class="btn-primary" id="arvSave">Добавить в реестр</button>
        </div>
      </div>
    `;
    document.body.appendChild(overlay);

    // Auto-resize textareas to fit content while keeping manual resize
    function autoResize(el) {
      el.style.height = 'auto';
      el.style.height = el.scrollHeight + 'px';
    }
    overlay.querySelectorAll('textarea').forEach((ta) => {
      ta.style.resize = 'vertical';
      ta.style.overflow = 'hidden';
      autoResize(ta);
      ta.addEventListener('input', () => autoResize(ta));
    });

    setTimeout(() => overlay.querySelector('#arvTitle')?.focus(), 50);

    const remove = () => overlay.remove();
    overlay.querySelector('#arvCancel').onclick = remove;
    overlay.addEventListener('keydown', (e) => { if (e.key === 'Escape') remove(); });

    // Toggle rule picker visibility
    overlay.querySelector('#arvPickRule')?.addEventListener('click', () => {
      const picker = overlay.querySelector('#arvRulePicker');
      if (picker) {
        picker.hidden = !picker.hidden;
        if (!picker.hidden) picker.querySelector('.arv-rule-search')?.focus();
      }
    });

    // Filter rule picker list on search input
    overlay.querySelector('.arv-rule-search')?.addEventListener('input', (e) => {
      const q = e.target.value.toLowerCase();
      overlay.querySelectorAll('.arv-rule-pick-item').forEach((el) => {
        const text = el.textContent.toLowerCase();
        el.hidden = q ? !text.includes(q) : false;
      });
    });

    // Select rule from picker — fills subTitle and formulaFromRules fields
    overlay.querySelectorAll('.arv-rule-pick-item').forEach((el) => {
      el.addEventListener('click', () => {
        const subTitleInput = overlay.querySelector('#arvSubTitle');
        if (subTitleInput) subTitleInput.value = el.dataset.ruleSubtitle || '';
        const formulaInput = overlay.querySelector('#arvFormulaFromRules');
        if (formulaInput && el.dataset.ruleFormula) {
          formulaInput.value = el.dataset.ruleFormula;
          autoResize(formulaInput);
        }
        const vidSelect = overlay.querySelector('#arvVid');
        if (vidSelect && el.dataset.ruleVid) vidSelect.value = el.dataset.ruleVid;
        const picker = overlay.querySelector('#arvRulePicker');
        if (picker) picker.hidden = true;
      });
    });

    // Save to registry
    overlay.querySelector('#arvSave').onclick = async () => {
      const title = overlay.querySelector('#arvTitle')?.value?.trim();
      if (!title) { GazpromToast.error('Укажите формулировку нарушения'); return; }

      const number = parseInt(overlay.querySelector('#arvNumber')?.value, 10) || nextNum;
      const subTitle = overlay.querySelector('#arvSubTitle')?.value?.trim() || '';
      const formulaFromRules = overlay.querySelector('#arvFormulaFromRules')?.value?.trim() || '';
      const description = overlay.querySelector('#arvDescription')?.value?.trim() || '';
      const vid = overlay.querySelector('#arvVid')?.value || '';

      await ViolationRegistry.addItem({ number, title, subTitle, formulaFromRules, description, vid });
      GazpromToast.success('Добавлено в реестр нарушений');
      remove();

      await ctx.reloadCatalog();

      // Pre-fill violation title field if it's empty
      const titleEl = document.getElementById('mvTitle');
      if (titleEl && !titleEl.value) {
        titleEl.value = title;
        scheduleViolationTextareaResize();
      }

      // Clear search and refresh registry results in violation editor
      const searchEl = document.getElementById('mvRegistrySearch');
      if (searchEl) searchEl.value = '';
      const results = document.getElementById('mvRegistryResults');
      if (results && renderRegistryResults && bindRegistryResultClicks) {
        results.innerHTML = renderRegistryResults('');
        bindRegistryResultClicks();
      }
    };
  }

  return { init, open, close, openViolationEditor, openQuickAdd, isSavingViolation };
})();
