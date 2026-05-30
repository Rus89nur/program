/**
 * CRUD-редакторы справочников в настройках.
 */
const CatalogEditor = (() => {
  const TYPES = {
    commission: {
      title: 'Комиссия',
      fields: [
        { key: 'fio', label: 'ФИО', required: true },
        { key: 'jobTitle', label: 'Должность' },
      ],
      listKey: 'comissionPeople',
      label: (r) => `${r.fio} — ${r.jobTitle || ''}`,
    },
    organizations: {
      title: 'Организации',
      fields: [
        { key: 'title', label: 'Наименование', required: true },
        { key: 'shortTitle', label: 'Краткое' },
      ],
      listKey: 'organizations',
      label: (r) => r.title,
    },
    objects: {
      title: 'Объекты',
      fields: [
        { key: 'title', label: 'Объект', required: true },
        { key: 'subTitle', label: 'Адрес / примечание' },
      ],
      listKey: 'objects',
      label: (r) => `${r.title}${r.subTitle ? ' — ' + r.subTitle : ''}`,
    },
    predstavitely: {
      title: 'Представители',
      fields: [
        { key: 'fio', label: 'ФИО', required: true },
        { key: 'jobTitle', label: 'Должность' },
        { key: 'organization', label: 'Организация' },
      ],
      listKey: 'predstavitely',
      label: (r) => `${r.fio} (${r.organization || '—'})`,
    },
  };

  let root = null;

  function ensureRoot() {
    if (root) return root;
    root = document.createElement('div');
    root.id = 'catalogEditorRoot';
    root.className = 'catalog-editor-root';
    root.hidden = true;
    document.body.appendChild(root);
    return root;
  }

  function close() {
    if (root) {
      root.hidden = true;
      root.innerHTML = '';
    }
  }

  async function saveList(catalog, listKey, list) {
    catalog[listKey] = list;
    await GazpromStore.set(catalog);
    GazpromStore.invalidateCache();
    await GazpromUI.refreshAll();
  }

  function open(typeKey) {
    const cfg = TYPES[typeKey];
    if (!cfg) return;

    GazpromStore.get().then((catalog) => {
      if (!catalog) {
        GazpromToast.error('Сначала загрузите резервную копию');
        return;
      }
      render(cfg, catalog);
    });
  }

  function render(cfg, catalog) {
    const el = ensureRoot();
    el.hidden = false;
    const list = [...(catalog[cfg.listKey] || [])];

    const rows = list
      .map(
        (item) => `
      <tr data-id="${item.id}">
        <td>${AktUtils.escapeHtml(cfg.label(item))}</td>
        <td class="btn-row">
          <button type="button" class="btn-ghost btn-sm" data-edit="${item.id}">Изменить</button>
          <button type="button" class="btn-ghost btn-sm modal-btn-danger" data-del="${item.id}">Удалить</button>
        </td>
      </tr>`
      )
      .join('');

    el.innerHTML = `
      <div class="catalog-editor-backdrop" data-close></div>
      <div class="catalog-editor-panel card">
        <div class="catalog-editor-header">
          <h3>${cfg.title}</h3>
          <button type="button" class="modal-close" data-close>×</button>
        </div>
        <div class="catalog-editor-body">
          <table class="list-table">
            <thead><tr><th>Запись</th><th></th></tr></thead>
            <tbody>${rows || '<tr><td colspan="2">Нет записей</td></tr>'}</tbody>
          </table>
        </div>
        <div class="catalog-editor-footer">
          <button type="button" class="btn-primary" data-add>+ Добавить</button>
          <button type="button" class="btn-ghost" data-close>Закрыть</button>
        </div>
      </div>
    `;

    el.querySelectorAll('[data-close]').forEach((b) => {
      b.addEventListener('click', close);
    });
    el.querySelector('[data-add]')?.addEventListener('click', () => openForm(cfg, catalog, null));
    el.querySelectorAll('[data-edit]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const item = list.find((x) => x.id === btn.dataset.edit);
        openForm(cfg, catalog, item);
      });
    });
    el.querySelectorAll('[data-del]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const ok = await GazpromToast.confirm('Удалить запись?', { confirmLabel: 'Удалить' });
        if (!ok) return;
        const next = list.filter((x) => x.id !== btn.dataset.del);
        await saveList(catalog, cfg.listKey, next);
        open(typeKeyFromList(cfg.listKey));
      });
    });
  }

  function typeKeyFromList(listKey) {
    return Object.keys(TYPES).find((k) => TYPES[k].listKey === listKey) || listKey;
  }

  function openForm(cfg, catalog, item) {
    const fieldsHtml = cfg.fields
      .map(
        (f) => `
      <div class="form-group">
        <label>${f.label}</label>
        <input class="form-control" data-field="${f.key}" value="${AktUtils.escapeHtml(item?.[f.key] || '')}">
      </div>`
      )
      .join('');

    const form = document.createElement('div');
    form.className = 'catalog-form-overlay';
    form.innerHTML = `
      <div class="catalog-form-dialog card">
        <h3>${item ? 'Изменить' : 'Добавить'}</h3>
        ${fieldsHtml}
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
      for (const f of cfg.fields) {
        const input = form.querySelector(`[data-field="${f.key}"]`);
        record[f.key] = input?.value?.trim() || '';
        if (f.required && !record[f.key]) {
          GazpromToast.error(`Заполните: ${f.label}`);
          return;
        }
      }
      const list = [...(catalog[cfg.listKey] || [])];
      const idx = list.findIndex((x) => x.id === record.id);
      if (idx >= 0) list[idx] = record;
      else list.push(record);
      await saveList(catalog, cfg.listKey, list);
      remove();
      close();
      const typeKey = Object.keys(TYPES).find((k) => TYPES[k].listKey === cfg.listKey);
      open(typeKey);
    };
  }

  function bindSettingsTiles() {
    const map = [
      { sel: '#screen-settings .settings-tile:nth-child(1)', key: 'commission' },
      { sel: '#screen-settings .settings-tile:nth-child(2)', key: 'organizations' },
      { sel: '#screen-settings .settings-tile:nth-child(3)', key: 'objects' },
      { sel: '#screen-settings .settings-tile:nth-child(5)', key: 'predstavitely' },
    ];
    map.forEach(({ sel, key }) => {
      document.querySelector(sel)?.addEventListener('click', () => open(key));
    });
  }

  return { open, bindSettingsTiles, TYPES };
})();
