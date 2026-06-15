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

  async function loadCatalog() {
    catalog = await GazpromStore.get();
    if (!catalog) {
      catalog = {
        akts: [],
        violationTypes: [],
        typeMappings: {},
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
          : ViolationTypes.getArchivedTypes(catalog).length;
      const warn =
        tab.key === 'map' && ViolationTypes.getUnmappedArchived(catalog).length > 0
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
    document.getElementById('vtAddTypeBtn')?.addEventListener('click', () => {
      handleAddType({ forMapColumn: currentTab === 'map' || !!mapSelectedFrom });
    });
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

    if (currentTab === 'active') renderActiveTab(body);
    else if (currentTab === 'archive') renderArchiveTab(body);
    else renderMapTab(body);
  }

  function renderActiveTab(body) {
    const items = filterByQuery(ViolationTypes.getActiveTypes(catalog));
    if (!items.length) {
      body.innerHTML = `<p class="vt-empty">Нет активных видов. Нажмите «+ Новый вид».</p>`;
      return;
    }

    body.innerHTML = `
      <table class="list-table">
        <thead>
          <tr>
            <th>Название</th>
            <th style="width:100px;">В данных</th>
            <th style="width:120px;"></th>
          </tr>
        </thead>
        <tbody>
          ${items
            .map((t) => {
              const n = ViolationTypes.usageCount(catalog, t);
              return `<tr>
                <td>${esc(t.title)}</td>
                <td>${n || '—'}</td>
                <td class="btn-row">
                  <button type="button" class="btn-ghost btn-sm" data-vt-archive="${esc(t.id)}" title="В архив">📦</button>
                </td>
              </tr>`;
            })
            .join('')}
        </tbody>
      </table>`;

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
  }

  function renderArchiveTab(body) {
    const items = filterByQuery(ViolationTypes.getArchivedTypes(catalog));
    if (!items.length) {
      body.innerHTML = `<p class="vt-empty">Архив пуст. Неактивные виды появятся здесь после переноса с вкладки «Активные» (кнопка 📦) или при импорте устаревших данных.</p>`;
      return;
    }

    body.innerHTML = `
      <table class="list-table">
        <thead>
          <tr>
            <th>Устаревший вид</th>
            <th style="width:100px;">В данных</th>
            <th>Заменён на</th>
            <th style="width:120px;"></th>
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
                <td>${esc(t.title)} ${status}</td>
                <td>${n || '—'}</td>
                <td>${mapped ? esc(mapped.title) : '—'}</td>
                <td class="btn-row">
                  <button type="button" class="btn-secondary btn-sm" data-vt-goto-map="${esc(t.id)}">Сопоставить</button>
                </td>
              </tr>`;
            })
            .join('')}
        </tbody>
      </table>`;

    body.querySelectorAll('[data-vt-goto-map]').forEach((btn) => {
      btn.addEventListener('click', () => openSplitModal(btn.dataset.vtGotoMap));
    });
  }

  function renderMapTab(body) {
    const archived = filterByQuery(ViolationTypes.getArchivedTypes(catalog));
    const active = ViolationTypes.getActiveTypes(catalog);

    if (!archived.length) {
      body.innerHTML = `<p class="vt-empty">Нет архивных видов для сопоставления. Перенесите вид в архив на вкладке «Активные» (кнопка 📦) или откройте вкладку «Архив».</p>`;
      return;
    }

    if (!active.length) {
      body.innerHTML = `<p class="vt-empty">Сначала создайте активный вид — кнопка «+ Новый вид» вверху.</p>`;
      return;
    }

    if (!mapSelectedFrom || !archived.some((t) => t.id === mapSelectedFrom)) {
      mapSelectedFrom = archived[0].id;
    }

    if (mapPinNewTypeId) {
      mapSelectedTo = mapPinNewTypeId;
      mapPinNewTypeId = null;
    }

    const fromType = ViolationTypes.findById(catalog, mapSelectedFrom);
    const activeIds = new Set(active.map((t) => t.id));
    if (!mapSelectedTo || !activeIds.has(mapSelectedTo)) {
      mapSelectedTo =
        fromType?.replacedBy ||
        ViolationTypes.getMappings(catalog)[mapSelectedFrom] ||
        active[0]?.id ||
        null;
    }

    const toType = ViolationTypes.findById(catalog, mapSelectedTo);
    const usageN = fromType ? ViolationTypes.usageCount(catalog, fromType) : 0;
    const previewText =
      fromType && toType
        ? usageN > 0
          ? `Отчёт «Виды выявленных нарушений»: +${usageN} к «${toType.title}»`
          : 'В данных нет записей с этим видом'
        : '';

    body.innerHTML = `
      <div class="vt-split-inline">
        <div class="vt-split-body">
          <div class="vt-split-col vt-split-col--old">
            <h4>Устаревший вид</h4>
            <div id="vtInlineOldList">
              ${archived
                .map((t) => {
                  const n = ViolationTypes.usageCount(catalog, t);
                  const mapped = ViolationTypes.isMappedToActive(catalog, t);
                  return `<button type="button" class="vt-type-item ${t.id === mapSelectedFrom ? 'selected' : ''}" data-vt-from-item="${esc(t.id)}">
                    <div>${esc(t.title)}</div>
                    <div class="vt-type-item__meta">
                      <span class="vt-badge vt-badge--archived">архив</span>
                      ${mapped ? '<span class="vt-badge vt-badge--ok">настроено</span>' : '<span class="vt-badge vt-badge--warn">нет пары</span>'}
                      ${n ? `<span class="vt-badge vt-badge--count">${n} зап.</span>` : ''}
                    </div>
                  </button>`;
                })
                .join('')}
            </div>
          </div>
          <div class="vt-split-arrow" aria-hidden="true">→</div>
          <div class="vt-split-col vt-split-col--new">
            <h4>Новый активный вид</h4>
            <div id="vtInlineNewList">
              ${[...active]
                .sort((a, b) => {
                  if (a.id === mapSelectedTo) return -1;
                  if (b.id === mapSelectedTo) return 1;
                  return a.title.localeCompare(b.title, 'ru');
                })
                .map(
                  (t) => `<button type="button" class="vt-type-item ${t.id === mapSelectedTo ? 'selected' : ''}" data-vt-to-item="${esc(t.id)}">
                    <div>${esc(t.title)}</div>
                    <div class="vt-type-item__meta">
                      <span class="vt-badge vt-badge--active">активен</span>
                      ${t.id === mapSelectedTo ? '<span class="vt-badge vt-badge--ok">новый</span>' : ''}
                    </div>
                  </button>`
                )
                .join('')}
            </div>
            <button type="button" class="btn-primary btn-sm vt-split-add-new" id="vtInlineAddType">+ Новый вид</button>
          </div>
        </div>
        ${previewText ? `<div class="vt-split-preview">${esc(previewText)}</div>` : ''}
        <div class="vt-footer-actions">
          <button type="button" class="btn-primary" id="vtInlineSaveMap">Сохранить соответствие</button>
          <button type="button" class="btn-secondary" id="vtMigrateData">Применить ко всем данным</button>
        </div>
      </div>`;

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
    body.querySelector('#vtInlineAddType')?.addEventListener('click', () => {
      handleAddType({ forMapColumn: true });
    });
    body.querySelector('#vtInlineSaveMap')?.addEventListener('click', async () => {
      if (!mapSelectedFrom || !mapSelectedTo) return;
      ViolationTypes.setMapping(catalog, mapSelectedFrom, mapSelectedTo);
      await saveCatalog('Соответствие сохранено');
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
      'Обновить поле «вид нарушения» во всех актах и реестре по новым соответствиям? Это необратимо.'
    );
    if (!ok) return;
    const n = ViolationTypes.migrateStoredVids(catalog);
    await saveCatalog(`Обновлено записей: ${n}`);
    renderScreen();
  }

  async function handleAddType({ forMapColumn = false } = {}) {
    const title = await GazpromToast.prompt('Название нового вида нарушения', '');
    if (title === null) return;
    const trimmed = String(title).trim();
    if (!trimmed) {
      GazpromToast.error('Введите название вида');
      return;
    }

    const created = ViolationTypes.addType(catalog, trimmed);
    if (!created) return;

    const useMapFlow = forMapColumn || currentTab === 'map' || !!mapSelectedFrom;

    if (useMapFlow) {
      mapPinNewTypeId = created.id;
      mapSelectedTo = created.id;
      currentTab = 'map';
      if (mapSelectedFrom && mapSelectedFrom !== created.id) {
        ViolationTypes.setMapping(catalog, mapSelectedFrom, created.id);
        await saveCatalog('Новый вид создан и выбран для сопоставления');
      } else {
        await saveCatalog('Новый вид добавлен');
      }
    } else {
      currentTab = 'active';
      await saveCatalog('Вид добавлен');
    }

    renderScreen();
    requestAnimationFrame(() => {
      document
        .querySelector('#vtInlineNewList .vt-type-item.selected')
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
            Также обновить «вид нарушения» во всех актах и реестре
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
          if (overlay.querySelector('#vtWizardAlsoMigrate')?.checked) {
            ViolationTypes.migrateStoredVids(catalog);
          }
          await saveCatalog('Миграция видов сохранена');
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
