/**
 * Редактор графика проверок (scheduleItems) — сетка по месяцам.
 */
const ScheduleEditor = (() => {
  const MONTH_NAMES = [
    'январь', 'февраль', 'март', 'апрель', 'май', 'июнь',
    'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь',
  ];

  let currentYear = new Date().getFullYear();

  function getPlanDate(item) {
    if (!item) return null;
    return item.scheduledDate || item.plannedDate || null;
  }

  function getItemMonth(item) {
    if (!item) return null;
    if (item.month != null && item.month !== '') return Number(item.month);
    const d = getPlanDate(item);
    if (!d) return null;
    return new Date(d).getMonth() + 1;
  }

  function getItemYear(item) {
    if (!item) return null;
    if (item.year != null && item.year !== '') return Number(item.year);
    const d = getPlanDate(item);
    if (!d) return null;
    return new Date(d).getFullYear();
  }

  function getItemTitle(item, catalog) {
    if (!item) return '—';
    if (item.objectCheck?.title) {
      const sub = item.objectCheck.subTitle;
      return sub ? `${item.objectCheck.title}, ${sub}` : item.objectCheck.title;
    }
    if (item.organizationTitle) return item.organizationTitle;
    const org = (catalog.organizations || []).find((o) => o.id === item.organizationId);
    return org?.title || '—';
  }

  function formatPlanDateShort(item) {
    if (!item) return '';
    const d = getPlanDate(item);
    if (!d) return '';
    const date = new Date(d);
    if (Number.isNaN(date.getTime())) return '';
    const dd = String(date.getDate()).padStart(2, '0');
    const mm = String(date.getMonth() + 1).padStart(2, '0');
    const yyyy = date.getFullYear();
    return `${dd}.${mm}.${yyyy}`;
  }

  function itemsForYear(catalog, year) {
    return (catalog.scheduleItems || []).filter((i) => i && getItemYear(i) === year);
  }

  function itemsForMonth(catalog, year, month) {
    return itemsForYear(catalog, year).filter((i) => getItemMonth(i) === month);
  }

  function ensureRoot() {
    let root = document.getElementById('scheduleEditorRoot');
    if (!root) {
      root = document.createElement('div');
      root.id = 'scheduleEditorRoot';
      root.className = 'catalog-editor-root';
      document.body.appendChild(root);
    }
    return root;
  }

  function bindClose(root, onClose) {
    root.querySelectorAll('[data-close]').forEach((el) => {
      el.addEventListener('click', onClose);
    });
  }

  function open() {
    GazpromStore.get().then((catalog) => {
      if (!GazpromStore.hasData(catalog)) {
        GazpromToast.error('Сначала загрузите данные');
        return;
      }
      showYearGrid(catalog);
    });
  }

  function showYearGrid(catalog) {
    const root = ensureRoot();
    const year = currentYear;
    const yearItems = itemsForYear(catalog, year);

    const cells = MONTH_NAMES.map((name, idx) => {
      const month = idx + 1;
      const monthItems = yearItems.filter((i) => getItemMonth(i) === month);
      const lines = monthItems.map((item) => {
        const title = AktUtils.escapeHtml(getItemTitle(item, catalog));
        const dateStr = formatPlanDateShort(item);
        const done = item.actualDate ? ' schedule-month-line--done' : '';
        return `<div class="schedule-month-line${done}">${title}${dateStr ? ` (${dateStr})` : ''}</div>`;
      });
      const content = lines.length ? lines.join('') : '<span class="schedule-month-empty">—</span>';
      const count = monthItems.length;
      const hasItems = count > 0 ? ' schedule-month-wrap--filled' : '';
      return `
        <div class="schedule-month-wrap${hasItems}">
          <div class="schedule-month-label">${name}</div>
          <div class="schedule-month-cell" role="button" tabindex="0"
               data-month="${month}" aria-label="${name}, ${count} объектов">
            <div class="schedule-month-content">${content}</div>
          </div>
        </div>`;
    }).join('');

    root.hidden = false;
    root.innerHTML = `
      <div class="catalog-editor-backdrop" data-close></div>
      <div class="catalog-editor-panel catalog-editor-panel--schedule card">
        <div class="catalog-editor-header catalog-editor-header--schedule catalog-editor-header--year">
          <h3 class="schedule-header-title">График проверок ${year}</h3>
          <div class="schedule-year-controls">
            <button type="button" class="btn-ghost btn-sm" data-year-prev aria-label="Предыдущий год">‹</button>
            <span class="schedule-year-label">${year}</span>
            <button type="button" class="btn-ghost btn-sm" data-year-next aria-label="Следующий год">›</button>
          </div>
          <button type="button" class="modal-close schedule-header-close" data-close aria-label="Закрыть">×</button>
        </div>
        <div class="catalog-editor-body schedule-editor-body">
          <p class="schedule-editor-hint">Нажмите на месяц, чтобы открыть перечень объектов и даты проверок.</p>
          <div class="schedule-year-grid">${cells}</div>
        </div>
        <div class="catalog-editor-footer">
          <button type="button" class="btn-ghost" data-close>Закрыть</button>
        </div>
      </div>
    `;

    const close = () => {
      root.hidden = true;
    };
    bindClose(root, close);

    root.querySelector('[data-year-prev]')?.addEventListener('click', () => {
      currentYear -= 1;
      showYearGrid(catalog);
    });
    root.querySelector('[data-year-next]')?.addEventListener('click', () => {
      currentYear += 1;
      showYearGrid(catalog);
    });

    root.querySelectorAll('.schedule-month-cell').forEach((cell) => {
      const month = parseInt(cell.dataset.month, 10);
      const openMonth = () => showMonthDetail(catalog, year, month);
      cell.addEventListener('click', openMonth);
      cell.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          openMonth();
        }
      });
    });
  }

  function showMonthDetail(catalog, year, month) {
    const root = ensureRoot();
    const monthItems = itemsForMonth(catalog, year, month);
    const monthName = MONTH_NAMES[month - 1];

    const rows = monthItems
      .map((item) => {
        const title = AktUtils.escapeHtml(getItemTitle(item, catalog));
        const plan = getPlanDate(item);
        const fact = item.actualDate;
        const statusClass = fact ? 'badge-green' : 'badge-orange';
        const statusText = fact ? 'Выполнено' : 'Запланировано';
        return `<tr data-id="${item.id}">
          <td>${title}</td>
          <td>${plan ? AktUtils.formatDateShort(plan) : '—'}</td>
          <td>${fact ? AktUtils.formatDateShort(fact) : '—'}</td>
          <td><span class="badge ${statusClass}">${statusText}</span></td>
          <td class="schedule-row-actions">
            <button type="button" class="btn-ghost btn-sm" data-edit="${item.id}" aria-label="Изменить">✏️</button>
            <button type="button" class="btn-ghost btn-sm modal-btn-danger" data-del="${item.id}" aria-label="Удалить">×</button>
          </td>
        </tr>`;
      })
      .join('');

    root.hidden = false;
    root.innerHTML = `
      <div class="catalog-editor-backdrop" data-close></div>
      <div class="catalog-editor-panel catalog-editor-panel--schedule card">
        <div class="catalog-editor-header catalog-editor-header--schedule">
          <button type="button" class="btn-ghost btn-sm schedule-back-btn" data-back aria-label="Назад">← Год</button>
          <h3 class="schedule-header-title">${monthName} ${year}</h3>
          <button type="button" class="modal-close schedule-header-close" data-close aria-label="Закрыть">×</button>
        </div>
        <div class="catalog-editor-body">
          <table class="list-table schedule-detail-table">
            <thead>
              <tr>
                <th>Объект</th>
                <th>План</th>
                <th>Факт</th>
                <th>Статус</th>
                <th></th>
              </tr>
            </thead>
            <tbody>${rows || '<tr><td colspan="5">Нет запланированных проверок</td></tr>'}</tbody>
          </table>
        </div>
        <div class="catalog-editor-footer">
          <button type="button" class="btn-primary" data-add>+ Добавить объект</button>
          <button type="button" class="btn-ghost" data-close>Закрыть</button>
        </div>
      </div>
    `;

    const close = () => {
      root.hidden = true;
    };
    const goBack = () => showYearGrid(catalog);

    bindClose(root, close);
    root.querySelectorAll('[data-back]').forEach((b) => b.addEventListener('click', goBack));

    root.querySelector('[data-add]')?.addEventListener('click', async () => {
      const fresh = await GazpromStore.get();
      openObjectPicker(fresh, { year, month });
    });

    root.querySelectorAll('[data-edit]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const fresh = await GazpromStore.get();
        const item = (fresh.scheduleItems || []).find((x) => x?.id === btn.dataset.edit);
        if (!item) {
          GazpromToast.error('Запись не найдена');
          return;
        }
        openForm(fresh, item, { year, month });
      });
    });

    root.querySelectorAll('[data-del]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const ok = await GazpromToast.confirm('Удалить запись графика?');
        if (!ok) return;
        const fresh = await GazpromStore.get();
        fresh.scheduleItems = (fresh.scheduleItems || []).filter((x) => x.id !== btn.dataset.del);
        await GazpromStore.set(fresh);
        GazpromStore.invalidateCache();
        await GazpromUI.refreshAll();
        showMonthDetail(await GazpromStore.get(), year, month);
      });
    });
  }

  function findObject(catalog, objectId) {
    return collectObjects(catalog).find((o) => String(o.id) === String(objectId)) || null;
  }

  async function persistScheduleItem(catalog, record, viewYear, viewMonth) {
    const fresh = await GazpromStore.get();
    const list = [...(fresh.scheduleItems || [])];
    const idx = list.findIndex((x) => x.id === record.id);
    if (idx >= 0) list[idx] = record;
    else list.push(record);
    fresh.scheduleItems = list;

    await GazpromStore.set(fresh);
    GazpromStore.invalidateCache();
    await GazpromUI.refreshAll();

    const updated = await GazpromStore.get();
    showMonthDetail(updated, Number(viewYear), Number(viewMonth));
    return record;
  }

  function buildScheduleRecord(catalog, { item, objectId, orgId, plan }) {
    const orgs = catalog.organizations || [];
    const planDate = new Date(plan + 'T12:00:00');
    if (Number.isNaN(planDate.getTime())) {
      throw new Error('Некорректная дата');
    }

    const record = item ? { ...item } : { id: AktUtils.uuid() };
    record.scheduledDate = planDate.toISOString();
    record.plannedDate = record.scheduledDate;
    record.year = planDate.getFullYear();
    record.month = planDate.getMonth() + 1;

    const resolvedObjectId = objectId || item?.objectCheck?.id || '';
    const resolvedOrgId = orgId || item?.organizationId || '';

    if (resolvedObjectId) {
      const obj = findObject(catalog, resolvedObjectId);
      if (!obj) throw new Error('Объект не найден');
      record.objectCheck = { id: obj.id, title: obj.title, subTitle: obj.subTitle || '' };
    } else {
      delete record.objectCheck;
    }

    if (resolvedOrgId) {
      const org = orgs.find((o) => String(o.id) === String(resolvedOrgId));
      record.organizationId = resolvedOrgId;
      record.organizationTitle = org?.title || '';
    } else {
      record.organizationId = null;
      record.organizationTitle = '';
    }

    if (!record.objectCheck && !record.organizationId) {
      throw new Error('Выберите объект или организацию');
    }

    return record;
  }

  function mountOverlay(html) {
    const overlay = document.createElement('div');
    overlay.className = 'catalog-form-overlay schedule-form-overlay';
    overlay.innerHTML = html;
    document.body.appendChild(overlay);
    return overlay;
  }

  function collectObjects(catalog) {
    const byId = new Map();
    (catalog.objects || []).forEach((o) => {
      if (o?.id) byId.set(o.id, o);
    });
    (catalog.scheduleItems || []).forEach((item) => {
      if (item?.objectCheck?.id) byId.set(item.objectCheck.id, item.objectCheck);
    });
    (catalog.akts || []).forEach((akt) => {
      (akt.objectsCheck || []).forEach((o) => {
        if (o?.id) byId.set(o.id, o);
      });
    });
    return [...byId.values()].sort((a, b) =>
      (a.title || '').localeCompare(b.title || '', 'ru')
    );
  }

  function getSelectionTitle(catalog, { objectId, orgId, item }) {
    if (objectId) {
      const obj = findObject(catalog, objectId);
      if (!obj) return '—';
      return obj.subTitle ? `${obj.title} — ${obj.subTitle}` : obj.title;
    }
    if (orgId) {
      const org = (catalog.organizations || []).find((o) => String(o.id) === String(orgId));
      return org?.title || '—';
    }
    if (item) return getItemTitle(item, catalog);
    return '—';
  }

  function openObjectPicker(catalog, context) {
    const objects = collectObjects(catalog);
    const orgs = catalog.organizations || [];
    const { year, month } = context;
    const monthName = MONTH_NAMES[month - 1];

    const objectRows = objects
      .map((o) => {
        const sub = o.subTitle ? `<span class="schedule-picker-sub">${AktUtils.escapeHtml(o.subTitle)}</span>` : '';
        return `<tr class="wizard-select-row schedule-picker-row" data-object-id="${o.id}" role="button" tabindex="0">
          <td>${AktUtils.escapeHtml(o.title)}${sub}</td>
        </tr>`;
      })
      .join('');

    const orgRows = orgs
      .map(
        (o) =>
          `<tr class="wizard-select-row schedule-picker-row" data-org-id="${o.id}" role="button" tabindex="0">
            <td>${AktUtils.escapeHtml(o.title)}</td>
          </tr>`
      )
      .join('');

    let bodyHtml = '';
    if (objectRows) {
      bodyHtml += `
        <p class="schedule-picker-section">Объекты проверки</p>
        <table class="list-table schedule-picker-table">
          <tbody>${objectRows}</tbody>
        </table>`;
    }
    if (orgRows) {
      bodyHtml += `
        <p class="schedule-picker-section">Организации</p>
        <table class="list-table schedule-picker-table">
          <tbody>${orgRows}</tbody>
        </table>`;
    }
    if (!bodyHtml) {
      bodyHtml = `<p class="schedule-picker-empty">Справочник объектов пуст. Добавьте объекты в разделе «Объекты» в настройках.</p>`;
    }

    const overlay = mountOverlay(`
      <div class="catalog-form-dialog catalog-form-dialog--wide card">
        <h3>Выберите объект — ${monthName} ${year}</h3>
        <div class="schedule-picker-search-wrap">
          <input type="search" class="form-control schedule-picker-search" placeholder="Поиск…" aria-label="Поиск объекта">
        </div>
        <div class="schedule-picker-list">${bodyHtml}</div>
        <div class="catalog-form-actions">
          <button type="button" class="btn-ghost" data-cancel>Отмена</button>
        </div>
      </div>
    `);

    const remove = () => overlay.remove();
    overlay.querySelector('[data-cancel]').onclick = remove;
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) remove();
    });
    overlay.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') remove();
    });

    const searchInput = overlay.querySelector('.schedule-picker-search');
    searchInput?.addEventListener('input', () => {
      const q = searchInput.value.trim().toLowerCase();
      overlay.querySelectorAll('.schedule-picker-row').forEach((row) => {
        const text = row.textContent.toLowerCase();
        row.hidden = q.length > 0 && !text.includes(q);
      });
    });

    const pickObject = async (objectId) => {
      remove();
      const fresh = await GazpromStore.get();
      openDateForm(fresh, { year, month, objectId });
    };
    const pickOrg = async (orgId) => {
      remove();
      const fresh = await GazpromStore.get();
      openDateForm(fresh, { year, month, orgId });
    };

    overlay.querySelectorAll('[data-object-id]').forEach((row) => {
      const id = row.dataset.objectId;
      const activate = () => {
        pickObject(id).catch((err) => GazpromToast.error(err?.message || 'Ошибка'));
      };
      row.addEventListener('click', activate);
      row.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          activate();
        }
      });
    });

    overlay.querySelectorAll('[data-org-id]').forEach((row) => {
      const id = row.dataset.orgId;
      const activate = () => {
        pickOrg(id).catch((err) => GazpromToast.error(err?.message || 'Ошибка'));
      };
      row.addEventListener('click', activate);
      row.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          activate();
        }
      });
    });

    setTimeout(() => searchInput?.focus(), 50);
  }

  function openDateForm(catalog, context) {
    const { year, month, objectId, orgId, item } = context;
    const y = year || getItemYear(item) || currentYear;
    const m = month || getItemMonth(item) || 1;
    const planVal = AktUtils.toDateInputValue(getPlanDate(item));
    const factVal = AktUtils.toDateInputValue(item?.actualDate);
    const defaultPlan = planVal || `${y}-${String(m).padStart(2, '0')}-15`;
    const title = getSelectionTitle(catalog, { objectId, orgId, item });
    const isEdit = !!item;

    const form = mountOverlay(`
      <div class="catalog-form-dialog card">
        <h3>${isEdit ? 'Изменить' : 'Добавить'} проверку</h3>
        <div class="form-group">
          <label>Объект</label>
          <div class="schedule-selected-object">${AktUtils.escapeHtml(title)}</div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label>План (дата)</label>
            <input type="date" class="form-control" data-plan value="${defaultPlan}">
          </div>
          <div class="form-group">
            <label>Факт (дата)</label>
            <input type="date" class="form-control" data-fact value="${factVal}">
          </div>
        </div>
        <div class="catalog-form-actions">
          <button type="button" class="btn-ghost" data-cancel>Отмена</button>
          <button type="button" class="btn-primary" data-save>Сохранить</button>
        </div>
      </div>
    `);

    const remove = () => form.remove();
    form.querySelector('[data-cancel]').onclick = remove;
    form.addEventListener('click', (e) => {
      if (e.target === form) remove();
    });
    form.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') remove();
    });

    form.querySelector('[data-save]').onclick = async () => {
      const plan = form.querySelector('[data-plan]')?.value || '';
      if (!plan) {
        GazpromToast.error('Укажите плановую дату');
        return;
      }

      try {
        const fresh = await GazpromStore.get();
        const record = buildScheduleRecord(fresh, {
          item,
          objectId,
          orgId,
          plan,
        });
        const fact = form.querySelector('[data-fact]')?.value || '';
        record.actualDate = fact ? new Date(fact + 'T12:00:00').toISOString() : null;

        await persistScheduleItem(fresh, record, record.year, record.month);
        remove();
        GazpromToast.success(isEdit ? 'Запись обновлена' : 'Объект добавлен в график');
      } catch (err) {
        GazpromToast.error(err?.message || 'Ошибка сохранения');
      }
    };

    setTimeout(() => form.querySelector('[data-plan]')?.focus(), 50);
  }

  function openForm(catalog, item, context) {
    openDateForm(catalog, {
      year: context?.year,
      month: context?.month,
      objectId: context?.objectId || item?.objectCheck?.id,
      orgId: context?.orgId || item?.organizationId,
      item,
    });
  }

  return { open };
})();
