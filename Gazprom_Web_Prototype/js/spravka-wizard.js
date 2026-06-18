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
      openLightbox: () => {},
      saveDraft,
      onUpdate: () => {
        render();
        updateSummary();
      },
      onQuickAdd: (type, item) => {
        if (type === 'object' && item?.id) {
          addObjectById(item.id);
        }
      },
    });
  }

  function initDraft() {
    const editable = SpravkaUtils.getEditableSpravka(catalog);
    draft = editable ? SpravkaUtils.clone(editable) : SpravkaUtils.createEmpty(catalog);
    draft.objectsCheck = SpravkaUtils.ensureObjectFields(draft.objectsCheck);
    draft.workerRows = (draft.workerRows || []).map(SpravkaUtils.normalizeWorkerRow);
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
      draft.subcontractorsList = document.getElementById('spSubcontractors')?.value || '';
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
        orgId: existing?.orgId || '',
        orgName: rowEl.querySelector('[data-sp-worker-name]')?.value?.trim() || '',
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
    if (!selected.length) {
      return '<p class="wizard-hint">Выберите объекты из справочника ниже</p>';
    }
    return selected.map((obj, idx) => `
      <div class="spravka-object-card card" data-sp-object-card="${obj.id}">
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
      .map((o) => `<button type="button" class="chip chip-removable" data-sp-remove-object="${AktUtils.escapeHtml(String(o.id))}" title="Убрать">${AktUtils.escapeHtml(o.title)}</button>`)
      .join('');

    const catalogChips = objects
      .filter((o) => !selectedIds.has(String(o.id)))
      .map((o) => `<button type="button" class="chip chip-catalog" data-sp-add-object="${AktUtils.escapeHtml(String(o.id))}" title="Добавить">${AktUtils.escapeHtml(o.title)}${o.subTitle ? ' — ' + AktUtils.escapeHtml(o.subTitle) : ''}</button>`)
      .join('');

    return `
      <h3>Объекты строительства</h3>
      <p class="wizard-hint">Можно выбрать несколько объектов — в отличие от полного акта проверки</p>
      <div class="chip-list" id="spObjectChips">${selectedChips || '<span class="wizard-hint">Объекты не выбраны</span>'}</div>
      <div class="commission-divider"></div>
      <div class="commission-catalog-section">
        <div class="commission-catalog-header">
          <span class="commission-catalog-label">Добавить из справочника</span>
          <button type="button" class="btn-ghost" id="spNewObjectBtn">+ В справочник</button>
        </div>
        <div class="chip-list">${catalogChips || '<span class="wizard-hint">Все объекты уже добавлены</span>'}</div>
      </div>
      <div class="spravka-object-cards" style="margin-top:20px;display:flex;flex-direction:column;gap:12px">
        ${renderObjectDetailsHtml()}
      </div>
    `;
  }

  function renderStepSubcontractors() {
    return `
      <h3>Основные субподрядчики</h3>
      <p class="wizard-hint">Список субподрядчиков на объектах (через запятую или с новой строки)</p>
      <textarea class="form-control" id="spSubcontractors" rows="5" placeholder="ООО «ГСП-1», ООО «ГСП-6», ООО «ССК «Газрегион»…">${AktUtils.escapeHtml(draft.subcontractorsList || '')}</textarea>
    `;
  }

  function renderWorkerRowHtml(row, idx) {
    return `
      <tr data-sp-worker-row="${row.id}">
        <td>${idx + 1}.</td>
        <td><input class="form-control form-control--sm" data-sp-worker-name value="${AktUtils.escapeHtml(row.orgName)}" placeholder="Организация"></td>
        <td><input class="form-control form-control--sm" type="number" min="0" data-sp-worker-pb value="${row.pbCount ?? ''}" placeholder="0"></td>
        <td><input class="form-control form-control--sm" type="number" min="0" data-sp-worker-count value="${row.workersCount ?? ''}" placeholder="0"></td>
        <td><button type="button" class="btn-ghost btn-sm" data-sp-worker-del aria-label="Удалить">🗑</button></td>
      </tr>
    `;
  }

  function renderStepWorkers() {
    const rows = draft.workerRows || [];
    const totals = SpravkaUtils.workerTotals(rows);
    const orgOptions = (catalog.organizations || [])
      .map((o) => `<option value="${AktUtils.escapeHtml(o.id)}">${AktUtils.escapeHtml(o.title)}</option>`)
      .join('');

    return `
      <h3>Работники на объекте</h3>
      <p class="wizard-hint">Укажите численность по организациям: специалисты по ПБ и работники</p>
      <div class="spravka-workers-toolbar" style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px">
        <select class="form-control" id="spWorkerOrgPick" style="max-width:320px">
          <option value="">— Организация из справочника —</option>
          ${orgOptions}
        </select>
        <button type="button" class="btn-secondary btn-sm" id="spWorkerAddOrg">+ Из справочника</button>
        <button type="button" class="btn-ghost btn-sm" id="spWorkerAddBlank">+ Пустая строка</button>
      </div>
      <div class="card card--flush">
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
      </div>
    `;
  }

  function filterViolations(list, query) {
    const q = String(query || '').trim().toLowerCase();
    if (!q) return list;
    return list.filter((v) =>
      [v.title, v.mesto, v.urlToPravilo, v.vid, v.formulaFromRules]
        .some((part) => String(part || '').toLowerCase().includes(q))
    );
  }

  function renderViolCard(v, num) {
    return `
      <div class="viol-card" data-violation-id="${v.id}" role="button" tabindex="0">
        <div class="viol-card-num">${num}</div>
        <div class="viol-card-body">
          <div class="viol-card-title">${AktUtils.escapeHtml(v.title)}</div>
          <div class="viol-card-meta"><span class="viol-card-mesto">📍 ${v.mesto ? AktUtils.escapeHtml(v.mesto) : '—'}</span></div>
        </div>
        <div class="viol-card-actions">
          <button type="button" class="btn-ghost btn-sm sp-viol-edit" data-vid="${v.id}" title="Редактировать">✏️</button>
          <button type="button" class="btn-ghost btn-sm sp-viol-del" data-vid="${v.id}" title="Удалить">🗑</button>
        </div>
      </div>
    `;
  }

  function renderStepViolations() {
    const all = draft.violations || [];
    const filtered = filterViolations(all, violSearchQuery);
    const cards = filtered.length
      ? filtered.map((v) => renderViolCard(v, all.indexOf(v) + 1)).join('')
      : `<div class="viol-empty"><div class="viol-empty-text">${all.length ? 'Ничего не найдено' : 'Нарушения не добавлены'}</div></div>`;

    return `
      <div class="viol-step-header">
        <h3 style="margin:0">Нарушения <span class="viol-total-badge">${all.length}</span></h3>
      </div>
      ${all.length ? `<input type="search" class="form-control" id="spViolSearch" placeholder="🔍 Поиск…" value="${AktUtils.escapeHtml(violSearchQuery)}">` : ''}
      <div class="viol-cards-list" id="spViolList">${cards}</div>
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
    renderStepViolations,
    renderStepRemarks,
    renderStepGenerate,
  ];

  function renderPanel() {
    const host = panelsHost();
    if (!host) return;
    host.innerHTML = `<div class="card wizard-panel-active">${STEP_RENDERERS[step]()}</div>`;
    bindPanelEvents();
    syncViolFab();
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
    commitObjectDetails();
    draft.objectsCheck = (draft.objectsCheck || []).filter((o) => String(o.id) !== String(id));
    scheduleAutosave();
    render();
    updateSummary();
  }

  function addWorkerFromOrg(orgId) {
    const org = (catalog.organizations || []).find((o) => o.id === orgId);
    if (!org) return;
    if ((draft.workerRows || []).some((r) => r.orgId === orgId)) {
      GazpromToast.info('Организация уже в таблице');
      return;
    }
    draft.workerRows = [...(draft.workerRows || []), SpravkaUtils.normalizeWorkerRow({
      orgId: org.id,
      orgName: org.title,
    })];
    scheduleAutosave();
    render();
  }

  function addBlankWorkerRow() {
    draft.workerRows = [...(draft.workerRows || []), SpravkaUtils.normalizeWorkerRow({ orgName: '' })];
    scheduleAutosave();
    render();
  }

  function handleSpravkaRootClick(e) {
    const addChip = e.target.closest('[data-sp-add-object]');
    if (addChip) {
      e.preventDefault();
      addObjectById(addChip.getAttribute('data-sp-add-object'));
      return;
    }
    const removeChip = e.target.closest('[data-sp-remove-object]');
    if (removeChip) {
      e.preventDefault();
      removeObjectById(removeChip.getAttribute('data-sp-remove-object'));
    }
  }

  function bindPanelEvents() {
    panelsHost()?.querySelectorAll('input, select, textarea').forEach((el) => {
      el.addEventListener('input', scheduleAutosave);
      el.addEventListener('change', scheduleAutosave);
    });

    document.getElementById('spNewObjectBtn')?.addEventListener('click', () => {
      WizardModals.openQuickAdd('object');
    });

    document.getElementById('spWorkerAddOrg')?.addEventListener('click', () => {
      const orgId = document.getElementById('spWorkerOrgPick')?.value;
      if (!orgId) {
        GazpromToast.error('Выберите организацию');
        return;
      }
      addWorkerFromOrg(orgId);
    });
    document.getElementById('spWorkerAddBlank')?.addEventListener('click', addBlankWorkerRow);

    panelsHost()?.querySelectorAll('[data-sp-worker-del]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const rowId = btn.closest('[data-sp-worker-row]')?.dataset.spWorkerRow;
        draft.workerRows = (draft.workerRows || []).filter((r) => r.id !== rowId);
        scheduleAutosave();
        render();
      });
    });
    panelsHost()?.querySelectorAll('[data-sp-worker-pb], [data-sp-worker-count], [data-sp-worker-name]').forEach((el) => {
      el.addEventListener('input', refreshWorkerTotals);
    });

    document.getElementById('spViolSearch')?.addEventListener('input', (e) => {
      violSearchQuery = e.target.value;
      const list = document.getElementById('spViolList');
      if (!list) return;
      const all = draft.violations || [];
      const filtered = filterViolations(all, violSearchQuery);
      list.innerHTML = filtered.length
        ? filtered.map((v) => renderViolCard(v, all.indexOf(v) + 1)).join('')
        : `<div class="viol-empty"><div class="viol-empty-text">Ничего не найдено</div></div>`;
      bindViolationEvents();
    });

    bindViolationEvents();

    document.getElementById('spGenerateDocx')?.addEventListener('click', async () => {
      commitStep(step);
      await saveDraft();
      try {
        await DocGenerator.generateFromSpravka(draft, catalog);
      } catch (err) {
        GazpromToast.error(err.message || 'Ошибка генерации');
      }
    });

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

  function bindViolationEvents() {
    panelsHost()?.querySelectorAll('.sp-viol-edit').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        WizardModals.openViolationEditor(btn.dataset.vid);
      });
    });
    panelsHost()?.querySelectorAll('.sp-viol-del').forEach((btn) => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const ok = await GazpromToast.confirm('Удалить нарушение?', { danger: true, confirmLabel: 'Удалить' });
        if (!ok) return;
        draft.violations = (draft.violations || []).filter((v) => v.id !== btn.dataset.vid);
        scheduleAutosave();
        render();
      });
    });
    panelsHost()?.querySelectorAll('.viol-card[data-violation-id]').forEach((card) => {
      card.addEventListener('click', () => WizardModals.openViolationEditor(card.dataset.violationId));
      card.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          WizardModals.openViolationEditor(card.dataset.violationId);
        }
      });
    });
  }

  function bindChrome() {
    if (chromeBound) return;
    chromeBound = true;
    const root = document.getElementById('spravkaRoot');
    root?.addEventListener('click', handleSpravkaRootClick);
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
    } else {
      initDraft();
    }
    draft.objectsCheck = SpravkaUtils.ensureObjectFields(draft.objectsCheck);
    if (!options.preserveStep) step = 0;
    render();
    bindChrome();
  }

  return { open, saveDraft };
})();
