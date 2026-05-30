/**
 * Отрисовка экранов из данных GazpromStore.
 */
const GazpromUI = (() => {
  let historyQuery = '';
  let historyFilter = { year: null, violationsOnly: false, draftsOnly: false };

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
      btn.textContent = editable
        ? `Продолжить акт № ${editable.number}`
        : 'Создать новый акт';
    }
    const subAction = document.getElementById('homeSubAction');
    if (subAction) subAction.hidden = !editable;

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

    const akts = AktSearch.filterAkts(data.akts, {
      query,
      year: filter.year,
      violationsOnly: filter.violationsOnly,
      draftsOnly: filter.draftsOnly,
    });

    if (!akts.length) {
      tbody.innerHTML =
        '<tr><td colspan="7" style="text-align:center;color:var(--text-muted);padding:32px;">Нет актов по выбранным критериям.</td></tr>';
      return;
    }

    tbody.innerHTML = akts
      .map((akt) => {
        const draft = isDraft(akt);
        const org = AktSearch.getOrgTitle(akt) || '—';
        const viol = countViolations(akt);
        const objs = (akt.objectsCheck || []).length;
        const icon = draft ? '✏️' : '📄';
        const title = draft ? 'Редактировать' : 'Открыть';
        return `<tr>
          <td><strong>${escapeHtml(akt.number)}</strong></td>
          <td>${formatDateShort(akt.date)}</td>
          <td>${escapeHtml(org)}</td>
          <td>${objs}</td>
          <td>${viol}</td>
          <td><span class="badge ${draft ? 'badge-orange' : 'badge-green'}">${draft ? 'Черновик' : 'Завершён'}</span></td>
          <td><button class="btn-ghost" type="button" title="${title}" data-akt-open="${escapeHtml(akt.id)}">${icon}</button></td>
        </tr>`;
      })
      .join('');
  }

  function renderElimination(data, options = {}) {
    const tbody = document.querySelector('#eliminationTableBody');
    if (!tbody) return;

    const mode = options.filterMode || EliminationEditor.filterMode?.() || 'open';
    let list = data.violationEliminations || [];
    if (mode === 'open') list = list.filter((e) => !e.isEliminated);
    else list = list.filter((e) => e.isEliminated);

    if (!list.length) {
      tbody.innerHTML =
        '<tr><td colspan="5" style="text-align:center;color:var(--text-muted);padding:32px;">Нет записей</td></tr>';
      return;
    }

    tbody.innerHTML = list
      .map((e) => {
        const deadline =
          e.deadlineHistory?.length > 0
            ? e.deadlineHistory[e.deadlineHistory.length - 1].deadlineDate
            : e.newEliminationDate || e.originalEliminationDate;
        const overdue = deadline && new Date(deadline) < new Date() && !e.isEliminated;
        const before = (e.beforePhotos || []).length;
        const after = (e.afterPhotos || []).length;
        const photoCell = `📷 ${before} / ${after ? '📷 ' + after : '—'}`;
        return `<tr>
          <td>№ ${escapeHtml(e.aktNumber)}</td>
          <td>${escapeHtml((e.violationTitle || '').slice(0, 80))}${(e.violationTitle || '').length > 80 ? '…' : ''}</td>
          <td class="${overdue ? 'text-danger' : ''}">${deadline ? formatDateShort(deadline) : '—'}${overdue ? ' ⚠' : ''}</td>
          <td>${photoCell}</td>
          <td><button class="btn-secondary btn-sm" type="button" data-elim-mark="${escapeHtml(e.id)}">Отметить</button></td>
        </tr>`;
      })
      .join('');
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
    if (!el) return;

    if (!GazpromStore.hasData(data)) {
      el.className = 'data-status data-status--empty';
      el.innerHTML =
        '<span>Данные не загружены</span> — импортируйте файл <code>.gazprombackup</code> или начните работу с нуля';
      return;
    }

    const s = GazpromBackup.getStats(data);
    const isFresh = !data.importedAt && !data.timestamp && s.akts === 0;
    if (isFresh) {
      el.className = 'data-status data-status--ok';
      el.innerHTML =
        '<span>✓ Новая база данных</span> — создавайте акты и заполняйте справочники в Настройках';
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

  function setHistoryQuery(q) {
    historyQuery = q;
  }

  function setHistoryFilter(filter) {
    historyFilter = { ...historyFilter, ...filter };
  }

  async function refreshAll() {
    const data = await GazpromStore.get();
    renderDataStatus(data);
    if (!GazpromStore.hasData(data)) return;
    renderHome(data);
    renderHistory(data);
    renderElimination(data);
    renderTrash(data);
    renderSettingsTilesSync(data);
    if (document.getElementById('screen-wizard')?.classList.contains('active')) {
      WizardController.open();
    }
  }

  function renderSettingsTilesSync(data) {
    const tiles = document.querySelectorAll('#screen-settings .settings-tile p');
    const counts = {
      0: data.comissionPeople?.length,
      1: data.organizations?.length,
      2: data.objects?.length,
      4: data.predstavitely?.length,
      5: `${data.scheduleItems?.length || 0} записей`,
      6: data.wordTemplateName || (data[DocGenerator.TEMPLATE_KEY] ? 'загружен' : 'не задан'),
      8: `${data.trash?.length || 0} в корзине`,
    };
    tiles.forEach((p, i) => {
      if (counts[i] !== undefined) {
        const n = counts[i];
        p.textContent = typeof n === 'number' ? `${n} записей` : String(n);
      }
    });
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
  };
})();
