/**
 * Редактор видов нарушений: вкладки (B), split-модалка (A), мастер миграции (C).
 */
const ViolationTypesEditor = (() => {
  const TABS = [
    { key: 'active', label: 'Активные' },
    { key: 'archive', label: 'Архив' },
    { key: 'map', label: 'Сопоставить' },
  ];

  let catalog = null;
  let currentTab = 'active';
  let screenQuery = '';
  let bound = false;
  let wizardStep = 0;
  let wizardMappings = new Map();
  let mapSelectedFrom = null;
  let mapSelectedTo = null;
  let mapPinNewTypeId = null;

  function esc(s) {
    return AktUtils.escapeHtml(String(s ?? ''));
  }

  let activeMappedTip = null;

  function hideMappedFromTip() {
    if (activeMappedTip?.tip?.parentNode) {
      activeMappedTip.tip.parentNode.removeChild(activeMappedTip.tip);
    }
    activeMappedTip = null;
  }

  function renderMappedFromBadge(catalog, toId) {
    const n = ViolationTypes.countMappedFrom(catalog, toId);
    if (n <= 0) return '';
    const titles = ViolationTypes.getMappedFromTitles(catalog, toId);
    const tipPlain =
      (n === 1 ? 'Устаревший вид: ' : 'Устаревшие виды: ') + titles.join('; ');
    return ` <span class="vt-badge vt-badge--ok vt-badge--has-tip" tabindex="0" title="${esc(tipPlain)}" data-vt-mapped-from="${esc(JSON.stringify(titles))}" aria-label="${esc(`${n} устаревших видов`)}">← ${n} устар.</span>`;
  }

  function bindMappedFromTips(root) {
    if (!root) return;
    root.querySelectorAll('.vt-badge--has-tip:not([data-tip-bound])').forEach((badge) => {
      badge.dataset.tipBound = '1';
      const showTip = () => {
        hideMappedFromTip();
        let titles = [];
        try {
          titles = JSON.parse(badge.dataset.vtMappedFrom || '[]');
        } catch (_) {
          titles = [];
        }
        if (!titles.length) return;

        const tip = document.createElement('div');
        tip.className = 'vt-mapped-tip-float';
        tip.setAttribute('role', 'tooltip');
        const heading = document.createElement('div');
        heading.className = 'vt-mapped-tip-float__title';
        heading.textContent = titles.length === 1 ? 'Устаревший вид' : 'Устаревшие виды';
        tip.appendChild(heading);
        const list = document.createElement('ul');
        list.className = 'vt-mapped-tip-float__list';
        titles.forEach((title) => {
          const li = document.createElement('li');
          li.textContent = title;
          list.appendChild(li);
        });
        tip.appendChild(list);
        document.body.appendChild(tip);

        const rect = badge.getBoundingClientRect();
        const tipRect = tip.getBoundingClientRect();
        let left = rect.left + rect.width / 2 - tipRect.width / 2;
        let top = rect.bottom + 8;
        left = Math.max(8, Math.min(left, window.innerWidth - tipRect.width - 8));
        if (top + tipRect.height > window.innerHeight - 8) {
          top = Math.max(8, rect.top - tipRect.height - 8);
        }
        tip.style.left = `${left}px`;
        tip.style.top = `${top}px`;
        activeMappedTip = { tip, badge };
      };
      const hideTip = () => {
        if (activeMappedTip?.badge === badge) hideMappedFromTip();
      };
      badge.addEventListener('mouseenter', showTip);
      badge.addEventListener('mouseleave', hideTip);
      badge.addEventListener('focus', showTip);
      badge.addEventListener('blur', hideTip);
    });
  }

  async function loadCatalog() {
    catalog = await GazpromStore.get();
    if (!catalog) {
      catalog = {
        akts: [],
        violationTypes: [],
        typeMappings: {},
        dismissedMappingSeeds: [],
      };
    }
    if (ViolationTypes.ensureCatalog(catalog)) {
      await GazpromStore.set(catalog);
      GazpromStore.invalidateCache();
    }
    return catalog;
  }

  async function saveCatalog(message) {
    await GazpromStore.set(catalog);
    GazpromStore.invalidateCache();
    await GazpromUI.refreshAll();
    if (message) GazpromToast.success(message);
  }

  async function createVtMigrateBackup() {
    if (typeof CatalogService === 'undefined' || typeof CatalogService.exportBackup !== 'function') {
      throw new Error('Модуль резервного копирования недоступен');
    }
    GazpromToast.info('Создание резервной копии перед миграцией…');
    await CatalogService.exportBackup(catalog, { filenameSuffix: 'before_vt_migrate' });
  }

  function activeSelectOptions(selectedId, { includeEmpty = false, emptyLabel = '— выберите новый вид —' } = {}) {
    const items = ViolationTypes.getActiveTypes(catalog);
    const opts = includeEmpty
      ? [`<option value="">${esc(emptyLabel)}</option>`]
      : [];
    for (const t of items) {
      opts.push(
        `<option value="${esc(t.id)}" ${t.id === selectedId ? 'selected' : ''}>${esc(t.title)}</option>`
      );
    }
    return opts.join('');
  }

  function renderHeader() {
    const host = document.getElementById('vtScreenHost');
    if (!host) return;

    const unmapped = ViolationTypes.getUnmappedArchived(catalog).length;
    const alert =
      unmapped > 0
        ? `<div class="vt-alert vt-alert--warn" role="status">
            <span>⚠️</span>
            <span>${unmapped} ${unmapped === 1 ? 'вид' : 'видов'} в архиве без соответствия</span>
            <button type="button" class="btn-primary btn-sm" id="vtRunWizardBtn">Мастер миграции</button>
          </div>`
        : '';

    const tabButtons = TABS.map((tab) => {
      const count =
        tab.key === 'active'
          ? ViolationTypes.getActiveTypes(catalog).length
          : tab.key === 'archive'
            ? ViolationTypes.getArchivedTypes(catalog).length
            : ViolationTypes.getPendingTypes(catalog).length;
      const warn =
        tab.key === 'map' && ViolationTypes.getPendingTypes(catalog).length > 0
          ? ' vt-tab--warn'
          : tab.key === 'map' && ViolationTypes.getUnmappedArchived(catalog).length > 0
            ? ' vt-tab--warn'
            : tab.key === 'archive' && ViolationTypes.getUnmappedArchived(catalog).length > 0
              ? ' vt-tab--warn'
              : '';
      return `<button type="button" class="vt-tab${currentTab === tab.key ? ' active' : ''}${warn}" data-vt-tab="${tab.key}">
        ${esc(tab.label)} (${count})
      </button>`;
    }).join('');

    host.innerHTML = `
      <div class="violations-screen-header card">
        <div class="violations-screen-nav">
          <button class="btn-ghost btn-sm" type="button" data-go="settings">← Настройки</button>
          <span class="violations-screen-breadcrumb">/ Виды нарушений</span>
        </div>
        ${alert}
        <div class="vt-toolbar">
          <input type="search" class="form-control" id="vtSearch" placeholder="Поиск по названию…" value="${esc(screenQuery)}" autocomplete="off">
          <button type="button" class="btn-primary btn-sm" id="vtAddTypeBtn">+ Новый вид</button>
        </div>
        <div class="vt-tabs" role="tablist">${tabButtons}</div>
      </div>
      <div class="card card--flush" id="vtTabBody"></div>
    `;

    document.getElementById('vtSearch')?.addEventListener('input', (e) => {
      screenQuery = e.target.value;
      renderTabBody();
    });
    document.getElementById('vtAddTypeBtn')?.addEventListener('click', () => handleAddType());
    document.getElementById('vtRunWizardBtn')?.addEventListener('click', () => openWizard());
    host.querySelectorAll('[data-vt-tab]').forEach((btn) => {
      btn.addEventListener('click', () => {
        currentTab = btn.dataset.vtTab;
        renderScreen();
      });
    });
  }

  function filterByQuery(items) {
    const q = screenQuery.trim().toLowerCase();
    if (!q) return items;
    return items.filter((t) => t.title.toLowerCase().includes(q));
  }

  function renderTabBody() {
    const body = document.getElementById('vtTabBody');
    if (!body || !catalog) return;

    hideMappedFromTip();
    if (currentTab === 'active') renderActiveTab(body);
    else if (currentTab === 'archive') renderArchiveTab(body);
    else renderMapTab(body);
  }

  function renderActiveTab(body) {
    const items = filterByQuery(ViolationTypes.getActiveTypes(catalog));
    if (!items.length) {
      body.innerHTML = `<p class="vt-empty">Нет активных видов. Новые виды создаются на вкладке «Сопоставить» и попадают в активные после привязки к архивному.</p>`;
      return;
    }

    body.innerHTML = `
      <div class="vt-table-wrap">
      <table class="list-table">
        <thead>
          <tr>
            <th>Название</th>
            <th class="vt-col-count">В данных</th>
            <th class="vt-col-actions"></th>
          </tr>
        </thead>
        <tbody>
          ${items
            .map((t) => {
              const n = ViolationTypes.usageCount(catalog, t);
              const standaloneBadge = t.standalone
                ? ' <span class="vt-badge vt-badge--standalone">уникальный</span>'
                : '';
              const mappedBadge = renderMappedFromBadge(catalog, t.id);
              return `<tr>
                <td class="vt-cell-title">${esc(t.title)}${standaloneBadge}${mappedBadge}</td>
                <td class="vt-col-count">${n || '—'}</td>
                <td class="btn-row vt-col-actions">
                  <button type="button" class="btn-ghost btn-sm" data-vt-archive="${esc(t.id)}" title="В архив">📦</button>
                  <button type="button" class="btn-ghost btn-sm modal-btn-danger" data-vt-delete="${esc(t.id)}" title="Удалить">🗑</button>
                </td>
              </tr>`;
            })
            .join('')}
        </tbody>
      </table>
      </div>`;

    bindMappedFromTips(body);
    body.querySelectorAll('[data-vt-archive]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const id = btn.dataset.vtArchive;
        const t = ViolationTypes.findById(catalog, id);
        if (!t) return;
        const n = ViolationTypes.usageCount(catalog, t);
        if (n > 0) {
          const ok = await GazpromToast.confirm(
            `Вид «${t.title}» используется в ${n} записях. Перенести в архив и настроить соответствие?`
          );
          if (!ok) return;
          ViolationTypes.archiveType(catalog, id);
          await saveCatalog('Вид перенесён в архив');
          openSplitModal(id);
          return;
        }
        ViolationTypes.archiveType(catalog, id);
        await saveCatalog('Вид перенесён в архив');
        currentTab = 'archive';
        renderScreen();
      });
    });
    bindDeleteButtons(body);
  }

  async function handleDeleteType(id) {
    const t = ViolationTypes.findById(catalog, id);
    if (!t) return;

    const usage = ViolationTypes.usageCount(catalog, t);
    if (usage > 0) {
      GazpromToast.error(
        `Вид «${t.title}» используется в ${usage} записях. Удаление невозможно — перенесите в архив и настройте замену.`
      );
      return;
    }

    const ok = await GazpromToast.confirm(`Удалить вид «${t.title}»?`);
    if (!ok) return;

    const result = ViolationTypes.deleteType(catalog, id);
    if (!result.ok) {
      GazpromToast.error('Не удалось удалить вид');
      return;
    }

    if (mapSelectedFrom === id) mapSelectedFrom = null;
    if (mapSelectedTo === id) mapSelectedTo = null;

    await saveCatalog('Вид удалён');
    renderScreen();
  }

  function bindDeleteButtons(root) {
    root.querySelectorAll('[data-vt-delete]').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        void handleDeleteType(btn.dataset.vtDelete);
      });
    });
  }

  function renderArchiveTab(body) {
    const items = filterByQuery(ViolationTypes.getArchivedTypes(catalog));
    if (!items.length) {
      body.innerHTML = `<p class="vt-empty">Архив пуст. Неактивные виды появятся здесь после переноса с вкладки «Активные» (кнопка 📦) или при импорте устаревших данных.</p>`;
      return;
    }

    body.innerHTML = `
      <div class="vt-table-wrap">
      <table class="list-table vt-archive-table">
        <thead>
          <tr>
            <th>Устаревший вид</th>
            <th class="vt-col-count">В данных</th>
            <th class="vt-col-mapped">Заменён на</th>
            <th class="vt-col-actions"></th>
          </tr>
        </thead>
        <tbody>
          ${items
            .map((t) => {
              const n = ViolationTypes.usageCount(catalog, t);
              const mappedId = t.replacedBy || ViolationTypes.getMappings(catalog)[t.id] || '';
              const mapped = ViolationTypes.findById(catalog, mappedId);
              const status = ViolationTypes.isMappedToActive(catalog, t)
                ? '<span class="vt-badge vt-badge--ok">настроено</span>'
                : '<span class="vt-badge vt-badge--warn">требует сопоставления</span>';
              return `<tr>
                <td class="vt-cell-title">${esc(t.title)} ${status}</td>
                <td class="vt-col-count">${n || '—'}</td>
                <td class="vt-col-mapped">${mapped ? esc(mapped.title) : '—'}</td>
                <td class="btn-row vt-col-actions">
                  <button type="button" class="btn-secondary btn-sm vt-btn-restore" data-vt-restore="${esc(t.id)}" title="Вернуть в активные"><span class="vt-btn-restore__full">↩ Активные</span><span class="vt-btn-restore__short" aria-hidden="true">↩</span></button>
                  <button type="button" class="btn-secondary btn-sm" data-vt-goto-map="${esc(t.id)}">Сопоставить</button>
                  <button type="button" class="btn-ghost btn-sm modal-btn-danger" data-vt-delete="${esc(t.id)}" title="Удалить">🗑</button>
                </td>
              </tr>`;
            })
            .join('')}
        </tbody>
      </table>
      </div>`;

    body.querySelectorAll('[data-vt-goto-map]').forEach((btn) => {
      btn.addEventListener('click', () => openSplitModal(btn.dataset.vtGotoMap));
    });
    body.querySelectorAll('[data-vt-restore]').forEach((btn) => {
      btn.addEventListener('click', () => handleRestoreType(btn.dataset.vtRestore));
    });
    bindDeleteButtons(body);
  }

  async function handleRestoreType(id) {
    const t = ViolationTypes.findById(catalog, id);
    if (!t) return;

    const hadMapping = ViolationTypes.isMappedToActive(catalog, t);
    let message = `Вернуть «${t.title}» в активные виды?`;
    if (hadMapping) {
      message += ' Соответствие с новым видом будет снято.';
    }

    const ok = await GazpromToast.confirm(message);
    if (!ok) return;

    const result = ViolationTypes.restoreType(catalog, id);
    if (!result.ok) {
      if (result.reason === 'duplicate') {
        GazpromToast.error(`Активный вид «${result.title}» уже существует`);
      } else {
        GazpromToast.error('Не удалось восстановить вид');
      }
      return;
    }

    if (mapSelectedFrom === id) mapSelectedFrom = null;
    await saveCatalog('Вид возвращён в активные');
    currentTab = 'active';
    renderScreen();
  }

  function renderMapTab(body) {
    const archived = filterByQuery(ViolationTypes.getArchivedTypes(catalog));
    const mapTargets = filterByQuery(ViolationTypes.getMapTargetTypes(catalog));
    const pendingCount = ViolationTypes.getPendingTypes(catalog).length;
    const standaloneFrom = ViolationTypes.STANDALONE_MAP_FROM;

    if (!archived.length && !pendingCount) {
      body.innerHTML = `<p class="vt-empty">Нет архивных видов для сопоставления. Перенесите вид в архив на вкладке «Активные» (кнопка 📦) или откройте вкладку «Архив». Новые виды для привязки добавляйте кнопкой «+ Новый вид».</p>`;
      return;
    }

    if (archived.length) {
      if (mapSelectedFrom !== standaloneFrom) {
        if (!mapSelectedFrom || !archived.some((t) => t.id === mapSelectedFrom)) {
          mapSelectedFrom = archived[0].id;
        }
      }
    } else {
      mapSelectedFrom = standaloneFrom;
    }

    if (mapPinNewTypeId) {
      mapSelectedTo = mapPinNewTypeId;
      mapPinNewTypeId = null;
    }

    const isStandalone = mapSelectedFrom === standaloneFrom;
    const fromType = !isStandalone && mapSelectedFrom
      ? ViolationTypes.findById(catalog, mapSelectedFrom)
      : null;
    const targetIds = new Set(mapTargets.map((t) => t.id));
    if (!mapSelectedTo || !targetIds.has(mapSelectedTo)) {
      mapSelectedTo =
        fromType?.replacedBy ||
        (!isStandalone && mapSelectedFrom
          ? ViolationTypes.getMappings(catalog)[mapSelectedFrom]
          : null) ||
        mapTargets.find((t) => t.status === ViolationTypes.STATUS_PENDING)?.id ||
        mapTargets[0]?.id ||
        null;
    }

    const toType = ViolationTypes.findById(catalog, mapSelectedTo);
    const usageN = fromType ? ViolationTypes.usageCount(catalog, fromType) : 0;
    const mappedToCount = mapSelectedTo ? ViolationTypes.countMappedFrom(catalog, mapSelectedTo) : 0;
    let previewText = '';
    if (isStandalone && toType) {
      previewText = `«${toType.title}» — новый уникальный вид, без замены устаревшего`;
    } else if (fromType && toType) {
      previewText =
        usageN > 0
          ? `Отчёт «Виды выявленных нарушений»: +${usageN} к «${toType.title}»`
          : 'В данных нет записей с этим видом';
      if (mappedToCount > 0) {
        previewText += `. К этому виду уже привязано устаревших: ${mappedToCount}`;
      }
    } else if (pendingCount && !archived.length) {
      previewText = `Загружено ${pendingCount} новых видов. Слева выберите «Нет старого вида» для уникальных или перенесите устаревшие в архив.`;
    }
    const canSaveMap = !!(mapSelectedFrom && mapSelectedTo);
    const saveLabel = isStandalone ? 'Сохранить как уникальный' : 'Сохранить соответствие';

    const standaloneBtn = `<button type="button" class="vt-type-item vt-type-item--standalone ${isStandalone ? 'selected' : ''}" data-vt-from-standalone="1">
      <div>— Нет старого вида</div>
      <div class="vt-type-item__meta">
        <span class="vt-badge vt-badge--standalone">уникальный новый</span>
      </div>
    </button>`;

    const archivedListHtml = archived.length
      ? archived
          .map((t) => {
            const n = ViolationTypes.usageCount(catalog, t);
            const mapped = ViolationTypes.isMappedToActive(catalog, t);
            const targetId = t.replacedBy || ViolationTypes.getMappings(catalog)[t.id];
            const target = ViolationTypes.findById(catalog, targetId);
            return `<button type="button" class="vt-type-item ${t.id === mapSelectedFrom ? 'selected' : ''}" data-vt-from-item="${esc(t.id)}">
              <div>${esc(t.title)}</div>
              <div class="vt-type-item__meta">
                <span class="vt-badge vt-badge--archived">архив</span>
                ${mapped ? '<span class="vt-badge vt-badge--ok">настроено</span>' : '<span class="vt-badge vt-badge--warn">нет пары</span>'}
                ${mapped && target ? `<span class="vt-badge vt-badge--count">→ ${esc(target.title.length > 28 ? target.title.slice(0, 25) + '…' : target.title)}</span>` : ''}
                ${n ? `<span class="vt-badge vt-badge--count">${n} зап.</span>` : ''}
              </div>
            </button>`;
          })
          .join('')
      : `<p class="vt-empty vt-empty--inline">Пока нет архивных видов. Выберите «Нет старого вида» для уникального нового вида или перенесите устаревший в архив (📦).</p>`;

    body.innerHTML = `
      <div class="vt-split-inline">
        <p class="vt-map-hint">Несколько устаревших видов можно привязать к одному новому — выберите каждый слева и сохраните соответствие.</p>
        <div class="vt-split-body">
          <div class="vt-split-col vt-split-col--old">
            <h4>Устаревший вид</h4>
            <div id="vtInlineOldList">${standaloneBtn}${archivedListHtml}</div>
          </div>
          <div class="vt-split-arrow" aria-hidden="true">→</div>
          <div class="vt-split-col vt-split-col--new">
            <h4>Новый вид (привязка)</h4>
            <div id="vtInlineNewList">
              ${mapTargets.length
                ? [...mapTargets]
                    .sort((a, b) => {
                      if (a.id === mapSelectedTo) return -1;
                      if (b.id === mapSelectedTo) return 1;
                      if (a.status === ViolationTypes.STATUS_PENDING) return -1;
                      if (b.status === ViolationTypes.STATUS_PENDING) return 1;
                      return a.title.localeCompare(b.title, 'ru');
                    })
                    .map((t) => {
                      const isPending = t.status === ViolationTypes.STATUS_PENDING;
                      const mappedFromBadge = renderMappedFromBadge(catalog, t.id);
                      const badges = [
                        isPending
                          ? '<span class="vt-badge vt-badge--warn">ожидает привязки</span>'
                          : '<span class="vt-badge vt-badge--active">активен</span>',
                        t.standalone
                          ? '<span class="vt-badge vt-badge--standalone">уникальный</span>'
                          : '',
                        mappedFromBadge.trim()
                          ? mappedFromBadge
                          : '',
                      ]
                        .filter(Boolean)
                        .join('');
                      const delBtn = isPending
                        ? `<button type="button" class="vt-type-item__delete" data-vt-delete="${esc(t.id)}" title="Удалить">🗑</button>`
                        : '';
                      return `<div class="vt-type-item-wrap ${t.id === mapSelectedTo ? 'selected' : ''}">
                        <button type="button" class="vt-type-item" data-vt-to-item="${esc(t.id)}">
                          <div>${esc(t.title)}</div>
                          <div class="vt-type-item__meta">${badges}</div>
                        </button>
                        ${delBtn}
                      </div>`;
                    })
                    .join('')
                : `<p class="vt-empty vt-empty--inline">Нажмите «+ Новый вид» — он появится здесь для привязки.</p>`}
            </div>
            <button type="button" class="btn-primary btn-sm vt-split-add-new" id="vtInlineAddType">+ Новый вид</button>
          </div>
        </div>
        ${previewText ? `<div class="vt-split-preview">${esc(previewText)}</div>` : ''}
        <div class="vt-footer-actions">
          <button type="button" class="btn-primary" id="vtInlineSaveMap" ${canSaveMap ? '' : 'disabled'}>${saveLabel}</button>
          <button type="button" class="btn-secondary" id="vtMigrateData">Применить ко всем данным</button>
        </div>
      </div>`;

    body.querySelector('[data-vt-from-standalone]')?.addEventListener('click', () => {
      mapSelectedFrom = standaloneFrom;
      renderMapTab(body);
    });
    body.querySelectorAll('[data-vt-from-item]').forEach((btn) => {
      btn.addEventListener('click', () => {
        mapSelectedFrom = btn.dataset.vtFromItem;
        const mapped =
          ViolationTypes.findById(catalog, mapSelectedFrom)?.replacedBy ||
          ViolationTypes.getMappings(catalog)[mapSelectedFrom];
        if (mapped) mapSelectedTo = mapped;
        renderMapTab(body);
      });
    });
    body.querySelectorAll('[data-vt-to-item]').forEach((btn) => {
      btn.addEventListener('click', () => {
        mapSelectedTo = btn.dataset.vtToItem;
        renderMapTab(body);
      });
    });
    bindMappedFromTips(body);
    bindDeleteButtons(body);
    body.querySelector('#vtInlineAddType')?.addEventListener('click', () => handleAddType());
    body.querySelector('#vtInlineSaveMap')?.addEventListener('click', async () => {
      if (!mapSelectedFrom || !mapSelectedTo) return;
      if (ViolationTypes.isStandaloneMapFrom(mapSelectedFrom)) {
        ViolationTypes.activateStandaloneType(catalog, mapSelectedTo);
        await saveCatalog('Уникальный вид сохранён в активные');
      } else {
        ViolationTypes.setMapping(catalog, mapSelectedFrom, mapSelectedTo);
        await saveCatalog('Соответствие сохранено');
      }
      renderScreen();
    });
    body.querySelector('#vtMigrateData')?.addEventListener('click', () => handleMigrateData());
  }

  async function handleMigrateData() {
    const unmapped = ViolationTypes.getUnmappedArchived(catalog);
    if (unmapped.length) {
      GazpromToast.error('Сначала настройте соответствия для всех архивных видов');
      return;
    }
    const ok = await GazpromToast.confirm(
      'Обновить поле «вид нарушения» во всех актах и реестре по новым соответствиям?\n\nПеред изменением автоматически скачается резервная копия (.gazprombackup).'
    );
    if (!ok) return;
    try {
      await createVtMigrateBackup();
    } catch (err) {
      GazpromToast.error(err.message || 'Не удалось создать резервную копию. Миграция отменена.');
      return;
    }
    const n = ViolationTypes.migrateStoredVids(catalog);
    await saveCatalog(`Резервная копия сохранена. Обновлено записей: ${n}`);
    renderScreen();
  }

  async function handleAddType() {
    const archived = ViolationTypes.getArchivedTypes(catalog);
    const standaloneFrom = ViolationTypes.STANDALONE_MAP_FROM;

    const title = await GazpromToast.prompt('Название нового вида нарушения', '');
    if (title === null) return;
    const trimmed = String(title).trim();
    if (!trimmed) {
      GazpromToast.error('Введите название вида');
      return;
    }

    const created = ViolationTypes.addType(catalog, trimmed, { forMapping: true });
    if (!created) return;

    if (archived.length) {
      if (
        !mapSelectedFrom ||
        mapSelectedFrom === standaloneFrom ||
        !archived.some((t) => t.id === mapSelectedFrom)
      ) {
        mapSelectedFrom = archived[0].id;
      }
    } else {
      mapSelectedFrom = standaloneFrom;
    }

    mapPinNewTypeId = created.id;
    mapSelectedTo = created.id;
    currentTab = 'map';

    const hint = archived.length
      ? 'Новый вид создан — выберите устаревший слева (или «Нет старого вида») и сохраните'
      : 'Новый вид создан — слева уже выбрано «Нет старого вида», нажмите «Сохранить как уникальный»';
    await saveCatalog(hint);
    renderScreen();
    requestAnimationFrame(() => {
      document
        .querySelector('#vtInlineNewList .vt-type-item-wrap.selected')
        ?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    });
  }

  function openSplitModal(preselectFromId = null) {
    currentTab = 'map';
    mapSelectedFrom = preselectFromId;
    mapSelectedTo = null;
    renderScreen();
  }

  function renderWizardChart(stats, title, highlightKinds = []) {
    const entries = [...stats.entries()].sort((a, b) => b[1] - a[1]).slice(0, 6);
    const max = Math.max(1, ...entries.map((e) => e[1]));
    const rows = entries
      .map(([label, val]) => {
        const pct = Math.round((val / max) * 100);
        const hl = highlightKinds.includes(label) ? ' vt-bar-row--highlight' : '';
        return `<div class="vt-bar-row${hl}">
          <span class="vt-bar-label">${esc(label.length > 42 ? label.slice(0, 39) + '…' : label)}</span>
          <div class="vt-bar-track"><span style="width:${pct}%"></span></div>
          <span class="vt-bar-val">${val}</span>
        </div>`;
      })
      .join('');
    return `<div class="vt-chart-mock"><h5>${esc(title)}</h5>${rows || '<p class="vt-empty">Нет данных</p>'}</div>`;
  }

  function openWizard() {
    const unmapped = ViolationTypes.getUnmappedArchived(catalog);
    if (!unmapped.length) {
      GazpromToast.info('Все архивные виды уже сопоставлены');
      return;
    }

    wizardStep = 0;
    wizardMappings = new Map();
    for (const t of unmapped) {
      const existing = t.replacedBy || ViolationTypes.getMappings(catalog)[t.id];
      if (existing) wizardMappings.set(t.id, existing);
    }

    const overlay = document.createElement('div');
    overlay.className = 'catalog-form-overlay vt-wizard-overlay';
    overlay.innerHTML = `
      <div class="vt-wizard-panel card">
        <div class="vt-split-header">
          <h3>Мастер миграции видов нарушений</h3>
          <button type="button" class="btn-ghost btn-sm vt-wizard-close" aria-label="Закрыть">✕</button>
        </div>
        <div class="vt-wizard-steps" id="vtWizardSteps"></div>
        <div class="vt-wizard-body" id="vtWizardBody"></div>
        <div class="vt-wizard-footer" id="vtWizardFooter"></div>
      </div>`;

    const close = () => {
      overlay.remove();
      GazpromMobileOverlay.unlock();
    };

    overlay.querySelector('.vt-wizard-close')?.addEventListener('click', close);
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) close();
    });

    const paintStep = () => {
      const stepsEl = overlay.querySelector('#vtWizardSteps');
      const bodyEl = overlay.querySelector('#vtWizardBody');
      const footEl = overlay.querySelector('#vtWizardFooter');
      const labels = ['Обзор', 'Сопоставление', 'Превью отчётов', 'Применить'];

      stepsEl.innerHTML = labels
        .map((label, i) => {
          let cls = 'vt-wizard-step';
          if (i < wizardStep) cls += ' done';
          if (i === wizardStep) cls += ' active';
          const num = i < wizardStep ? '✓' : String(i + 1);
          return `<div class="${cls}"><div class="vt-wizard-step__num">${num}</div>${esc(label)}</div>`;
        })
        .join('');

      if (wizardStep === 0) {
        bodyEl.innerHTML = `
          <p class="vt-wizard-intro">Обнаружено <strong>${unmapped.length}</strong> устаревших видов без полного соответствия. Настройте замену — отчёты и дашборды будут группировать исторические нарушения под новыми видами.</p>
          <ul class="vt-wizard-list">
            ${unmapped
              .map((t) => {
                const n = ViolationTypes.usageCount(catalog, t);
                return `<li><strong>${esc(t.title)}</strong> — ${n} в данных</li>`;
              })
              .join('')}
          </ul>`;
        footEl.innerHTML = `<button type="button" class="btn-ghost vt-wizard-close">Отмена</button>
          <button type="button" class="btn-primary" id="vtWizardNext">Далее →</button>`;
        footEl.querySelector('#vtWizardNext')?.addEventListener('click', () => {
          wizardStep = 1;
          paintStep();
        });
      } else if (wizardStep === 1) {
        bodyEl.innerHTML = unmapped
          .map((t) => {
            const sel = wizardMappings.get(t.id) || '';
            return `<div class="vt-wizard-pair">
              <div class="vt-wizard-pair__old"><span class="vt-badge vt-badge--archived">было</span> ${esc(t.title)}</div>
              <div class="vt-wizard-pair__arrow">→</div>
              <select class="form-control vt-wizard-pair__select" data-vt-wiz-from="${esc(t.id)}">
                ${activeSelectOptions(sel, { includeEmpty: true })}
              </select>
            </div>`;
          })
          .join('');
        footEl.innerHTML = `<button type="button" class="btn-secondary" id="vtWizardBack">← Назад</button>
          <button type="button" class="btn-primary" id="vtWizardNext">Далее →</button>`;
        footEl.querySelector('#vtWizardBack')?.addEventListener('click', () => {
          wizardStep = 0;
          paintStep();
        });
        footEl.querySelector('#vtWizardNext')?.addEventListener('click', () => {
          bodyEl.querySelectorAll('.vt-wizard-pair__select').forEach((sel) => {
            if (sel.value) wizardMappings.set(sel.dataset.vtWizFrom, sel.value);
          });
          const missing = unmapped.filter((t) => !wizardMappings.get(t.id));
          if (missing.length) {
            GazpromToast.error('Выберите новый вид для каждого устаревшего');
            return;
          }
          wizardStep = 2;
          paintStep();
        });
      } else if (wizardStep === 2) {
        const before = ViolationTypes.buildKindStats(catalog, { resolve: false });
        const afterCatalog = JSON.parse(JSON.stringify(catalog));
        for (const [fromId, toId] of wizardMappings) {
          ViolationTypes.setMapping(afterCatalog, fromId, toId);
        }
        const after = ViolationTypes.buildKindStats(afterCatalog, { resolve: true });
        const highlight = [...after.keys()].slice(0, 3);
        bodyEl.innerHTML = `<p class="vt-wizard-intro">Как изменятся диаграммы после переноса.</p>
          <div class="vt-wizard-charts">
            ${renderWizardChart(before, 'До миграции')}
            ${renderWizardChart(after, 'После миграции', highlight)}
          </div>`;
        footEl.innerHTML = `<button type="button" class="btn-secondary" id="vtWizardBack">← Назад</button>
          <button type="button" class="btn-primary" id="vtWizardNext">Далее →</button>`;
        footEl.querySelector('#vtWizardBack')?.addEventListener('click', () => {
          wizardStep = 1;
          paintStep();
        });
        footEl.querySelector('#vtWizardNext')?.addEventListener('click', () => {
          wizardStep = 3;
          paintStep();
        });
      } else {
        bodyEl.innerHTML = `<p class="vt-wizard-intro">Сохранить ${wizardMappings.size} соответствий? Отчёты начнут группировать нарушения по новым видам.</p>
          <label class="vt-wizard-check">
            <input type="checkbox" id="vtWizardAlsoMigrate">
            Также обновить «вид нарушения» во всех актах и реестре (перед этим скачается резервная копия)
          </label>`;
        footEl.innerHTML = `<button type="button" class="btn-secondary" id="vtWizardBack">← Назад</button>
          <button type="button" class="btn-primary" id="vtWizardApply">Сохранить</button>`;
        footEl.querySelector('#vtWizardBack')?.addEventListener('click', () => {
          wizardStep = 2;
          paintStep();
        });
        footEl.querySelector('#vtWizardApply')?.addEventListener('click', async () => {
          for (const [fromId, toId] of wizardMappings) {
            ViolationTypes.setMapping(catalog, fromId, toId);
          }
          const alsoMigrate = overlay.querySelector('#vtWizardAlsoMigrate')?.checked;
          if (alsoMigrate) {
            try {
              await createVtMigrateBackup();
            } catch (err) {
              GazpromToast.error(err.message || 'Не удалось создать резервную копию. Миграция отменена.');
              return;
            }
            ViolationTypes.migrateStoredVids(catalog);
          }
          await saveCatalog(
            alsoMigrate ? 'Резервная копия сохранена. Миграция видов выполнена' : 'Миграция видов сохранена'
          );
          close();
          renderScreen();
        });
      }

      footEl.querySelectorAll('.vt-wizard-close').forEach((b) =>
        b.addEventListener('click', close)
      );
    };

    document.body.appendChild(overlay);
    GazpromMobileOverlay.lock();
    paintStep();
  }

  async function renderScreen() {
    await loadCatalog();
    if (
      currentTab === 'active' &&
      ViolationTypes.getPendingTypes(catalog).length > 0 &&
      ViolationTypes.getArchivedTypes(catalog).length === 0
    ) {
      currentTab = 'map';
    }
    renderHeader();
    renderTabBody();
  }

  function bindScreen() {
    if (bound) return;
    bound = true;
    document.querySelector('.settings-tile--violation-types')?.addEventListener('click', () => {
      if (typeof goTo === 'function') goTo('violation-types');
    });
    document.querySelector('.settings-tile--violation-types')?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        if (typeof goTo === 'function') goTo('violation-types');
      }
    });
  }

  async function maybePromptAfterImport() {
    const cat = await GazpromStore.get();
    if (!cat || !GazpromStore.hasData(cat)) return;
    ViolationTypes.ensureCatalog(cat);
    await GazpromStore.set(cat);
    const unmapped = ViolationTypes.getUnmappedArchived(cat);
    if (!unmapped.length) return;
    const run = await GazpromToast.confirm(
      `Обнаружено ${unmapped.length} устаревших видов нарушений без соответствия. Открыть мастер миграции?`
    );
    if (!run) return;
    catalog = cat;
    if (typeof goTo === 'function') goTo('violation-types');
    openWizard();
  }

  function init() {
    bindScreen();
  }

  return {
    init,
    renderScreen,
    openWizard,
    openSplitModal,
    maybePromptAfterImport,
  };
})();
