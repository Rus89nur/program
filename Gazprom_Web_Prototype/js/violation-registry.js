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
  const XLSX_CDN = 'https://cdn.sheetjs.com/xlsx-0.20.1/package/dist/xlsx.full.min.js';

  /* ——— Хранилище ——— */

  async function getAll() {
    const catalog = await GazpromStore.get();
    return catalog?.[LIST_KEY] || [];
  }

  async function saveAll(list) {
    const catalog = await GazpromStore.get();
    catalog[LIST_KEY] = list;
    await GazpromStore.set(catalog);
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

  /* ——— SheetJS lazy loader ——— */

  async function loadXlsx() {
    if (typeof XLSX !== 'undefined') return XLSX;
    GazpromToast.info('Загрузка библиотеки Excel…');
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = XLSX_CDN;
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

    if (replace) {
      await saveAll(imported);
    } else {
      const existing = await getAll();
      const merged = [...existing];
      for (const item of imported) {
        const dup = merged.find((x) => x.title === item.title && x.subTitle === item.subTitle);
        if (!dup) merged.push(item);
      }
      await saveAll(merged);
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
    const list = await getAll();
    const rows = [
      ['№', 'Формулировка несоответствия', 'Ссылка на нормативный документ', 'Примечание', 'Вид нарушения', 'Формулировка из правил'],
      ...list.map((v) => [v.number || '', v.title || '', v.subTitle || '', v.description || '', v.vid || '', v.formulaFromRules || '']),
    ];
    const ws = xlsx.utils.aoa_to_sheet(rows);
    ws['!cols'] = [{ wch: 5 }, { wch: 60 }, { wch: 50 }, { wch: 30 }, { wch: 40 }, { wch: 50 }];
    const wb = xlsx.utils.book_new();
    xlsx.utils.book_append_sheet(wb, ws, 'Реестр нарушений');
    xlsx.writeFile(wb, 'Реестр_нарушений.xlsx');
  }

  /* ——— Вход в экран ——— */

  function open() {
    // Переключить экран через goTo (определено в app.js)
    if (typeof goTo === 'function') goTo('violations');
    renderScreen();
  }

  /* ——— Рендер экрана #screen-violations ——— */

  let screenQuery = '';
  let screenVidFilter = '';
  let screenBound = false;

  async function renderScreen(query = screenQuery, vidFilter = screenVidFilter) {
    screenQuery = query;
    screenVidFilter = vidFilter;

    const all = await getAll();
    const filtered = filterItems(all, query, vidFilter);
    const tbody = document.getElementById('vrScreenTableBody');
    if (!tbody) return;

    // Наполнить выпадающий список видов (один раз)
    const vidSelect = document.getElementById('vrScreenVidFilter');
    if (vidSelect && vidSelect.options.length <= 1) {
      ViolationTemplates.VIOLATION_TYPES.forEach((v) => {
        const opt = document.createElement('option');
        opt.value = v;
        opt.textContent = v;
        vidSelect.appendChild(opt);
      });
    }
    if (vidSelect) vidSelect.value = vidFilter;

    // Синхронизировать поисковую строку
    const searchInput = document.getElementById('vrScreenSearch');
    if (searchInput && searchInput.value !== query) searchInput.value = query;

    if (all.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="5">
            <div class="vr-screen-empty">
              <div style="font-size:40px;margin-bottom:12px;">⚠️</div>
              <p>Реестр нарушений пуст</p>
              <p style="font-size:13px;color:var(--text-muted);margin-top:8px;max-width:400px;">
                Нажмите «+ Добавить» чтобы внести первое нарушение,<br>
                или «📂 Импорт Excel» для загрузки из файла.<br><br>
                Формат Excel: колонки «№», «Формулировка несоответствия», «Ссылка на нормативный документ», «Примечание», «Вид нарушения», «Формулировка из правил».
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
        <td style="text-align:center;color:var(--text-muted);font-size:12px;width:44px;">
          ${item.number || i + 1}
        </td>
        <td>
          <div class="vr-cell-title" style="font-weight:600;font-size:13px;line-height:1.45;color:var(--text);">
            ${escHtml(item.title)}
          </div>
          ${item.subTitle ? `
          <div class="vr-cell-ref" style="font-size:12px;color:var(--text-muted);margin-top:6px;padding-top:5px;border-top:1px dashed var(--border);">
            📄 ${escHtml(item.subTitle)}
          </div>` : ''}
          ${item.formulaFromRules ? `
          <div class="vr-cell-formula" style="font-size:11px;color:var(--accent);margin-top:5px;font-style:italic;">
            📋 ${escHtml(item.formulaFromRules.slice(0, 100))}${item.formulaFromRules.length > 100 ? '…' : ''}
          </div>` : ''}
        </td>
        <td style="width:200px;padding-top:16px;">
          ${item.vid
            ? `<span class="badge" style="background:var(--primary-soft);color:var(--primary);font-size:11px;white-space:normal;line-height:1.4;padding:4px 8px;display:inline-block;">${escHtml(item.vid)}</span>`
            : '<span style="color:var(--text-muted);font-size:13px;">—</span>'}
        </td>
        <td style="width:160px;font-size:12px;color:var(--text-muted);padding-top:16px;line-height:1.5;">
          ${item.description
            ? escHtml(item.description.slice(0, 80)) + (item.description.length > 80 ? '…' : '')
            : '<span style="color:var(--border);">—</span>'}
        </td>
        <td class="btn-row" style="width:80px;white-space:nowrap;padding-top:12px;">
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

  /* ——— Привязка событий экрана (один раз при init) ——— */

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

    // Импорт — кнопка открывает сначала опции, потом диалог файла
    const importInput = document.getElementById('vrScreenImportInput');
    const importBtn   = document.getElementById('vrScreenImportBtn');
    const importOptions = document.getElementById('vrScreenImportOptions');

    importBtn?.addEventListener('click', () => {
      // Диалог ДОЛЖЕН открываться синхронно внутри обработчика пользовательского жеста
      importInput?.click();
      // Показываем опции после открытия диалога
      if (importOptions) importOptions.hidden = false;
    });

    importInput?.addEventListener('change', async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      const merge = document.getElementById('vrScreenMergeCheckbox')?.checked ?? false;

      // Сразу скрываем опции
      if (importOptions) importOptions.hidden = true;

      try {
        GazpromToast.info('Читаю файл…');
        const count = await importFromExcel(file, { replace: !merge });
        GazpromToast.success(`Импортировано нарушений: ${count}`);
        renderScreen('', '');
      } catch (err) {
        console.error('[ViolationRegistry] import error:', err);
        GazpromToast.error('Ошибка импорта: ' + (err.message || String(err)));
      } finally {
        e.target.value = ''; // сброс, чтобы можно было выбрать тот же файл снова
      }
    });

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
    const vidTypes = ViolationTemplates.VIOLATION_TYPES;
    const vidOptions = vidTypes
      .map((v) => `<option value="${escHtml(v)}" ${item?.vid === v ? 'selected' : ''}>${escHtml(v)}</option>`)
      .join('');

    const form = document.createElement('div');
    form.className = 'vr-form-overlay';
    form.innerHTML = `
      <div class="vr-form-dialog card">
        <h3>${item ? 'Изменить нарушение' : 'Добавить нарушение'}</h3>
        <div class="form-group">
          <label class="form-label">Формулировка несоответствия <span style="color:var(--danger)">*</span></label>
          <textarea class="form-control" data-field="title" rows="3" placeholder="Не проведён инструктаж по охране труда…">${escHtml(item?.title || '')}</textarea>
        </div>
        <div class="form-group">
          <label class="form-label">Ссылка на нормативный документ</label>
          <textarea class="form-control" data-field="subTitle" rows="2" placeholder="п. 4.1 СП 12-135-2003">${escHtml(item?.subTitle || '')}</textarea>
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
          <textarea class="form-control" data-field="formulaFromRules" rows="2" placeholder="Согласно п. …">${escHtml(item?.formulaFromRules || '')}</textarea>
        </div>
        <div class="catalog-form-actions">
          <button type="button" class="btn-ghost" data-cancel>Отмена</button>
          <button type="button" class="btn-primary" data-save>${item ? 'Сохранить' : 'Добавить'}</button>
        </div>
      </div>
    `;
    document.body.appendChild(form);

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

    const remove = () => form.remove();
    form.querySelector('[data-cancel]').onclick = remove;
    form.addEventListener('keydown', (e) => { if (e.key === 'Escape') remove(); });

    form.querySelector('[data-save]').onclick = async () => {
      const title = form.querySelector('[data-field="title"]')?.value?.trim();
      if (!title) { GazpromToast.error('Заполните формулировку несоответствия'); return; }

      const fields = {
        title,
        subTitle:         form.querySelector('[data-field="subTitle"]')?.value?.trim() || '',
        description:      form.querySelector('[data-field="description"]')?.value?.trim() || '',
        vid:              form.querySelector('[data-field="vid"]')?.value || '',
        formulaFromRules: form.querySelector('[data-field="formulaFromRules"]')?.value?.trim() || '',
      };

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
    };
  }

  /* ——— Вспомогательные ——— */

  function filterItems(list, query, vidFilter) {
    let result = list;
    if (vidFilter) result = result.filter((x) => x.vid === vidFilter);
    if (query) {
      const q = query.toLowerCase();
      result = result.filter(
        (x) =>
          (x.title || '').toLowerCase().includes(q) ||
          (x.subTitle || '').toLowerCase().includes(q) ||
          (x.description || '').toLowerCase().includes(q) ||
          (x.formulaFromRules || '').toLowerCase().includes(q)
      );
    }
    return result;
  }

  function escHtml(s) {
    return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  return {
    open,
    bindScreen,
    renderScreen,
    getAll,
    addItem,
    updateItem,
    deleteItem,
    importFromExcel,
    exportToExcel,
  };
})();
