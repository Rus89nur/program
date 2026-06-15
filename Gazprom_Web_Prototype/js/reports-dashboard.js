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

  const STATUS_META = {
    done: { label: 'Устранено', color: 'var(--success)', cls: 'done' },
    overdue: { label: 'Срок устранения истёк', color: 'var(--danger)', cls: 'overdue' },
    ontime: { label: 'Срок устранения не истёк', color: '#f59e0b', cls: 'ontime' },
    nodeadline: { label: 'Отсутствует срок исполнения', color: '#94a3b8', cls: 'nodeadline' },
  };

  let filters = {
    acts: new Set(),
    years: new Set(),
    objects: new Set(),
    contractors: new Set(),
  };

  let openGroup = null;
  let bound = false;

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

  function getOrgTitle(akt) {
    return akt.organization?.shortTitle || akt.organization?.title || '—';
  }

  function getObjectTitle(akt) {
    return (akt.objectsCheck || [])[0]?.title || '—';
  }

  function getViolationKind(v) {
    const vid = String(v.vid || '').trim();
    if (vid) return vid;
    const title = String(v.title || '').trim();
    if (!title) return 'Без названия';
    return title.length > 80 ? `${title.slice(0, 77)}…` : title;
  }

  function buildFilterOptions(data) {
    const acts = new Set();
    const years = new Set();
    const objects = new Set();
    const contractors = new Set();

    (data.akts || []).forEach((akt) => {
      if (akt.number != null && akt.number !== '') acts.add(String(akt.number));
      if (akt.date) {
        const y = new Date(akt.date).getFullYear();
        if (!Number.isNaN(y)) years.add(y);
      }
      const obj = getObjectTitle(akt);
      if (obj && obj !== '—') objects.add(obj);
      const org = getOrgTitle(akt);
      if (org && org !== '—') contractors.add(org);
    });

    return {
      acts: [...acts].sort((a, b) => (parseInt(a, 10) || 0) - (parseInt(b, 10) || 0)),
      years: [...years].sort((a, b) => b - a),
      objects: [...objects].sort((a, b) => a.localeCompare(b, 'ru')),
      contractors: [...contractors].sort((a, b) => a.localeCompare(b, 'ru')),
    };
  }

  function pruneFilters(options) {
    const prune = (set, list, asString = true) => {
      const valid = new Set(list.map((v) => (asString ? String(v) : v)));
      for (const val of [...set]) {
        if (!valid.has(asString ? String(val) : val)) set.delete(val);
      }
    };
    prune(filters.acts, options.acts);
    prune(filters.years, options.years, false);
    prune(filters.objects, options.objects);
    prune(filters.contractors, options.contractors);
  }

  function filterAkts(akts) {
    return (akts || []).filter((akt) => {
      if (filters.acts.size && !filters.acts.has(String(akt.number))) return false;
      if (filters.years.size) {
        const y = new Date(akt.date).getFullYear();
        if (!filters.years.has(y)) return false;
      }
      if (filters.objects.size && !filters.objects.has(getObjectTitle(akt))) return false;
      if (filters.contractors.size && !filters.contractors.has(getOrgTitle(akt))) return false;
      return true;
    });
  }

  function collectRows(data) {
    const eliminations = data.violationEliminations || [];
    const akts = filterAkts(data.akts || []);
    const rows = [];

    for (const akt of akts) {
      const org = getOrgTitle(akt);
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
    const wrap = document.getElementById('reportsFilterGroups');
    if (!wrap) return;

    wrap.innerHTML = FILTER_GROUPS.map(({ key, label }) => {
      const activeCount = filters[key].size;
      const isOpen = openGroup === key;
      const items = options[key] || [];
      const chips = items.length
        ? items
            .map((item) => {
              const val = key === 'years' ? item : String(item);
              const active =
                key === 'years' ? filters.years.has(item) : filters[key].has(String(item));
              return `<button type="button" class="btn-org-filter${active ? ' btn-org-filter-active' : ''}" data-reports-filter="${key}" data-reports-value="${AktUtils.escapeHtml(String(val))}">${AktUtils.escapeHtml(String(item))}</button>`;
            })
            .join('')
        : '<p class="reports-filter-empty">Нет данных</p>';

      return `<div class="reports-filter-group${isOpen ? ' reports-filter-group--open' : ''}" data-filter-group="${key}">
        <button type="button" class="reports-filter-trigger" aria-expanded="${isOpen}" aria-controls="reportsFilterPanel-${key}">
          <span>${AktUtils.escapeHtml(label)}</span>
          <span class="reports-filter-badge${activeCount ? '' : ' reports-filter-badge--hidden'}">${activeCount || ''}</span>
          <span class="reports-filter-chevron" aria-hidden="true">▾</span>
        </button>
        <div class="reports-filter-panel" id="reportsFilterPanel-${key}" role="region" aria-label="Фильтр: ${AktUtils.escapeHtml(label)}"${isOpen ? '' : ' hidden'}>
          <div class="reports-filter-chips">${chips}</div>
        </div>
      </div>`;
    }).join('');
  }

  function renderKpi(rows, akts) {
    const stats = countByStatus(rows);
    const orgs = new Set(akts.map((a) => getOrgTitle(a)).filter((o) => o && o !== '—'));
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

  function renderOrgTreemap(rows) {
    const wrap = document.getElementById('reportsOrgTreemap');
    if (!wrap) return;

    if (!rows.length) {
      wrap.innerHTML = '<p class="reports-chart-empty" role="status">Нет данных для отображения</p>';
      return;
    }

    const byOrg = new Map();
    for (const r of rows) {
      if (!byOrg.has(r.org)) {
        byOrg.set(r.org, { total: 0, done: 0, overdue: 0, ontime: 0, nodeadline: 0 });
      }
      const bucket = byOrg.get(r.org);
      bucket.total += 1;
      bucket[r.status] += 1;
    }

    const entries = [...byOrg.entries()].sort((a, b) => b[1].total - a[1].total);
    const max = entries[0][1].total || 1;

    wrap.innerHTML = `<div class="reports-treemap">${entries
      .map(([org, counts]) => {
        const flex = Math.max(1, Math.round((counts.total / max) * 100));
        const color = orgBlockColor(counts);
        return `<div class="reports-treemap__cell" style="flex:${flex};background:${color}" title="${AktUtils.escapeHtml(org)} — ${counts.total}">
          <span class="reports-treemap__name">${AktUtils.escapeHtml(org)}</span>
          <span class="reports-treemap__val">${counts.total}</span>
        </div>`;
      })
      .join('')}</div>`;
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

  function toggleFilter(group, rawValue) {
    const set = filters[group];
    if (!set) return;
    const value = group === 'years' ? parseInt(rawValue, 10) : rawValue;
    if (set.has(value)) set.delete(value);
    else set.add(value);
  }

  function resetFilters() {
    filters = {
      acts: new Set(),
      years: new Set(),
      objects: new Set(),
      contractors: new Set(),
    };
    openGroup = null;
  }

  function closePanels() {
    openGroup = null;
    document.querySelectorAll('.reports-filter-group').forEach((g) => {
      g.classList.remove('reports-filter-group--open');
      const panel = g.querySelector('.reports-filter-panel');
      const trigger = g.querySelector('.reports-filter-trigger');
      if (panel) panel.hidden = true;
      if (trigger) trigger.setAttribute('aria-expanded', 'false');
    });
  }

  function render(data) {
    if (!data) return;
    const options = buildFilterOptions(data);
    pruneFilters(options);
    renderFilterGroups(options);
    renderTreemapLegend();

    const { rows, akts } = collectRows(data);
    const stats = countByStatus(rows);

    renderKpi(rows, akts);
    renderDonut(stats);
    renderOrgTreemap(rows);
    renderBarChart(rows);
  }

  function bind() {
    if (bound) return;
    bound = true;
    const screen = document.getElementById('screen-reports');
    if (!screen) return;

    screen.addEventListener('click', async (e) => {
      const trigger = e.target.closest('.reports-filter-trigger');
      if (trigger) {
        const group = trigger.closest('[data-filter-group]')?.dataset.filterGroup;
        if (!group) return;
        if (openGroup === group) {
          closePanels();
        } else {
          openGroup = group;
          render(await GazpromStore.get());
        }
        return;
      }

      const chip = e.target.closest('[data-reports-filter]');
      if (chip) {
        toggleFilter(chip.dataset.reportsFilter, chip.dataset.reportsValue);
        render(await GazpromStore.get());
        return;
      }

      if (e.target.closest('#reportsResetFilters')) {
        resetFilters();
        render(await GazpromStore.get());
        return;
      }

      if (e.target.closest('#reportsExportBtn')) {
        try {
          await ReportExporter.exportViolationsReport();
        } catch (err) {
          GazpromToast.error(err.message);
        }
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
        try {
          await ReportExporter.exportSchedule();
        } catch (err) {
          GazpromToast.error(err.message);
        }
      }
    });

    document.addEventListener('click', (e) => {
      if (!openGroup) return;
      if (e.target.closest('.reports-filter-group')) return;
      closePanels();
      void GazpromStore.get().then(render);
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && openGroup) {
        closePanels();
        void GazpromStore.get().then(render);
      }
    });
  }

  function init() {
    bind();
  }

  return { init, render, resetFilters };
})();
