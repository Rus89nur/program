/**
 * Устранение нарушений — UI и логика как в iOS (список по актам, статистика, детальная карточка).
 */
const EliminationEditor = (() => {
  let selectedYear = null;
  let selectedFilter = 'all';
  let detailState = null;
  let persistTimer = null;

  const RING_R = 28;
  const RING_C = 2 * Math.PI * RING_R;
  const RING_CX = 34;

  function schedulePersist(catalog) {
    GazpromStore.updateCache(catalog);
    clearTimeout(persistTimer);
    persistTimer = setTimeout(() => {
      void GazpromStore.set(catalog);
    }, 400);
  }

  async function flushPersist() {
    if (!persistTimer) return;
    clearTimeout(persistTimer);
    persistTimer = null;
    const data = await GazpromStore.get();
    await GazpromStore.set(data);
  }

  function refreshEliminationLight(catalog, aktId = null) {
    const items = buildEliminationItems(catalog);
    renderStats(items);
    renderDonut(computeStats(items));
    if (aktId) {
      patchActCard(aktId, items);
    } else {
      renderCardList(applyStatusFilter(items));
    }
  }

  function applyStatusFilter(items) {
    if (selectedFilter === 'overdue') {
      return items.filter(
        (i) => i.totalViolations > 0 && i.hasOverdue && !i.allEliminated
      );
    }
    return items;
  }

  function ringMetrics(eliminated, total) {
    if (total <= 0) {
      return { dash: `0 ${RING_C}`, label: '—', pct: 0 };
    }
    const pct = Math.min(100, Math.round((eliminated / total) * 100));
    const filled = (RING_C * eliminated) / total;
    return {
      dash: `${filled} ${RING_C - filled}`,
      label: `${pct}%`,
      pct,
    };
  }

  function buildStatusLineHtml(akt, allDone, overdue, noViolations) {
    if (noViolations) {
      return '<p class="elimination-act-card__status-line elimination-act-card__status-line--muted">Нарушения отсутствуют</p>';
    }
    const orgName = akt.organization?.shortTitle || akt.organization?.title || '—';
    const orgPart = `<span class="elimination-act-card__org-line">${AktUtils.escapeHtml(orgName)}</span>`;
    if (allDone) {
      return `<p class="elimination-act-card__status-line">${orgPart} · <span class="elimination-act-card__status-line--done">Выполнено</span></p>`;
    }
    if (overdue) {
      return `<p class="elimination-act-card__status-line">${orgPart} · <span class="elimination-act-card__status-line--overdue">Просрочено</span></p>`;
    }
    return `<p class="elimination-act-card__status-line">${orgPart}</p>`;
  }

  function buildActHeaderHtml(aktNumber, item, noViolations) {
    let deadlineHtml = '';
    if (!noViolations) {
      if (item.earliestDeadline) {
        const dl = AktUtils.formatDateShort(item.earliestDeadline);
        deadlineHtml = `<span class="elimination-act-card__deadline">Срок: ${AktUtils.escapeHtml(dl)}</span>`;
      } else {
        deadlineHtml =
          '<span class="elimination-act-card__deadline elimination-act-card__deadline--unset">Срок не установлен</span>';
      }
    }
    return `<div class="elimination-act-card__head">
      <h4 class="elimination-act-card__title">Акт №${AktUtils.escapeHtml(aktNumber)}</h4>
      ${deadlineHtml}
    </div>`;
  }

  function buildObjectHtml(akt) {
    const objectTitle = (akt.objectsCheck || [])[0]?.title || '';
    if (!objectTitle) return '';
    return `<p class="elimination-act-card__object">${AktUtils.escapeHtml(objectTitle)}</p>`;
  }

  function buildToggleBtnHtml(item, allDone, overdue, noViolations) {
    if (noViolations) {
      return '<span class="elimination-act-card__pill elimination-act-card__pill--muted">—</span>';
    }
    const label = allDone ? 'Устранено' : 'Не устранено';
    const title = allDone
      ? 'Снять отметки устранения по акту'
      : 'Отметить все нарушения акта устранёнными';
    const cls = [
      'elimination-act-card__toggle',
      allDone ? 'elimination-act-card__toggle--done' : 'elimination-act-card__toggle--open',
      !allDone && overdue ? 'elimination-act-card__toggle--overdue' : '',
    ]
      .filter(Boolean)
      .join(' ');
    return `<button type="button" class="${cls}" data-elim-toggle="${AktUtils.escapeHtml(item.aktId)}" title="${AktUtils.escapeHtml(title)}" aria-label="${AktUtils.escapeHtml(title)}">${AktUtils.escapeHtml(label)}</button>`;
  }

  function patchActCard(aktId, items) {
    const filtered = applyStatusFilter(items);
    const item = items.find((i) => aktIdMatch(i.aktId, aktId));
    const card = document.querySelector(`[data-elim-akt="${CSS.escape(String(aktId))}"]`);
    const inFilter = item && filtered.some((i) => aktIdMatch(i.aktId, aktId));

    if (!item || !inFilter) {
      if (card) card.remove();
      const list = document.getElementById('eliminationCardList');
      if (list && !list.querySelector('[data-elim-akt]')) {
        list.innerHTML = renderCardListHtml([], filterEmptyMessage());
      }
      return;
    }
    if (!card) {
      renderCardList(filtered);
      return;
    }
    const wrapper = document.createElement('div');
    wrapper.innerHTML = renderCardListHtml([item]);
    const next = wrapper.firstElementChild;
    if (next) card.replaceWith(next);
  }

  function patchViolationRow(violationId) {
    if (!detailState) return;
    const row = document.querySelector(
      `#elimDetailBody [data-violation-id="${CSS.escape(String(violationId))}"]`
    );
    if (!row) return;
    const v = detailState.violations.find((x) => x.id === violationId);
    const el = detailState.eliminations.find((e) => e.violationId === violationId);
    if (!v) return;
    const done = el?.isEliminated;
    const overdue = el && isEliminationOverdue(el);
    row.classList.toggle('elimination-violation-row--selected', false);
    const titleEl = row.querySelector('.elimination-violation-row__title');
    if (titleEl) {
      titleEl.className = 'elimination-violation-row__title';
      if (done) titleEl.classList.add('elimination-violation-row__title--done');
      else if (overdue) titleEl.classList.add('elimination-violation-row__title--overdue');
    }
    const statusEl = row.querySelector('.elimination-violation-row__status');
    if (statusEl && !detailState.selectionMode) {
      statusEl.textContent = done ? '✅' : overdue ? '⚠️' : '❌';
    }
    const deadlineEl = row.querySelector('.elimination-violation-row__deadline');
    if (deadlineEl) {
      const deadline = el ? eliminationDeadline(el) : null;
      if (deadline) {
        deadlineEl.className = `elimination-violation-row__deadline${overdue ? ' elimination-violation-row__deadline--overdue' : ''}`;
        deadlineEl.innerHTML = `Срок: ${AktUtils.formatDateShort(deadline)}${overdue ? '<span class="elimination-violation-row__overdue-badge">ПРОСРОЧЕНО</span>' : ''}`;
      } else {
        deadlineEl.className = 'elimination-violation-row__deadline';
        deadlineEl.textContent = 'Срок не установлен';
      }
    }
  }

  function aktIdMatch(a, b) {
    return String(a || '').toLowerCase() === String(b || '').toLowerCase();
  }

  function eliminationDeadline(e) {
    const history = e.deadlineHistory || [];
    if (history.length > 0) {
      const sorted = [...history].sort(
        (a, b) =>
          new Date(b.changeDate || b.changedAt || 0).getTime() -
          new Date(a.changeDate || a.changedAt || 0).getTime()
      );
      return sorted[0]?.deadlineDate;
    }
    return e.newEliminationDate || e.originalEliminationDate;
  }

  function isEliminationOverdue(e) {
    if (e.isEliminated) return false;
    const deadline = eliminationDeadline(e);
    if (!deadline) return false;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const d = new Date(deadline);
    if (Number.isNaN(d.getTime())) return false;
    d.setHours(0, 0, 0, 0);
    return today >= d;
  }

  function violationsLabel(count) {
    if (count === 1) return 'нарушение';
    return 'нарушений';
  }

  function minDeadline(dates) {
    let min = null;
    for (const iso of dates) {
      if (!iso) continue;
      const t = new Date(iso).getTime();
      if (Number.isNaN(t)) continue;
      if (min == null || t < new Date(min).getTime()) min = iso;
    }
    return min;
  }

  function buildEliminationItems(data, yearFilter = selectedYear) {
    const akts = data.akts || [];
    const allEliminations = data.violationEliminations || [];

    let items = akts.map((akt) => {
      const violationIds = new Set((akt.violations || []).map((v) => v.id));
      const eliminations = allEliminations.filter(
        (e) => aktIdMatch(e.aktId, akt.id) && violationIds.has(e.violationId)
      );

      const totalViolations = (akt.violations || []).length;
      const eliminatedViolations = eliminations.filter((e) => e.isEliminated).length;
      const overdueCount = eliminations.filter((e) => isEliminationOverdue(e)).length;
      const onTimeCount = eliminations.filter(
        (e) => !e.isEliminated && !isEliminationOverdue(e)
      ).length;

      const uneliminated = eliminations.filter((e) => !e.isEliminated);
      const deadlines = uneliminated.map((e) => eliminationDeadline(e)).filter(Boolean);
      let earliestDeadline = minDeadline(deadlines);
      if (!earliestDeadline && totalViolations > 0) {
        earliestDeadline = AktUtils.getEliminationDeadline(akt);
      }

      const allEliminated =
        totalViolations > 0 && eliminatedViolations === totalViolations;

      return {
        aktId: akt.id,
        aktNumber: akt.number,
        akt,
        totalViolations,
        eliminatedViolations,
        overdueCount,
        onTimeCount,
        hasOverdue: overdueCount > 0,
        earliestDeadline,
        allEliminated,
        eliminations,
      };
    });

    items.sort(
      (a, b) => (parseInt(a.aktNumber, 10) || 0) - (parseInt(b.aktNumber, 10) || 0)
    );

    if (yearFilter != null) {
      items = items.filter((item) => {
        const d = item.akt?.date;
        if (!d) return false;
        return new Date(d).getFullYear() === yearFilter;
      });
    }

    return items;
  }

  function computeStats(items) {
    return items.reduce(
      (acc, item) => {
        acc.total += item.totalViolations;
        acc.done += item.eliminatedViolations;
        acc.overdue += item.overdueCount;
        acc.onTime += item.onTimeCount;
        return acc;
      },
      { total: 0, done: 0, overdue: 0, onTime: 0 }
    );
  }

  function getAvailableYears(data) {
    const years = new Set();
    (data.akts || []).forEach((a) => {
      if (a.date) years.add(new Date(a.date).getFullYear());
    });
    return [...years].sort((a, b) => b - a);
  }

  function renderStats(items) {
    const total = items.length;
    const done = items.filter(
      (i) => i.totalViolations === 0 || i.allEliminated
    ).length;
    const open = total - done;
    const pct = (n) => (total ? `${Math.round((n / total) * 100)}%` : '0%');
    const set = (id, val) => {
      const el = document.getElementById(id);
      if (el) el.textContent = String(val);
    };
    set('elimStatTotal', total);
    set('elimStatDone', done);
    set('elimStatOpen', open);
    set('elimStatTotalPct', total ? '100%' : '0%');
    set('elimStatDonePct', pct(done));
    set('elimStatOpenPct', pct(open));
  }

  function renderDonut(stats) {
    const donut = document.getElementById('elimDonut');
    const totalEl = document.getElementById('elimDonutTotal');
    const legend = document.getElementById('elimDonutLegend');
    if (!donut) return;

    const total = stats.total;
    if (totalEl) totalEl.textContent = String(total);

    if (total === 0) {
      donut.className = 'elim-donut elim-donut--empty';
      donut.style.background = '';
      if (legend) {
        legend.innerHTML =
          '<li><span class="elim-donut-legend__dot elim-donut-legend__dot--muted"></span>Нет нарушений<span class="elim-donut-legend__val">0</span></li>';
      }
      return;
    }

    donut.classList.remove('elim-donut--empty');
    const done = stats.done;
    const overdue = stats.overdue;
    const onTime = stats.onTime;
    const other = Math.max(0, total - done - overdue - onTime);

    const deg = (n) => (n / total) * 360;
    let cursor = 0;
    const segments = [];
    const push = (size, color) => {
      if (size <= 0) return;
      const start = cursor;
      cursor += deg(size);
      segments.push(`${color} ${start}deg ${cursor}deg`);
    };
    push(done, 'var(--success)');
    push(overdue, 'var(--danger)');
    push(onTime, 'var(--primary)');
    push(other, '#cbd5e1');
    donut.style.background = `conic-gradient(${segments.join(', ')})`;

    if (legend) {
      const rows = [
        { cls: 'done', label: 'Устранено', val: done },
        { cls: 'overdue', label: 'Просрочено', val: overdue },
        { cls: 'ontime', label: 'Срок не истёк', val: onTime },
      ];
      if (other > 0) {
        rows.push({ cls: 'muted', label: 'Прочее', val: other });
      }
      legend.innerHTML = rows
        .map(
          (r) =>
            `<li><span class="elim-donut-legend__dot elim-donut-legend__dot--${r.cls}"></span>${AktUtils.escapeHtml(r.label)}<span class="elim-donut-legend__val">${r.val}</span></li>`
        )
        .join('');
    }
  }

  function renderYearPills(data) {
    const wrap = document.getElementById('elimYearPills');
    if (!wrap) return;
    const years = getAvailableYears(data);
    const pills = [
      { label: 'Все', year: null },
      ...years.map((y) => ({ label: String(y), year: y })),
    ];
    const yearHtml = pills
      .map(({ label, year }) => {
        const active =
          year === selectedYear || (year == null && selectedYear == null);
        return `<button type="button" class="btn-org-filter${active ? ' btn-org-filter-active' : ''}" data-elim-year="${year == null ? '' : year}">${AktUtils.escapeHtml(label)}</button>`;
      })
      .join('');
    const overdueActive = selectedFilter === 'overdue';
    wrap.innerHTML =
      yearHtml +
      `<button type="button" class="btn-org-filter btn-org-filter--overdue${overdueActive ? ' btn-org-filter-active' : ''}" data-elim-filter="overdue">Просрочено</button>`;
  }

  function bindYearPills() {
    const screen = document.getElementById('screen-elimination');
    if (!screen || screen.dataset.elimYearBound) return;
    screen.dataset.elimYearBound = '1';
    screen.addEventListener('click', async (e) => {
      const overdueBtn = e.target.closest('#elimYearPills [data-elim-filter="overdue"]');
      if (overdueBtn) {
        selectedFilter = selectedFilter === 'overdue' ? 'all' : 'overdue';
        const catalog = await GazpromStore.get();
        render(catalog);
        return;
      }
      const btn = e.target.closest('#elimYearPills [data-elim-year]');
      if (!btn) return;
      const raw = btn.dataset.elimYear;
      selectedYear = raw === '' ? null : parseInt(raw, 10);
      const catalog = await GazpromStore.get();
      render(catalog);
    });
  }

  function renderCardListHtml(items, emptyMessage) {
    if (!items.length) {
      return `<p class="elimination-empty" role="status">${AktUtils.escapeHtml(emptyMessage || 'Нет актов для отображения')}</p>`;
    }
    return items
      .map((item) => {
        const allDone = item.allEliminated;
        const noViolations = item.totalViolations === 0;
        const overdue = item.hasOverdue && !allDone;
        const cardClass = [
          'elimination-act-card',
          allDone ? 'elimination-act-card--done' : '',
          overdue ? 'elimination-act-card--overdue' : '',
        ]
          .filter(Boolean)
          .join(' ');

        const ring = ringMetrics(item.eliminatedViolations, item.totalViolations);
        const headerHtml = buildActHeaderHtml(item.aktNumber, item, noViolations);
        const objectHtml = buildObjectHtml(item.akt);
        const statusLineHtml = buildStatusLineHtml(item.akt, allDone, overdue, noViolations);
        const toggleHtml = buildToggleBtnHtml(item, allDone, overdue, noViolations);
        const ringStateClass = allDone
          ? 'elimination-act-card__ring--done'
          : overdue
            ? 'elimination-act-card__ring--overdue'
            : noViolations
              ? 'elimination-act-card__ring--empty'
              : 'elimination-act-card__ring--open';

        return `<article class="${cardClass} card" data-elim-akt="${AktUtils.escapeHtml(item.aktId)}" role="listitem" tabindex="0" aria-label="Акт № ${AktUtils.escapeHtml(item.aktNumber)}">
          <div class="elimination-act-card__ring ${ringStateClass}" aria-hidden="true">
            <svg class="elim-ring" viewBox="0 0 68 68">
              <circle class="elim-ring__track" cx="${RING_CX}" cy="${RING_CX}" r="${RING_R}"></circle>
              <circle class="elim-ring__fill" cx="${RING_CX}" cy="${RING_CX}" r="${RING_R}" stroke-dasharray="${ring.dash}"></circle>
            </svg>
            <span class="elim-ring__label">${AktUtils.escapeHtml(ring.label)}</span>
          </div>
          <div class="elimination-act-card__body">
            ${headerHtml}
            ${objectHtml}
            ${statusLineHtml}
          </div>
          <div class="elimination-act-card__aside">
            ${toggleHtml}
            <span class="elimination-act-card__chevron" aria-hidden="true">›</span>
          </div>
        </article>`;
      })
      .join('');
  }

  function filterEmptyMessage() {
    if (selectedFilter === 'overdue') return 'Нет просроченных актов';
    return 'Нет актов для отображения';
  }

  function renderCardList(items) {
    const list = document.getElementById('eliminationCardList');
    if (!list) return;
    list.innerHTML = renderCardListHtml(items, filterEmptyMessage());
  }

  function render(data) {
    const items = buildEliminationItems(data);
    renderYearPills(data);
    renderStats(items);
    renderDonut(computeStats(items));
    renderCardList(applyStatusFilter(items));
    return items;
  }

  function ensureEliminationsForAkt(catalog, akt) {
    const list = [...(catalog.violationEliminations || [])];
    let changed = false;
    const violationIds = new Set((akt.violations || []).map((v) => v.id));
    for (const v of akt.violations || []) {
      const exists = list.find(
        (e) => aktIdMatch(e.aktId, akt.id) && e.violationId === v.id
      );
      if (!exists) {
        list.push({
          id: AktUtils.uuid(),
          aktId: akt.id,
          aktNumber: akt.number,
          violationId: v.id,
          violationTitle: v.title,
          isEliminated: false,
          originalEliminationDate: AktUtils.getEliminationDeadline(akt),
          deadlineHistory: AktUtils.getEliminationDeadline(akt)
            ? [
                {
                  id: AktUtils.uuid(),
                  deadlineDate: AktUtils.getEliminationDeadline(akt),
                  changeDate: new Date().toISOString(),
                  isOriginal: true,
                },
              ]
            : [],
        });
        changed = true;
      }
    }
    if (changed) catalog.violationEliminations = list;
    return {
      changed,
      eliminations: list.filter(
        (e) => aktIdMatch(e.aktId, akt.id) && violationIds.has(e.violationId)
      ),
    };
  }

  async function toggleAllForAkt(aktId, shouldEliminate) {
    const catalog = await GazpromStore.get();
    const akt = (catalog.akts || []).find((a) => aktIdMatch(a.id, aktId));
    if (!akt) return;

    ensureEliminationsForAkt(catalog, akt);
    const violationIds = new Set((akt.violations || []).map((v) => v.id));
    const now = new Date().toISOString();

    catalog.violationEliminations = (catalog.violationEliminations || []).map((e) => {
      if (!aktIdMatch(e.aktId, aktId) || !violationIds.has(e.violationId)) return e;
      return {
        ...e,
        isEliminated: shouldEliminate,
        eliminatedAt: shouldEliminate ? e.eliminatedAt || now : e.eliminatedAt,
        eliminationDate: shouldEliminate ? now : e.eliminationDate,
      };
    });

    for (const v of akt.violations || []) {
      const exists = catalog.violationEliminations.find(
        (e) => aktIdMatch(e.aktId, aktId) && e.violationId === v.id
      );
      if (!exists && shouldEliminate) {
        catalog.violationEliminations.push({
          id: AktUtils.uuid(),
          aktId: akt.id,
          aktNumber: akt.number,
          violationId: v.id,
          violationTitle: v.title,
          isEliminated: true,
          eliminatedAt: now,
          eliminationDate: now,
          originalEliminationDate: AktUtils.getEliminationDeadline(akt),
          deadlineHistory: [],
        });
      }
    }

    schedulePersist(catalog);
    refreshEliminationLight(catalog, aktId);

    if (detailState && aktIdMatch(detailState.akt.id, aktId)) {
      detailState.eliminations = (catalog.violationEliminations || []).filter((e) =>
        aktIdMatch(e.aktId, aktId)
      );
      if (detailState.selectionMode) {
        renderDetailViolations();
      } else {
        (akt.violations || []).forEach((v) => patchViolationRow(v.id));
      }
      updateDetailHeader();
    }
  }

  function formatDeadlineLong(iso) {
    if (!iso) return null;
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return null;
    return d.toLocaleDateString('ru-RU', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
  }

  function closeDetail() {
    void flushPersist();
    document.querySelector('.elimination-detail-overlay')?.remove();
    detailState = null;
    void GazpromStore.get().then((catalog) => {
      refreshEliminationLight(catalog);
    });
  }

  function renderDetailViolations() {
    if (!detailState) return;
    const { violations, eliminations, selectionMode, selectedIds } = detailState;
    const body = document.getElementById('elimDetailBody');
    if (!body) return;

    const toShow = selectionMode
      ? violations.filter((v) => {
          const el = eliminations.find((e) => e.violationId === v.id);
          return !(el?.isEliminated);
        })
      : violations;

    body.innerHTML = toShow
      .map((v, index) => {
        const el = eliminations.find((e) => e.violationId === v.id);
        const done = el?.isEliminated;
        const overdue = el && isEliminationOverdue(el);
        const selected = selectedIds.has(v.id);
        const rowClass = [
          'elimination-violation-row',
          selectionMode && selected ? 'elimination-violation-row--selected' : '',
        ]
          .filter(Boolean)
          .join(' ');

        let titleClass = 'elimination-violation-row__title';
        if (done) titleClass += ' elimination-violation-row__title--done';
        else if (overdue) titleClass += ' elimination-violation-row__title--overdue';

        const statusIcon = done ? '✅' : overdue ? '⚠️' : '❌';
        const deadline = el ? eliminationDeadline(el) : null;
        const deadlineLine = deadline
          ? `<div class="elimination-violation-row__deadline${overdue ? ' elimination-violation-row__deadline--overdue' : ''}">Срок: ${AktUtils.formatDateShort(deadline)}${overdue ? '<span class="elimination-violation-row__overdue-badge">ПРОСРОЧЕНО</span>' : ''}</div>`
          : '<div class="elimination-violation-row__deadline">Срок не установлен</div>';

        const checkbox = selectionMode
          ? `<span style="margin-left:auto">${selected ? '☑' : '☐'}</span>`
          : `<span class="elimination-violation-row__status" aria-hidden="true">${statusIcon}</span>`;

        return `<div class="${rowClass}" data-violation-id="${AktUtils.escapeHtml(v.id)}" role="button" tabindex="0">
          <div class="elimination-violation-row__head">
            <span class="elimination-violation-row__num">${index + 1}.</span>
            <span class="${titleClass}">${AktUtils.escapeHtml(v.title)}</span>
            ${checkbox}
          </div>
          <div class="elimination-violation-row__mesto">Место: ${AktUtils.escapeHtml(v.mesto || '—')}</div>
          ${deadlineLine}
        </div>`;
      })
      .join('');
  }

  function updateDetailHeader() {
    if (!detailState) return;
    const { item, eliminations, akt } = detailState;
    const eliminated = eliminations.filter((e) => e.isEliminated).length;
    const total = (akt.violations || []).length;
    const allDone = total > 0 && eliminated === total;
    const hasOverdue = eliminations.some((e) => isEliminationOverdue(e));

    const countEl = document.getElementById('elimDetailCount');
    if (countEl) {
      countEl.textContent = `${eliminated}/${total} ${violationsLabel(total)} устранено`;
      countEl.className = 'elimination-detail-count';
      if (allDone) countEl.classList.add('elimination-detail-count--done');
      else if (hasOverdue) countEl.classList.add('elimination-detail-count--overdue');
    }

    const deadlines = eliminations
      .filter((e) => !e.isEliminated)
      .map((e) => eliminationDeadline(e))
      .filter(Boolean);
    let earliest = minDeadline(deadlines) || item.earliestDeadline;

    const deadlineEl = document.getElementById('elimDetailDeadline');
    if (deadlineEl) {
      const long = formatDeadlineLong(earliest);
      deadlineEl.textContent = long
        ? `Срок устранения: ${long} года`
        : 'Срок устранения не установлен';
      deadlineEl.className = 'elimination-detail-deadline';
      if (allDone) deadlineEl.classList.add('elimination-detail-deadline--done');
      else if (hasOverdue) deadlineEl.classList.add('elimination-detail-deadline--overdue');
    }

    const markBtn = document.getElementById('elimDetailMarkAll');
    if (markBtn && !detailState.selectionMode) {
      const allElim = eliminations.length > 0 && eliminations.every((e) => e.isEliminated);
      markBtn.textContent = allElim
        ? 'Снять отметки об устранении'
        : 'Отметить все как устраненные';
    }
  }

  async function openDetail(item) {
    const catalog = await GazpromStore.get();
    const akt = (catalog.akts || []).find((a) => aktIdMatch(a.id, item.aktId));
    if (!akt) {
      GazpromToast.error('Акт не найден');
      return;
    }

    await CatalogService.rememberLastOpenedAkt(akt);

    const { changed, eliminations } = ensureEliminationsForAkt(catalog, akt);
    if (changed) await GazpromStore.set(catalog);

    detailState = {
      item,
      akt,
      catalog,
      violations: [...(akt.violations || [])],
      eliminations,
      selectionMode: false,
      selectedIds: new Set(),
    };

    const org = AktSearch.getOrgTitle(akt);
    const objectTitle = (akt.objectsCheck || [])[0]?.title || '—';

    const overlay = document.createElement('div');
    overlay.className = 'elimination-detail-overlay';
    overlay.innerHTML = `
      <div class="elimination-detail-sheet" role="dialog" aria-modal="true" aria-labelledby="elimDetailTitle">
        <div class="elimination-detail-grabber" aria-hidden="true"></div>
        <div class="elimination-detail-header">
          <h3 id="elimDetailTitle">Акт №${AktUtils.escapeHtml(item.aktNumber)}</h3>
          <div class="elimination-detail-meta">${AktUtils.escapeHtml(org)}</div>
          <div class="elimination-detail-meta">${AktUtils.escapeHtml(objectTitle)}</div>
          <div class="elimination-detail-count" id="elimDetailCount"></div>
          <div class="elimination-detail-deadline" id="elimDetailDeadline"></div>
        </div>
        <div class="elimination-detail-body" id="elimDetailBody"></div>
        <div class="elimination-detail-footer">
          <button type="button" class="btn-primary elim-btn-mark-all" id="elimDetailMarkAll">Отметить все как устраненные</button>
          <button type="button" class="btn-secondary elim-btn-extend" id="elimDetailExtend">Продлить срок устранения</button>
          <button type="button" class="btn-secondary elim-btn-history" id="elimDetailHistory">История сроков</button>
          <button type="button" class="btn-ghost" id="elimDetailClose">Закрыть</button>
        </div>
      </div>
    `;
    document.body.appendChild(overlay);

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) closeDetail();
    });
    overlay.querySelector('#elimDetailClose')?.addEventListener('click', closeDetail);

    updateDetailHeader();
    renderDetailViolations();

    overlay.querySelector('#elimDetailBody')?.addEventListener('click', async (e) => {
      const row = e.target.closest('[data-violation-id]');
      if (!row || !detailState) return;
      const vid = row.dataset.violationId;
      if (detailState.selectionMode) {
        if (detailState.selectedIds.has(vid)) detailState.selectedIds.delete(vid);
        else detailState.selectedIds.add(vid);
        renderDetailViolations();
        updateExtendButtonLabel();
        return;
      }
      await toggleViolation(vid);
    });

    overlay.querySelector('#elimDetailMarkAll')?.addEventListener('click', async () => {
      if (detailState?.selectionMode) return;
      const allElim =
        detailState.eliminations.length > 0 &&
        detailState.eliminations.every((e) => e.isEliminated);
      await markAllInDetail(!allElim);
    });

    overlay.querySelector('#elimDetailExtend')?.addEventListener('click', () => {
      handleExtendButton();
    });

    overlay.querySelector('#elimDetailHistory')?.addEventListener('click', () => {
      showDeadlineHistory();
    });
  }

  function updateExtendButtonLabel() {
    const btn = document.getElementById('elimDetailExtend');
    const markBtn = document.getElementById('elimDetailMarkAll');
    if (!btn || !detailState) return;
    if (detailState.selectionMode) {
      const n = detailState.selectedIds.size;
      btn.textContent =
        n > 0 ? `Продлить срок устранения (${n})` : 'Завершить выбор';
      btn.classList.toggle('elim-btn-extend', n === 0);
      if (markBtn) markBtn.hidden = true;
    } else {
      btn.textContent = 'Продлить срок устранения';
      if (markBtn) markBtn.hidden = false;
    }
  }

  function handleExtendButton() {
    if (!detailState) return;
    if (!detailState.selectionMode) {
      detailState.selectionMode = true;
      detailState.selectedIds = new Set();
      renderDetailViolations();
      updateExtendButtonLabel();
      return;
    }
    if (detailState.selectedIds.size === 0) {
      detailState.selectionMode = false;
      renderDetailViolations();
      updateExtendButtonLabel();
      return;
    }
    showExtendDateDialog();
  }

  function showExtendDateDialog() {
    const overlay = document.createElement('div');
    overlay.className = 'catalog-form-overlay';
    const defaultDate = new Date();
    defaultDate.setDate(defaultDate.getDate() + 30);
    overlay.innerHTML = `
      <div class="catalog-form-dialog card">
        <h3>Новый срок устранения</h3>
        <div class="form-group">
          <label>Дата</label>
          <input type="date" class="form-control" id="elimExtendDate" value="${AktUtils.toDateInputValue(defaultDate.toISOString())}">
        </div>
        <div class="form-group">
          <label>Причина (необязательно)</label>
          <input type="text" class="form-control" id="elimExtendReason" placeholder="Причина продления">
        </div>
        <div class="catalog-form-actions">
          <button type="button" class="btn-ghost" data-cancel>Отмена</button>
          <button type="button" class="btn-primary" data-save>Продлить</button>
        </div>
      </div>
    `;
    document.body.appendChild(overlay);
    const remove = () => overlay.remove();
    overlay.querySelector('[data-cancel]').onclick = () => {
      remove();
      if (detailState) {
        detailState.selectionMode = false;
        detailState.selectedIds = new Set();
        renderDetailViolations();
        updateExtendButtonLabel();
      }
    };
    overlay.querySelector('[data-save]').onclick = async () => {
      const dateVal = document.getElementById('elimExtendDate')?.value;
      if (!dateVal) {
        GazpromToast.error('Укажите дату');
        return;
      }
      const reason = document.getElementById('elimExtendReason')?.value?.trim() || null;
      const newIso = new Date(dateVal + 'T12:00:00').toISOString();
      await extendDeadlinesForSelected(newIso, reason);
      remove();
    };
  }

  async function extendDeadlinesForSelected(newIso, reason) {
    if (!detailState) return;
    const catalog = await GazpromStore.get();
    const { akt, selectedIds } = detailState;
    const now = new Date().toISOString();

    catalog.violationEliminations = (catalog.violationEliminations || []).map((e) => {
      if (!aktIdMatch(e.aktId, akt.id) || !selectedIds.has(e.violationId)) return e;
      const entry = {
        id: AktUtils.uuid(),
        deadlineDate: newIso,
        changeDate: now,
        reason,
        isOriginal: false,
      };
      return {
        ...e,
        newEliminationDate: newIso,
        originalEliminationDate: newIso,
        deadlineHistory: [...(e.deadlineHistory || []), entry],
      };
    });

    schedulePersist(catalog);
    detailState.selectionMode = false;
    detailState.selectedIds = new Set();
    detailState.eliminations = (catalog.violationEliminations || []).filter((e) =>
      aktIdMatch(e.aktId, akt.id)
    );
    renderDetailViolations();
    updateDetailHeader();
    updateExtendButtonLabel();
    refreshEliminationLight(catalog, akt.id);
    GazpromToast.success('Сроки продлены');
  }

  function showDeadlineHistory() {
    if (!detailState) return;
    const entries = [];
    for (const e of detailState.eliminations) {
      for (const h of e.deadlineHistory || []) {
        entries.push({
          violation: e.violationTitle,
          date: h.deadlineDate,
          changeDate: h.changeDate || h.changedAt,
          reason: h.reason,
        });
      }
    }
    entries.sort(
      (a, b) => new Date(b.changeDate || 0).getTime() - new Date(a.changeDate || 0).getTime()
    );

    const overlay = document.createElement('div');
    overlay.className = 'catalog-form-overlay';
    const rows = entries.length
      ? entries
          .map(
            (en) =>
              `<li style="margin-bottom:10px;font-size:13px"><strong>${AktUtils.escapeHtml((en.violation || '').slice(0, 60))}</strong><br>Срок: ${AktUtils.formatDateShort(en.date)} · ${AktUtils.formatDateShort(en.changeDate)}${en.reason ? `<br>Причина: ${AktUtils.escapeHtml(en.reason)}` : ''}</li>`
          )
          .join('')
      : '<li style="color:var(--text-muted)">История сроков пуста</li>';

    overlay.innerHTML = `
      <div class="catalog-form-dialog card" style="max-width:520px;max-height:80vh;overflow:auto">
        <h3>История сроков</h3>
        <ul style="padding-left:18px;margin:12px 0">${rows}</ul>
        <div class="catalog-form-actions">
          <button type="button" class="btn-primary" data-close>Закрыть</button>
        </div>
      </div>
    `;
    document.body.appendChild(overlay);
    overlay.querySelector('[data-close]').onclick = () => overlay.remove();
    overlay.addEventListener('click', (ev) => {
      if (ev.target === overlay) overlay.remove();
    });
  }

  async function toggleViolation(violationId) {
    if (!detailState) return;
    const catalog = await GazpromStore.get();
    const { akt } = detailState;
    const violation = (akt.violations || []).find((v) => v.id === violationId);
    if (!violation) return;

    let rec = (catalog.violationEliminations || []).find(
      (e) => aktIdMatch(e.aktId, akt.id) && e.violationId === violationId
    );

    const now = new Date().toISOString();
    if (!rec) {
      rec = {
        id: AktUtils.uuid(),
        aktId: akt.id,
        aktNumber: akt.number,
        violationId: violation.id,
        violationTitle: violation.title,
        isEliminated: true,
        eliminatedAt: now,
        eliminationDate: now,
        originalEliminationDate: AktUtils.getEliminationDeadline(akt),
        deadlineHistory: [],
      };
      catalog.violationEliminations = [...(catalog.violationEliminations || []), rec];
    } else {
      const next = !rec.isEliminated;
      rec = {
        ...rec,
        isEliminated: next,
        eliminatedAt: next ? now : rec.eliminatedAt,
        eliminationDate: next ? now : rec.eliminationDate,
      };
      catalog.violationEliminations = (catalog.violationEliminations || []).map((e) =>
        e.id === rec.id ? rec : e
      );
    }

    schedulePersist(catalog);
    detailState.eliminations = (catalog.violationEliminations || []).filter((e) =>
      aktIdMatch(e.aktId, akt.id)
    );
    patchViolationRow(violationId);
    updateDetailHeader();
    refreshEliminationLight(catalog, akt.id);
  }

  async function markAllInDetail(shouldEliminate) {
    if (!detailState) return;
    await toggleAllForAkt(detailState.akt.id, shouldEliminate);
  }


  function bindCardList() {
    const list = document.getElementById('eliminationCardList');
    if (!list || list.dataset.bound) return;
    list.dataset.bound = '1';

    list.addEventListener('click', async (e) => {
      const toggleBtn = e.target.closest('[data-elim-toggle]');
      if (toggleBtn) {
        e.stopPropagation();
        const aktId = toggleBtn.dataset.elimToggle;
        const data = await GazpromStore.get();
        const items = buildEliminationItems(data);
        const item = items.find((i) => aktIdMatch(i.aktId, aktId));
        if (!item || item.totalViolations === 0) return;
        await toggleAllForAkt(aktId, !item.allEliminated);
        return;
      }

      const card = e.target.closest('[data-elim-akt]');
      if (!card) return;
      const aktId = card.dataset.elimAkt;
      const data = await GazpromStore.get();
      const items = buildEliminationItems(data);
      const item = items.find((i) => aktIdMatch(i.aktId, aktId));
      if (item) openDetail(item);
    });

    list.addEventListener('keydown', async (e) => {
      if (e.key !== 'Enter' && e.key !== ' ') return;
      if (e.target.closest('[data-elim-toggle]')) return;
      const card = e.target.closest('[data-elim-akt]');
      if (!card) return;
      e.preventDefault();
      const data = await GazpromStore.get();
      const items = buildEliminationItems(data);
      const item = items.find((i) => aktIdMatch(i.aktId, card.dataset.elimAkt));
      if (item) openDetail(item);
    });
  }

  function bindFilters() {
    /* фильтр «Просрочено» — в блоке elimYearPills (bindYearPills) */
  }

  function bindBulkActions() {
    /* массовая отметка — через свайп-кнопку на карточке акта */
  }

  function bindTableActions() {
    bindCardList();
    bindYearPills();
  }

  return {
    render,
    buildEliminationItems,
    bindFilters,
    bindBulkActions,
    bindTableActions,
    getYearFilter: () => selectedYear,
  };
})();
