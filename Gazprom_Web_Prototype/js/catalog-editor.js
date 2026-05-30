/**
 * CRUD-редакторы справочников в настройках.
 * Плитки открываются через атрибут data-catalog на элементе.
 */
const CatalogEditor = (() => {
  const TYPES = {
    commission: {
      title: 'Комиссия',
      icon: '👥',
      fields: [
        { key: 'fio',      label: 'ФИО',       required: true, placeholder: 'Иванов Иван Иванович' },
        { key: 'jobTitle', label: 'Должность',  placeholder: 'Инженер по охране труда' },
      ],
      listKey: 'comissionPeople',
      label: (r) => `${r.fio}${r.jobTitle ? ' — ' + r.jobTitle : ''}`,
      searchText: (r) => `${r.fio} ${r.jobTitle || ''}`.toLowerCase(),
    },
    organizations: {
      title: 'Организации',
      icon: '🏢',
      fields: [
        { key: 'title',      label: 'Наименование', required: true, placeholder: 'ООО «Название»' },
        { key: 'shortTitle', label: 'Краткое',       placeholder: 'ООО «Назв.»' },
      ],
      listKey: 'organizations',
      label: (r) => r.title,
      searchText: (r) => `${r.title} ${r.shortTitle || ''}`.toLowerCase(),
    },
    objects: {
      title: 'Объекты проверки',
      icon: '📍',
      fields: [
        { key: 'title',    label: 'Объект',             required: true, placeholder: 'Компрессорная станция' },
        { key: 'subTitle', label: 'Адрес / примечание', placeholder: 'г. Надым, ул. Промышленная, 5' },
      ],
      listKey: 'objects',
      label: (r) => `${r.title}${r.subTitle ? ' — ' + r.subTitle : ''}`,
      searchText: (r) => `${r.title} ${r.subTitle || ''}`.toLowerCase(),
    },
    predstavitely: {
      title: 'Представители',
      icon: '👤',
      fields: [
        { key: 'fio',          label: 'ФИО',          required: true, placeholder: 'Петров Пётр Петрович' },
        { key: 'jobTitle',     label: 'Должность',    placeholder: 'Директор' },
        { key: 'organization', label: 'Организация',  placeholder: 'ООО «…»' },
      ],
      listKey: 'predstavitely',
      label: (r) => `${r.fio}${r.organization ? ' (' + r.organization + ')' : ''}`,
      searchText: (r) => `${r.fio} ${r.jobTitle || ''} ${r.organization || ''}`.toLowerCase(),
    },
    violations: {
      title: 'Нарушения',
      icon: '⚠️',
      readonly: true, // особый режим: только просмотр
    },
  };

  let root = null;
  let escListener = null;

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
    if (escListener) {
      document.removeEventListener('keydown', escListener);
      escListener = null;
    }
  }

  function addEscListener() {
    if (escListener) document.removeEventListener('keydown', escListener);
    escListener = (e) => { if (e.key === 'Escape') close(); };
    document.addEventListener('keydown', escListener);
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

    if (typeKey === 'violations') {
      ViolationRegistry.open();
      return;
    }

    GazpromStore.get().then((catalog) => {
      if (!catalog) {
        GazpromToast.error('Нет данных в базе');
        return;
      }
      renderList(cfg, catalog, '');
    });
  }

  /* ——— Стандартный CRUD список ——— */

  function renderList(cfg, catalog, query) {
    const el = ensureRoot();
    el.hidden = false;
    addEscListener();

    const all = [...(catalog[cfg.listKey] || [])];
    const q = query.toLowerCase();
    const filtered = q
      ? all.filter((item) => (cfg.searchText ? cfg.searchText(item) : cfg.label(item).toLowerCase()).includes(q))
      : all;

    const rows = filtered
      .map(
        (item) => `
      <tr data-id="${item.id}">
        <td>${escHtml(cfg.label(item))}</td>
        <td class="btn-row">
          <button type="button" class="btn-ghost btn-sm" data-edit="${item.id}">Изменить</button>
          <button type="button" class="btn-ghost btn-sm modal-btn-danger" data-del="${item.id}">Удалить</button>
        </td>
      </tr>`
      )
      .join('');

    const countHint = query
      ? `${filtered.length} из ${all.length}`
      : `${all.length} записей`;

    el.innerHTML = `
      <div class="catalog-editor-backdrop" data-close></div>
      <div class="catalog-editor-panel card">
        <div class="catalog-editor-header">
          <div>
            <h3>${cfg.icon || ''} ${cfg.title}</h3>
            <small class="catalog-editor-count" style="color:var(--text-muted);">${countHint}</small>
          </div>
          <button type="button" class="modal-close" data-close>×</button>
        </div>
        <div class="catalog-editor-search-bar">
          <input type="search" class="form-control catalog-search-input" placeholder="🔍 Поиск…" value="${escHtml(query)}" autocomplete="off">
        </div>
        <div class="catalog-editor-body">
          <table class="list-table">
            <thead><tr><th>Запись</th><th></th></tr></thead>
            <tbody>${rows || `<tr><td colspan="2" style="text-align:center;padding:32px;color:var(--text-muted);">${query ? 'Ничего не найдено' : 'Нет записей — нажмите «+ Добавить»'}</td></tr>`}</tbody>
          </table>
        </div>
        <div class="catalog-editor-footer">
          <button type="button" class="btn-primary" data-add>+ Добавить</button>
          <button type="button" class="btn-ghost" data-close>Закрыть</button>
        </div>
      </div>
    `;

    el.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', close));

    const searchInput = el.querySelector('.catalog-search-input');
    searchInput?.addEventListener('input', (e) => renderList(cfg, catalog, e.target.value.trim()));

    el.querySelector('[data-add]')?.addEventListener('click', () => openForm(cfg, catalog, null, query));

    el.querySelectorAll('[data-edit]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const item = all.find((x) => x.id === btn.dataset.edit);
        openForm(cfg, catalog, item, query);
      });
    });

    el.querySelectorAll('[data-del]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const item = all.find((x) => x.id === btn.dataset.del);
        const ok = await GazpromToast.confirm(
          `Удалить запись?\n«${cfg.label(item)}»`,
          { confirmLabel: 'Удалить', danger: true }
        );
        if (!ok) return;
        const next = all.filter((x) => x.id !== btn.dataset.del);
        await saveList(catalog, cfg.listKey, next);
        const fresh = await GazpromStore.get();
        renderList(cfg, fresh, query);
      });
    });
  }

  /* ——— Форма добавления / редактирования ——— */

  function openForm(cfg, catalog, item, prevQuery = '') {
    const fieldsHtml = cfg.fields
      .map(
        (f) => `
      <div class="form-group">
        <label class="form-label">${f.label}${f.required ? ' <span style="color:var(--danger)">*</span>' : ''}</label>
        <input class="form-control" data-field="${f.key}"
               value="${escHtml(item?.[f.key] || '')}"
               placeholder="${escHtml(f.placeholder || '')}"
               ${f.required ? 'required' : ''}>
      </div>`
      )
      .join('');

    const form = document.createElement('div');
    form.className = 'catalog-form-overlay';
    form.innerHTML = `
      <div class="catalog-form-dialog card">
        <h3>${item ? 'Изменить запись' : 'Добавить запись'}</h3>
        ${fieldsHtml}
        <div class="catalog-form-actions">
          <button type="button" class="btn-ghost" data-cancel>Отмена</button>
          <button type="button" class="btn-primary" data-save>${item ? 'Сохранить' : 'Добавить'}</button>
        </div>
      </div>
    `;
    document.body.appendChild(form);

    const firstInput = form.querySelector('input');
    setTimeout(() => firstInput?.focus(), 50);

    const remove = () => form.remove();
    form.querySelector('[data-cancel]').onclick = remove;

    form.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') remove();
      if (e.key === 'Enter' && !e.shiftKey) form.querySelector('[data-save]')?.click();
    });

    form.querySelector('[data-save]').onclick = async () => {
      const record = item ? { ...item } : { id: AktUtils.uuid() };
      for (const f of cfg.fields) {
        const input = form.querySelector(`[data-field="${f.key}"]`);
        record[f.key] = input?.value?.trim() || '';
        if (f.required && !record[f.key]) {
          GazpromToast.error(`Заполните поле: ${f.label}`);
          input?.focus();
          return;
        }
      }
      const list = [...(catalog[cfg.listKey] || [])];
      const idx = list.findIndex((x) => x.id === record.id);
      if (idx >= 0) list[idx] = record;
      else list.push(record);
      await saveList(catalog, cfg.listKey, list);
      remove();
      const fresh = await GazpromStore.get();
      renderList(cfg, fresh, prevQuery);
    };
  }

  /* ——— Привязка тайлов через data-catalog ——— */

  function bindSettingsTiles() {
    document.querySelectorAll('[data-catalog]').forEach((tile) => {
      const key = tile.dataset.catalog;
      tile.addEventListener('click', () => open(key));
      tile.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(key); }
      });
    });
  }

  function escHtml(s) {
    return String(s ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  return { open, bindSettingsTiles, TYPES };
})();
