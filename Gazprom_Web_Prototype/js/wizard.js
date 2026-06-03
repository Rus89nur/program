/**
 * Мастер «Редактируемый акт» — редактирование черновика из бэкапа.
 */
const WizardController = (() => {
  const TOTAL_STEPS = 6;
  let catalog = null;
  let draft = null;
  let step = 0;
  let autosaveTimer = null;
  let dirty = false;
  let descEditMode = false;
  let predOrgFilters = new Set();

  const panelsHost = () => document.getElementById('wizardPanels');
  const emptyEl = () => document.getElementById('wizardEmpty');

  async function loadCatalog() {
    catalog = await GazpromStore.get();
  }

  async function reloadCatalog() {
    GazpromStore.invalidateCache();
    await loadCatalog();
  }

  function setupModals() {
    WizardModals.init({
      getDraft: () => draft,
      setDraft: (d) => {
        draft = d;
      },
      getCatalog: () => catalog,
      reloadCatalog,
      openLightbox,
      saveDraft,
      onUpdate: () => {
        render();
        updateSummary();
      },
      onQuickAdd: (type, item) => {
        if (type === 'org') {
          draft.organization = { ...item };
        }
        if (type === 'object') {
          normalizeObjectsCheck();
          draft.objectsCheck = [{ ...item }];
        }
        if (type === 'commission') {
          draft.comission = [...(draft.comission || []), { ...item }];
        }
        if (type === 'pred') {
          if (!(draft.predstavitelyComission || []).some((x) => x.id === item.id)) {
            draft.predstavitelyComission = [...(draft.predstavitelyComission || []), { ...item }];
          }
        }
        render();
        updateSummary();
      },
    });
  }

  function initDraft() {
    const editable = AktUtils.getFullEditableAkt(catalog);
    draft = editable ? AktUtils.clone(editable) : AktUtils.createEmptyDraft(catalog);
  }

  function showEmpty(show) {
    const e = emptyEl();
    const root = document.getElementById('wizardRoot');
    if (e) e.hidden = !show;
    if (root) root.hidden = show;
  }

  function scheduleAutosave() {
    dirty = true;
    updateDirtyIndicator();
    clearTimeout(autosaveTimer);
    autosaveTimer = setTimeout(async () => {
      commitStep(step);
      await saveDraft();
      dirty = false;
      updateDirtyIndicator();
    }, 2000);
  }

  function updateDirtyIndicator() {
    const el = document.getElementById('wizardDirtyBadge');
    if (el) el.hidden = !dirty;
  }

  function resetAutosaveTimer() {
    clearTimeout(autosaveTimer);
    autosaveTimer = null;
    dirty = false;
    updateDirtyIndicator();
  }

  async function startNewDraft() {
    resetAutosaveTimer();
    if (draft) {
      commitStep(step);
      await saveDraft();
      await GazpromStore.persistCatalog(catalog);
    } else {
      const prevFull = AktUtils.getFullEditableAkt(catalog);
      if (prevFull) {
        draft = AktUtils.clone(prevFull);
        await saveDraft();
        await GazpromStore.persistCatalog(catalog);
      }
    }
    draft = AktUtils.createEmptyDraft(catalog);
    step = 0;
    descEditMode = false;
    predOrgFilters = new Set();
    await saveDraft();
    render();
    updateSummary();
    bindAutosaveOnPanel();
  }

  async function open(aktId = null, options = {}) {
    const preserveStep = options.preserveStep === true;
    const preserveDraft = options.preserveDraft === true;
    const forceNew = options.forceNew === true;
    const savedStep = step;
    await loadCatalog();
    showEmpty(false);
    setupModals();
    if (forceNew) {
      await startNewDraft();
      return;
    }
    if (!preserveDraft) {
      if (aktId) {
        const akt = (catalog.akts || []).find((a) => a.id === aktId);
        if (!akt) {
          GazpromToast.error('Акт не найден');
          return;
        }
        if (AktUtils.isShortFormat(akt)) {
          ShortAktForm.open(aktId);
          return;
        }
        draft = AktUtils.clone(akt);
        AktUtils.applyCurrentEditable(catalog, draft);
        await CatalogService.rememberLastOpenedAkt(draft);
      } else {
        initDraft();
      }
      normalizeObjectsCheck();
    }
    step = aktId ? 0 : (preserveStep ? Math.min(savedStep, TOTAL_STEPS - 1) : 0);
    if (!preserveDraft) dirty = false;
    render();
    updateSummary();
    bindAutosaveOnPanel();
  }

  function openWithAkt(aktId) {
    return open(aktId);
  }

  function setStep(newStep) {
    commitStep(step);
    descEditMode = false;
    predOrgFilters = new Set();
    step = Math.max(0, Math.min(TOTAL_STEPS - 1, newStep));
    if (step === 2) normalizeObjectsCheck();
    syncStepperUI();
    render();
    updateSummary();
  }

  function syncStepperUI() {
    document.querySelectorAll('#wizardStepper .wizard-step').forEach((el) => {
      const n = parseInt(el.dataset.step, 10);
      el.classList.remove('current', 'done');
      if (n < step) el.classList.add('done');
      if (n === step) el.classList.add('current');
    });
    document.querySelectorAll('#wizardStepper .wizard-connector').forEach((el, i) => {
      el.classList.toggle('done', i < step);
    });
    const prev = document.getElementById('wizardPrev');
    const next = document.getElementById('wizardNext');
    if (prev) prev.style.visibility = step === 0 ? 'hidden' : 'visible';
    if (next) {
      next.textContent = step === TOTAL_STEPS - 1 ? '💾 Сохранить черновик' : 'Далее →';
    }
  }

  function render() {
    syncStepperUI();
    const host = panelsHost();
    if (!host || !draft) return;
    if (step === 2) normalizeObjectsCheck();

    const renderers = [
      renderStepDateCommission,
      renderStepOrganization,
      renderStepObjects,
      renderStepViolations,
      renderStepDescription,
      renderStepGenerate,
    ];
    try {
      const html = renderers[step]();
      host.innerHTML = `<div class="card wizard-panel-active">${html}</div>`;
    } catch (err) {
      console.error(err);
      host.innerHTML = `<div class="card wizard-panel-active"><p style="color:red">Ошибка отрисовки: ${err}</p></div>`;
    }
    bindPanelEvents();
    bindAutosaveOnPanel();
    hydrateViolationThumbs();
  }

  function bindAutosaveOnPanel() {
    panelsHost()?.querySelectorAll('input, select, textarea').forEach((el) => {
      el.removeEventListener('input', scheduleAutosave);
      el.removeEventListener('change', scheduleAutosave);
      el.addEventListener('input', scheduleAutosave);
      el.addEventListener('change', scheduleAutosave);
    });
  }

  async function hydrateViolationThumbs() {
    panelsHost()?.querySelectorAll('img[data-photo-ref]').forEach(async (img) => {
      const ref = img.dataset.photoRef;
      img.src = (await PhotoStore.resolveDataUrl(ref)) || AktUtils.photoSrc(ref);
    });
  }

  function numberOptions() {
    const draftYear = draft.date ? new Date(draft.date).getFullYear() : new Date().getFullYear();
    const occupied = AktUtils.occupiedNumbers(catalog.akts, draft.id, draftYear);
    const current = parseInt(draft.number, 10) || 1;
    const maxNum = Math.max(70, current, ...[...occupied].map((s) => parseInt(s, 10) || 0));
    const nums = [];
    for (let n = 1; n <= maxNum; n++) {
      if (!occupied.has(String(n)) || n === current) nums.push(n);
    }
    return nums;
  }

  function renderStepDateCommission() {
    const people = catalog.comissionPeople || [];
    const selectedIds = new Set((draft.comission || []).map((p) => p.id));

    const chips = (draft.comission || [])
      .map(
        (p) =>
          `<span class="chip chip-removable" draggable="true" data-remove-person="${p.id}" data-person-id="${p.id}" title="Удерживайте для перетаскивания, нажмите чтобы убрать">${AktUtils.escapeHtml(p.fio)}${p.jobTitle ? ' — ' + AktUtils.escapeHtml(p.jobTitle) : ''}</span>`
      )
      .join('');

    const catalogChips = people
      .filter((p) => !selectedIds.has(p.id))
      .map(
        (p) =>
          `<span class="chip chip-catalog" data-add-person="${p.id}" title="Нажмите, чтобы добавить">${AktUtils.escapeHtml(p.fio)}${p.jobTitle ? ' — ' + AktUtils.escapeHtml(p.jobTitle) : ''}</span>`
      )
      .join('');

    const numOpts = numberOptions()
      .map(
        (n) =>
          `<option value="${n}" ${String(draft.number) === String(n) ? 'selected' : ''}>${n}</option>`
      )
      .join('');

    return `
      <h3>Дата проверки и номер акта</h3>
      <div class="form-row">
        <div class="form-group">
          <label>Дата проверки</label>
          <input class="form-control" type="date" id="wDate" value="${AktUtils.toDateInputValue(draft.date)}">
        </div>
        <div class="form-group">
          <label>Номер акта</label>
          <select class="form-control" id="wNumber" size="1">${numOpts}</select>
        </div>
      </div>
      <h3 style="margin-top:8px;">Состав комиссии</h3>
      <div class="chip-list" id="wCommissionChips">${chips || '<span class="wizard-hint">Добавьте членов комиссии</span>'}</div>
      <div class="commission-divider"></div>
      <div class="commission-catalog-section">
        <div class="commission-catalog-header">
          <span class="commission-catalog-label">Выбрать из справочника</span>
          <button type="button" class="btn-ghost" id="wNewPersonBtn">+ Добавить в справочник</button>
        </div>
        <div class="chip-list">${catalogChips || '<span class="wizard-hint">Все из справочника уже добавлены</span>'}</div>
      </div>
    `;
  }

  function renderStepOrganization() {
    const orgs = catalog.organizations || [];
    const selected = draft.organization;
    const selectedId = selected?.id;

    const selectedChip = selected?.title
      ? `<span class="chip chip-removable" data-clear-org title="Нажмите, чтобы убрать">${AktUtils.escapeHtml(selected.title)}${selected.shortTitle ? ' — ' + AktUtils.escapeHtml(selected.shortTitle) : ''}</span>`
      : '';

    const catalogChips = orgs
      .filter((o) => o.id !== selectedId)
      .map(
        (o) =>
          `<span class="chip chip-catalog" data-select-org="${o.id}" title="Нажмите, чтобы выбрать">${AktUtils.escapeHtml(o.title)}${o.shortTitle ? ' — ' + AktUtils.escapeHtml(o.shortTitle) : ''}</span>`
      )
      .join('');

    const catalogBlock = orgs.length
      ? `<div class="chip-list">${catalogChips || '<span class="wizard-hint">Все из справочника уже выбраны</span>'}</div>`
      : '<p class="wizard-hint">В бэкапе нет организаций — добавьте через кнопку справа.</p>';

    return `
      <h3>Организация проверки</h3>
      <p class="wizard-hint">Выберите одну организацию (как в iOS-приложении)</p>
      <div class="chip-list" id="wOrgChips">${selectedChip || '<span class="wizard-hint">Выберите организацию из справочника</span>'}</div>
      <div class="commission-divider"></div>
      <div class="commission-catalog-section">
        <div class="commission-catalog-header">
          <span class="commission-catalog-label">Выбрать из справочника</span>
          <button type="button" class="btn-ghost" id="wNewOrgBtn">+ Добавить в справочник</button>
        </div>
        ${catalogBlock}
      </div>
    `;
  }

  function normalizeObjectsCheck() {
    const list = draft.objectsCheck || [];
    draft.objectsCheck = list.length ? list.slice(0, 1) : [];
  }

  function renderStepObjects() {
    normalizeObjectsCheck();
    const objects = catalog.objects || [];
    const selected = (draft.objectsCheck || [])[0];
    const selectedId = selected?.id;

    const objectViolCount = (o) =>
      (draft.violations || []).filter((v) => v.mesto === o.title || v.mesto === o.subTitle).length;

    const selectedViolHint =
      selected && objectViolCount(selected) > 0 ? ` · ${objectViolCount(selected)} наруш.` : '';
    const selectedChip = selected?.title
      ? `<span class="chip chip-removable" data-clear-object title="Нажмите, чтобы убрать">${AktUtils.escapeHtml(selected.title)}${selected.subTitle ? ' — ' + AktUtils.escapeHtml(selected.subTitle) : ''}${selectedViolHint}</span>`
      : '';

    const catalogChips = objects
      .filter((o) => o.id !== selectedId)
      .map((o) => {
        const violCount = objectViolCount(o);
        const violHint = violCount > 0 ? ` · ${violCount} наруш.` : '';
        return `<span class="chip chip-catalog" data-select-object="${o.id}" title="Нажмите, чтобы выбрать">${AktUtils.escapeHtml(o.title)}${o.subTitle ? ' — ' + AktUtils.escapeHtml(o.subTitle) : ''}${violHint}</span>`;
      })
      .join('');

    const catalogBlock = objects.length
      ? `<div class="chip-list">${catalogChips || '<span class="wizard-hint">Все из справочника уже выбраны</span>'}</div>`
      : '<p class="wizard-hint">Справочник объектов пуст — добавьте через кнопку справа.</p>';

    return `
      <h3>Объект проверки</h3>
      <p class="wizard-hint">Выберите объект проверки (как в iOS-приложении)</p>
      <div class="chip-list" id="wObjectChips">${selectedChip || '<span class="wizard-hint">Выберите объект из справочника</span>'}</div>
      <div class="commission-divider"></div>
      <div class="commission-catalog-section">
        <div class="commission-catalog-header">
          <span class="commission-catalog-label">Выбрать из справочника</span>
          <button type="button" class="btn-ghost" id="wNewObjBtn">+ Новый объект</button>
        </div>
        ${catalogBlock}
      </div>
    `;
  }

  function renderStepViolations() {
    const allViolations = draft.violations || [];

    const cards = allViolations.length
      ? allViolations
          .map((v, i) => {
            const photos = v.photo?.length || 0;
            const vidBadge = v.vid
              ? `<span class="viol-card-badge" title="${AktUtils.escapeHtml(v.vid)}">${AktUtils.escapeHtml(v.vid)}</span>`
              : '';
            const refLine = v.urlToPravilo
              ? `<div class="viol-card-subtitle">📄 ${AktUtils.escapeHtml(v.urlToPravilo)}</div>`
              : '';
            const maxThumbs = 5;
            const thumbsHtml = photos
              ? `<div class="viol-card-thumbs">
                  ${(v.photo || []).slice(0, maxThumbs).map((p, idx) =>
                    `<div class="viol-card-thumb wizard-photo-thumb photo-slot filled" data-vid="${v.id}" data-pidx="${idx}">
                      <img src="${AktUtils.photoSrc(p)}" alt="">
                    </div>`
                  ).join('')}
                  ${photos > maxThumbs ? `<div class="viol-card-thumb viol-card-thumb-more">+${photos - maxThumbs}</div>` : ''}
                </div>`
              : '';
            return `<div class="viol-card" data-violation-id="${v.id}" role="button" tabindex="0" title="Открыть карточку нарушения" draggable="true">
              <div class="viol-card-num">${i + 1}</div>
              <div class="viol-card-body">
                <div class="viol-card-title">${AktUtils.escapeHtml(v.title)}</div>
                ${refLine}
                <div class="viol-card-meta">
                  <span class="viol-card-mesto">📍 ${v.mesto ? AktUtils.escapeHtml(v.mesto) : '<span style="color:var(--border)">—</span>'}</span>
                  ${vidBadge}
                </div>
                ${thumbsHtml}
              </div>
              <div class="viol-card-actions">
                <button type="button" class="btn-ghost btn-sm w-viol-edit" data-vid="${v.id}" title="Редактировать">✏️</button>
                <button type="button" class="btn-ghost btn-sm modal-btn-danger w-viol-del" data-vid="${v.id}" title="Удалить">🗑</button>
              </div>
            </div>`;
          })
          .join('')
      : `<div class="viol-empty">
          <div class="viol-empty-icon">⚠️</div>
          <div class="viol-empty-text">Нарушения не добавлены</div>
          <div class="viol-empty-hint">Нажмите «+ Добавить нарушение» чтобы зафиксировать нарушение</div>
        </div>`;

    const allPhotos = allViolations.flatMap((v) =>
      (v.photo || []).map((p, idx) => ({ v, idx, src: AktUtils.photoSrc(p) }))
    );
    const photoSection = allPhotos.length
      ? `<h3 style="margin-top:4px;font-size:14px;margin-bottom:12px">Все фото акта</h3>
         <div class="photo-grid" id="wPhotoGrid">${
           allPhotos
             .slice(0, 16)
             .map(
               ({ src, v, idx }) =>
                 `<div class="photo-slot filled wizard-photo-thumb" data-vid="${v.id}" data-pidx="${idx}" title="${AktUtils.escapeHtml(v.title)}">
                   <img src="${src}" alt="">
                 </div>`
             )
             .join('') + (allPhotos.length > 16 ? `<div class="photo-slot">+${allPhotos.length - 16}</div>` : '')
         }</div>`
      : '';

    return `
      <div class="viol-step-header">
        <h3 style="margin:0">Нарушения <span class="viol-total-badge">${allViolations.length}</span></h3>
        <button type="button" class="btn-primary" id="wAddViolation">+ Добавить нарушение</button>
      </div>
      <div class="viol-cards-list" id="wViolList">${cards}</div>
      ${photoSection}
    `;
  }

  function renderStepDescription() {
    const allPreds = catalog.predstavitely || [];
    const selectedPredIds = new Set((draft.predstavitelyComission || []).map((p) => p.id));

    const predChips = (draft.predstavitelyComission || [])
      .map(
        (p) =>
          `<span class="chip chip-removable" data-remove-pred="${p.id}" title="Нажмите, чтобы убрать">${AktUtils.escapeHtml(p.fio)}${p.jobTitle ? ' — ' + AktUtils.escapeHtml(p.jobTitle) : ''}</span>`
      )
      .join('');

    const orgNames = [...new Set(allPreds.map((p) => p.organization).filter(Boolean))].sort();

    const filteredPreds = allPreds.filter((p) => {
      if (selectedPredIds.has(p.id)) return false;
      if (predOrgFilters.size === 0) return true;
      return predOrgFilters.has(p.organization || '');
    });

    const predCatalogChips = filteredPreds
      .map(
        (p) =>
          `<span class="chip chip-catalog" data-add-pred="${p.id}" title="Нажмите, чтобы добавить">${AktUtils.escapeHtml(p.fio)}${p.jobTitle ? ' — ' + AktUtils.escapeHtml(p.jobTitle) : ''}</span>`
      )
      .join('');

    const filterBtns = orgNames
      .map((org) => {
        const active = predOrgFilters.has(org);
        return `<button type="button" class="btn-org-filter${active ? ' btn-org-filter-active' : ''}" data-org-filter="${AktUtils.escapeHtml(org)}">${AktUtils.escapeHtml(org)}</button>`;
      })
      .join('');

    const resetBtn = predOrgFilters.size > 0
      ? `<button type="button" class="btn-org-filter-reset" id="wPredFilterReset">✕ Сбросить</button>`
      : '';

    const filterRow = orgNames.length > 1
      ? `<div class="pred-filter-row">${filterBtns}${resetBtn}</div>`
      : '';

    const templates = catalog.descriptionTemplates || ['', '', ''];
    const isEdit = descEditMode;
    const vyvody = AktUtils.escapeHtml(draft.komissijaVyvody || '');

    const templateBtns = [0, 1, 2]
      .map((i) => {
        if (isEdit) {
          return `<button type="button" class="btn-template-save" data-save-template="${i}" title="Сохранить текущий текст как Шаблон ${i + 1}">Сохранить в Шаблон ${i + 1}</button>`;
        }
        const hasTpl = templates[i] && templates[i].trim();
        return `<button type="button" class="btn-template${hasTpl ? '' : ' btn-template-empty'}" data-load-template="${i}">Шаблон ${i + 1}</button>`;
      })
      .join('');

    const editBtn = isEdit
      ? `<button type="button" class="btn-edit-active" id="wVyvodyEditBtn">💾 Сохранить</button>`
      : `<button type="button" class="btn-edit" id="wVyvodyEditBtn">✏ Редактировать</button>`;

    return `
      <h3>Выводы комиссии</h3>
      <div class="form-group vyvody-group">
        <label>Выводы комиссии</label>
        <textarea class="form-control" id="wVyvody" rows="4" placeholder="Введите выводы комиссии…">${vyvody}</textarea>
        <div class="vyvody-actions">
          ${editBtn}
          <div class="vyvody-templates">${templateBtns}</div>
        </div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label>Срок устранения</label>
          <input class="form-control" type="date" id="wElimDate" value="${AktUtils.toDateInputValue(draft.actustranenDate)}">
        </div>
        <div class="form-group">
          <label>Дата предоставления</label>
          <input class="form-control" type="date" id="wPredDate" value="${AktUtils.toDateInputValue(draft.actPredostavlenDate)}">
        </div>
      </div>
      <div class="form-group">
        <label>Дата утверждения</label>
        <input class="form-control" type="date" id="wUtverDate" value="${AktUtils.toDateInputValue(draft.actUtverzdenDate)}">
      </div>

      <h3 style="margin-top:8px;">Представители организации</h3>
      <div class="chip-list" id="wPredChips">${predChips || '<span class="wizard-hint">Добавьте представителей организации</span>'}</div>
      <div class="commission-divider"></div>
      <div class="commission-catalog-section">
        <div class="commission-catalog-header">
          <span class="commission-catalog-label">Выбрать из справочника</span>
          <button type="button" class="btn-ghost" id="wNewPredBtn">+ Новый представитель</button>
        </div>
        ${filterRow}
        <div class="chip-list">${predCatalogChips || '<span class="wizard-hint">Все из справочника уже добавлены</span>'}</div>
      </div>
    `;
  }

  function buildAktPreviewHtml() {
    const lines = [];
    lines.push(`<strong>АКТ № ${AktUtils.escapeHtml(draft.number)}</strong> от ${AktUtils.formatDateShort(draft.date)}`);
    lines.push(`Организация: ${AktUtils.escapeHtml(draft.organization?.title || '—')}`);
    lines.push(`<br><strong>Комиссия:</strong>`);
    (draft.comission || []).forEach((p) => {
      lines.push(`• ${AktUtils.escapeHtml(p.fio)} — ${AktUtils.escapeHtml(p.jobTitle || '')}`);
    });
    const obj = (draft.objectsCheck || [])[0];
    lines.push(`<br><strong>Объект:</strong> ${obj ? `${AktUtils.escapeHtml(obj.title)} (${AktUtils.escapeHtml(obj.subTitle || '')})` : '—'}`);
    lines.push(`<br><strong>Нарушения (${(draft.violations || []).length}):</strong>`);
    (draft.violations || []).forEach((v, i) => {
      lines.push(
        `${i + 1}. ${AktUtils.escapeHtml(v.title)} — ${AktUtils.escapeHtml(v.mesto || '')} [фото: ${v.photo?.length || 0}]`
      );
    });
    if (draft.description) {
      lines.push(`<br><strong>Заключение:</strong><br>${AktUtils.escapeHtml(draft.description)}`);
    }
    if (draft.komissijaVyvody) {
      lines.push(`<br><strong>Выводы комиссии:</strong><br>${AktUtils.escapeHtml(draft.komissijaVyvody)}`);
    }
    (draft.predstavitelyComission || []).forEach((p) => {
      lines.push(`<br>Представитель: ${AktUtils.escapeHtml(p.fio)} — ${AktUtils.escapeHtml(p.jobTitle || '')}`);
    });
    lines.push(`<br>Срок устранения: ${AktUtils.formatDateShort(draft.actustranenDate)}`);
    return lines.join('<br>');
  }

  function renderStepGenerate() {
    const photos = AktUtils.countPhotos(draft);
    const org = draft.organization?.title || '—';
    const isDone = !AktUtils.isDraft(draft);
    return `
      <h3>Генерация акта</h3>
      <div class="wizard-checklist" style="margin-bottom:16px">
        <div>✓ Акт № <strong>${AktUtils.escapeHtml(draft.number)}</strong> от ${AktUtils.formatDateShort(draft.date)}</div>
        <div>✓ ${AktUtils.escapeHtml(org)}</div>
        <div>✓ Комиссия: ${(draft.comission || []).length} чел. · Объект: ${AktUtils.escapeHtml((draft.objectsCheck || [])[0]?.title || '—')}</div>
        <div>✓ Нарушений: ${(draft.violations || []).length} · Фото: ${photos}</div>
        <div>✓ Статус: ${isDone ? '<span class="badge badge-green">Готов (веб)</span>' : '<span class="badge badge-orange">Черновик</span>'}</div>
      </div>

      <div id="wDocxTemplateStatus" style="margin-bottom:16px;padding:12px 14px;border-radius:var(--radius);font-size:13px;background:var(--primary-soft);">
        <span id="wDocxTemplateStatusText">⏳ Проверка шаблона…</span>
        <button type="button" class="btn-ghost btn-sm" style="margin-left:12px;" data-go="settings">Открыть настройки</button>
      </div>

      <h3 style="margin-top:4px;font-size:14px">Предпросмотр содержания</h3>
      <div class="akt-preview-box">${buildAktPreviewHtml()}</div>

      <div style="display:flex;gap:12px;flex-wrap:wrap;margin-top:20px">
        <button type="button" class="btn-primary" id="wGenerateDocx" style="font-size:15px;padding:12px 24px;">📄 Сформировать акт Word</button>
        <button type="button" class="btn-secondary" id="wSaveDraft">💾 Сохранить черновик</button>
        <button type="button" class="btn-secondary" id="wMarkReady">${isDone ? '↩ Вернуть в черновик' : '✓ Отметить готовым'}</button>
      </div>
    `;
  }

  function bindViolationDragDrop() {
    const container = document.getElementById('wViolList');
    if (!container) return;

    let dragSrcId = null;
    let dragOverId = null;

    function getCards() {
      return [...container.querySelectorAll('.viol-card[data-violation-id]')];
    }

    function clearDropIndicators() {
      container.querySelectorAll('.viol-card--drag-over-top, .viol-card--drag-over-bottom')
        .forEach((el) => {
          el.classList.remove('viol-card--drag-over-top', 'viol-card--drag-over-bottom');
        });
    }

    getCards().forEach((card) => {
      card.addEventListener('dragstart', (e) => {
        dragSrcId = card.dataset.violationId;
        container.dataset.dragging = '1';
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', dragSrcId);
        setTimeout(() => card.classList.add('viol-card--dragging'), 0);
      });

      card.addEventListener('dragend', () => {
        card.classList.remove('viol-card--dragging');
        clearDropIndicators();
        dragSrcId = null;
        dragOverId = null;
        setTimeout(() => { delete container.dataset.dragging; }, 0);
      });

      card.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        if (card.dataset.violationId === dragSrcId) return;
        clearDropIndicators();
        // Determine if dropping above or below the midpoint
        const rect = card.getBoundingClientRect();
        const mid = rect.top + rect.height / 2;
        dragOverId = card.dataset.violationId;
        if (e.clientY < mid) {
          card.classList.add('viol-card--drag-over-top');
        } else {
          card.classList.add('viol-card--drag-over-bottom');
        }
      });

      card.addEventListener('dragleave', (e) => {
        if (!card.contains(e.relatedTarget)) {
          card.classList.remove('viol-card--drag-over-top', 'viol-card--drag-over-bottom');
        }
      });

      card.addEventListener('drop', (e) => {
        e.preventDefault();
        if (!dragSrcId || card.dataset.violationId === dragSrcId) return;

        const violations = [...(draft.violations || [])];
        const srcIdx = violations.findIndex((v) => v.id === dragSrcId);
        const tgtIdx = violations.findIndex((v) => v.id === card.dataset.violationId);
        if (srcIdx === -1 || tgtIdx === -1) return;

        const rect = card.getBoundingClientRect();
        const mid = rect.top + rect.height / 2;
        const insertAfter = e.clientY >= mid;

        const [moved] = violations.splice(srcIdx, 1);
        const newTgtIdx = violations.findIndex((v) => v.id === card.dataset.violationId);
        violations.splice(insertAfter ? newTgtIdx + 1 : newTgtIdx, 0, moved);

        draft.violations = violations;
        scheduleAutosave();
        render();
        updateSummary();
      });
    });
  }

  function bindCommissionDragDrop() {
    const container = document.getElementById('wCommissionChips');
    if (!container) return;

    let dragSrcId = null;

    container.querySelectorAll('.chip-removable[draggable]').forEach((chip) => {
      chip.addEventListener('dragstart', (e) => {
        dragSrcId = chip.dataset.personId;
        e.dataTransfer.effectAllowed = 'move';
        chip.classList.add('chip-dragging');
      });

      chip.addEventListener('dragend', () => {
        chip.classList.remove('chip-dragging');
        container.querySelectorAll('.chip-drag-over').forEach((el) => el.classList.remove('chip-drag-over'));
      });

      chip.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        if (chip.dataset.personId !== dragSrcId) {
          container.querySelectorAll('.chip-drag-over').forEach((el) => el.classList.remove('chip-drag-over'));
          chip.classList.add('chip-drag-over');
        }
      });

      chip.addEventListener('drop', (e) => {
        e.preventDefault();
        const targetId = chip.dataset.personId;
        if (!dragSrcId || dragSrcId === targetId) return;

        const commission = draft.comission || [];
        const srcIdx = commission.findIndex((p) => p.id === dragSrcId);
        const tgtIdx = commission.findIndex((p) => p.id === targetId);
        if (srcIdx === -1 || tgtIdx === -1) return;

        const [moved] = commission.splice(srcIdx, 1);
        commission.splice(tgtIdx, 0, moved);
        draft.comission = commission;
        render();
      });
    });
  }

  function selectOrganizationById(id) {
    const org = (catalog.organizations || []).find((o) => o.id === id);
    if (!org) return;
    draft.organization = { ...org };
    scheduleAutosave();
    render();
    updateSummary();
  }

  function clearOrganization() {
    draft.organization = { id: '', title: '', shortTitle: '' };
    scheduleAutosave();
    render();
    updateSummary();
  }

  function selectObjectById(id) {
    const obj = (catalog.objects || []).find((o) => o.id === id);
    if (!obj) return;
    normalizeObjectsCheck();
    draft.objectsCheck = [{ ...obj }];
    scheduleAutosave();
    render();
    updateSummary();
  }

  function clearObject() {
    draft.objectsCheck = [];
    scheduleAutosave();
    render();
    updateSummary();
  }

  function bindPanelEvents() {
    if (step === 2) normalizeObjectsCheck();

    panelsHost()?.querySelectorAll('[data-add-person]').forEach((chip) => {
      chip.addEventListener('click', () => addPersonById(chip.dataset.addPerson));
    });

    document.getElementById('wDate')?.addEventListener('change', () => {
      const dateEl = document.getElementById('wDate');
      const numEl = document.getElementById('wNumber');
      if (!dateEl?.value || !numEl) return;
      draft.date = new Date(dateEl.value + 'T12:00:00').toISOString();
      const year = new Date(draft.date).getFullYear();
      const occupied = AktUtils.occupiedNumbers(catalog.akts, draft.id, year);
      let selected = numEl.value;
      if (occupied.has(String(selected))) {
        selected = AktUtils.nextAktNumberForYear(catalog.akts, year, draft.id);
        draft.number = selected;
      }
      const opts = numberOptions();
      numEl.size = 1;
      numEl.innerHTML = opts
        .map((n) => `<option value="${n}" ${String(selected) === String(n) ? 'selected' : ''}>${n}</option>`)
        .join('');
      scheduleAutosave();
    });
    document.getElementById('wNewPersonBtn')?.addEventListener('click', () =>
      WizardModals.openQuickAdd('commission')
    );
    document.getElementById('wNewOrgBtn')?.addEventListener('click', () => WizardModals.openQuickAdd('org'));
    document.getElementById('wNewObjBtn')?.addEventListener('click', () => WizardModals.openQuickAdd('object'));

    panelsHost()?.querySelectorAll('[data-select-org]').forEach((chip) => {
      chip.addEventListener('click', () => selectOrganizationById(chip.dataset.selectOrg));
    });
    panelsHost()?.querySelectorAll('[data-clear-org]').forEach((chip) => {
      chip.addEventListener('click', () => clearOrganization());
    });
    panelsHost()?.querySelectorAll('[data-select-object]').forEach((chip) => {
      chip.addEventListener('click', () => selectObjectById(chip.dataset.selectObject));
    });
    panelsHost()?.querySelectorAll('[data-clear-object]').forEach((chip) => {
      chip.addEventListener('click', () => clearObject());
    });
    document.getElementById('wNewPredBtn')?.addEventListener('click', () => WizardModals.openQuickAdd('pred'));

    panelsHost()?.querySelectorAll('[data-remove-person]').forEach((btn) => {
      btn.addEventListener('click', () => removePerson(btn.dataset.removePerson));
    });

    panelsHost()?.querySelectorAll('[data-add-pred]').forEach((chip) => {
      chip.addEventListener('click', () => addPredById(chip.dataset.addPred));
    });
    panelsHost()?.querySelectorAll('[data-remove-pred]').forEach((chip) => {
      chip.addEventListener('click', () => removePred(chip.dataset.removePred));
    });

    panelsHost()?.querySelectorAll('[data-org-filter]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const org = btn.dataset.orgFilter;
        if (predOrgFilters.has(org)) {
          predOrgFilters.delete(org);
        } else {
          predOrgFilters.add(org);
        }
        render();
      });
    });

    document.getElementById('wPredFilterReset')?.addEventListener('click', () => {
      predOrgFilters = new Set();
      render();
    });

    document.getElementById('wVyvodyEditBtn')?.addEventListener('click', async () => {
      const textarea = document.getElementById('wVyvody');
      if (!descEditMode) {
        descEditMode = true;
        render();
        document.getElementById('wVyvody')?.focus();
      } else {
        const val = textarea ? textarea.value : '';
        draft.komissijaVyvody = val;
        descEditMode = false;
        await saveDraft();
        render();
      }
    });

    panelsHost()?.querySelectorAll('[data-load-template]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const idx = parseInt(btn.dataset.loadTemplate, 10);
        const templates = catalog.descriptionTemplates || ['', '', ''];
        const text = templates[idx] || '';
        if (!text.trim()) {
          GazpromToast.info(`Шаблон ${idx + 1} пуст. Введите текст и нажмите «Сохранить в Шаблон ${idx + 1}» в режиме редактирования`);
          return;
        }
        draft.komissijaVyvody = text;
        await saveDraft();
        render();
      });
    });

    panelsHost()?.querySelectorAll('[data-save-template]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const idx = parseInt(btn.dataset.saveTemplate, 10);
        const textarea = document.getElementById('wVyvody');
        const val = textarea ? textarea.value : '';
        draft.komissijaVyvody = val;
        if (!catalog.descriptionTemplates) catalog.descriptionTemplates = ['', '', ''];
        catalog.descriptionTemplates[idx] = val;
        descEditMode = false;
        await saveDraft();
        GazpromToast.success(`Текст сохранён как Шаблон ${idx + 1}`);
        render();
      });
    });

    bindCommissionDragDrop();
    bindViolationDragDrop();

    document.getElementById('wAddViolation')?.addEventListener('click', () => {
      WizardModals.openViolationEditor(null);
    });
    panelsHost()?.querySelectorAll('.viol-card[data-violation-id]').forEach((card) => {
      const openCard = () => WizardModals.openViolationEditor(card.dataset.violationId);
      card.addEventListener('click', (e) => {
        if (e.target.closest('.viol-card-actions')) return;
        if (e.target.closest('.viol-card-thumbs')) return;
        if (document.getElementById('wViolList')?.dataset.dragging) return;
        openCard();
      });
      card.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          openCard();
        }
      });
    });
    panelsHost()?.querySelectorAll('.w-viol-edit').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        WizardModals.openViolationEditor(btn.dataset.vid);
      });
    });
    panelsHost()?.querySelectorAll('.w-viol-del').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const v = (draft.violations || []).find((x) => x.id === btn.dataset.vid);
        GazpromToast.confirm(`Удалить нарушение?\n«${(v?.title || '').slice(0, 80)}»`, { confirmLabel: 'Удалить', danger: true }).then((ok) => {
          if (!ok) return;
          draft.violations = (draft.violations || []).filter((x) => x.id !== btn.dataset.vid);
          ctx.setDraft(draft);
          render();
          updateSummary();
        });
      });
    });
    panelsHost()?.querySelectorAll('.wizard-photo-thumb').forEach((el) => {
      el.addEventListener('click', () => {
        const v = (draft.violations || []).find((x) => x.id === el.dataset.vid);
        const idx = parseInt(el.dataset.pidx, 10);
        if (v?.photo?.[idx]) openLightbox(AktUtils.photoSrc(v.photo[idx]));
      });
    });
    document.getElementById('wSaveDraft')?.addEventListener('click', () => finish());
    // Проверяем наличие шаблона и обновляем статус-блок
    DocGenerator.hasTemplate().then((has) => {
      const statusEl = document.getElementById('wDocxTemplateStatusText');
      const generateBtn = document.getElementById('wGenerateDocx');
      if (!statusEl) return;
      if (has) {
        DocGenerator.getTemplateName().then((name) => {
          statusEl.textContent = `✅ Шаблон загружен${name ? ': ' + name : ''}. Нажмите «Сформировать акт Word» для генерации.`;
          statusEl.closest('#wDocxTemplateStatus').style.background = 'var(--success-soft, #e8f5e9)';
        });
      } else {
        statusEl.textContent = '⚠️ Шаблон Word не загружен. Загрузите .docx-шаблон в Настройках → Шаблон акта.';
        statusEl.closest('#wDocxTemplateStatus').style.background = 'var(--warning-soft, #fff8e1)';
        if (generateBtn) {
          generateBtn.disabled = true;
          generateBtn.style.opacity = '0.5';
        }
      }
    });

    document.getElementById('wGenerateDocx')?.addEventListener('click', async () => {
      const btn = document.getElementById('wGenerateDocx');
      if (btn) { btn.disabled = true; btn.textContent = '⏳ Генерация…'; }
      try {
        commitStep(step);
        await flushSave();
        await DocGenerator.generateFromAkt(draft, catalog);
      } catch (e) {
        console.error(e);
        GazpromToast.error(e.message || 'Ошибка генерации Word');
      } finally {
        if (btn) { btn.disabled = false; btn.textContent = '📄 Сформировать акт Word'; }
      }
    });
    document.getElementById('wMarkReady')?.addEventListener('click', async () => {
      if (AktUtils.isDraft(draft)) {
        draft.urlToFllACT = `web:completed/${draft.id}`;
      } else {
        draft.urlToFllACT = null;
      }
      await saveDraft();
      render();
      updateSummary();
    });
  }

  function addPersonFromSelect() {
    const sel = document.getElementById('wAddPerson');
    if (sel?.value) addPersonById(sel.value);
  }

  function addPersonById(id) {
    const p = (catalog.comissionPeople || []).find((x) => x.id === id);
    if (!p) return;
    if ((draft.comission || []).some((x) => x.id === id)) return;
    draft.comission = [...(draft.comission || []), { ...p }];
    render();
    updateSummary();
  }

  function removePerson(id) {
    draft.comission = (draft.comission || []).filter((p) => p.id !== id);
    render();
    updateSummary();
  }

  function addPredById(id) {
    const p = (catalog.predstavitely || []).find((x) => x.id === id);
    if (!p) return;
    if ((draft.predstavitelyComission || []).some((x) => x.id === id)) return;
    draft.predstavitelyComission = [...(draft.predstavitelyComission || []), { ...p }];
    render();
    updateSummary();
  }

  function removePred(id) {
    draft.predstavitelyComission = (draft.predstavitelyComission || []).filter((p) => p.id !== id);
    render();
    updateSummary();
  }

  async function showViolationPhotos(violationId) {
    const v = (draft.violations || []).find((x) => x.id === violationId);
    if (!v?.photo?.length) {
      GazpromToast.info('У этого нарушения нет фотографий');
      return;
    }
    const urls = await Promise.all(v.photo.map((p) => AktUtils.photoSrcAsync(p)));
    const gallery = urls.filter(Boolean);
    if (!gallery.length) {
      GazpromToast.info('Фото загружаются… попробуйте снова');
      return;
    }
    openLightbox(gallery[0], gallery);
  }

  function openLightbox(src, gallery) {
    let box = document.getElementById('photoLightbox');
    if (!box) {
      box = document.createElement('div');
      box.id = 'photoLightbox';
      box.className = 'photo-lightbox';
      box.innerHTML = `
        <button type="button" class="photo-lightbox-close">×</button>
        <button type="button" class="photo-lightbox-nav photo-lightbox-prev">‹</button>
        <img class="photo-lightbox-img" alt="">
        <button type="button" class="photo-lightbox-nav photo-lightbox-next">›</button>
      `;
      document.body.appendChild(box);
      box.querySelector('.photo-lightbox-close').onclick = () => box.classList.remove('show');
      box.onclick = (e) => {
        if (e.target === box) box.classList.remove('show');
      };
    }
    const imgs = gallery?.length ? gallery : [src];
    let idx = 0;
    const imgEl = box.querySelector('.photo-lightbox-img');
    const show = (i) => {
      idx = (i + imgs.length) % imgs.length;
      imgEl.src = imgs[idx];
    };
    show(0);
    box.querySelector('.photo-lightbox-prev').onclick = (e) => {
      e.stopPropagation();
      show(idx - 1);
    };
    box.querySelector('.photo-lightbox-next').onclick = (e) => {
      e.stopPropagation();
      show(idx + 1);
    };
    box.classList.add('show');
  }

  function commitStep(s) {
    if (!draft) return;

    if (s === 0) {
      const dateEl = document.getElementById('wDate');
      const numEl = document.getElementById('wNumber');
      if (dateEl?.value) draft.date = new Date(dateEl.value + 'T12:00:00').toISOString();
      if (numEl?.value) draft.number = numEl.value;
    }

    // Шаги 1–2 (организация, объект): выбор через chips, draft уже актуален
    if (s === 2) normalizeObjectsCheck();

    if (s === 4) {
      const desc = document.getElementById('wDescription');
      if (desc) draft.description = desc.value;
      const vyvody = document.getElementById('wVyvody');
      if (vyvody) draft.komissijaVyvody = vyvody.value;
      const el = document.getElementById('wElimDate');
      const pd = document.getElementById('wPredDate');
      const ud = document.getElementById('wUtverDate');
      if (el?.value) draft.actustranenDate = new Date(el.value + 'T12:00:00').toISOString();
      if (pd?.value) draft.actPredostavlenDate = new Date(pd.value + 'T12:00:00').toISOString();
      if (ud?.value) draft.actUtverzdenDate = new Date(ud.value + 'T12:00:00').toISOString();
    }
  }

  function validateStep(s) {
    if (s === 0) {
      if (!(draft.comission || []).length) {
        GazpromToast.error('Добавьте хотя бы одного члена комиссии');
        return false;
      }
      const draftYear = draft.date ? new Date(draft.date).getFullYear() : new Date().getFullYear();
      const occupied = AktUtils.occupiedNumbers(catalog.akts, draft.id, draftYear);
      if (occupied.has(String(draft.number))) {
        GazpromToast.error(`Акт № ${draft.number} уже существует в ${draftYear} году. Выберите другой номер.`);
        return false;
      }
    }
    if (s === 1 && !draft.organization?.title) {
      GazpromToast.error('Выберите организацию');
      return false;
    }
    if (s === 2) {
      normalizeObjectsCheck();
      if (!(draft.objectsCheck || [])[0]?.title) {
        GazpromToast.error('Выберите объект проверки');
        return false;
      }
    }
    return true;
  }

  let saveDraftChain = Promise.resolve();

  async function saveDraft() {
    if (!catalog || !draft) return;

    const draftCopy = AktUtils.clone(draft);
    const draftId = draftCopy.id;
    const draftNumber = draftCopy.number;

    const op = saveDraftChain.then(async () => {
      AktUtils.applyCurrentEditable(catalog, draftCopy);

      const idx = (catalog.akts || []).findIndex((a) => a.id === draftId);
      if (idx >= 0) catalog.akts[idx] = draftCopy;
      else catalog.akts = [...(catalog.akts || []), draftCopy];

      await GazpromStore.saveWizardDraft(draftCopy, {
        aktId: draftId,
        aktNumber: draftNumber,
        lastModified: catalog.editableAkt.lastModified,
      });
    });
    saveDraftChain = op.catch(() => {});
    await op;
  }

  async function syncCatalog() {
    await loadCatalog();
    updateSummary();
  }

  function isDirty() {
    return dirty;
  }

  async function flushSave() {
    if (!draft) return;
    commitStep(step);
    clearTimeout(autosaveTimer);
    await saveDraft();
    dirty = false;
    updateDirtyIndicator();
  }

  function updateSummary() {
    const panel = document.getElementById('wizardSummaryCard');
    if (!panel || !draft) return;
    const photos = AktUtils.countPhotos(draft);
    const rows = panel.querySelectorAll('.summary-row');
    const vals = [
      `№ ${draft.number}`,
      AktUtils.formatDateShort(draft.date),
      `${(draft.comission || []).length} чел.`,
      draft.organization?.title ? '1' : '0',
      (draft.objectsCheck || [])[0]?.title ? '1' : '0',
      `${(draft.violations || []).length}`,
      `${photos}`,
    ];
    rows.forEach((row, i) => {
      const span = row.querySelector('span:last-child');
      if (span && vals[i] !== undefined) span.textContent = vals[i];
    });
  }

  async function next() {
    commitStep(step);
    if (!validateStep(step)) return;
    if (step < TOTAL_STEPS - 1) {
      setStep(step + 1);
      saveDraft().catch((e) => {
        console.error(e);
        GazpromToast.error(e.message || 'Ошибка сохранения черновика');
      });
      return;
    }
    try {
      await saveDraft();
      await finish();
    } catch (e) {
      console.error(e);
      GazpromToast.error(e.message || 'Ошибка сохранения черновика');
    }
  }

  async function prev() {
    commitStep(step);
    if (step > 0) {
      setStep(step - 1);
      saveDraft().catch((e) => {
        console.error(e);
        GazpromToast.error(e.message || 'Ошибка сохранения черновика');
      });
    }
  }

  async function finish() {
    commitStep(step);
    if (!validateStep(step)) return;
    await saveDraft();
    await GazpromStore.persistCatalog(catalog);
    await GazpromUI.refreshAll();
    GazpromToast.success(`Черновик акта № ${draft.number} сохранён`);
  }

  function canGoToStep(target) {
    if (target <= step) return true;
    commitStep(step);
    for (let s = step; s < target; s++) {
      if (!validateStep(s)) return false;
    }
    return true;
  }

  function bindGlobalControls() {
    document.getElementById('wizardNext')?.addEventListener('click', () => next());
    document.getElementById('wizardPrev')?.addEventListener('click', () => prev());
    document.querySelectorAll('#wizardStepper .wizard-step').forEach((btn) => {
      btn.addEventListener('click', () => {
        const target = parseInt(btn.dataset.step, 10);
        if (Number.isNaN(target) || target === step) return;
        if (target > step && !canGoToStep(target)) return;
        if (target < step) commitStep(step);
        setStep(target);
        saveDraft().catch((e) => {
          console.error(e);
          GazpromToast.error(e.message || 'Ошибка сохранения черновика');
        });
      });
    });
    document.getElementById('wizardNewBtn')?.addEventListener('click', async () => {
      if (draft) {
        const ok = await GazpromToast.confirm(
          'Начать новый полный акт? Текущий черновик будет сохранён в списке актов.'
        );
        if (!ok) return;
      }
      try {
        await startNewDraft();
        GazpromToast.success('Новый полный акт создан');
      } catch (e) {
        console.error(e);
        GazpromToast.error(e.message || 'Ошибка создания нового акта');
      }
    });
  }

  bindGlobalControls();

  return { open, openWithAkt, setStep, updateSummary, scheduleAutosave, syncCatalog, isDirty, flushSave };
})();
