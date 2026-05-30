/**
 * Мастер «Новый акт» — редактирование черновика из бэкапа.
 */
const WizardController = (() => {
  const TOTAL_STEPS = 6;
  let catalog = null;
  let draft = null;
  let step = 0;
  let violationObjectFilter = 'all';
  let autosaveTimer = null;
  let dirty = false;

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
      onUpdate: () => {
        render();
        updateSummary();
      },
      onQuickAdd: (type, item) => {
        if (type === 'org') {
          draft.organization = { ...item };
        }
        if (type === 'object') {
          draft.objectsCheck = [...(draft.objectsCheck || []), { ...item }];
        }
        if (type === 'commission') {
          draft.comission = [...(draft.comission || []), { ...item }];
        }
        if (type === 'pred') {
          draft.predstavitelyComission = [{ ...item }];
        }
        render();
        updateSummary();
      },
    });
  }

  function initDraft() {
    const editable = catalog?.editableAkt?.akt;
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

  async function open(aktId = null) {
    await loadCatalog();
    if (!GazpromStore.hasData(catalog)) {
      showEmpty(true);
      return;
    }
    showEmpty(false);
    if (aktId) {
      const akt = (catalog.akts || []).find((a) => a.id === aktId);
      if (!akt) {
        GazpromToast.error('Акт не найден');
        return;
      }
      draft = AktUtils.clone(akt);
      catalog.editableAkt = {
        akt: draft,
        isEditable: true,
        lastModified: new Date().toISOString(),
      };
    } else {
      initDraft();
    }
    setupModals();
    step = 0;
    violationObjectFilter = 'all';
    dirty = false;
    render();
    updateSummary();
    bindAutosaveOnPanel();
  }

  function openWithAkt(aktId) {
    return open(aktId);
  }

  function setStep(newStep) {
    commitStep(step);
    step = Math.max(0, Math.min(TOTAL_STEPS - 1, newStep));
    syncStepperUI();
    render();
    updateSummary();
  }

  function syncStepperUI() {
    document.querySelectorAll('.wizard-step').forEach((el, i) => {
      el.classList.remove('current', 'done');
      if (i < step) el.classList.add('done');
      if (i === step) el.classList.add('current');
    });
    document.querySelectorAll('.wizard-connector').forEach((el, i) => {
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

    const renderers = [
      renderStepDateCommission,
      renderStepOrganization,
      renderStepObjects,
      renderStepViolations,
      renderStepDescription,
      renderStepGenerate,
    ];
    host.innerHTML = `<div class="card wizard-panel-active">${renderers[step]()}</div>`;
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
    const occupied = AktUtils.occupiedNumbers(catalog.akts, draft.id);
    const current = parseInt(draft.number, 10) || 1;
    const nums = new Set();
    for (let n = Math.max(1, current - 3); n <= current + 10; n++) nums.add(n);
    occupied.forEach((s) => {
      const n = parseInt(s, 10);
      if (!Number.isNaN(n)) nums.add(n);
    });
    nums.add(current);
    return [...nums].sort((a, b) => a - b);
  }

  function renderStepDateCommission() {
    const people = catalog.comissionPeople || [];
    const selectedIds = new Set((draft.comission || []).map((p) => p.id));

    const chips = (draft.comission || [])
      .map(
        (p) =>
          `<span class="chip" data-person-id="${p.id}">${AktUtils.escapeHtml(p.fio)}${p.jobTitle ? ' — ' + AktUtils.escapeHtml(p.jobTitle) : ''}
            <button type="button" class="chip-remove" data-remove-person="${p.id}">×</button></span>`
      )
      .join('');

    const options = people
      .filter((p) => !selectedIds.has(p.id))
      .map(
        (p) =>
          `<option value="${p.id}">${AktUtils.escapeHtml(p.fio)} — ${AktUtils.escapeHtml(p.jobTitle || '')}</option>`
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
          <select class="form-control" id="wNumber">${numOpts}</select>
        </div>
      </div>
      <h3 style="margin-top:8px;">Состав комиссии</h3>
      <div class="chip-list" id="wCommissionChips">${chips || '<span class="wizard-hint">Добавьте членов комиссии</span>'}</div>
      <div class="wizard-add-row">
        <select class="form-control" id="wAddPerson" ${options ? '' : 'disabled'}>
          <option value="">— выбрать из справочника —</option>${options}
        </select>
        <button type="button" class="btn-secondary" id="wAddPersonBtn" ${options ? '' : 'disabled'}>+ Добавить</button>
        <button type="button" class="btn-ghost" id="wNewPersonBtn">+ Новый в справочник</button>
      </div>
    `;
  }

  function renderStepOrganization() {
    const orgs = catalog.organizations || [];
    if (!orgs.length) {
      return `<h3>Организация</h3><p class="wizard-hint">В бэкапе нет организаций.</p>`;
    }
    const rows = orgs
      .map((o) => {
        const checked = draft.organization?.id === o.id ? 'checked' : '';
        return `<tr>
          <td style="width:40px"><input type="radio" name="wOrg" value="${o.id}" ${checked}></td>
          <td>${AktUtils.escapeHtml(o.title)}</td>
          <td>${AktUtils.escapeHtml(o.shortTitle || '—')}</td>
        </tr>`;
      })
      .join('');

    return `
      <h3>Организация проверки</h3>
      <p class="wizard-hint">Выберите одну организацию (как в iOS-приложении)</p>
      <table class="list-table">
        <thead><tr><th></th><th>Наименование</th><th>Краткое</th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
      <div class="wizard-actions-row">
        <button type="button" class="btn-ghost" id="wNewOrgBtn">+ Новая организация</button>
      </div>
    `;
  }

  function renderStepObjects() {
    const objects = catalog.objects || [];
    const selectedIds = new Set((draft.objectsCheck || []).map((o) => o.id));

    if (!objects.length) {
      return `<h3>Объекты проверки</h3><p class="wizard-hint">Справочник объектов пуст.</p>`;
    }

    const rows = objects
      .map((o) => {
        const violCount = (draft.violations || []).filter(
          (v) => v.mesto === o.title || v.mesto === o.subTitle
        ).length;
        const badge =
          violCount > 0
            ? `<span class="badge badge-blue">${violCount} наруш.</span>`
            : `<span class="badge badge-green">OK</span>`;
        return `<tr>
          <td style="width:40px"><input type="checkbox" name="wObj" value="${o.id}" ${selectedIds.has(o.id) ? 'checked' : ''}></td>
          <td>${AktUtils.escapeHtml(o.title)}</td>
          <td>${AktUtils.escapeHtml(o.subTitle || '—')}</td>
          <td>${badge}</td>
        </tr>`;
      })
      .join('');

    return `
      <h3>Объекты проверки</h3>
      <p class="wizard-hint">Отметьте объекты, включённые в акт</p>
      <table class="list-table">
        <thead><tr><th></th><th>Объект</th><th>Адрес / примечание</th><th></th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
      <div class="wizard-actions-row">
        <button type="button" class="btn-ghost" id="wNewObjBtn">+ Новый объект</button>
      </div>
    `;
  }

  function renderStepViolations() {
    const objects = draft.objectsCheck || [];
    const filterOpts =
      `<option value="all" ${violationObjectFilter === 'all' ? 'selected' : ''}>Все объекты</option>` +
      objects
        .map(
          (o) =>
            `<option value="${o.id}" ${violationObjectFilter === o.id ? 'selected' : ''}>${AktUtils.escapeHtml(o.title)}</option>`
        )
        .join('');

    let violations = draft.violations || [];
    if (violationObjectFilter !== 'all') {
      const obj = objects.find((o) => o.id === violationObjectFilter);
      if (obj) {
        violations = violations.filter(
          (v) => v.mesto === obj.title || v.mesto === obj.subTitle
        );
      }
    }

    const rows = violations.length
      ? violations
          .map((v, i) => {
            const photos = v.photo?.length || 0;
            return `<tr data-violation-id="${v.id}">
              <td>${i + 1}</td>
              <td>${AktUtils.escapeHtml(v.title)}</td>
              <td>${AktUtils.escapeHtml(v.mesto || '—')}</td>
              <td>${photos ? `📷 ${photos}` : '—'}</td>
              <td class="btn-row">
                <button type="button" class="btn-ghost btn-sm w-viol-edit" data-vid="${v.id}">✏️</button>
                <button type="button" class="btn-ghost btn-sm w-viol-view" data-vid="${v.id}">Фото</button>
              </td>
            </tr>`;
          })
          .join('')
      : `<tr><td colspan="5" class="wizard-hint" style="text-align:center;padding:20px">Нет нарушений — нажмите «Добавить»</td></tr>`;

    const allPhotos = (draft.violations || []).flatMap((v) =>
      (v.photo || []).map((p, idx) => ({ v, idx, src: AktUtils.photoSrc(p) }))
    );
    const photoHtml = allPhotos.length
      ? allPhotos
          .slice(0, 16)
          .map(
            ({ src, v, idx }) =>
              `<div class="photo-slot filled wizard-photo-thumb" data-vid="${v.id}" data-pidx="${idx}" title="${AktUtils.escapeHtml(v.title)}">
                <img src="${src}" alt="">
              </div>`
          )
          .join('') +
        (allPhotos.length > 16 ? `<div class="photo-slot">+${allPhotos.length - 16}</div>` : '')
      : `<div class="photo-slot wizard-photo-add">Фото добавляются<br>в карточке нарушения</div>`;

    return `
      <h3>Нарушения</h3>
      <div class="wizard-add-row">
        <select class="form-control" id="wViolFilter" style="flex:1">${filterOpts}</select>
        <button type="button" class="btn-secondary" id="wAddViolation">+ Добавить нарушение</button>
      </div>
      <table class="list-table">
        <thead><tr><th>№</th><th>Описание</th><th>Объект</th><th>Фото</th><th></th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
      <h3 style="margin-top:20px;">Все фото акта</h3>
      <div class="photo-grid" id="wPhotoGrid">${photoHtml}</div>
    `;
  }

  function renderStepDescription() {
    const orgTitle = draft.organization?.title || '';
    const preds = (catalog.predstavitely || []).filter(
      (p) => !orgTitle || !p.organization || p.organization === orgTitle || orgTitle.includes(p.organization)
    );
    const predOpts =
      preds.length > 0
        ? preds
            .map((p) => {
              const label = `${p.fio}${p.jobTitle ? ' — ' + p.jobTitle : ''}`;
              const sel = (draft.predstavitelyComission || []).some((x) => x.id === p.id)
                ? 'selected'
                : '';
              return `<option value="${p.id}" ${sel}>${AktUtils.escapeHtml(label)}</option>`;
            })
            .join('')
        : '<option value="">— нет в справочнике —</option>';

    return `
      <h3>Описание проверки</h3>
      <div class="form-group" style="margin-bottom:16px">
        <label>Общие замечания инспектора</label>
        <textarea class="form-control" id="wDescription" rows="5" placeholder="Введите описание…">${AktUtils.escapeHtml(draft.description || '')}</textarea>
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
      <div class="form-group">
        <label>Представитель организации</label>
        <select class="form-control" id="wPred">${predOpts}</select>
      </div>
      <div class="wizard-actions-row">
        <button type="button" class="btn-ghost" id="wNewPredBtn">+ Новый представитель</button>
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
    lines.push(`<br><strong>Объекты:</strong>`);
    (draft.objectsCheck || []).forEach((o) => {
      lines.push(`• ${AktUtils.escapeHtml(o.title)} (${AktUtils.escapeHtml(o.subTitle || '')})`);
    });
    lines.push(`<br><strong>Нарушения (${(draft.violations || []).length}):</strong>`);
    (draft.violations || []).forEach((v, i) => {
      lines.push(
        `${i + 1}. ${AktUtils.escapeHtml(v.title)} — ${AktUtils.escapeHtml(v.mesto || '')} [фото: ${v.photo?.length || 0}]`
      );
    });
    if (draft.description) {
      lines.push(`<br><strong>Заключение:</strong><br>${AktUtils.escapeHtml(draft.description)}`);
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
      <p style="font-size:14px;color:var(--text-muted);margin-bottom:16px">
        Word-файл на вебе пока не формируется. Сохраните черновик или отметьте акт готовым и экспортируйте
        <strong>.gazprombackup</strong> для переноса на iPhone.
      </p>
      <div class="wizard-checklist">
        <div>✓ Акт № <strong>${AktUtils.escapeHtml(draft.number)}</strong> от ${AktUtils.formatDateShort(draft.date)}</div>
        <div>✓ ${AktUtils.escapeHtml(org)}</div>
        <div>✓ Комиссия: ${(draft.comission || []).length} чел. · Объектов: ${(draft.objectsCheck || []).length}</div>
        <div>✓ Нарушений: ${(draft.violations || []).length} · Фото: ${photos}</div>
        <div>✓ Статус: ${isDone ? '<span class="badge badge-green">Готов (веб)</span>' : '<span class="badge badge-orange">Черновик</span>'}</div>
      </div>
      <h3 style="margin-top:16px;font-size:14px">Предпросмотр содержания</h3>
      <div class="akt-preview-box">${buildAktPreviewHtml()}</div>
      <div style="display:flex;gap:12px;flex-wrap:wrap;margin-top:20px">
        <button type="button" class="btn-primary" id="wSaveDraft">💾 Сохранить черновик</button>
        <button type="button" class="btn-secondary" id="wMarkReady">${isDone ? '↩ Вернуть в черновик' : '✓ Отметить готовым'}</button>
        <button type="button" class="btn-secondary" id="wExportBackup">📤 Экспорт .gazprombackup</button>
        <button type="button" class="btn-secondary" id="wGenerateDocx">📄 Скачать Word</button>
        <button type="button" class="btn-ghost" id="wExportJson">JSON акта</button>
      </div>
    `;
  }

  function bindPanelEvents() {
    document.getElementById('wAddPersonBtn')?.addEventListener('click', addPersonFromSelect);
    document.getElementById('wAddPerson')?.addEventListener('change', (e) => {
      if (e.target.value) addPersonById(e.target.value);
    });
    document.getElementById('wNewPersonBtn')?.addEventListener('click', () =>
      WizardModals.openQuickAdd('commission')
    );
    document.getElementById('wNewOrgBtn')?.addEventListener('click', () => WizardModals.openQuickAdd('org'));
    document.getElementById('wNewObjBtn')?.addEventListener('click', () => WizardModals.openQuickAdd('object'));
    document.getElementById('wNewPredBtn')?.addEventListener('click', () => WizardModals.openQuickAdd('pred'));

    panelsHost()?.querySelectorAll('[data-remove-person]').forEach((btn) => {
      btn.addEventListener('click', () => removePerson(btn.dataset.removePerson));
    });

    document.getElementById('wViolFilter')?.addEventListener('change', (e) => {
      commitStep(3);
      violationObjectFilter = e.target.value;
      render();
      updateSummary();
    });

    document.getElementById('wAddViolation')?.addEventListener('click', () => {
      if (!(draft.objectsCheck || []).length) {
        GazpromToast.error('Сначала выберите объекты на шаге 3');
        return;
      }
      WizardModals.openViolationEditor(null);
    });
    panelsHost()?.querySelectorAll('.w-viol-edit').forEach((btn) => {
      btn.addEventListener('click', () => WizardModals.openViolationEditor(btn.dataset.vid));
    });
    panelsHost()?.querySelectorAll('.w-viol-view').forEach((btn) => {
      btn.addEventListener('click', () => showViolationPhotos(btn.dataset.vid));
    });
    panelsHost()?.querySelectorAll('.wizard-photo-thumb').forEach((el) => {
      el.addEventListener('click', () => {
        const v = (draft.violations || []).find((x) => x.id === el.dataset.vid);
        const idx = parseInt(el.dataset.pidx, 10);
        if (v?.photo?.[idx]) openLightbox(AktUtils.photoSrc(v.photo[idx]));
      });
    });

    document.getElementById('wSaveDraft')?.addEventListener('click', () => finish());
    document.getElementById('wExportJson')?.addEventListener('click', exportDraftJson);
    document.getElementById('wExportBackup')?.addEventListener('click', async () => {
      await saveDraft();
      await reloadCatalog();
      await CatalogService.exportBackup(catalog);
      GazpromToast.success('Файл .gazprombackup скачан. Перенесите на iPhone через «Поделиться».');
    });
    document.getElementById('wGenerateDocx')?.addEventListener('click', async () => {
      try {
        await saveDraft();
        await DocGenerator.generateFromAkt(draft);
      } catch (e) {
        GazpromToast.error(e.message || 'Ошибка генерации Word');
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

    if (s === 1) {
      const radio = document.querySelector('input[name="wOrg"]:checked');
      if (radio) {
        const org = (catalog.organizations || []).find((o) => o.id === radio.value);
        if (org) draft.organization = { ...org };
      }
    }

    if (s === 2) {
      const checked = [...document.querySelectorAll('input[name="wObj"]:checked')];
      draft.objectsCheck = checked
        .map((el) => (catalog.objects || []).find((o) => o.id === el.value))
        .filter(Boolean);
    }

    if (s === 4) {
      const desc = document.getElementById('wDescription');
      if (desc) draft.description = desc.value;
      const pred = document.getElementById('wPred');
      if (pred?.value) {
        const p = (catalog.predstavitely || []).find((x) => x.id === pred.value);
        if (p) draft.predstavitelyComission = [{ ...p }];
      }
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
      const occupied = AktUtils.occupiedNumbers(catalog.akts, draft.id);
      if (occupied.has(String(draft.number))) {
        GazpromToast.error(`Акт № ${draft.number} уже существует. Выберите другой номер.`);
        return false;
      }
    }
    if (s === 1 && !draft.organization?.title) {
      GazpromToast.error('Выберите организацию');
      return false;
    }
    if (s === 2 && !(draft.objectsCheck || []).length) {
      GazpromToast.error('Выберите хотя бы один объект проверки');
      return false;
    }
    return true;
  }

  async function saveDraft() {
    catalog.editableAkt = {
      akt: draft,
      isEditable: true,
      lastModified: new Date().toISOString(),
    };
    catalog.editableAktReference = {
      aktId: draft.id,
      aktNumber: draft.number,
      lastModified: catalog.editableAkt.lastModified,
    };

    const idx = (catalog.akts || []).findIndex((a) => a.id === draft.id);
    if (idx >= 0) catalog.akts[idx] = AktUtils.clone(draft);
    else catalog.akts = [...(catalog.akts || []), AktUtils.clone(draft)];

    await GazpromStore.set(catalog);
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
      `${(draft.objectsCheck || []).length}`,
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
    await saveDraft();
    if (step < TOTAL_STEPS - 1) {
      step += 1;
      render();
      updateSummary();
    } else {
      await finish();
    }
  }

  async function prev() {
    commitStep(step);
    await saveDraft();
    if (step > 0) {
      step -= 1;
      render();
      updateSummary();
    }
  }

  async function finish() {
    commitStep(step);
    if (!validateStep(step)) return;
    await saveDraft();
    await GazpromUI.refreshAll();
    GazpromToast.success(`Черновик акта № ${draft.number} сохранён`);
  }

  function exportDraftJson() {
    const blob = new Blob([JSON.stringify(draft, null, 2)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `akt_${draft.number}.json`;
    a.click();
    URL.revokeObjectURL(a.href);
  }

  function bindGlobalControls() {
    document.getElementById('wizardNext')?.addEventListener('click', () => next());
    document.getElementById('wizardPrev')?.addEventListener('click', () => prev());
    document.querySelectorAll('.wizard-step').forEach((btn) => {
      btn.addEventListener('click', () => {
        const target = parseInt(btn.dataset.step, 10);
        if (target === step) return;
        commitStep(step);
        if (target > step && !validateStep(step)) return;
        saveDraft().then(() => {
          step = target;
          render();
          updateSummary();
        });
      });
    });
    document.getElementById('wizardNewBtn')?.addEventListener('click', async () => {
      if (draft) {
        const ok = await GazpromToast.confirm(
          'Начать новый акт? Текущий шаг будет сохранён в черновик.'
        );
        if (!ok) return;
      }
      commitStep(step);
      await saveDraft();
      draft = AktUtils.createEmptyDraft(catalog);
      step = 0;
      render();
      updateSummary();
    });
  }

  bindGlobalControls();

  return { open, openWithAkt, setStep, updateSummary, scheduleAutosave };
})();
