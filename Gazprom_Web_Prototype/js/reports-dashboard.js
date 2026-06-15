/**
 * Отчёты — аналитический дашборд с графиками и группированными фильтрами.
 */
const ReportsDashboard = (() => {
  const FILTER_GROUPS = [
    { key: 'acts', label: 'Акты' },
    { key: 'years', label: 'Годы' },
    { key: 'objects', label: 'Объекты' },
    { key: 'contractors', label: 'Подрядчики' },
  ];

  const MONTH_SHORT = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  const STATUS_META = {
    done: { label: 'Устранено', color: '#2e7d32', cls: 'done' },
    overdue: { label: 'Срок устранения истёк', color: '#c62828', cls: 'overdue' },
    ontime: { label: 'Срок устранения не истёк', color: '#f59e0b', cls: 'ontime' },
    nodeadline: { label: 'Отсутствует срок исполнения', color: '#94a3b8', cls: 'nodeadline' },
  };

  let filters = {
    acts: new Set(),
    years: new Set(),
    objects: new Set(),
    contractors: new Set(),
  };

  let scheduleYears = new Set();
  let overdueViewMode = 'contractors';

  let openGroup = null;
  let bound = false;
  let activeCatalog = null;

  function aktIdMatch(a, b) {
    return String(a || '').toLowerCase() === String(b || '').toLowerCase();
  }

  function eliminationDeadline(e) {
    const history = AktUtils.extensionDeadlineHistory(e.deadlineHistory);
    if (history.length > 0) {
      const sorted = [...history].sort(
        (a, b) =>
          new Date(b.changeDate || b.changedAt || 0).getTime() -
          new Date(a.changeDate || a.changedAt || 0).getTime()
      );
      return sorted[0]?.deadlineDate;
    }
    return e?.newEliminationDate || e?.originalEliminationDate || null;
  }

  function isEliminationOverdue(e) {
    if (!e || e.isEliminated) return false;
    const deadline = eliminationDeadline(e);
    if (!deadline) return false;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const d = new Date(deadline);
    if (Number.isNaN(d.getTime())) return false;
    d.setHours(0, 0, 0, 0);
    return today >= d;
  }

  function classifyViolation(el, akt) {
    if (el?.isEliminated) return 'done';
    const deadline = el ? eliminationDeadline(el) : AktUtils.getEliminationDeadline(akt);
    if (!deadline) return 'nodeadline';
    if (isEliminationOverdue(el || { isEliminated: false, originalEliminationDate: deadline })) {
      return 'overdue';
    }
    return 'ontime';
  }

  function getOrgTitle(akt, data) {
    const embedded = akt?.organization?.shortTitle || akt?.organization?.title;
    if (embedded) return embedded;
    const orgId = akt?.organization?.id;
    if (orgId && data) {
      const org = (data.organizations || []).find((o) => o.id === orgId);
      if (org) return org.shortTitle || org.title || '—';
    }
    if (typeof AktSearch !== 'undefined') {
      const fromSearch = AktSearch.getOrgTitle(akt);
      if (fromSearch) return fromSearch;
    }
    return '—';
  }

  function getOrgAliases(akt, data) {
    const aliases = new Set();
    const add = (val) => {
      const s = String(val || '').trim();
      if (s && s !== '—') aliases.add(s);
    };
    add(getOrgTitle(akt, data));
    add(akt?.organization?.title);
    add(akt?.organization?.shortTitle);
    add(akt?.organization?.id);
    const orgId = akt?.organization?.id;
    if (orgId && data) {
      const org = (data.organizations || []).find((o) => o.id === orgId);
      if (org) {
        add(org.title);
        add(org.shortTitle);
        add(org.id);
      }
    }
    return aliases;
  }

  function contractorFilterValues() {
    return [...filters.contractors];
  }

  function isContractorFilterActive(...labels) {
    if (!filters.contractors.size) return false;
    const selected = contractorFilterValues();
    return labels.some((label) => {
      const val = String(label || '').trim();
      if (!val) return false;
      return selected.includes(val);
    });
  }

  function matchesContractorFilter(akt, data) {
    if (!filters.contractors.size) return true;
    const aliases = getOrgAliases(akt, data);
    return contractorFilterValues().some((f) => aliases.has(f));
  }

  function getObjectTitle(akt) {
    return (akt.objectsCheck || [])[0]?.title || '—';
  }

  function getViolationKind(v) {
    const vid = String(v.vid || '').trim();
    if (vid) {
      const out = vid;
      return out.length > 80 ? `${out.slice(0, 77)}…` : out;
    }
    const title = String(v.title || '').trim();
    if (!title) return 'Без названия';
    const shortPrefix = /^[^:]+:\s*/;
    const normalized = shortPrefix.test(title) ? title.replace(shortPrefix, '').trim() : title;
    const label = normalized || title;
    return label.length > 80 ? `${label.slice(0, 77)}…` : label;
  }

  function getSchedulePlanDate(item) {
    return item?.scheduledDate || item?.plannedDate || null;
  }

  function getScheduleYear(item) {
    if (item?.year != null && item.year !== '') return Number(item.year);
    const d = getSchedulePlanDate(item);
    if (!d) return null;
    const y = new Date(d).getFullYear();
    return Number.isNaN(y) ? null : y;
  }

  function getScheduleMonth(item) {
    if (item?.month != null && item.month !== '') return Number(item.month);
    const d = getSchedulePlanDate(item);
    if (!d) return null;
    const m = new Date(d).getMonth() + 1;
    return Number.isNaN(m) ? null : m;
  }

  function getScheduleOrgTitle(item, data) {
    if (item?.organizationTitle) return item.organizationTitle;
    const org = (data.organizations || []).find((o) => o.id === item?.organizationId);
    return org?.shortTitle || org?.title || '—';
  }

  function getScheduleObjectTitle(item) {
    return item?.objectCheck?.title || '—';
  }

  function isScheduleOverdue(item) {
    if (item?.actualDate) return false;
    const plan = getSchedulePlanDate(item);
    if (!plan) return false;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const d = new Date(plan);
    if (Number.isNaN(d.getTime())) return false;
    d.setHours(0, 0, 0, 0);
    return today > d;
  }

  function buildFilterOptions(data, { forGroup = null } = {}) {
    const effectiveFilters = getEffectiveFilters(forGroup);
    const filteredAkts = filterAkts(data.akts || [], data, { effectiveFilters }).filter(aktHasViolations);
    const filteredSchedule = filterScheduleItems(data.scheduleItems || [], data, effectiveFilters);

    const acts = new Set();
    const years = new Set();
    const objects = new Set();
    const contractors = new Set();

    filteredAkts.forEach((akt) => {
      if (akt.number != null && akt.number !== '') acts.add(String(akt.number));
      if (akt.date) {
        const y = new Date(akt.date).getFullYear();
        if (!Number.isNaN(y)) years.add(y);
      }
      const obj = getObjectTitle(akt);
      if (obj && obj !== '—') objects.add(obj);
      const org = getOrgTitle(akt, data);
      if (org && org !== '—') contractors.add(org);
    });

    filteredSchedule.forEach((item) => {
      const y = getScheduleYear(item);
      if (y) years.add(y);
      const obj = getScheduleObjectTitle(item);
      if (obj && obj !== '—') objects.add(obj);
      const org = getScheduleOrgTitle(item, data);
      if (org && org !== '—') contractors.add(org);
    });

    return {
      acts: [...acts].sort((a, b) => (parseInt(a, 10) || 0) - (parseInt(b, 10) || 0)),
      years: [...years].sort((a, b) => b - a),
      objects: [...objects].sort((a, b) => a.localeCompare(b, 'ru')),
      contractors: [...contractors].sort((a, b) => a.localeCompare(b, 'ru')),
    };
  }

  function pruneFilters(data) {
    const prune = (set, list, asString = true) => {
      const valid = new Set(list.map((v) => (asString ? String(v) : v)));
      for (const val of [...set]) {
        if (!valid.has(asString ? String(val) : val)) set.delete(val);
      }
    };
    for (const { key } of FILTER_GROUPS) {
      const options = buildFilterOptions(data, { forGroup: key });
      prune(filters[key], options[key], key !== 'years');
    }
  }

  function getEffectiveFilters(forGroup) {
    return {
      acts: forGroup === 'acts' ? new Set() : filters.acts,
      years: forGroup === 'years' ? new Set() : filters.years,
      objects: forGroup === 'objects' ? new Set() : filters.objects,
      contractors: forGroup === 'contractors' ? new Set() : filters.contractors,
    };
  }

  function matchesContractorFilterWith(akt, data, effectiveFilters) {
    if (!effectiveFilters.contractors.size) return true;
    const aliases = getOrgAliases(akt, data);
    return [...effectiveFilters.contractors].some((f) => aliases.has(f));
  }

  function matchesScheduleContractorFilter(item, data, effectiveFilters) {
    if (!effectiveFilters.contractors.size) return true;
    const org = getScheduleOrgTitle(item, data);
    return effectiveFilters.contractors.has(org);
  }

  function filterAkts(akts, data, { ignoreContractorFilter = false, effectiveFilters = filters } = {}) {
    return (akts || []).filter((akt) => {
      if (effectiveFilters.acts.size && !effectiveFilters.acts.has(String(akt.number))) return false;
      if (effectiveFilters.years.size) {
        const y = new Date(akt.date).getFullYear();
        if (!effectiveFilters.years.has(y)) return false;
      }
      if (effectiveFilters.objects.size && !effectiveFilters.objects.has(getObjectTitle(akt))) return false;
      if (
        !ignoreContractorFilter &&
        effectiveFilters.contractors.size &&
        !matchesContractorFilterWith(akt, data, effectiveFilters)
      ) {
        return false;
      }
      return true;
    });
  }

  function filterScheduleItems(items, data, effectiveFilters = filters) {
    return (items || []).filter((item) => {
      if (effectiveFilters.years.size) {
        const y = getScheduleYear(item);
        if (!y || !effectiveFilters.years.has(y)) return false;
      }
      if (effectiveFilters.objects.size && !effectiveFilters.objects.has(getScheduleObjectTitle(item))) {
        return false;
      }
      if (
        effectiveFilters.contractors.size &&
        !matchesScheduleContractorFilter(item, data, effectiveFilters)
      ) {
        return false;
      }
      return true;
    });
  }

  function aktHasViolations(akt) {
    return (akt.violations || []).length > 0;
  }

  function collectRows(data, { ignoreContractorFilter = false, ignoreFilters = false } = {}) {
    const eliminations = data.violationEliminations || [];
    const akts = ignoreFilters
      ? data.akts || []
      : filterAkts(data.akts || [], data, { ignoreContractorFilter });
    const rows = [];

    for (const akt of akts) {
      const org = getOrgTitle(akt, data);
      const obj = getObjectTitle(akt);
      for (const v of akt.violations || []) {
        const el = eliminations.find(
          (e) => aktIdMatch(e.aktId, akt.id) && e.violationId === v.id
        );
        rows.push({
          violation: v,
          akt,
          org,
          obj,
          status: classifyViolation(el, akt),
        });
      }
    }
    return { rows, akts };
  }

  function countByStatus(rows) {
    return rows.reduce(
      (acc, r) => {
        acc[r.status] = (acc[r.status] || 0) + 1;
        acc.total += 1;
        return acc;
      },
      { total: 0, done: 0, overdue: 0, ontime: 0, nodeadline: 0 }
    );
  }

  function renderFilterGroups(options) {
    const groupsWrap = document.getElementById('reportsFilterGroups');
    const pillsWrap = document.getElementById('reportsFilterPills');
    const panelRow = document.getElementById('reportsFilterPanelRow');
    if (!groupsWrap) return;

    groupsWrap.innerHTML = FILTER_GROUPS.map(({ key, label }) => {
      const activeCount = filters[key].size;
      const isOpen = openGroup === key;
      const cls = [
        'filter-pill',
        'reports-filter-group-btn',
        isOpen ? 'active' : '',
        activeCount ? 'reports-filter-group-btn--selected' : '',
      ]
        .filter(Boolean)
        .join(' ');
      const badge = activeCount
        ? `<span class="reports-filter-count">${activeCount}</span>`
        : '';
      return `<button type="button" class="${cls}" data-reports-group="${key}" aria-expanded="${isOpen}">
        ${AktUtils.escapeHtml(label)}${badge}
      </button>`;
    }).join('');

    if (!pillsWrap || !panelRow) return;

    if (!openGroup) {
      panelRow.hidden = true;
      pillsWrap.innerHTML = '';
      return;
    }

    panelRow.hidden = false;
    const items = options[openGroup] || [];
    pillsWrap.innerHTML = items.length
      ? items
          .map((item) => {
            const val = openGroup === 'years' ? item : String(item);
            const active =
              openGroup === 'years'
                ? filters.years.has(item)
                : filters[openGroup].has(String(item));
            return `<button type="button" class="filter-pill${active ? ' active' : ''}" data-reports-filter="${openGroup}" data-reports-value="${AktUtils.escapeHtml(String(val))}">${AktUtils.escapeHtml(String(item))}</button>`;
          })
          .join('')
      : '<span class="reports-filter-empty">Нет данных</span>';
  }

  function renderKpi(rows, akts) {
    const stats = countByStatus(rows);
    const orgs = new Set(akts.map((a) => getOrgTitle(a, activeCatalog)).filter((o) => o && o !== '—'));
    const objs = new Set(akts.map((a) => getObjectTitle(a)).filter((o) => o && o !== '—'));
    const open = stats.total - stats.done;

    const set = (id, val) => {
      const el = document.getElementById(id);
      if (el) el.textContent = String(val);
    };
    set('reportsKpiOrgs', orgs.size);
    set('reportsKpiObjects', objs.size);
    set('reportsKpiOpen', open);
    set('reportsKpiDone', stats.done);
  }

  function renderDonut(stats) {
    const donut = document.getElementById('reportsDonut');
    const totalEl = document.getElementById('reportsDonutTotal');
    const legend = document.getElementById('reportsDonutLegend');
    if (!donut) return;

    const total = stats.total;
    if (totalEl) totalEl.textContent = String(total);

    if (total === 0) {
      donut.className = 'reports-donut reports-donut--empty';
      donut.style.background = '';
      if (legend) {
        legend.innerHTML =
          '<li><span class="reports-legend__dot reports-legend__dot--muted"></span><span class="reports-legend__label">Нет нарушений</span><span class="reports-legend__val">0</span></li>';
      }
      return;
    }

    donut.classList.remove('reports-donut--empty');
    const order = ['done', 'overdue', 'ontime', 'nodeadline'];
    const deg = (n) => (n / total) * 360;
    let cursor = 0;
    const segments = [];
    for (const key of order) {
      const size = stats[key] || 0;
      if (size <= 0) continue;
      const start = cursor;
      cursor += deg(size);
      segments.push(`${STATUS_META[key].color} ${start}deg ${cursor}deg`);
    }
    donut.style.background = `conic-gradient(${segments.join(', ')})`;

    if (legend) {
      legend.innerHTML = order
        .filter((k) => (stats[k] || 0) > 0)
        .map(
          (k) =>
            `<li><span class="reports-legend__dot reports-legend__dot--${STATUS_META[k].cls}"></span><span class="reports-legend__label">${AktUtils.escapeHtml(STATUS_META[k].label)}</span><span class="reports-legend__val">${stats[k]}</span></li>`
        )
        .join('');
    }
  }

  function orgBlockColor(counts) {
    if (counts.overdue > 0) return STATUS_META.overdue.color;
    if (counts.ontime > 0) return STATUS_META.ontime.color;
    if (counts.done > 0) return STATUS_META.done.color;
    return STATUS_META.nodeadline.color;
  }

  function selectContractorFromTreemap(org) {
    if (!org || org === '—') return;
    const onlyThis = filters.contractors.size === 1 && filters.contractors.has(org);
    filters.contractors.clear();
    if (!onlyThis) filters.contractors.add(org);
  }

  function renderOrgTreemap(data) {
    const wrap =
      document.getElementById('reportsOrgTreemap') ||
      document.getElementById('reportsContractorGrid');
    if (!wrap) return;

    try {
      const { rows } = collectRows(data, { ignoreFilters: true });

      if (!rows.length) {
        wrap.innerHTML =
          '<p class="reports-chart-empty" role="status">Нет нарушений по подрядчикам</p>';
        return;
      }

      const byOrg = new Map();
      for (const r of rows) {
        const org = r.org && r.org !== '—' ? r.org : 'Организация не указана';
        if (!byOrg.has(org)) {
          byOrg.set(org, { total: 0, done: 0, overdue: 0, ontime: 0, nodeadline: 0 });
        }
        const bucket = byOrg.get(org);
        bucket.total += 1;
        bucket[r.status] += 1;
      }

      const entries = [...byOrg.entries()].sort((a, b) => b[1].total - a[1].total);
      const max = entries[0][1].total || 1;
      const totalViolations = entries.reduce((sum, [, c]) => sum + c.total, 0);

      wrap.innerHTML = `<div class="reports-treemap">${entries
        .map(([org, counts]) => {
          const filterOrg = org === 'Организация не указана' ? '—' : org;
          const isActive = isContractorFilterActive(org, filterOrg);
          const color = orgBlockColor(counts);
          const widthPct = Math.max(18, Math.round((counts.total / totalViolations) * 100));
          const grow = Math.max(1, Math.round((counts.total / max) * 100));
          return `<button type="button" class="reports-treemap__cell${isActive ? ' reports-treemap__cell--active' : ''}" style="flex-grow:${grow};flex-basis:calc(${widthPct}% - 8px);background:${color}" data-reports-org="${AktUtils.escapeHtml(filterOrg)}" title="${AktUtils.escapeHtml(org)} — ${counts.total}" aria-pressed="${isActive}" aria-label="Фильтр: ${AktUtils.escapeHtml(org)}, ${counts.total} нарушений">
            <span class="reports-treemap__name">${AktUtils.escapeHtml(org)}</span>
            <span class="reports-treemap__val">${counts.total}</span>
          </button>`;
        })
        .join('')}</div>`;
    } catch (err) {
      console.error('ReportsDashboard: renderOrgTreemap', err);
      wrap.innerHTML =
        '<p class="reports-chart-empty" role="status">Не удалось построить диаграмму по подрядчикам</p>';
    }
  }

  function renderBarChart(rows) {
    const wrap = document.getElementById('reportsBarChart');
    if (!wrap) return;

    if (!rows.length) {
      wrap.innerHTML = '<p class="reports-chart-empty" role="status">Нет данных для отображения</p>';
      return;
    }

    const byKind = new Map();
    for (const r of rows) {
      const kind = getViolationKind(r.violation);
      byKind.set(kind, (byKind.get(kind) || 0) + 1);
    }

    const entries = [...byKind.entries()].sort((a, b) => b[1] - a[1]).slice(0, 14);
    const max = entries[0][1] || 1;

    wrap.innerHTML = entries
      .map(([label, count]) => {
        const pct = Math.round((count / max) * 100);
        return `<div class="reports-bar-row">
          <div class="reports-bar-row__label" title="${AktUtils.escapeHtml(label)}">${AktUtils.escapeHtml(label)}</div>
          <div class="reports-bar-row__track" aria-hidden="true">
            <div class="reports-bar-row__fill" style="width:${pct}%"></div>
          </div>
          <div class="reports-bar-row__val">${count}</div>
        </div>`;
      })
      .join('');
  }

  function getOverdueGroupKey(row, mode) {
    if (mode === 'objects') {
      const obj = row.obj && row.obj !== '—' ? row.obj : 'Объект не указан';
      return obj;
    }
    return row.org && row.org !== '—' ? row.org : 'Организация не указана';
  }

  function aggregateOverdueByGroup(rows, mode) {
    const byGroup = new Map();
    for (const row of rows) {
      const label = getOverdueGroupKey(row, mode);
      if (!byGroup.has(label)) {
        byGroup.set(label, { total: 0, overdue: 0 });
      }
      const bucket = byGroup.get(label);
      bucket.total += 1;
      if (row.status === 'overdue') bucket.overdue += 1;
    }
    return [...byGroup.entries()]
      .map(([label, counts]) => ({
        label,
        total: counts.total,
        overdue: counts.overdue,
        pct: counts.total > 0 ? Math.round((counts.overdue / counts.total) * 100) : 0,
      }))
      .filter((entry) => entry.overdue > 0)
      .sort((a, b) => b.pct - a.pct || b.overdue - a.overdue || a.label.localeCompare(b.label, 'ru'))
      .slice(0, 12);
  }

  function overdueBarFillClass(pct) {
    if (pct >= 50) return 'reports-bar-row__fill--overdue-high';
    if (pct >= 25) return 'reports-bar-row__fill--overdue-mid';
    return 'reports-bar-row__fill--overdue-low';
  }

  function renderOverdueViewToggle() {
    const wrap = document.getElementById('reportsOverdueViewFilters');
    if (!wrap) return;
    wrap.querySelectorAll('[data-reports-overdue-view]').forEach((btn) => {
      const active = btn.dataset.reportsOverdueView === overdueViewMode;
      btn.classList.toggle('active', active);
      btn.setAttribute('aria-pressed', String(active));
    });
  }

  function renderOverdueChart(rows) {
    const wrap = document.getElementById('reportsOverdueChart');
    const summary = document.getElementById('reportsOverdueSummary');
    if (!wrap) return;

    renderOverdueViewToggle();

    const total = rows.length;
    const overdueTotal = rows.filter((r) => r.status === 'overdue').length;
    const overallPct = total > 0 ? Math.round((overdueTotal / total) * 100) : 0;

    if (summary) {
      summary.textContent =
        total > 0
          ? `Среди отфильтрованных нарушений: ${overallPct}% (${overdueTotal} из ${total}) с истёкшим сроком устранения`
          : 'Нет нарушений по выбранным фильтрам';
    }

    if (!total) {
      wrap.innerHTML = '<p class="reports-chart-empty" role="status">Нет данных для отображения</p>';
      return;
    }

    if (!overdueTotal) {
      wrap.innerHTML =
        '<p class="reports-chart-empty" role="status">Нет просроченных нарушений — все сроки устранения в норме</p>';
      return;
    }

    const entries = aggregateOverdueByGroup(rows, overdueViewMode);
    if (!entries.length) {
      wrap.innerHTML =
        '<p class="reports-chart-empty" role="status">Нет просроченных нарушений в выбранной группировке</p>';
      return;
    }

    wrap.innerHTML = entries
      .map(({ label, total: groupTotal, overdue, pct }) => {
        const fillCls = overdueBarFillClass(pct);
        return `<div class="reports-bar-row reports-bar-row--overdue">
          <div class="reports-bar-row__label" title="${AktUtils.escapeHtml(label)}">
            <span class="reports-overdue-row__name">${AktUtils.escapeHtml(label)}</span>
            <span class="reports-overdue-row__sub">${overdue} из ${groupTotal}</span>
          </div>
          <div class="reports-bar-row__track" aria-hidden="true">
            <div class="reports-bar-row__fill ${fillCls}" style="width:${pct}%"></div>
          </div>
          <div class="reports-bar-row__val reports-bar-row__val--overdue">${pct}%</div>
        </div>`;
      })
      .join('');
  }

  function buildScheduleYearOptions(data) {
    const years = new Set();
    (data.scheduleItems || []).forEach((item) => {
      const y = getScheduleYear(item);
      if (y) years.add(y);
    });
    return [...years].sort((a, b) => b - a);
  }

  function pruneScheduleYears(validYears) {
    const valid = new Set(validYears);
    for (const year of [...scheduleYears]) {
      if (!valid.has(year)) scheduleYears.delete(year);
    }
  }

  function toggleScheduleYear(rawYear) {
    const year = parseInt(rawYear, 10);
    if (Number.isNaN(year)) return;
    if (scheduleYears.has(year)) scheduleYears.delete(year);
    else scheduleYears.add(year);
  }

  function filterScheduleItemsByYear(items) {
    if (!scheduleYears.size) return items;
    return (items || []).filter((item) => {
      const y = getScheduleYear(item);
      return y && scheduleYears.has(y);
    });
  }

  function renderScheduleYearFilters(years) {
    const wrap = document.getElementById('reportsScheduleYearFilters');
    if (!wrap) return;
    if (!years.length) {
      wrap.innerHTML = '';
      wrap.hidden = true;
      return;
    }
    wrap.hidden = false;
    wrap.innerHTML = years
      .map((year) => {
        const active = scheduleYears.has(year);
        return `<button type="button" class="filter-pill${active ? ' active' : ''}" data-reports-schedule-year="${year}" aria-pressed="${active}">${year}</button>`;
      })
      .join('');
  }

  function renderTreemapLegend() {
    const el = document.getElementById('reportsTreemapLegend');
    if (!el) return;
    el.innerHTML = Object.values(STATUS_META)
      .map(
        (m) =>
          `<span class="reports-treemap-legend__item"><span class="reports-legend__dot reports-legend__dot--${m.cls}"></span>${AktUtils.escapeHtml(m.label)}</span>`
      )
      .join('');
  }

  function renderScheduleDashboard(data) {
    const yearOptions = buildScheduleYearOptions(data);
    pruneScheduleYears(yearOptions);
    renderScheduleYearFilters(yearOptions);

    const items = filterScheduleItemsByYear(data.scheduleItems || []);
    const total = items.length;
    const done = items.filter((i) => i.actualDate).length;
    const pending = total - done;
    const overdue = items.filter((i) => isScheduleOverdue(i)).length;
    const pct = total > 0 ? Math.round((done / total) * 100) : 0;

    const set = (id, val) => {
      const el = document.getElementById(id);
      if (el) el.textContent = String(val);
    };
    set('reportsSchedulePlan', total);
    set('reportsScheduleDone', done);
    set('reportsSchedulePending', pending);
    set('reportsScheduleOverdue', overdue);

    const label = document.getElementById('reportsScheduleProgressLabel');
    const sub = document.getElementById('reportsScheduleProgressSub');
    const fill = document.getElementById('reportsScheduleProgressFill');
    if (label) {
      label.textContent = total > 0 ? `Выполнение: ${pct}%` : 'График не задан';
    }
    if (sub) {
      sub.textContent = total > 0 ? `${done} из ${total} проверок` : '—';
    }
    if (fill) fill.style.width = `${pct}%`;

    const monthsWrap = document.getElementById('reportsScheduleMonths');
    if (!monthsWrap) return;

    if (!total) {
      monthsWrap.innerHTML = '<p class="reports-chart-empty" role="status">Нет запланированных проверок</p>';
      return;
    }

    const byMonth = Array.from({ length: 12 }, (_, i) => ({
      month: i + 1,
      plan: 0,
      done: 0,
    }));
    for (const item of items) {
      const m = getScheduleMonth(item);
      if (!m || m < 1 || m > 12) continue;
      const bucket = byMonth[m - 1];
      bucket.plan += 1;
      if (item.actualDate) bucket.done += 1;
    }

    const activeMonths = byMonth.filter((b) => b.plan > 0);
    const maxPlan = Math.max(...activeMonths.map((b) => b.plan), 1);

    monthsWrap.innerHTML = activeMonths
      .map((b) => {
        const monthPct = b.plan > 0 ? Math.round((b.done / b.plan) * 100) : 0;
        const width = Math.max(8, Math.round((b.plan / maxPlan) * 100));
        return `<div class="reports-schedule-month">
          <div class="reports-schedule-month__head">
            <span class="reports-schedule-month__name">${MONTH_SHORT[b.month - 1]}</span>
            <span class="reports-schedule-month__val">${b.done}/${b.plan}</span>
          </div>
          <div class="reports-schedule-month__track" aria-hidden="true">
            <div class="reports-schedule-month__fill" style="width:${width}%">
              <span class="reports-schedule-month__fill-inner" style="width:${monthPct}%"></span>
            </div>
          </div>
        </div>`;
      })
      .join('');
  }

  function toggleFilter(group, rawValue) {
    const set = filters[group];
    if (!set) return;
    let value = rawValue;
    if (group === 'years') {
      value = parseInt(rawValue, 10);
      if (Number.isNaN(value)) return;
    }
    if (set.has(value)) set.delete(value);
    else set.add(value);
  }

  function applyRender(data) {
    if (!data) return;
    activeCatalog = data;
    try {
      if (typeof ViolationTypes !== 'undefined') ViolationTypes.ensureCatalog(activeCatalog);
    } catch (err) {
      console.warn('ReportsDashboard: ViolationTypes', err);
    }
    const options = buildFilterOptions(data);
    pruneFilters(data);
    const displayOptions = { ...options };
    if (openGroup) {
      displayOptions[openGroup] = buildFilterOptions(data, { forGroup: openGroup })[openGroup];
    }
    renderFilterGroups(displayOptions);
    renderTreemapLegend();

    const { rows, akts } = collectRows(data);
    const stats = countByStatus(rows);

    renderKpi(rows, akts);
    renderDonut(stats);
    renderOrgTreemap(data);
    renderBarChart(rows);
    renderOverdueChart(rows);
    renderScheduleDashboard(data);
  }

  function resetFilters() {
    filters = {
      acts: new Set(),
      years: new Set(),
      objects: new Set(),
      contractors: new Set(),
    };
    scheduleYears = new Set();
    openGroup = null;
  }

  function closePanels() {
    openGroup = null;
    const panelRow = document.getElementById('reportsFilterPanelRow');
    if (panelRow) panelRow.hidden = true;
  }

  function render(data) {
    applyRender(data);
  }

  function requestRender() {
    void GazpromStore.get().then(applyRender);
  }

  function bind() {
    if (bound) return;
    bound = true;
    const screen = document.getElementById('screen-reports');
    if (!screen) return;

    screen.addEventListener('click', (e) => {
      const overdueViewBtn = e.target.closest('[data-reports-overdue-view]');
      if (overdueViewBtn) {
        e.stopPropagation();
        overdueViewMode = overdueViewBtn.dataset.reportsOverdueView || 'contractors';
        requestRender();
        return;
      }

      const scheduleYearBtn = e.target.closest('[data-reports-schedule-year]');
      if (scheduleYearBtn) {
        e.stopPropagation();
        toggleScheduleYear(scheduleYearBtn.dataset.reportsScheduleYear);
        requestRender();
        return;
      }

      const orgCell = e.target.closest('[data-reports-org]');
      if (orgCell) {
        e.stopPropagation();
        selectContractorFromTreemap(orgCell.dataset.reportsOrg);
        requestRender();
        return;
      }

      const groupBtn = e.target.closest('[data-reports-group]');
      if (groupBtn) {
        e.stopPropagation();
        const group = groupBtn.dataset.reportsGroup;
        if (!group) return;
        if (openGroup === group) closePanels();
        else openGroup = group;
        requestRender();
        return;
      }

      const chip = e.target.closest('[data-reports-filter]');
      if (chip) {
        e.stopPropagation();
        toggleFilter(chip.dataset.reportsFilter, chip.dataset.reportsValue);
        requestRender();
        return;
      }

      if (e.target.closest('#reportsResetFilters')) {
        resetFilters();
        requestRender();
        return;
      }

      if (e.target.closest('#reportsExportBtn')) {
        void ReportExporter.exportViolationsReport().catch((err) => {
          GazpromToast.error(err.message);
        });
        return;
      }

      if (e.target.closest('#reportsScheduleBtn')) {
        try {
          ScheduleEditor.open();
        } catch (err) {
          GazpromToast.error(err.message);
        }
        return;
      }

      if (e.target.closest('#reportsScheduleExportBtn')) {
        void ReportExporter.exportSchedule().catch((err) => {
          GazpromToast.error(err.message);
        });
      }
    });

    document.addEventListener('click', (e) => {
      if (!openGroup) return;
      const reportsScreen = document.getElementById('screen-reports');
      if (!reportsScreen?.classList.contains('active')) return;
      if (e.target.closest('.reports-filter-toolbar')) return;
      closePanels();
      requestRender();
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && openGroup) {
        closePanels();
        requestRender();
      }
    });
  }

  function init() {
    bind();
  }

  return { init, render, resetFilters };
})();
