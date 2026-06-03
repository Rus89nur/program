/**
 * Сокращённый акт — форма как ShortAktFormViewController (iOS).
 */
const ShortAktForm = (() => {
  let editingAkt = null;

  function ensureModalRoot() {
    let root = document.getElementById('shortAktModalRoot');
    if (root) return root;
    root = document.createElement('div');
    root.id = 'shortAktModalRoot';
    root.className = 'modal-root';
    root.hidden = true;
    root.innerHTML = `
      <div class="modal-backdrop" data-short-close></div>
      <div class="modal-dialog modal-dialog--wide" role="dialog" aria-modal="true" aria-labelledby="shortAktModalTitle">
        <div class="modal-header">
          <h3 id="shortAktModalTitle">Сокращённый акт</h3>
          <button type="button" class="modal-close" data-short-close aria-label="Закрыть">×</button>
        </div>
        <div class="modal-body" id="shortAktModalBody"></div>
        <div class="modal-footer" id="shortAktModalFooter"></div>
      </div>
    `;
    document.body.appendChild(root);
    root.querySelectorAll('[data-short-close]').forEach((el) => {
      el.addEventListener('click', close);
    });
    return root;
  }

  function close() {
    const root = document.getElementById('shortAktModalRoot');
    if (root) {
      root.classList.remove('show');
      root.hidden = true;
    }
    document.body.style.overflow = '';
    editingAkt = null;
  }

  function openModal(title, bodyHtml, footerHtml) {
    const root = ensureModalRoot();
    root.hidden = false;
    root.classList.add('show');
    document.body.style.overflow = 'hidden';
    document.getElementById('shortAktModalTitle').textContent = title;
    document.getElementById('shortAktModalBody').innerHTML = bodyHtml;
    const footer = document.getElementById('shortAktModalFooter');
    footer.innerHTML = footerHtml || '';
    footer.querySelectorAll('[data-short-close]').forEach((el) => {
      el.addEventListener('click', close);
    });
  }

  function isNumberAvailable(catalog, number, year, excludeId) {
    const occupied = AktUtils.occupiedNumbers(catalog.akts || [], excludeId, year);
    return !occupied.has(String(number));
  }

  function syncEliminations(catalog, akt) {
    const deadline = AktUtils.getEliminationDeadline(akt);
    const list = [...(catalog.violationEliminations || [])];
    const violationIds = new Set((akt.violations || []).map((v) => v.id));
    let changed = false;

    for (const v of akt.violations || []) {
      const idx = list.findIndex(
        (e) => String(e.aktId) === String(akt.id) && e.violationId === v.id
      );
      if (idx < 0) {
        list.push({
          id: AktUtils.uuid(),
          aktId: akt.id,
          aktNumber: akt.number,
          violationId: v.id,
          violationTitle: v.title,
          isEliminated: false,
          originalEliminationDate: deadline,
          deadlineHistory: deadline
            ? [
                {
                  id: AktUtils.uuid(),
                  deadlineDate: deadline,
                  changeDate: new Date().toISOString(),
                  isOriginal: true,
                },
              ]
            : [],
        });
        changed = true;
        continue;
      }
      const entry = list[idx];
      if (deadline && entry.originalEliminationDate !== deadline) {
        list[idx] = {
          ...entry,
          violationTitle: v.title,
          originalEliminationDate: deadline,
          deadlineHistory: [
            {
              id: AktUtils.uuid(),
              deadlineDate: deadline,
              changeDate: new Date().toISOString(),
              isOriginal: true,
            },
          ],
        };
        changed = true;
      }
    }

    const filtered = list.filter((e) => {
      if (String(e.aktId) !== String(akt.id)) return true;
      return violationIds.has(e.violationId);
    });
    if (filtered.length !== list.length) changed = true;

    if (changed) catalog.violationEliminations = filtered;
    return changed;
  }

  function buildFormHtml(catalog, akt) {
    const counts = akt ? AktUtils.parseShortViolationCounts(akt) : {};
    const emptyCounts = {};
    AktUtils.SHORT_VIOLATION_TYPES.forEach((t) => {
      emptyCounts[t] = counts[t] || 0;
    });

    const inspectionDate = akt?.date
      ? AktUtils.toDateInputValue(akt.date)
      : AktUtils.toDateInputValue(new Date().toISOString());
    const reportDate = akt?.actPredostavlenDate
      ? AktUtils.toDateInputValue(akt.actPredostavlenDate)
      : AktUtils.toDateInputValue(AktUtils.addMonthsIso(inspectionDate + 'T12:00:00', 1));

    const orgs = catalog.organizations || [];
    const objects = catalog.objects || [];
    const orgId = akt?.organization?.id || '';
    const objId = akt?.objectsCheck?.[0]?.id || '';

    const year = new Date((akt?.date || inspectionDate) + 'T12:00:00').getFullYear();
    const defaultNumber =
      akt?.number || AktUtils.nextAktNumberForYear(catalog.akts || [], year, akt?.id);
    const numberOptions = Array.from({ length: 200 }, (_, i) => String(i + 1))
      .map(
        (n) =>
          `<option value="${n}"${String(defaultNumber) === n ? ' selected' : ''}>${n}</option>`
      )
      .join('');

    const orgOptions = orgs
      .map(
        (o) =>
          `<option value="${AktUtils.escapeHtml(o.id)}"${o.id === orgId ? ' selected' : ''}>${AktUtils.escapeHtml(o.title)}</option>`
      )
      .join('');

    const objOptions = objects
      .map(
        (o) =>
          `<option value="${AktUtils.escapeHtml(o.id)}"${o.id === objId ? ' selected' : ''}>${AktUtils.escapeHtml(o.title)}${o.subTitle ? ` — ${AktUtils.escapeHtml(o.subTitle)}` : ''}</option>`
      )
      .join('');

    const steppers = AktUtils.SHORT_VIOLATION_TYPES.map((type) => {
      const c = emptyCounts[type] || 0;
      const shortLabel =
        type.length > 48 ? `${type.slice(0, 45)}…` : type;
      return `
        <div class="short-akt-stepper" data-short-type="${AktUtils.escapeHtml(type)}">
          <label class="short-akt-stepper__label" title="${AktUtils.escapeHtml(type)}">${AktUtils.escapeHtml(shortLabel)}</label>
          <div class="short-akt-stepper__ctrl">
            <button type="button" class="btn-ghost btn-sm" data-short-dec aria-label="Уменьшить">−</button>
            <span class="short-akt-stepper__val" data-short-val>${c}</span>
            <button type="button" class="btn-ghost btn-sm" data-short-inc aria-label="Увеличить">+</button>
          </div>
        </div>`;
    }).join('');

    const total = Object.values(emptyCounts).reduce((s, n) => s + n, 0);

    return `
      <p class="short-akt-hint">Минимальный набор полей, как в iOS. Нарушения сохраняются с префиксом «Сокращенный:».</p>
      <div class="form-grid">
        <label class="form-label">Номер акта</label>
        <select class="form-control" id="shortAktNumber">${numberOptions}</select>
        <label class="form-label">Дата проверки</label>
        <input class="form-control" type="date" id="shortAktInspection" value="${inspectionDate}">
        <label class="form-label">Дата предоставления отчёта</label>
        <input class="form-control" type="date" id="shortAktReport" value="${reportDate}">
        <label class="form-label">Подрядчик (организация)</label>
        <select class="form-control" id="shortAktOrg">
          <option value="">— выберите —</option>
          ${orgOptions}
        </select>
        <label class="form-label">Объект</label>
        <select class="form-control" id="shortAktObject">
          <option value="">— выберите —</option>
          ${objOptions}
        </select>
      </div>
      <h4 class="short-akt-section-title">Распределение нарушений по видам</h4>
      <div class="short-akt-steppers">${steppers}</div>
      <p class="short-akt-total" id="shortAktTotal">Итого нарушений: <strong>${total}</strong></p>
    `;
  }

  function bindFormHandlers(catalog) {
    const body = document.getElementById('shortAktModalBody');
    if (!body) return;

    const counts = {};
    AktUtils.SHORT_VIOLATION_TYPES.forEach((t) => {
      counts[t] = 0;
    });
    body.querySelectorAll('.short-akt-stepper').forEach((row) => {
      const type = row.dataset.shortType;
      const valEl = row.querySelector('[data-short-val]');
      counts[type] = parseInt(valEl?.textContent, 10) || 0;
      row.querySelector('[data-short-inc]')?.addEventListener('click', () => {
        counts[type] = Math.min(999, (counts[type] || 0) + 1);
        if (valEl) valEl.textContent = String(counts[type]);
        updateTotal(body, counts);
      });
      row.querySelector('[data-short-dec]')?.addEventListener('click', () => {
        counts[type] = Math.max(0, (counts[type] || 0) - 1);
        if (valEl) valEl.textContent = String(counts[type]);
        updateTotal(body, counts);
      });
    });

    const inspection = body.querySelector('#shortAktInspection');
    const report = body.querySelector('#shortAktReport');
    if (inspection && report && !editingAkt) {
      inspection.addEventListener('change', () => {
        if (!inspection.value) return;
        report.value = AktUtils.toDateInputValue(
          AktUtils.addMonthsIso(inspection.value + 'T12:00:00', 1)
        );
      });
    }

    body._shortCounts = counts;
  }

  function updateTotal(body, counts) {
    const total = Object.values(counts).reduce((s, n) => s + (parseInt(n, 10) || 0), 0);
    const el = body.querySelector('#shortAktTotal strong');
    if (el) el.textContent = String(total);
  }

  function readForm(catalog) {
    const body = document.getElementById('shortAktModalBody');
    const number = body.querySelector('#shortAktNumber')?.value?.trim();
    const inspectionVal = body.querySelector('#shortAktInspection')?.value;
    const reportVal = body.querySelector('#shortAktReport')?.value;
    const orgId = body.querySelector('#shortAktOrg')?.value;
    const objId = body.querySelector('#shortAktObject')?.value;

    if (!number) throw new Error('Выберите номер акта');
    if (!inspectionVal) throw new Error('Укажите дату проверки');
    if (!reportVal) throw new Error('Укажите дату предоставления отчёта');

    const org = (catalog.organizations || []).find((o) => o.id === orgId);
    if (!org) throw new Error('Выберите организацию');
    const obj = (catalog.objects || []).find((o) => o.id === objId);
    if (!obj) throw new Error('Выберите объект');

    const counts = body._shortCounts || {};
    const violations = AktUtils.buildShortViolations(counts);
    const totalViol = violations.length;
    if (totalViol === 0) throw new Error('Укажите хотя бы одно нарушение');

    const inspectionIso = new Date(inspectionVal + 'T12:00:00').toISOString();
    const reportIso = new Date(reportVal + 'T12:00:00').toISOString();
    const year = new Date(inspectionIso).getFullYear();
    const excludeId = editingAkt?.id;
    if (!isNumberAvailable(catalog, number, year, excludeId)) {
      throw new Error('Номер уже занят в этом году. Выберите другой.');
    }

    const now = new Date().toISOString();
    const base = editingAkt || {
      id: AktUtils.uuid(),
      comission: [],
      predstavitelyComission: [],
      description: '',
      urlToFllACT: null,
      realDateCreate: now,
      uniqueID: `${inspectionVal}-${number}`,
    };

    return {
      ...base,
      number,
      date: inspectionIso,
      organization: { ...org },
      objectsCheck: [{ ...obj }],
      violations,
      actustranenDate: reportIso,
      actPredostavlenDate: reportIso,
      actUtverzdenDate: inspectionIso,
    };
  }

  async function handleSave() {
    try {
      const catalog = await GazpromStore.get();
      const akt = readForm(catalog);
      const idx = (catalog.akts || []).findIndex((a) => a.id === akt.id);
      if (idx >= 0) {
        catalog.akts[idx] = akt;
      } else {
        catalog.akts = [...(catalog.akts || []), akt];
      }
      syncEliminations(catalog, akt);
      await GazpromStore.set(catalog);
      if (typeof GazpromUI !== 'undefined') {
        GazpromUI.renderHome(catalog);
      }
      close();
      GazpromToast.success(editingAkt ? `Акт № ${akt.number} сохранён` : `Сокращённый акт № ${akt.number} создан`);
      await GazpromUI.refreshAll();
    } catch (e) {
      GazpromToast.error(e.message || 'Ошибка сохранения');
    }
  }

  async function open(aktId = null) {
    const catalog = await GazpromStore.get();
    editingAkt = aktId
      ? (catalog.akts || []).find((a) => a.id === aktId) || null
      : null;

    if (aktId && !editingAkt) {
      GazpromToast.error('Акт не найден');
      return;
    }
    if (aktId && editingAkt && !AktUtils.isShortFormat(editingAkt)) {
      goTo('wizard', { aktId });
      return;
    }

    const title = editingAkt
      ? `Редактирование сокращённого акта № ${editingAkt.number}`
      : 'Сокращённый акт';

    if (!editingAkt && !catalog.organizations?.length) {
      GazpromToast.error('Сначала добавьте организации в Настройках');
      goTo('settings');
      return;
    }

    openModal(
      title,
      buildFormHtml(catalog, editingAkt),
      `
        <button type="button" class="btn-secondary" data-short-close>Отмена</button>
        <button type="button" class="btn-primary" id="shortAktSaveBtn">Сохранить</button>
      `
    );
    bindFormHandlers(catalog);
    document.getElementById('shortAktSaveBtn')?.addEventListener('click', () => {
      void handleSave();
    });
  }

  return { open, close };
})();
