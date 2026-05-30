/**
 * Редактор графика проверок (scheduleItems).
 */
const ScheduleEditor = (() => {
  function open() {
    GazpromStore.get().then((catalog) => {
      if (!GazpromStore.hasData(catalog)) {
        GazpromToast.error('Сначала загрузите данные');
        return;
      }
      showPanel(catalog);
    });
  }

  function showPanel(catalog) {
    let root = document.getElementById('scheduleEditorRoot');
    if (!root) {
      root = document.createElement('div');
      root.id = 'scheduleEditorRoot';
      root.className = 'catalog-editor-root';
      document.body.appendChild(root);
    }
    const items = [...(catalog.scheduleItems || [])];
    const orgs = catalog.organizations || [];

    const rows = items
      .map((i) => {
        const org =
          i.organizationTitle ||
          orgs.find((o) => o.id === i.organizationId)?.title ||
          '—';
        return `<tr data-id="${i.id}">
          <td>${i.year}</td>
          <td>${i.month || '—'}</td>
          <td>${AktUtils.escapeHtml(org)}</td>
          <td>${i.plannedDate ? AktUtils.formatDateShort(i.plannedDate) : '—'}</td>
          <td>${i.actualDate ? AktUtils.formatDateShort(i.actualDate) : '—'}</td>
          <td><button type="button" class="btn-ghost btn-sm" data-edit="${i.id}">✏️</button>
          <button type="button" class="btn-ghost btn-sm modal-btn-danger" data-del="${i.id}">×</button></td>
        </tr>`;
      })
      .join('');

    root.hidden = false;
    root.innerHTML = `
      <div class="catalog-editor-backdrop" data-close></div>
      <div class="catalog-editor-panel card">
        <div class="catalog-editor-header">
          <h3>График проверок</h3>
          <button type="button" class="modal-close" data-close>×</button>
        </div>
        <table class="list-table">
          <thead><tr><th>Год</th><th>Мес.</th><th>Организация</th><th>План</th><th>Факт</th><th></th></tr></thead>
          <tbody>${rows || '<tr><td colspan="6">Нет записей</td></tr>'}</tbody>
        </table>
        <div class="catalog-editor-footer">
          <button type="button" class="btn-primary" data-add>+ Добавить</button>
          <button type="button" class="btn-ghost" data-close>Закрыть</button>
        </div>
      </div>
    `;

    const close = () => {
      root.hidden = true;
    };
    root.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', close));
    root.querySelector('[data-add]')?.addEventListener('click', () => openForm(catalog, null, orgs));
    root.querySelectorAll('[data-edit]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const item = items.find((x) => x.id === btn.dataset.edit);
        openForm(catalog, item, orgs);
      });
    });
    root.querySelectorAll('[data-del]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const ok = await GazpromToast.confirm('Удалить запись графика?');
        if (!ok) return;
        catalog.scheduleItems = items.filter((x) => x.id !== btn.dataset.del);
        await GazpromStore.set(catalog);
        GazpromStore.invalidateCache();
        await GazpromUI.refreshAll();
        open();
      });
    });
  }

  function openForm(catalog, item, orgs) {
    const orgOpts = orgs
      .map(
        (o) =>
          `<option value="${o.id}" ${item?.organizationId === o.id ? 'selected' : ''}>${AktUtils.escapeHtml(o.title)}</option>`
      )
      .join('');
    const y = new Date().getFullYear();
    const form = document.createElement('div');
    form.className = 'catalog-form-overlay';
    form.innerHTML = `
      <div class="catalog-form-dialog card">
        <h3>${item ? 'Изменить' : 'Добавить'} план</h3>
        <div class="form-row">
          <div class="form-group"><label>Год</label><input type="number" class="form-control" id="schYear" value="${item?.year || y}"></div>
          <div class="form-group"><label>Месяц (1-12)</label><input type="number" class="form-control" id="schMonth" min="1" max="12" value="${item?.month || ''}"></div>
        </div>
        <div class="form-group"><label>Организация</label><select class="form-control" id="schOrg"><option value="">—</option>${orgOpts}</select></div>
        <div class="form-row">
          <div class="form-group"><label>План (дата)</label><input type="date" class="form-control" id="schPlan" value="${AktUtils.toDateInputValue(item?.plannedDate)}"></div>
          <div class="form-group"><label>Факт (дата)</label><input type="date" class="form-control" id="schFact" value="${AktUtils.toDateInputValue(item?.actualDate)}"></div>
        </div>
        <div class="catalog-form-actions">
          <button type="button" class="btn-ghost" data-cancel>Отмена</button>
          <button type="button" class="btn-primary" data-save>Сохранить</button>
        </div>
      </div>
    `;
    document.body.appendChild(form);
    const remove = () => form.remove();
    form.querySelector('[data-cancel]').onclick = remove;
    form.querySelector('[data-save]').onclick = async () => {
      const record = item ? { ...item } : { id: AktUtils.uuid() };
      record.year = parseInt(document.getElementById('schYear').value, 10) || y;
      const m = document.getElementById('schMonth').value;
      record.month = m ? parseInt(m, 10) : null;
      const orgId = document.getElementById('schOrg').value;
      record.organizationId = orgId || null;
      const org = orgs.find((o) => o.id === orgId);
      record.organizationTitle = org?.title || '';
      const plan = document.getElementById('schPlan').value;
      const fact = document.getElementById('schFact').value;
      record.plannedDate = plan ? new Date(plan + 'T12:00:00').toISOString() : null;
      record.actualDate = fact ? new Date(fact + 'T12:00:00').toISOString() : null;
      const list = [...(catalog.scheduleItems || [])];
      const idx = list.findIndex((x) => x.id === record.id);
      if (idx >= 0) list[idx] = record;
      else list.push(record);
      catalog.scheduleItems = list;
      await GazpromStore.set(catalog);
      GazpromStore.invalidateCache();
      await GazpromUI.refreshAll();
      remove();
      open();
    };
  }

  return { open };
})();
