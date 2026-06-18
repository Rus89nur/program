/**
 * Мастер создания справки по производственной безопасности.
 */
const SpravkaWizard = (() => {
  const TOTAL_STEPS = 7;
  const AUTOSAVE_MS = window.matchMedia('(pointer: coarse)').matches ? 600 : 2000;

  let catalog = null;
  let draft = null;
  let step = 0;
  let autosaveTimer = null;
  let dirty = false;
  let violSearchQuery = '';
  let quickAddOrgTarget = 'subcontractor';

  const panelsHost = () => document.getElementById('spravkaPanels');
  const emptyEl = () => document.getElementById('spravkaEmpty');

  async function loadCatalog() {
    catalog = await GazpromStore.get();
  }

  async function reloadCatalog() {
    GazpromStore.invalidateCache();
    await loadCatalog();
  }

  let chromeBound = false;

  function setupModals() {
    WizardModals.init({
      getDraft: () => draft,
      setDraft: (d) => { draft = d; },
      getCatalog: () => catalog,
      reloadCatalog,
      openLightbox: (src, gallery) => PhotoLightbox.open(src, gallery),
      saveDraft,
      onUpdate: () => {
        render();
        updateSummary();
      },
      onQuickAdd: (type, item) => {
        if (type === 'object' && item?.id) {
          addObjectById(item.id);
        }
        if (type === 'org' && item?.id) {
          if (quickAddOrgTarget === 'worker') addWorkerFromOrg(item.id);
          else addSubcontractorById(item.id);
        }
      },
    });
  }

  function initDraft() {
    const editable = SpravkaUtils.getEditableSpravka(catalog);
    draft = editable ? SpravkaUtils.clone(editable) : SpravkaUtils.createEmpty(catalog);
    draft.objectsCheck = SpravkaUtils.ensureObjectFields(draft.objectsCheck);
    draft.workerRows = (draft.workerRows || []).map((row) => {
      const normalized = SpravkaUtils.normalizeWorkerRow(row);
      if (!normalized.orgId && normalized.orgName) {
        const org = SpravkaUtils.matchOrganizationByTitle(catalog?.organizations, normalized.orgName);
        if (org) {
          normalized.orgId = String(org.id);
          normalized.orgName = org.title;
        }
      } else if (normalized.orgId) {
        normalized.orgId = String(normalized.orgId);
      }
      return normalized;
    });
    draft.violationFormat = SpravkaUtils.normalizeViolationFormat(draft.violationFormat);
    violSearchQuery = '';
  }

  function showEmpty(show) {
    const e = emptyEl();
    const root = document.getElementById('spravkaRoot');
    if (e) e.hidden = !show;
    if (root) root.hidden = show;
    syncViolFab();
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
    }, AUTOSAVE_MS);
  }

  function updateDirtyIndicator() {
    const el = document.getElementById('spravkaDirtyBadge');
    if (el) el.hidden = !dirty;
  }

  async function saveDraft() {
    if (!draft || !catalog) return;
    const draftCopy = SpravkaUtils.clone(draft);
    SpravkaUtils.upsertInCatalog(catalog, draftCopy);
    await GazpromStore.saveSpravkaDraft(draftCopy);
    GazpromStore.updateCache(catalog);
  }

  async function persistCatalog() {
    if (!catalog) return;
    await GazpromStore.persistCatalog(catalog);
  }

  function commitStep(s) {
    if (!draft) return;
    if (s === 0) {
      const dateEl = document.getElementById('spDate');
      if (dateEl?.value) draft.date = new Date(dateEl.value + 'T12:00:00').toISOString();
    }
    if (s === 1) commitObjectDetails();
    if (s === 2) {
      /* subcontractorsList обновляется при добавлении/удалении чипов */
    }
    if (s === 3) commitWorkerRows();
    if (s === 5) {
      draft.remarksRMM = document.getElementById('spRemarksRMM')?.value || '';
      draft.conclusion = document.getElementById('spConclusion')?.value || '';
    }
  }

  function getCatalogObjects() {
    return (catalog?.objects || []).map((o, index) => {
      const id = o.id || o._id || `legacy-obj-${index}`;
      return { ...o, id: String(id) };
    });
  }

  function findCatalogObject(id) {
    const key = String(id || '');
    return getCatalogObjects().find((o) => String(o.id) === key);
  }

  function getCatalogOrganizations() {
    return (catalog?.organizations || []).map((o, index) => {
      const id = o.id || o._id || `legacy-org-${index}`;
      return { ...o, id: String(id) };
    });
  }

  function findCatalogOrganization(id) {
    const key = String(id || '');
    return getCatalogOrganizations().find((o) => String(o.id) === key);
  }

  function getSelectedSubcontractorTitles() {
    return SpravkaUtils.parseSubcontractorsList(draft.subcontractorsList);
  }

  function setSelectedSubcontractorTitles(titles) {
    draft.subcontractorsList = SpravkaUtils.formatSubcontractorsList(titles);
  }

  function addSubcontractorById(id) {
    const org = findCatalogOrganization(id);
    if (!org) return;
    const titles = getSelectedSubcontractorTitles();
    if (titles.includes(org.title)) {
      GazpromToast.info('Организация уже в списке субподрядчиков');
      return;
    }
    titles.push(org.title);
    setSelectedSubcontractorTitles(titles);
    scheduleAutosave();
    render();
  }

  function removeSubcontractorByTitle(title) {
    const titles = getSelectedSubcontractorTitles().filter((t) => t !== title);
    setSelectedSubcontractorTitles(titles);
    scheduleAutosave();
    render();
  }

  function removeSubcontractorById(id) {
    const org = findCatalogOrganization(id);
    if (!org) return;
    removeSubcontractorByTitle(org.title);
  }

  function commitObjectDetails() {
    (draft.objectsCheck || []).forEach((obj) => {
      const codeEl = document.getElementById(`spObjCode_${obj.id}`);
      const gpEl = document.getElementById(`spObjGp_${obj.id}`);
      if (codeEl) obj.objectCode = codeEl.value.trim();
      if (gpEl) obj.gpLine = gpEl.value.trim();
    });
  }

  function commitWorkerRows() {
    const rows = [];
    document.querySelectorAll('[data-sp-worker-row]').forEach((rowEl) => {
      const id = rowEl.dataset.spWorkerRow;
      const existing = (draft.workerRows || []).find((r) => r.id === id);
      rows.push(SpravkaUtils.normalizeWorkerRow({
        id,
        orgId: existing?.orgId || rowEl.dataset.spWorkerOrg || '',
        orgName: existing?.orgName || '',
        pbCount: rowEl.querySelector('[data-sp-worker-pb]')?.value,
        workersCount: rowEl.querySelector('[data-sp-worker-count]')?.value,
      }));
    });
    draft.workerRows = rows.filter((r) => r.orgName);
  }

  function validateStep(s) {
    if (s === 0) {
      const dateEl = document.getElementById('spDate');
      if (!dateEl?.value) {
        GazpromToast.error('Укажите дату справки');
        return false;
      }
    }
    if (s === 1) {
      if (!(draft.objectsCheck || []).length) {
        GazpromToast.error('Выберите хотя бы один объект строительства');
        return false;
      }
    }
    return true;
  }

  function syncViolFab() {
    const fab = document.getElementById('spravkaViolFab');
    if (!fab) return;
    const active = document.getElementById('screen-spravka')?.classList.contains('active');
    fab.hidden = !active || step !== 4;
  }

  function updateStepper() {
    document.querySelectorAll('#spravkaStepper .wizard-step').forEach((btn) => {
      const n = parseInt(btn.dataset.step, 10);
      btn.classList.toggle('current', n === step);
      btn.classList.toggle('done', n < step);
    });
    const prev = document.getElementById('spravkaPrev');
    const next = document.getElementById('spravkaNext');
    if (prev) prev.disabled = step === 0;
    if (next) next.textContent = step === TOTAL_STEPS - 1 ? 'Готово' : 'Далее →';
  }

  function updateSummary() {
    if (!draft) return;
    const map = {
      date: AktUtils.formatDateShort(draft.date),
      objects: String((draft.objectsCheck || []).length),
      workers: String((draft.workerRows || []).length),
      violations: String((draft.violations || []).length),
      status: SpravkaUtils.isDraft(draft) ? 'Черновик' : 'Готова',
    };
    Object.entries(map).forEach(([key, val]) => {
      const row = document.querySelector(`#spravkaSummaryBody [data-summary-key="${key}"] span:last-child`);
      if (row) row.textContent = val;
    });
  }

  const violUi = WizardViolationsUI.create({
    ids: {
      list: 'spViolList',
      search: 'spViolSearch',
      badge: 'spViolCountBadge',
      photoSection: 'spViolPhotoSection',
      photoGrid: 'spPhotoGrid',
    },
    editClass: 'sp-viol-edit',
    delClass: 'sp-viol-del',
    getDraft: () => draft,
    getViolSearchQuery: () => violSearchQuery,
    setViolSearchQuery: (q) => { violSearchQuery = q; },
    getStep: () => step,
    violationsStep: 4,
    panelsHost,
    scheduleAutosave,
    render,
    updateSummary,
    openLightbox: (src, gallery) => PhotoLightbox.open(src, gallery),
    docLabel: 'справки',
    photoSectionTitle: 'Все фото справки',
    getViolationFormat: () => draft?.violationFormat,
    formatViolationTitle: (v) => SpravkaUtils.formatViolationText(v, draft?.violationFormat),
    renderStepExtra: () => {
      const fmt = SpravkaUtils.normalizeViolationFormat(draft?.violationFormat);
      const mestoClass = fmt.includeMesto ? 'btn-org-filter-active' : '';
      const ruleClass = fmt.includeRuleRef ? 'btn-org-filter-active' : '';
      return `
        <div class="spravka-viol-format-toolbar" style="margin-bottom:14px">
          <p class="wizard-hint" style="margin:0 0 8px">Как нарушения попадут в текст Word-документа:</p>
          <div class="pred-filter-row" style="flex-wrap:wrap;gap:8px">
            <button type="button" class="btn-org-filter ${mestoClass}" data-sp-viol-fmt="mesto" aria-pressed="${fmt.includeMesto}">
              Место нарушения
            </button>
            <button type="button" class="btn-org-filter ${ruleClass}" data-sp-viol-fmt="rule" aria-pressed="${fmt.includeRuleRef}">
              Пункт правил (в скобках)
            </button>
          </div>
          <p class="wizard-hint" style="margin:8px 0 0;font-size:12px">
            Пример: «Котельная №2: Не проведён инструктаж (п. 4.1 СП 12-135-2003)»
          </p>
        </div>
      `;
    },
  });

  function renderStepDate() {
    return `
      <h3>Дата справки</h3>
      <p class="wizard-hint">Дата, на которую формируется справка о состоянии производственной безопасности</p>
      <div class="form-group" style="max-width:280px">
        <label for="spDate">Дата</label>
        <input class="form-control" type="date" id="spDate" value="${AktUtils.toDateInputValue(draft.date)}">
      </div>
    `;
  }

  function renderObjectDetailsHtml() {
    const selected = draft.objectsCheck || [];
    if (!selected.length) return '';
    return selected.map((obj, idx) => `
      <div class="spravka-object-card" data-sp-object-card="${obj.id}">
        <h4 style="margin:0 0 12px;font-size:14px">${idx + 1}. ${AktUtils.escapeHtml(obj.title)}</h4>
        <div class="form-row">
          <div class="form-group">
            <label for="spObjCode_${obj.id}">Код объекта</label>
            <input class="form-control" id="spObjCode_${obj.id}" value="${AktUtils.escapeHtml(obj.objectCode || '')}" placeholder="051-2001292">
          </div>
        </div>
        <div class="form-group">
          <label for="spObjGp_${obj.id}">Генподрядчик и договор</label>
          <textarea class="form-control" id="spObjGp_${obj.id}" rows="2" placeholder="ГП – ООО «РусГазШельф» (РГШ), договор ГП от 05.06.2019 № 0675/19.">${AktUtils.escapeHtml(obj.gpLine || '')}</textarea>
        </div>
        ${obj.subTitle ? `<p class="wizard-hint">Из справочника: ${AktUtils.escapeHtml(obj.subTitle)}</p>` : ''}
      </div>
    `).join('');
  }

  function renderStepObjects() {
    const objects = getCatalogObjects();
    const selectedIds = new Set((draft.objectsCheck || []).map((o) => String(o.id)));

    const selectedChips = (draft.objectsCheck || [])
      .map(
        (o) =>
          `<button type="button" class="chip chip-removable" data-sp-remove-object="${AktUtils.escapeHtml(String(o.id))}" title="Нажмите, чтобы убрать">${AktUtils.escapeHtml(o.title)}${o.subTitle ? ' — ' + AktUtils.escapeHtml(o.subTitle) : ''}</button>`
      )
      .join('');

    const catalogChips = objects
      .filter((o) => !selectedIds.has(String(o.id)))
      .map(
        (o) =>
          `<button type="button" class="chip chip-catalog" data-sp-add-object="${AktUtils.escapeHtml(String(o.id))}" title="Нажмите, чтобы добавить">${AktUtils.escapeHtml(o.title)}${o.subTitle ? ' — ' + AktUtils.escapeHtml(o.subTitle) : ''}</button>`
      )
      .join('');

    const catalogBlock = objects.length
      ? `<div class="chip-list">${catalogChips || '<span class="wizard-hint">Все из справочника уже добавлены</span>'}</div>`
      : '<p class="wizard-hint">Справочник объектов пуст — добавьте через кнопку справа.</p>';

    const detailsBlock = renderObjectDetailsHtml();

    return `
      <h3>Объекты строительства</h3>
      <p class="wizard-hint">Можно выбрать несколько объектов — в отличие от полного акта проверки</p>
      <div class="chip-list" id="spObjectChips">${selectedChips || '<span class="wizard-hint">Выберите объект из справочника</span>'}</div>
      <div class="commission-divider"></div>
      <div class="commission-catalog-section">
        <div class="commission-catalog-header">
          <span class="commission-catalog-label">Выбрать из справочника</span>
          <button type="button" class="btn-ghost" id="spNewObjectBtn">+ Новый объект</button>
        </div>
        ${catalogBlock}
      </div>
      ${detailsBlock ? `<div class="spravka-object-cards">${detailsBlock}</div>` : ''}
    `;
  }

  function formatOrgChipLabel(o) {
    return `${AktUtils.escapeHtml(o.title)}${o.shortTitle ? ' — ' + AktUtils.escapeHtml(o.shortTitle) : ''}`;
  }

  function resolveSubcontractorSelection() {
    const orgs = getCatalogOrganizations();
    const titles = getSelectedSubcontractorTitles();
    const selectedOrgIds = [];
    const customTitles = [];
    titles.forEach((title) => {
      const org = SpravkaUtils.matchOrganizationByTitle(orgs, title);
      if (org) selectedOrgIds.push(String(org.id));
      else customTitles.push(title);
    });
    return { selectedOrgIds, customTitles };
  }

  function renderOrganizationChipPicker({
    orgs,
    selectedOrgIds,
    customTitles = [],
    chipsId,
    newBtnId,
    emptyHint,
    addAttr,
    removeAttr,
    removeTitleAttr,
  }) {
    const selectedSet = new Set(selectedOrgIds.map(String));
    const selectedFromCatalog = orgs.filter((o) => selectedSet.has(String(o.id)));

    const selectedChips = [
      ...selectedFromCatalog.map(
        (o) =>
          `<button type="button" class="chip chip-removable" ${removeAttr}="${AktUtils.escapeHtml(o.id)}" title="Нажмите, чтобы убрать">${formatOrgChipLabel(o)}</button>`
      ),
      ...(removeTitleAttr
        ? customTitles.map(
            (t) =>
              `<button type="button" class="chip chip-removable" ${removeTitleAttr}="${AktUtils.escapeHtml(t)}" title="Нажмите, чтобы убрать">${AktUtils.escapeHtml(t)}</button>`
          )
        : []),
    ].join('');

    const catalogChips = orgs
      .filter((o) => !selectedSet.has(String(o.id)))
      .map(
        (o) =>
          `<button type="button" class="chip chip-catalog" ${addAttr}="${AktUtils.escapeHtml(o.id)}" title="Нажмите, чтобы добавить">${formatOrgChipLabel(o)}</button>`
      )
      .join('');

    const catalogBlock = orgs.length
      ? `<div class="chip-list">${catalogChips || '<span class="wizard-hint">Все из справочника уже добавлены</span>'}</div>`
      : '<p class="wizard-hint">Справочник организаций пуст — добавьте через кнопку справа.</p>';

    return `
      <div class="chip-list" id="${chipsId}">${selectedChips || `<span class="wizard-hint">${emptyHint}</span>`}</div>
      <div class="commission-divider"></div>
      <div class="commission-catalog-section">
        <div class="commission-catalog-header">
          <span class="commission-catalog-label">Выбрать из справочника</span>
          <button type="button" class="btn-ghost" id="${newBtnId}">+ Новая организация</button>
        </div>
        ${catalogBlock}
      </div>
    `;
  }

  function bindOrgChipHandlers({ addAttr, removeAttr, removeTitleAttr, onAdd, onRemove, onRemoveTitle, newBtnId, quickAddTarget }) {
    document.getElementById(newBtnId)?.addEventListener('click', () => {
      quickAddOrgTarget = quickAddTarget;
      WizardModals.openQuickAdd('org');
    });
    panelsHost()?.querySelectorAll(`[${addAttr}]`).forEach((chip) => {
      chip.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        onAdd(chip.getAttribute(addAttr));
      });
    });
    panelsHost()?.querySelectorAll(`[${removeAttr}]`).forEach((chip) => {
      chip.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        onRemove(chip.getAttribute(removeAttr));
      });
    });
    if (removeTitleAttr && onRemoveTitle) {
      panelsHost()?.querySelectorAll(`[${removeTitleAttr}]`).forEach((chip) => {
        chip.addEventListener('click', (e) => {
          e.preventDefault();
          e.stopPropagation();
          onRemoveTitle(chip.getAttribute(removeTitleAttr));
        });
      });
    }
  }

  function renderStepSubcontractors() {
    const orgs = getCatalogOrganizations();
    const { selectedOrgIds, customTitles } = resolveSubcontractorSelection();

    return `
      <h3>Основные субподрядчики</h3>
      <p class="wizard-hint">Выберите субподрядчиков из справочника организаций</p>
      ${renderOrganizationChipPicker({
        orgs,
        selectedOrgIds,
        customTitles,
        chipsId: 'spSubcontractorChips',
        newBtnId: 'spNewSubcontractorBtn',
        emptyHint: 'Выберите субподрядчиков из справочника',
        addAttr: 'data-sp-add-subcontractor',
        removeAttr: 'data-sp-remove-subcontractor',
        removeTitleAttr: 'data-sp-remove-subcontractor-title',
      })}
    `;
  }

  function renderWorkerRowHtml(row, idx) {
    return `
      <tr data-sp-worker-row="${row.id}" data-sp-worker-org="${AktUtils.escapeHtml(String(row.orgId || ''))}">
        <td>${idx + 1}.</td>
        <td>${AktUtils.escapeHtml(row.orgName)}</td>
        <td><input class="form-control form-control--sm" type="number" min="0" data-sp-worker-pb value="${row.pbCount ?? ''}" placeholder="0"></td>
        <td><input class="form-control form-control--sm" type="number" min="0" data-sp-worker-count value="${row.workersCount ?? ''}" placeholder="0"></td>
        <td><button type="button" class="btn-ghost btn-sm" data-sp-worker-del aria-label="Удалить">🗑</button></td>
      </tr>
    `;
  }

  function renderStepWorkers() {
    const orgs = getCatalogOrganizations();
    const rows = draft.workerRows || [];
    const totals = SpravkaUtils.workerTotals(rows);
    const selectedOrgIds = rows.map((r) => r.orgId).filter(Boolean);

    const tableBlock = rows.length
      ? `
      <div class="card card--flush" style="margin-top:16px">
        <table class="list-table spravka-workers-table">
          <thead>
            <tr>
              <th style="width:44px">№</th>
              <th>Организация</th>
              <th style="width:110px">Спец. ПБ</th>
              <th style="width:110px">Работники</th>
              <th style="width:44px"></th>
            </tr>
          </thead>
          <tbody id="spWorkerRows">${rows.map(renderWorkerRowHtml).join('')}</tbody>
          <tfoot>
            <tr class="spravka-workers-total">
              <td></td>
              <td><strong>ВСЕГО</strong></td>
              <td id="spWorkerPbTotal">${totals.pb}</td>
              <td id="spWorkerCountTotal">${totals.workers}</td>
              <td></td>
            </tr>
          </tfoot>
        </table>
      </div>`
      : '';

    return `
      <h3>Работники на объекте</h3>
      <p class="wizard-hint">Выберите организации из справочника и укажите численность: специалисты по ПБ и работники</p>
      ${renderOrganizationChipPicker({
        orgs,
        selectedOrgIds,
        chipsId: 'spWorkerChips',
        newBtnId: 'spNewWorkerOrgBtn',
        emptyHint: 'Выберите организации из справочника',
        addAttr: 'data-sp-add-worker-org',
        removeAttr: 'data-sp-remove-worker-org',
      })}
      ${tableBlock}
    `;
  }

  function renderStepRemarks() {
    return `
      <h3>Замечания по РММ и компенсирующие мероприятия</h3>
      <div class="form-group">
        <label for="spRemarksRMM">Устранение замечаний по РММ и складам ПСК</label>
        <textarea class="form-control" id="spRemarksRMM" rows="8" placeholder="ГСП-1&#10;Комплектацию ДЭС… до 29.05.2026.">${AktUtils.escapeHtml(draft.remarksRMM || '')}</textarea>
      </div>
      <div class="form-group">
        <label for="spConclusion">Компенсирующие мероприятия</label>
        <textarea class="form-control" id="spConclusion" rows="4" placeholder="автономные пожарные извещатели, обход…">${AktUtils.escapeHtml(draft.conclusion || '')}</textarea>
      </div>
    `;
  }

  function renderStepGenerate() {
    const totals = SpravkaUtils.workerTotals(draft.workerRows);
    const isDone = !SpravkaUtils.isDraft(draft);
    return `
      <h3>Генерация справки</h3>
      <div class="wizard-checklist" style="margin-bottom:16px">
        <div>✓ Дата: <strong>${AktUtils.formatDateShort(draft.date)}</strong></div>
        <div>✓ Объектов: ${(draft.objectsCheck || []).length}</div>
        <div>✓ Организаций в таблице: ${(draft.workerRows || []).length} (спец. ПБ: ${totals.pb}, работников: ${totals.workers})</div>
        <div>✓ Нарушений: ${(draft.violations || []).length}</div>
        <div>✓ Статус: ${isDone ? '<span class="badge badge-green">Готова</span>' : '<span class="badge badge-orange">Черновик</span>'}</div>
      </div>
      <div id="spSpravkaTemplateStatus" style="margin-bottom:16px;padding:12px 14px;border-radius:var(--radius);font-size:13px;background:var(--primary-soft);">
        <span id="spSpravkaTemplateStatusText">⏳ Проверка шаблона…</span>
        <button type="button" class="btn-ghost btn-sm" style="margin-left:12px;" data-go="settings">Открыть настройки</button>
      </div>
      <div style="display:flex;gap:12px;flex-wrap:wrap;margin-top:20px">
        <button type="button" class="btn-primary" id="spGenerateDocx" style="font-size:15px;padding:12px 24px;">📄 Сформировать справку Word</button>
        <button type="button" class="btn-secondary" id="spSaveDraft">💾 Сохранить черновик</button>
        <button type="button" class="btn-secondary" id="spMarkReady">${isDone ? '↩ В черновик' : '✓ Отметить готовой'}</button>
      </div>
    `;
  }

  const STEP_RENDERERS = [
    renderStepDate,
    renderStepObjects,
    renderStepSubcontractors,
    renderStepWorkers,
    () => violUi.renderStepViolations(),
    renderStepRemarks,
    renderStepGenerate,
  ];

  const STEP_PANEL_CLASSES = [
    'wizard-panel--date',
    'wizard-panel--objects',
    'wizard-panel--org',
    'wizard-panel--workers',
    'wizard-panel--violations',
    'wizard-panel--conclusions',
    'wizard-panel--generate',
  ];

  function renderPanel() {
    const host = panelsHost();
    if (!host) return;
    const panelClass = STEP_PANEL_CLASSES[step] || '';
    try {
      host.innerHTML = `<div class="card wizard-panel-active ${panelClass}">${STEP_RENDERERS[step]()}</div>`;
    } catch (err) {
      console.error(err);
      host.innerHTML = `<div class="card wizard-panel-active"><p style="color:red">Ошибка отрисовки: ${AktUtils.escapeHtml(err.message || String(err))}</p></div>`;
    }
    bindPanelEvents();
    syncViolFab();
    violUi.hydrateViolationThumbs();
  }

  function render() {
    updateStepper();
    renderPanel();
    updateSummary();
  }

  function refreshWorkerTotals() {
    commitWorkerRows();
    const totals = SpravkaUtils.workerTotals(draft.workerRows);
    const pbEl = document.getElementById('spWorkerPbTotal');
    const countEl = document.getElementById('spWorkerCountTotal');
    if (pbEl) pbEl.textContent = String(totals.pb);
    if (countEl) countEl.textContent = String(totals.workers);
  }

  function addObjectById(id) {
    if (!draft || !catalog) return;
    commitObjectDetails();
    const obj = findCatalogObject(id);
    if (!obj) {
      GazpromToast.error('Объект не найден в справочнике');
      return;
    }
    const objId = String(obj.id);
    if ((draft.objectsCheck || []).some((o) => String(o.id) === objId)) return;
    draft.objectsCheck = [...(draft.objectsCheck || []), SpravkaUtils.normalizeObjectEntry({ ...obj, id: objId })];
    scheduleAutosave();
    render();
    updateSummary();
  }

  function removeObjectById(id) {
    if (!draft) return;
    commitObjectDetails();
    draft.objectsCheck = (draft.objectsCheck || []).filter((o) => String(o.id) !== String(id));
    scheduleAutosave();
    render();
    updateSummary();
  }

  function handleSpravkaObjectClick(e) {
    const addChip = e.target.closest('[data-sp-add-object]');
    if (addChip) {
      e.preventDefault();
      e.stopPropagation();
      addObjectById(addChip.getAttribute('data-sp-add-object'));
      return;
    }
    const removeChip = e.target.closest('[data-sp-remove-object]');
    if (removeChip) {
      e.preventDefault();
      e.stopPropagation();
      removeObjectById(removeChip.getAttribute('data-sp-remove-object'));
    }
  }

  function addWorkerFromOrg(orgId) {
    commitWorkerRows();
    const org = findCatalogOrganization(orgId);
    if (!org) return;
    const key = String(org.id);
    if ((draft.workerRows || []).some((r) => String(r.orgId) === key)) {
      GazpromToast.info('Организация уже в таблице');
      return;
    }
    draft.workerRows = [...(draft.workerRows || []), SpravkaUtils.normalizeWorkerRow({
      orgId: key,
      orgName: org.title,
    })];
    scheduleAutosave();
    render();
    updateSummary();
  }

  function removeWorkerByOrgId(orgId) {
    commitWorkerRows();
    draft.workerRows = (draft.workerRows || []).filter((r) => String(r.orgId) !== String(orgId));
    scheduleAutosave();
    render();
    updateSummary();
  }

  function bindPanelEvents() {
    panelsHost()?.querySelectorAll('input, select, textarea').forEach((el) => {
      if (el.id === 'spViolSearch') return;
      el.addEventListener('input', scheduleAutosave);
      el.addEventListener('change', scheduleAutosave);
    });

    document.getElementById('spNewObjectBtn')?.addEventListener('click', () => {
      WizardModals.openQuickAdd('object');
    });

    bindOrgChipHandlers({
      addAttr: 'data-sp-add-subcontractor',
      removeAttr: 'data-sp-remove-subcontractor',
      removeTitleAttr: 'data-sp-remove-subcontractor-title',
      onAdd: addSubcontractorById,
      onRemove: removeSubcontractorById,
      onRemoveTitle: removeSubcontractorByTitle,
      newBtnId: 'spNewSubcontractorBtn',
      quickAddTarget: 'subcontractor',
    });

    bindOrgChipHandlers({
      addAttr: 'data-sp-add-worker-org',
      removeAttr: 'data-sp-remove-worker-org',
      onAdd: addWorkerFromOrg,
      onRemove: removeWorkerByOrgId,
      newBtnId: 'spNewWorkerOrgBtn',
      quickAddTarget: 'worker',
    });

    panelsHost()?.querySelectorAll('[data-sp-add-object]').forEach((chip) => {
      chip.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        addObjectById(chip.getAttribute('data-sp-add-object'));
      });
    });
    panelsHost()?.querySelectorAll('[data-sp-remove-object]').forEach((chip) => {
      chip.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        removeObjectById(chip.getAttribute('data-sp-remove-object'));
      });
    });

    panelsHost()?.querySelectorAll('[data-sp-worker-del]').forEach((btn) => {
      btn.addEventListener('click', () => {
        commitWorkerRows();
        const rowEl = btn.closest('[data-sp-worker-row]');
        const orgId = rowEl?.dataset.spWorkerOrg;
        if (orgId) {
          removeWorkerByOrgId(orgId);
          return;
        }
        const rowId = rowEl?.dataset.spWorkerRow;
        draft.workerRows = (draft.workerRows || []).filter((r) => r.id !== rowId);
        scheduleAutosave();
        render();
        updateSummary();
      });
    });
    panelsHost()?.querySelectorAll('[data-sp-worker-pb], [data-sp-worker-count]').forEach((el) => {
      el.addEventListener('input', refreshWorkerTotals);
    });

    violUi.bindViolationListEvents();
    violUi.bindViolSearchEvents();

    panelsHost()?.querySelectorAll('[data-sp-viol-fmt]').forEach((btn) => {
      btn.addEventListener('click', () => {
        if (!draft) return;
        const key = btn.getAttribute('data-sp-viol-fmt');
        draft.violationFormat = SpravkaUtils.normalizeViolationFormat(draft.violationFormat);
        if (key === 'mesto') {
          draft.violationFormat.includeMesto = !draft.violationFormat.includeMesto;
        }
        if (key === 'rule') {
          draft.violationFormat.includeRuleRef = !draft.violationFormat.includeRuleRef;
        }
        scheduleAutosave();
        render();
      });
    });

    document.getElementById('spGenerateDocx')?.addEventListener('click', async () => {
      commitStep(step);
      await saveDraft();
      try {
        await DocGenerator.generateFromSpravka(draft, catalog);
      } catch (err) {
        GazpromToast.error(err.message || 'Ошибка генерации');
      }
    });

    if (step === 6 && catalog) {
      const statusEl = document.getElementById('spSpravkaTemplateStatusText');
      const generateBtn = document.getElementById('spGenerateDocx');
      const hasTpl = typeof DocGenerator?.hasSpravkaTemplate === 'function'
        ? DocGenerator.hasSpravkaTemplate(catalog)
        : true;
      if (statusEl) {
        if (hasTpl) {
          const name = catalog.spravkaTemplateName || 'Шаблон_справки_ПБ.docx';
          statusEl.textContent = `✅ Шаблон справки: ${name}. Нажмите «Сформировать справку Word».`;
          statusEl.closest('#spSpravkaTemplateStatus').style.background = 'var(--success-soft, #e8f5e9)';
        } else {
          statusEl.textContent = '⚠️ Шаблон справки не выбран. Настройки → Шаблоны справки.';
          statusEl.closest('#spSpravkaTemplateStatus').style.background = 'var(--warning-soft, #fff8e1)';
        }
      }
      if (generateBtn) generateBtn.disabled = !hasTpl;
    }

    document.getElementById('spSaveDraft')?.addEventListener('click', async () => {
      commitStep(step);
      await saveDraft();
      await persistCatalog();
      GazpromToast.success('Черновик справки сохранён');
    });

    document.getElementById('spMarkReady')?.addEventListener('click', async () => {
      if (SpravkaUtils.isDraft(draft)) {
        draft.urlToFllACT = 'web:completed/spravka';
        draft.isDraft = false;
      } else {
        draft.urlToFllACT = null;
        draft.isDraft = true;
      }
      await saveDraft();
      await persistCatalog();
      render();
    });
  }

  function bindChrome() {
    if (chromeBound) return;
    chromeBound = true;
    const root = document.getElementById('spravkaRoot');
    root?.addEventListener('click', handleSpravkaObjectClick);
    document.getElementById('spravkaPrev')?.addEventListener('click', async () => {
      if (step === 0) return;
      commitStep(step);
      step -= 1;
      render();
    });
    document.getElementById('spravkaNext')?.addEventListener('click', async () => {
      commitStep(step);
      if (!validateStep(step)) return;
      if (step >= TOTAL_STEPS - 1) {
        goTo('home');
        return;
      }
      step += 1;
      await saveDraft();
      render();
    });
    document.querySelectorAll('#spravkaStepper .wizard-step').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const target = parseInt(btn.dataset.step, 10);
        if (Number.isNaN(target) || target === step) return;
        commitStep(step);
        if (target > step && !validateStep(step)) return;
        step = target;
        render();
      });
    });
    document.getElementById('spravkaNewBtn')?.addEventListener('click', async () => {
      const ok = await GazpromToast.confirm('Начать новую справку? Текущий черновик будет сохранён.', { confirmLabel: 'Новая справка' });
      if (!ok) return;
      commitStep(step);
      await saveDraft();
      await persistCatalog();
      draft = SpravkaUtils.createEmpty(catalog);
      step = 0;
      await saveDraft();
      render();
    });
    document.getElementById('spravkaViolFab')?.addEventListener('click', () => {
      WizardModals.openViolationEditor(null);
    });
    document.getElementById('spravkaSummaryToggle')?.addEventListener('click', () => {
      document.getElementById('spravkaSummaryPanel')?.classList.toggle('summary-panel--collapsed');
    });
  }

  async function startNew() {
    commitStep(step);
    if (draft) await saveDraft();
    draft = SpravkaUtils.createEmpty(catalog);
    step = 0;
    await saveDraft();
    render();
  }

  async function open(options = {}) {
    await loadCatalog();
    if (!GazpromStore.isReady(catalog)) {
      showEmpty(true);
      return;
    }
    showEmpty(false);
    setupModals();
    if (options.forceNew) {
      await startNew();
      return;
    }
    if (options.spravkaId) {
      const found = (catalog.spravkas || []).find((s) => s.id === options.spravkaId);
      if (!found) {
        GazpromToast.error('Справка не найдена');
        initDraft();
      } else {
        draft = SpravkaUtils.clone(found);
      }
    } else if (!options.preserveDraft || !draft) {
      initDraft();
    }
    draft.objectsCheck = SpravkaUtils.ensureObjectFields(draft.objectsCheck);
    if (!options.preserveStep) step = 0;
    render();
    bindChrome();
  }

  return { open, saveDraft };
})();
