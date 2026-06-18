/**
 * ViolationRegistry — реестр нарушений.
 *
 * Структура записи (совместима с iOS Excel-форматом):
 *   { id, number, title, subTitle, description, vid, formulaFromRules }
 *
 * Хранится в: catalog.violationRegistry (IndexedDB через GazpromStore)
 * Импорт/Экспорт: Excel (.xlsx) через SheetJS (CDN), JSON
 * UI: встроенный экран #screen-violations
 */
const ViolationRegistry = (() => {
  const LIST_KEY = 'violationRegistry';
  const XLSX_LOCAL = './assets/vendor/xlsx.full.min.js';

  /* ——— Хранилище ——— */

  async function getAll() {
    const catalog = await GazpromStore.get();
    return catalog?.[LIST_KEY] || [];
  }

  async function saveAll(list, { markCustom = true, keepDraft = true } = {}) {
    const catalog = await GazpromStore.get();
    catalog[LIST_KEY] = list;
    if (markCustom && typeof DefaultsBootstrap !== 'undefined') {
      DefaultsBootstrap.markRegistryCustom(catalog);
    }
    await GazpromStore.set(catalog, { skipPhotoIngest: true, keepDraft });
    GazpromStore.invalidateCache();
  }

  /* ——— CRUD ——— */

  async function addItem(item) {
    const list = await getAll();
    const maxNum = Math.max(0, ...list.map((x) => x.number || 0));
    const newItem = { id: AktUtils.uuid(), number: maxNum + 1, ...item };
    list.push(newItem);
    await saveAll(list);
    return newItem;
  }

  async function updateItem(id, fields) {
    const list = await getAll();
    const idx = list.findIndex((x) => x.id === id);
    if (idx < 0) return;
    list[idx] = { ...list[idx], ...fields };
    await saveAll(list);
  }

  async function deleteItem(id) {
    const list = await getAll();
    await saveAll(list.filter((x) => x.id !== id));
  }

  function findByFormulation(list, title, subTitle) {
    const t = String(title || '').trim();
    const s = String(subTitle || '').trim();
    if (!t) return null;
    const exact = (list || []).find(
      (r) => r.title?.trim() === t && (r.subTitle || '').trim() === s
    );
    if (exact) return exact;
    if (!s) return null;
    return (list || []).find((r) => r.title?.trim() === t && !(r.subTitle || '').trim()) || null;
  }

  /**
   * Сохранить вид нарушения в реестре (для всех будущих актов) и в классификаторе.
   * Ищет запись по id или по паре «формулировка + ссылка на правило».
   */
  async function bindVidToRegistryItem(catalog, { registryId, title, subTitle, vid }) {
    const normalizedVid = String(vid || '').trim();
    if (!normalizedVid || !catalog) return false;

    if (typeof ViolationTypes !== 'undefined') {
      ViolationTypes.ensureActiveType(catalog, normalizedVid);
    }

    const list = [...(catalog.violationRegistry || [])];
    let item = registryId ? list.find((r) => r.id === registryId) : null;
    if (!item) item = findByFormulation(list, title, subTitle);
    if (!item) {
      await GazpromStore.set(catalog, { skipPhotoIngest: true, keepDraft: true });
      GazpromStore.invalidateCache();
      return false;
    }

    item.vid = normalizedVid;
    catalog.violationRegistry = list;
    if (typeof DefaultsBootstrap !== 'undefined') {
      DefaultsBootstrap.markRegistryCustom(catalog);
    }
    await GazpromStore.set(catalog, { skipPhotoIngest: true, keepDraft: true });
    GazpromStore.invalidateCache();
    return true;
  }

  /* ——— SheetJS lazy loader ——— */

  async function loadXlsx() {
    if (typeof XLSX !== 'undefined') return XLSX;
    GazpromToast.info('Загрузка библиотеки Excel…');
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = XLSX_LOCAL;
      const timer = setTimeout(() => {
        reject(new Error('Время ожидания загрузки SheetJS истекло. Проверьте интернет.'));
      }, 15000);
      s.onload = () => {
        clearTimeout(timer);
        if (typeof XLSX === 'undefined') {
          reject(new Error('SheetJS загружен, но объект XLSX не найден.'));
        } else {
          resolve(XLSX);
        }
      };
      s.onerror = () => {
        clearTimeout(timer);
        reject(new Error('Не удалось загрузить SheetJS. Проверьте интернет-соединение.'));
      };
      document.head.appendChild(s);
    });
  }

  /* ——— Импорт из Excel ——— */

  async function importFromExcel(file, { replace = true } = {}) {
    const xlsx = await loadXlsx();
    const buf = await file.arrayBuffer();
    // SheetJS требует Uint8Array, а не ArrayBuffer напрямую
    const wb = xlsx.read(new Uint8Array(buf), { type: 'array' });
    const ws = wb.Sheets[wb.SheetNames[0]];
    const rows = xlsx.utils.sheet_to_json(ws, { header: 1, defval: '' });

    if (rows.length < 2) throw new Error('Файл пустой или не содержит данных');

    const header = rows[0].map((h) => String(h).trim().toLowerCase());
    const colMap = {
      number:           findCol(header, ['№', '#', 'number', 'номер']),
      title:            findCol(header, ['формулировка несоответствия', 'формулировка', 'title', 'наименование']),
      subTitle:         findCol(header, ['ссылка на нормативный документ', 'ссылка', 'норм', 'subtitle', 'document']),
      description:      findCol(header, ['примечание', 'description', 'note', 'прим']),
      vid:              findCol(header, ['вид нарушения', 'вид', 'vid', 'type']),
      formulaFromRules: findCol(header, ['формулировка из правил', 'формулировка правил', 'formula']),
    };

    const imported = [];
    for (let i = 1; i < rows.length; i++) {
      const row = rows[i];
      const title = getStr(row, colMap.title);
      if (!title) continue;
      imported.push({
        id:               AktUtils.uuid(),
        number:           parseInt(getStr(row, colMap.number), 10) || null,
        title,
        subTitle:         getStr(row, colMap.subTitle),
        description:      getStr(row, colMap.description),
        vid:              getStr(row, colMap.vid),
        formulaFromRules: getStr(row, colMap.formulaFromRules),
      });
    }

    if (!imported.length) throw new Error('Не найдено ни одного нарушения в файле');

    const catalog = await GazpromStore.get();
    if (replace) {
      catalog[LIST_KEY] = imported;
    } else {
      const merged = [...(catalog[LIST_KEY] || [])];
      for (const item of imported) {
        const dup = merged.find((x) => x.title === item.title && x.subTitle === item.subTitle);
        if (!dup) merged.push(item);
      }
      catalog[LIST_KEY] = merged;
    }

    if (typeof DefaultsBootstrap !== 'undefined') {
      await DefaultsBootstrap.saveCustomRegistryPreset(file?.name || 'Импорт Excel', catalog[LIST_KEY]);
    } else {
      await GazpromStore.set(catalog);
      GazpromStore.invalidateCache();
    }

    await GazpromUI.refreshAll();
    return imported.length;
  }

  function findCol(header, variants) {
    for (const v of variants) {
      const idx = header.findIndex((h) => h.includes(v));
      if (idx >= 0) return idx;
    }
    return -1;
  }

  function getStr(row, col) {
    if (col < 0 || col >= row.length) return '';
    const v = row[col];
    if (v === null || v === undefined || v === '-' || v === '--') return '';
    return String(v).trim();
  }

  /* ——— Экспорт в Excel ——— */

  async function exportToExcel() {
    const xlsx = await loadXlsx();
    const catalog = await GazpromStore.get();
    if (catalog && typeof ViolationTypes !== 'undefined') ViolationTypes.ensureCatalog(catalog);
    const list = await getAll();
    const formatVid = (raw) => {
      if (!raw) return '';
      if (catalog && typeof ViolationTypes !== 'undefined') {
        return ViolationTypes.resolveVid(catalog, raw) || raw;
      }
      return raw;
    };
    const rows = [
      ['№', 'Формулировка несоответствия', 'Ссылка на нормативный документ', 'Примечание', 'Вид нарушения', 'Формулировка из правил'],
      ...list.map((v) => [
        v.number || '',
        v.title || '',
        v.subTitle || '',
        v.description || '',
        formatVid(v.vid),
        v.formulaFromRules || '',
      ]),
    ];
    const ws = xlsx.utils.aoa_to_sheet(rows);
    ws['!cols'] = [{ wch: 5 }, { wch: 60 }, { wch: 50 }, { wch: 30 }, { wch: 40 }, { wch: 50 }];
    const wb = xlsx.utils.book_new();
    xlsx.utils.book_append_sheet(wb, ws, 'Реестр нарушений');
    xlsx.writeFile(wb, 'Реестр_нарушений.xlsx');
  }

  /* ——— Вход в экран ——— */

  function open() {
    if (typeof DefaultsBootstrap !== 'undefined' && typeof DefaultsBootstrap.openRegistryModal === 'function') {
      DefaultsBootstrap.openRegistryModal();
      return;
    }
    GazpromToast?.error?.('Модуль выбора реестра не загружен. Обновите страницу (Сборка на главной).');
  }

  function openRegistryModal() {
    if (typeof DefaultsBootstrap !== 'undefined' && typeof DefaultsBootstrap.openRegistryModal === 'function') {
      DefaultsBootstrap.openRegistryModal();
      return;
    }
    open();
  }

  /* ——— Рендер экрана #screen-violations ——— */

  let screenQuery = '';
  let screenVidFilter = '';
  let screenBound = false;

  async function renderScreen(query = screenQuery, vidFilter = screenVidFilter) {
    screenQuery = query;
    screenVidFilter = vidFilter;

    const catalog = await GazpromStore.get();
    if (catalog && typeof ViolationTypes !== 'undefined') ViolationTypes.ensureCatalog(catalog);

    const all = await getAll();
    const filtered = filterItems(all, query, vidFilter, catalog);
    const tbody = document.getElementById('vrScreenTableBody');
    if (!tbody) return;

    // Наполнить выпадающий список видов (один раз)
    const vidSelect = document.getElementById('vrScreenVidFilter');
    if (vidSelect) {
      const titles =
        catalog && typeof ViolationTypes !== 'undefined'
          ? ViolationTypes.getVidSelectTitles(catalog, '')
          : [];
      const current = vidSelect.value;
      vidSelect.innerHTML = '<option value="">Все виды нарушений</option>';
      titles.forEach((v) => {
        const opt = document.createElement('option');
        opt.value = v;
        opt.textContent = v;
        vidSelect.appendChild(opt);
      });
      vidSelect.value = vidFilter || current || '';
    }

    // Синхронизировать поисковую строку
    const searchInput = document.getElementById('vrScreenSearch');
    if (searchInput && searchInput.value !== query) searchInput.value = query;

    const sourceEl = document.getElementById('vrScreenSourceMeta');
    if (sourceEl && typeof DefaultsBootstrap !== 'undefined') {
      const label = DefaultsBootstrap.registrySourceLabel(catalog);
      const count = all.length;
      sourceEl.textContent = count
        ? `${count} записей · ${label}`
        : 'Реестр пуст — вернитесь к выбору';
      sourceEl.className = `vr-screen-source defaults-source defaults-source--${catalog?.violationRegistrySource || 'empty'}`;
    }

    if (all.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="5">
            <div class="vr-screen-empty">
              <div style="font-size:40px;margin-bottom:12px;">⚠️</div>
              <p>Реестр нарушений пуст</p>
              <p style="font-size:13px;color:var(--text-muted);margin-top:8px;max-width:400px;">
                Вернитесь к <strong>«Выбор реестра»</strong> и выберите карточку,<br>
                или нажмите «+ Добавить» для ручного ввода.
              </p>
            </div>
          </td>
        </tr>`;
      return;
    }

    if (filtered.length === 0) {
      tbody.innerHTML = `<tr><td colspan="5" style="text-align:center;padding:40px;color:var(--text-muted);">
        Ничего не найдено по запросу «${escHtml(query || vidFilter)}»
      </td></tr>`;
      return;
    }

    tbody.innerHTML = filtered
      .map(
        (item, i) => `
      <tr>
        <td class="vr-col-num">${item.number || i + 1}</td>
        <td class="vr-col-title">
          <div class="vr-cell-title">${escHtml(item.title)}</div>
          ${item.subTitle ? `
          <div class="vr-cell-ref" style="font-size:12px;color:var(--text-muted);margin-top:6px;padding-top:5px;border-top:1px dashed var(--border);">
            📄 ${escHtml(item.subTitle)}
          </div>` : ''}
          ${item.formulaFromRules ? `
          <div class="vr-cell-formula" style="font-size:11px;color:var(--accent);margin-top:5px;font-style:italic;">
            📋 ${escHtml(item.formulaFromRules.slice(0, 100))}${item.formulaFromRules.length > 100 ? '…' : ''}
          </div>` : ''}
        </td>
        <td class="vr-col-vid">
          ${item.vid
            ? (() => {
                const fmt =
                  catalog && typeof ViolationTypes !== 'undefined'
                    ? ViolationTypes.formatVidDisplay(catalog, item.vid)
                    : { display: item.vid, original: item.vid, migrated: false };
                const titleAttr = fmt.migrated ? ` title="Было: ${escHtml(fmt.original)}"` : '';
                return `<span class="badge vr-vid-badge"${titleAttr}>${escHtml(fmt.display)}</span>`;
              })()
            : '<span class="vr-cell-empty">—</span>'}
        </td>
        <td class="vr-col-note">
          ${item.description
            ? escHtml(item.description.slice(0, 80)) + (item.description.length > 80 ? '…' : '')
            : '<span class="vr-cell-empty">—</span>'}
        </td>
        <td class="btn-row vr-col-actions">
          <button class="btn-ghost btn-sm" title="Изменить" data-vrs-edit="${item.id}">✏️</button>
          <button class="btn-ghost btn-sm modal-btn-danger" title="Удалить" data-vrs-del="${item.id}">🗑</button>
        </td>
      </tr>`
      )
      .join('');

    // Перепривязать кнопки строк
    tbody.querySelectorAll('[data-vrs-edit]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const item = all.find((x) => x.id === btn.dataset.vrsEdit);
        if (item) openForm(item);
      });
    });
    tbody.querySelectorAll('[data-vrs-del]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const item = all.find((x) => x.id === btn.dataset.vrsDel);
        const ok = await GazpromToast.confirm(
          `Удалить нарушение из реестра?\n«${(item?.title || '').slice(0, 80)}»`,
          { confirmLabel: 'Удалить', danger: true }
        );
        if (!ok) return;
        await deleteItem(btn.dataset.vrsDel);
        GazpromToast.success('Удалено из реестра');
        await GazpromUI.refreshAll();
        renderScreen(screenQuery, screenVidFilter);
      });
    });
  }

  function bindScreen() {
    if (screenBound) return;
    screenBound = true;

    // Поиск
    let searchTimer = null;
    document.getElementById('vrScreenSearch')?.addEventListener('input', (e) => {
      clearTimeout(searchTimer);
      searchTimer = setTimeout(() => renderScreen(e.target.value.trim(), screenVidFilter), 250);
    });

    // Фильтр по виду
    document.getElementById('vrScreenVidFilter')?.addEventListener('change', (e) => {
      renderScreen(screenQuery, e.target.value);
    });

    // + Добавить
    document.getElementById('vrScreenAddBtn')?.addEventListener('click', () => openForm(null));

    // Экспорт
    document.getElementById('vrScreenExportBtn')?.addEventListener('click', async () => {
      try {
        const all = await getAll();
        if (!all.length) { GazpromToast.error('Реестр пуст — нечего экспортировать'); return; }
        await exportToExcel();
        GazpromToast.success('Excel-файл скачан');
      } catch (err) {
        GazpromToast.error(err.message);
      }
    });
  }

  /* ——— Форма добавления / редактирования ——— */

  function openForm(item) {
    const existing = document.querySelector('.vr-form-overlay');
    if (existing) {
      existing.remove();
      GazpromMobileOverlay.unlock();
    }

    GazpromStore.get().then((catalog) => {
      if (catalog && typeof ViolationTypes !== 'undefined') ViolationTypes.ensureCatalog(catalog);
      const resolvedVid =
        catalog && typeof ViolationTypes !== 'undefined'
          ? ViolationTypes.resolveVid(catalog, item?.vid)
          : (item?.vid || '');
      const vidTypes =
        catalog && typeof ViolationTypes !== 'undefined'
          ? ViolationTypes.getVidSelectTitles(catalog, item?.vid)
          : [];
      const vidOptions = vidTypes
        .map((v) => `<option value="${escHtml(v)}" ${resolvedVid === v ? 'selected' : ''}>${escHtml(v)}</option>`)
        .join('');
      renderOpenFormBody(item, vidOptions);
    });
  }

  function renderOpenFormBody(item, vidOptions) {
    const form = document.createElement('div');
    form.className = 'vr-form-overlay';
    form.innerHTML = `
      <div class="vr-form-dialog card">
        <h3>${item ? 'Изменить нарушение' : 'Добавить нарушение'}</h3>
        <div class="form-group">
          <label class="form-label">Формулировка несоответствия <span style="color:var(--danger)">*</span></label>
          <textarea class="form-control" data-field="title" rows="3" data-no-capitalize placeholder="Не проведён инструктаж по охране труда…">${escHtml(item?.title || '')}</textarea>
        </div>
        <div class="form-group">
          <label class="form-label">Ссылка на нормативный документ</label>
          <textarea class="form-control" data-field="subTitle" rows="2" data-no-capitalize placeholder="п. 4.1 СП 12-135-2003">${escHtml(item?.subTitle || '')}</textarea>
        </div>
        <div class="form-group">
          <label class="form-label">Примечание</label>
          <input class="form-control" data-field="description" value="${escHtml(item?.description || '')}" placeholder="Доп. информация">
        </div>
        <div class="form-group">
          <label class="form-label">Вид нарушения</label>
          <select class="form-control" data-field="vid">
            <option value="">— не выбрано —</option>
            ${vidOptions}
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">Формулировка из правил</label>
          <textarea class="form-control" data-field="formulaFromRules" rows="2" data-no-capitalize placeholder="Согласно п. …">${escHtml(item?.formulaFromRules || '')}</textarea>
        </div>
        <div class="catalog-form-actions">
          <button type="button" class="btn-ghost" data-cancel>Отмена</button>
          <button type="button" class="btn-primary" data-save>${item ? 'Сохранить' : 'Добавить'}</button>
        </div>
      </div>
    `;
    document.body.appendChild(form);
    GazpromMobileOverlay.lock();

    function vrAutoResize(el) {
      if (!el) return;
      el.style.height = 'auto';
      el.style.height = el.scrollHeight + 'px';
    }

    form.querySelectorAll('textarea.form-control').forEach((ta) => {
      ta.addEventListener('input', () => vrAutoResize(ta));
    });

    // After layout — resize all textareas to fit their content
    setTimeout(() => {
      form.querySelectorAll('textarea.form-control').forEach((ta) => vrAutoResize(ta));
      form.querySelector('textarea')?.focus();
    }, 50);

    const remove = () => {
      form.remove();
      GazpromMobileOverlay.unlock();
    };
    form.querySelector('[data-cancel]').onclick = remove;
    form.addEventListener('keydown', (e) => { if (e.key === 'Escape') remove(); });

    const saveBtn = form.querySelector('[data-save]');
    const defaultSaveLabel = saveBtn?.textContent || 'Сохранить';

    saveBtn.onclick = async () => {
      if (saveBtn.disabled) return;

      const readRaw = (sel) => form.querySelector(sel)?.value ?? '';
      const title = readRaw('[data-field="title"]');
      if (!title.trim()) { GazpromToast.error('Заполните формулировку несоответствия'); return; }

      const fields = {
        title,
        subTitle:         readRaw('[data-field="subTitle"]'),
        description:      readRaw('[data-field="description"]'),
        vid:              form.querySelector('[data-field="vid"]')?.value || '',
        formulaFromRules: readRaw('[data-field="formulaFromRules"]'),
      };

      saveBtn.disabled = true;
      saveBtn.textContent = 'Сохранение…';
      form.querySelector('[data-cancel]').disabled = true;

      try {
        if (item) {
          await updateItem(item.id, fields);
          GazpromToast.success('Запись обновлена');
        } else {
          await addItem(fields);
          GazpromToast.success('Нарушение добавлено в реестр');
        }

        remove();
        await GazpromUI.refreshAll();
        renderScreen(screenQuery, screenVidFilter);
      } catch (err) {
        console.error('[ViolationRegistry] save error:', err);
        GazpromToast.error(err?.message || 'Не удалось сохранить. Попробуйте ещё раз.');
        saveBtn.disabled = false;
        saveBtn.textContent = defaultSaveLabel;
        form.querySelector('[data-cancel]').disabled = false;
      }
    };
  }

  /* ——— Вспомогательные ——— */

  function filterItems(list, query, vidFilter, catalog) {
    return ViolationSearch.filterRegistry(list, query, { vidFilter, catalog });
  }

  function escHtml(s) {
    return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  return {
    open,
    openRegistryModal,
    bindScreen,
    renderScreen,
    getAll,
    addItem,
    updateItem,
    deleteItem,
    findByFormulation,
    bindVidToRegistryItem,
    importFromExcel,
    exportToExcel,
    loadXlsx,
  };
})();
