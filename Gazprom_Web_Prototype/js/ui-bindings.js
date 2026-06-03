/**
 * Отрисовка экранов из данных GazpromStore.
 */
const GazpromUI = (() => {
  let historyQuery = '';
  let historyFilter = {
    years: [],
    violationsOnly: false,
    draftsOnly: false,
    shortOnly: false,
    fullOnly: false,
  };
  let historySort = { key: 'date', direction: 'desc' };
  let lastSyncAt = null;
  let dataStatusHideTimer = null;
  const DATA_STATUS_PEEK_MS = 3500;
  const DATA_STATUS_ANIM_MS = 750;

  function clearDataStatusInlineHide(el) {
    if (!el) return;
    [
      'display',
      'max-height',
      'padding-top',
      'padding-bottom',
      'margin',
      'opacity',
      'transform',
      'overflow',
      'border-bottom-width',
      'transition',
    ].forEach((prop) => el.style.removeProperty(prop));
  }

  function resetDataStatusPeek(el) {
    if (!el) return;
    clearTimeout(dataStatusHideTimer);
    dataStatusHideTimer = null;
    el.classList.remove('data-status--peek', 'data-status--hidden');
    el.hidden = false;
    clearDataStatusInlineHide(el);
    el.removeAttribute('aria-hidden');
  }

  function finalizeDataStatusHide(el) {
    if (!el || el.hidden) return;
    el.classList.add('data-status--hidden');
    el.setAttribute('aria-hidden', 'true');
    let finalized = false;
    const done = () => {
      if (finalized) return;
      finalized = true;
      el.hidden = true;
      el.style.display = 'none';
    };
    const onTransitionEnd = (e) => {
      if (e.target !== el) return;
      done();
    };
    el.addEventListener('transitionend', onTransitionEnd);
    setTimeout(() => {
      el.removeEventListener('transitionend', onTransitionEnd);
      done();
    }, DATA_STATUS_ANIM_MS + 120);
  }

  function peekDataStatusBar(el) {
    if (!el) return;
    clearTimeout(dataStatusHideTimer);
    el.hidden = false;
    clearDataStatusInlineHide(el);
    el.classList.add('data-status--peek', 'data-status--hidden');
    el.setAttribute('aria-hidden', 'true');
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        el.classList.remove('data-status--hidden');
        el.setAttribute('aria-hidden', 'false');
      });
    });
    dataStatusHideTimer = setTimeout(() => {
      finalizeDataStatusHide(el);
      dataStatusHideTimer = null;
    }, DATA_STATUS_PEEK_MS);
  }

  function formatSyncTime(date = new Date()) {
    const d = date instanceof Date ? date : new Date(date);
    if (Number.isNaN(d.getTime())) return '—';
    const now = new Date();
    const time = d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
    if (d.toDateString() === now.toDateString()) return `Сегодня, ${time}`;
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    if (d.toDateString() === yesterday.toDateString()) return `Вчера, ${time}`;
    return d.toLocaleString('ru-RU', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  function updateHeaderSync({ busy = false } = {}) {
    const btn = document.getElementById('headerSyncBtn');
    const statusEl = document.getElementById('headerSyncStatus');
    const timeEl = document.getElementById('headerSyncTime');
    if (!btn || !statusEl || !timeEl) return;

    if (busy) {
      btn.classList.add('header-sync--busy');
      statusEl.textContent = 'Обновление…';
      return;
    }

    btn.classList.remove('header-sync--busy');
    if (!lastSyncAt) lastSyncAt = new Date();
    statusEl.textContent = 'Синхронизировано';
    timeEl.textContent = formatSyncTime(lastSyncAt);
  }

  function formatDateShort(iso) {
    if (!iso) return '—';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return '—';
    return d.toLocaleDateString('ru-RU');
  }

  function isDraft(akt) {
    return AktUtils.isDraft(akt);
  }

  function countViolations(akt) {
    return (akt.violations || []).length;
  }

  function renderHome(data) {
    if (!data) return;

    const akts = data.akts || [];
    const drafts = akts.filter(isDraft).length;
    const editable = AktUtils.getFullEditableAkt(data);
    const currentNum = editable?.number || (akts.length ? akts[akts.length - 1].number : '—');

    const elCurrent = document.getElementById('homeStatCurrent');
    const elTotal = document.getElementById('homeStatTotal');
    const elDrafts = document.getElementById('homeStatDrafts');
    if (elCurrent) elCurrent.textContent = currentNum;
    if (elTotal) elTotal.textContent = String(akts.length);
    if (elDrafts) elDrafts.textContent = String(drafts);

    const btn = document.querySelector('#screen-home .btn-primary[data-go="wizard"]');
    if (btn) {
      btn.textContent = editable
        ? `Продолжить полный акт № ${editable.number}`
        : 'Создать полный акт';
    }
    const subAction = document.getElementById('homeSubAction');
    if (subAction) {
      subAction.hidden = !editable;
      if (editable) {
        subAction.innerHTML =
          '<button class="btn-secondary home-akt-actions__sub" type="button" data-go="wizard" data-wizard-new="1">Начать новый полный Акт</button>';
      }
    }

    renderScheduleProgress(data);
  }

  function renderScheduleProgress(data) {
    const items = data.scheduleItems || [];
    const year = new Date().getFullYear();
    const yearItems = items.filter((i) => i.year === year);
    const plan = yearItems.length;
    const done = yearItems.filter((i) => i.actualDate).length;
    const percent = plan > 0 ? done / plan : 0;

    const fill = document.getElementById('progressFill');
    const label = document.getElementById('progressLabel');
    if (fill) fill.style.width = `${Math.round(percent * 100)}%`;
    if (label) {
      label.textContent =
        plan > 0
          ? `График проверок ${year} г.: ${Math.round(percent * 100)}% (${done}/${plan})`
          : `График проверок ${year} г.: план не задан`;
    }

    const progressBlock = document.querySelector('.progress-block');
    if (progressBlock && !progressBlock.dataset.bound) {
      progressBlock.dataset.bound = '1';
      progressBlock.style.cursor = 'pointer';
      let monthMode = false;
      progressBlock.addEventListener('click', () => {
        monthMode = !monthMode;
        const now = new Date();
        if (monthMode) {
          const monthItems = yearItems.filter((i) => i.month === now.getMonth() + 1);
          const mPlan = monthItems.length;
          const mDone = monthItems.filter((i) => i.actualDate).length;
          const p = mPlan > 0 ? Math.round((mDone / mPlan) * 100) : 0;
          if (fill) fill.style.width = `${p}%`;
          if (label) {
            label.textContent =
              mPlan > 0
                ? `График за ${now.toLocaleString('ru', { month: 'long' })}: ${p}% (${mDone}/${mPlan})`
                : `График за месяц: план не задан`;
          }
        } else {
          renderScheduleProgress(data);
        }
      });
    }
  }

  function getHistoryActType(short, full) {
    return short ? 'Сокращённый акт' : full ? 'Полный акт' : 'Акт проверки';
  }

  function getHistoryObjectHtml(akt) {
    const obj = (akt.objectsCheck || [])[0];
    const objectTitle = obj?.title || obj?.subTitle || '';
    if (!objectTitle) return '';
    return `<p class="history-list-item__object">${escapeHtml(objectTitle)}</p>`;
  }

  const historyDocIcon = `<svg class="history-list-item__icon-svg" viewBox="0 0 24 24" fill="none" aria-hidden="true">
    <path d="M8 3h7l4 4v14a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M15 3v4h4M9 12h6M9 16h4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
  </svg>`;

  function renderHistory(data, options = {}) {
    const list = document.querySelector('#historyList');
    if (!list) return;

    const query = options.query ?? historyQuery;
    const filter = options.filter ?? historyFilter;

    const filtered = AktSearch.filterAkts(data.akts, {
      query,
      years: filter.years,
      violationsOnly: filter.violationsOnly,
      draftsOnly: filter.draftsOnly,
      shortOnly: filter.shortOnly,
      fullOnly: filter.fullOnly,
    });
    const akts = AktSearch.sortAkts(filtered, historySort.key, historySort.direction);
    updateHistorySortHeaders();

    if (!akts.length) {
      list.innerHTML =
        '<div class="history-list-empty">Нет актов по выбранным критериям.</div>';
      return;
    }

    list.innerHTML = akts
      .map((akt) => {
        const draft = isDraft(akt);
        const short = AktUtils.isShortFormat(akt);
        const full = AktUtils.isFullFormat(akt);
        const org = AktSearch.getOrgTitle(akt) || '—';
        const objectHtml = getHistoryObjectHtml(akt);
        const inspectionDate =
          typeof AktUtils?.formatDateShort === 'function'
            ? AktUtils.formatDateShort(akt.date)
            : formatDateShort(akt.date);
        const actType = getHistoryActType(short, full);
        const draftHint = draft
          ? '<span class="history-list-item__draft">Черновик</span>'
          : '';
        const openLabel = short
          ? 'Редактировать сокращённый акт'
          : draft
            ? 'Редактировать полный акт'
            : 'Открыть полный акт';
        const rowClass = short
          ? 'history-list-item history-row history-row--short card'
          : full
            ? 'history-list-item history-row history-row--full card'
            : 'history-list-item history-row card';
        return `<div class="${rowClass}" data-akt-id="${escapeHtml(akt.id)}" data-akt-short="${short ? '1' : '0'}" role="listitem" tabindex="0" title="${openLabel}" aria-label="${openLabel}: № ${escapeHtml(akt.number)}">
          <div class="history-list-item__icon">${historyDocIcon}</div>
          <div class="history-list-item__content">
            <div class="history-list-item__header">
              <div class="history-list-item__body">
                <div class="history-list-item__head">
                  <h4 class="history-list-item__title">Акт №${escapeHtml(akt.number)}</h4>
                  <span class="history-list-item__org">${escapeHtml(org)}</span>
                  <span class="history-list-item__date">Проверка: ${escapeHtml(inspectionDate)}</span>
                </div>
              </div>
              <div class="history-list-item__aside">
                <button type="button" class="history-list-item__delete" data-history-trash="${escapeHtml(akt.id)}" aria-label="Переместить акт № ${escapeHtml(akt.number)} в корзину" title="В корзину"><span aria-hidden="true">×</span></button>
                <span class="history-list-item__chevron" aria-hidden="true">›</span>
              </div>
            </div>
            <div class="history-list-item__foot">
              ${objectHtml}
              <span class="history-list-item__type">${escapeHtml(actType)}</span>
              ${draftHint}
            </div>
          </div>
        </div>`;
      })
      .join('');
  }

  function renderElimination(data) {
    if (typeof EliminationEditor?.render === 'function') {
      EliminationEditor.render(data);
    }
  }

  function renderTrash(data) {
    const tbody = document.querySelector('#trashTableBody');
    if (!tbody) return;
    const trash = data.trash || [];
    if (!trash.length) {
      tbody.innerHTML =
        '<tr><td colspan="5" style="text-align:center;padding:24px;color:var(--text-muted)">Корзина пуста</td></tr>';
      return;
    }
    tbody.innerHTML = trash
      .map(
        (akt) => `<tr>
        <td><strong>${escapeHtml(akt.number)}</strong></td>
        <td>${formatDateShort(akt.date)}</td>
        <td>${escapeHtml(AktSearch.getOrgTitle(akt))}</td>
        <td>${countViolations(akt)}</td>
        <td>
          <button type="button" class="btn-secondary btn-sm" data-trash-restore="${escapeHtml(akt.id)}">Восстановить</button>
          <button type="button" class="btn-ghost btn-sm modal-btn-danger" data-trash-delete="${escapeHtml(akt.id)}">Удалить</button>
        </td>
      </tr>`
      )
      .join('');
  }

  function renderDataStatus(data) {
    const el = document.getElementById('dataStatusBar');
    if (!el || !data) return;

    const s = GazpromBackup.getStats(data);
    const isFresh =
      !data.importedAt &&
      !data.timestamp &&
      !data.sourceFileName &&
      s.akts === 0;
    if (isFresh) {
      resetDataStatusPeek(el);
      el.className = 'data-status data-status--ok';
      el.innerHTML =
        '<span class="data-status__line data-status__line--full"><span>✓ Новая база данных</span> — создавайте акты и заполняйте справочники в Настройках</span>' +
        '<span class="data-status__line data-status__line--compact">✓ Новая база — создавайте акты в Настройках</span>';
      return;
    }

    if (!GazpromStore.hasData(data)) {
      resetDataStatusPeek(el);
      el.className = 'data-status data-status--empty';
      el.innerHTML =
        '<span class="data-status__line data-status__line--full"><span>Данные не загружены</span> — импортируйте файл <code>.gazprombackup</code> или начните работу с нуля</span>' +
        '<span class="data-status__line data-status__line--compact">Данные не загружены — импорт <code>.gazprombackup</code></span>';
      return;
    }

    const fileLabel = data.sourceFileName ? escapeHtml(data.sourceFileName) : 'резервная копия';
    const dateLabel = GazpromBackup.formatDate(data.importedAt || data.timestamp);
    el.className = 'data-status data-status--ok';
    el.setAttribute('role', 'status');
    el.setAttribute('aria-live', 'polite');
    el.innerHTML = `
      <span class="data-status__line data-status__line--full">
        <span>✓ Данные загружены</span>
        · актов: <strong>${s.akts}</strong>
        · организаций: <strong>${s.organizations}</strong>
        · фото: <strong>${s.photos}</strong>
        · ${fileLabel}
        · ${dateLabel}
      </span>
      <span class="data-status__line data-status__line--compact">
        ✓ актов: <strong>${s.akts}</strong> · орг: <strong>${s.organizations}</strong> · фото: <strong>${s.photos}</strong>
      </span>
    `;
    peekDataStatusBar(el);
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function updateHistorySortHeaders() {
    document.querySelectorAll('#screen-history .history-sort-btn[data-sort-key]').forEach((btn) => {
      const active = btn.dataset.sortKey === historySort.key;
      btn.classList.toggle('history-sort-btn--active', active);
      btn.classList.toggle('history-sort-btn--asc', active && historySort.direction === 'asc');
      btn.classList.toggle('history-sort-btn--desc', active && historySort.direction === 'desc');
      btn.setAttribute('aria-sort', active ? (historySort.direction === 'asc' ? 'ascending' : 'descending') : 'none');
    });
  }

  function toggleHistorySort(key) {
    if (historySort.key === key) {
      historySort = { key, direction: historySort.direction === 'asc' ? 'desc' : 'asc' };
    } else {
      historySort = { key, direction: 'asc' };
    }
  }

  function setHistoryQuery(q) {
    historyQuery = q;
  }

  function setHistoryFilter(filter) {
    historyFilter = {
      years: [],
      violationsOnly: false,
      draftsOnly: false,
      shortOnly: false,
      fullOnly: false,
      ...filter,
    };
  }

  async function refreshAll() {
    updateHeaderSync({ busy: true });
    try {
      const data = await GazpromStore.get();
      renderDataStatus(data);
      renderHome(data);
      renderHistory(data);
      renderElimination(data);
      renderTrash(data);
      renderSettingsTilesSync(data);
      if (document.getElementById('screen-wizard')?.classList.contains('active')) {
        await WizardController.syncCatalog();
      }
      lastSyncAt = new Date();
    } finally {
      updateHeaderSync({ busy: false });
    }
  }

  function renderSettingsTilesSync(data) {
    // Обновляем бейджи на тайлах справочников через data-catalog
    const catalogCounts = {
      commission:    data.comissionPeople?.length ?? 0,
      organizations: data.organizations?.length ?? 0,
      objects:       data.objects?.length ?? 0,
      predstavitely: data.predstavitely?.length ?? 0,
      violations:    data.violationRegistry?.length ?? 0,
    };

    Object.entries(catalogCounts).forEach(([key, count]) => {
      const tile = document.querySelector(`[data-catalog="${key}"]`);
      if (!tile) return;
      const badge = tile.querySelector('.tile-count');
      if (badge) badge.textContent = count > 0 ? String(count) : '';
    });

    // График
    const scheduleTile = document.querySelector('.settings-tile--schedule');
    if (scheduleTile) {
      const badge = scheduleTile.querySelector('.tile-count');
      if (badge) {
        const n = data.scheduleItems?.length || 0;
        badge.textContent = n > 0 ? String(n) : '';
      }
    }

    // Шаблон Word
    const templateBadge = document.querySelector('[data-template-status]');
    if (templateBadge) {
      const hasTemplate = !!(data.wordTemplateName || data[DocGenerator?.TEMPLATE_KEY]);
      templateBadge.textContent = hasTemplate
        ? (data.wordTemplateName || 'загружен')
        : '';
      templateBadge.style.color = hasTemplate ? 'var(--success)' : '';
    }

    // Корзина
    const trashBadge = document.querySelector('[data-trash-count]');
    if (trashBadge) {
      const n = data.trash?.length || 0;
      trashBadge.textContent = n > 0 ? String(n) : '';
    }
  }

  return {
    refreshAll,
    renderHome,
    renderHistory,
    renderElimination,
    renderTrash,
    renderDataStatus,
    setHistoryQuery,
    setHistoryFilter,
    toggleHistorySort,
  };
})();
