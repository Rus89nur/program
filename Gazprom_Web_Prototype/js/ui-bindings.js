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
    const editable = data.editableAkt?.akt;
    const currentNum = editable?.number || (akts.length ? akts[akts.length - 1].number : '—');

    const elCurrent = document.getElementById('homeStatCurrent');
    const elTotal = document.getElementById('homeStatTotal');
    const elDrafts = document.getElementById('homeStatDrafts');
    if (elCurrent) elCurrent.textContent = currentNum;
    if (elTotal) elTotal.textContent = String(akts.length);
    if (elDrafts) elDrafts.textContent = String(drafts);

    const btn = document.querySelector('#screen-home .btn-primary[data-go="wizard"]');
    if (btn) {
      const shortEditable = editable && AktUtils.isShortFormat(editable);
      btn.textContent = editable
        ? shortEditable
          ? `Продолжить сокращённый № ${editable.number}`
          : `Продолжить полный акт № ${editable.number}`
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

  function renderHistory(data, options = {}) {
    const tbody = document.querySelector('#historyTableBody');
    if (!tbody) return;

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
      tbody.innerHTML =
        '<tr><td colspan="6" style="text-align:center;color:var(--text-muted);padding:32px;">Нет актов по выбранным критериям.</td></tr>';
      return;
    }

    tbody.innerHTML = akts
      .map((akt) => {
        const draft = isDraft(akt);
        const short = AktUtils.isShortFormat(akt);
        const full = AktUtils.isFullFormat(akt);
        const org = AktSearch.getOrgTitle(akt) || '—';
        const viol = countViolations(akt);
        const openLabel = short
          ? 'Редактировать сокращённый акт'
          : draft
            ? 'Редактировать полный акт'
            : 'Открыть полный акт';
        const rowClass = short
          ? 'history-row history-row--short'
          : full
            ? 'history-row history-row--full'
            : 'history-row';
        const typeBadge = short
          ? '<span class="akt-badge akt-badge--short">Сокращённый</span>'
          : full
            ? '<span class="akt-badge akt-badge--full">Полный</span>'
            : '<span class="akt-badge akt-badge--muted">—</span>';
        const draftBadge = draft
          ? ' <span class="akt-badge akt-badge--draft">Черновик</span>'
          : '';
        return `<tr class="${rowClass}" data-akt-id="${escapeHtml(akt.id)}" data-akt-short="${short ? '1' : '0'}" role="button" tabindex="0" title="${openLabel}" aria-label="${openLabel}: № ${escapeHtml(akt.number)}">
          <td><strong>${escapeHtml(akt.number)}</strong></td>
          <td>${formatDateShort(akt.date)}</td>
          <td>${escapeHtml(org)}</td>
          <td>${viol}</td>
          <td class="history-type-cell">${typeBadge}${draftBadge}</td>
          <td class="history-actions-cell">
            <button type="button" class="history-delete-btn" data-history-trash="${escapeHtml(akt.id)}" aria-label="Переместить акт № ${escapeHtml(akt.number)} в корзину" title="В корзину">🗑</button>
          </td>
        </tr>`;
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
      el.className = 'data-status data-status--ok';
      el.innerHTML =
        '<span>✓ Новая база данных</span> — создавайте акты и заполняйте справочники в Настройках';
      return;
    }

    if (!GazpromStore.hasData(data)) {
      el.className = 'data-status data-status--empty';
      el.innerHTML =
        '<span>Данные не загружены</span> — импортируйте файл <code>.gazprombackup</code> или начните работу с нуля';
      return;
    }

    el.className = 'data-status data-status--ok';
    el.innerHTML = `
      <span>✓ Данные загружены</span>
      · актов: <strong>${s.akts}</strong>
      · организаций: <strong>${s.organizations}</strong>
      · фото: <strong>${s.photos}</strong>
      · ${data.sourceFileName ? escapeHtml(data.sourceFileName) : 'резервная копия'}
      · ${GazpromBackup.formatDate(data.importedAt || data.timestamp)}
    `;
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function updateHistorySortHeaders() {
    document.querySelectorAll('#screen-history .list-table thead th[data-sort-key]').forEach((th) => {
      const active = th.dataset.sortKey === historySort.key;
      th.classList.toggle('th--sorted', active);
      th.classList.toggle('th--sorted-asc', active && historySort.direction === 'asc');
      th.classList.toggle('th--sorted-desc', active && historySort.direction === 'desc');
      th.setAttribute('aria-sort', active ? (historySort.direction === 'asc' ? 'ascending' : 'descending') : 'none');
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
