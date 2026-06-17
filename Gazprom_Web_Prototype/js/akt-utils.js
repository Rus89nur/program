/** Утилиты для актов (совместимость с iOS AKT). */
const AktUtils = (() => {
  function uuid() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }

  function toDateInputValue(iso) {
    if (!iso) return '';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return '';
    return d.toISOString().slice(0, 10);
  }

  function formatDateShort(iso) {
    if (!iso) return '—';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return '—';
    return d.toLocaleDateString('ru-RU');
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  /** Префиксы заголовков нарушений сокращённого акта (как в iOS AKT.isShortFormat). */
  const SHORT_VIOLATION_PREFIXES = ['Сокращенный:', 'Сокращённый:', 'Внешний:'];

  /** Виды нарушений для сокращённого акта (ViolationType.displayName, iOS). */
  const SHORT_VIOLATION_TYPES = [
    'Обучение работников в области производственной безопасности',
    'Обеспечение работников СИЗ, применении работниками СИЗ',
    'Работы на высоте',
    'Пожароопасные работы',
    'Газоопасные работы',
    'Земляные работы',
    'Погрузочно-разгрузочные работы,складирование материалов',
    'Эксплуатация инструмента и приспособлений',
    'Эксплуатация машин и механизмов, подъёмных сооружений, подъёмных средств, подъёмных механизмов',
    'Эксплуатация, перевозка, хранение баллонов с сжиженным газом и газовых баллонов',
    'Пожарная безопасность',
    'Электробезопасность',
    'Безопасность дорожного движения, перевозка пассажиров и грузов',
    'Санитарно-бытовое обеспечение',
    'Организация внутреннего контроля за соблюдением требований производственной безопасности на ОРП',
    'Организация работы с происшествиями (несчастными случаями, авариями, инцидентами, пожарами, транспортными происшествиями)',
    'Прочие работы',
  ];

  const LEGACY_FULL_NUMBERS = new Set(['19', '20']);

  function isShortViolationTitle(title) {
    const t = String(title || '').trim();
    return SHORT_VIOLATION_PREFIXES.some((p) => t.startsWith(p));
  }

  function isShortFormat(akt) {
    return (akt?.violations || []).some((v) => isShortViolationTitle(v.title));
  }

  function isFullFormat(akt) {
    if (isShortFormat(akt)) return false;
    const url = akt?.urlToFllACT;
    if (typeof url === 'string' && url.length > 0 && !isDraft(akt)) return true;
    return LEGACY_FULL_NUMBERS.has(String(akt?.number ?? ''));
  }

  function getFormatKind(akt) {
    if (isShortFormat(akt)) return 'short';
    if (isFullFormat(akt)) return 'full';
    return 'other';
  }

  function formatKindLabel(akt) {
    const k = getFormatKind(akt);
    if (k === 'short') return 'Сокращённый';
    if (k === 'full') return 'Полный';
    return '—';
  }

  /** История сроков: только продления (без первоначального срока из акта). */
  function extensionDeadlineHistory(history) {
    return (history || []).filter((h) => h && h.isOriginal !== true);
  }

  function parseCalendarDate(iso) {
    if (!iso) return null;
    const s = String(iso);
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (m) return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return null;
    return new Date(d.getFullYear(), d.getMonth(), d.getDate());
  }

  function todayCalendarDate() {
    const today = new Date();
    return new Date(today.getFullYear(), today.getMonth(), today.getDate());
  }

  function isDeadlineExpired(iso) {
    const deadline = parseCalendarDate(iso);
    if (!deadline) return false;
    return todayCalendarDate() > deadline;
  }

  function sameDeadlineDay(aIso, bIso) {
    const a = parseCalendarDate(aIso);
    const b = parseCalendarDate(bIso);
    if (!a || !b) return false;
    return (
      a.getFullYear() === b.getFullYear() &&
      a.getMonth() === b.getMonth() &&
      a.getDate() === b.getDate()
    );
  }

  /** Поздняя из двух дат (по календарному дню) — актуально после сдвига срока в мастере. */
  function pickLaterDeadline(aIso, bIso) {
    if (!aIso) return bIso || null;
    if (!bIso) return aIso || null;
    const a = parseCalendarDate(aIso);
    const b = parseCalendarDate(bIso);
    if (!a) return bIso;
    if (!b) return aIso;
    return a >= b ? aIso : bIso;
  }

  function getRecordOnlyDeadline(el) {
    if (!el) return null;
    const history = extensionDeadlineHistory(el.deadlineHistory);
    if (history.length > 0) {
      return history.reduce(
        (best, h) => pickLaterDeadline(best, h?.deadlineDate),
        null
      );
    }
    return el.newEliminationDate || el.originalEliminationDate || null;
  }

  /** Срок устранения: для сокращённых — дата предоставления отчёта; для полных — actustranenDate. */
  function getEliminationDeadline(akt) {
    if (!akt) return null;
    if (isShortFormat(akt)) {
      return akt.actPredostavlenDate || akt.actustranenDate || null;
    }
    if (akt.actustranenDate) return akt.actustranenDate;
    if (akt.date) {
      const d = new Date(akt.date);
      if (!Number.isNaN(d.getTime())) {
        const plus = new Date(d);
        plus.setMonth(plus.getMonth() + 1);
        return plus.toISOString();
      }
    }
    return null;
  }

  function aktIdMatch(a, b) {
    return String(a || '').toLowerCase() === String(b || '').toLowerCase();
  }

  /** Лучшая запись устранения при дубликатах (импорт / повторное создание). */
  function findViolationElimination(eliminations, aktId, violationId) {
    const matches = (eliminations || []).filter(
      (e) => aktIdMatch(e.aktId, aktId) && e.violationId === violationId
    );
    if (!matches.length) return null;
    if (matches.length === 1) return matches[0];
    return matches.sort((a, b) => {
      if (!!a.isEliminated !== !!b.isEliminated) return a.isEliminated ? -1 : 1;
      const ta = new Date(a.eliminatedAt || a.eliminationDate || 0).getTime();
      const tb = new Date(b.eliminatedAt || b.eliminationDate || 0).getTime();
      return tb - ta;
    })[0];
  }

  /**
   * Актуальный срок по нарушению: продления из истории, иначе срок из акта
   * (чтобы отчёты не показывали просрочку после изменения даты в мастере).
   */
  function getViolationEliminationDeadline(el, akt) {
    const aktDeadline = getEliminationDeadline(akt);
    if (!el) return aktDeadline;
    const history = extensionDeadlineHistory(el.deadlineHistory);
    let fromRecord = null;
    if (history.length > 0) {
      fromRecord = history.reduce(
        (best, h) => pickLaterDeadline(best, h?.deadlineDate),
        null
      );
    } else if (el.newEliminationDate) {
      fromRecord = el.newEliminationDate;
    } else {
      fromRecord = el.originalEliminationDate || null;
    }
    return pickLaterDeadline(aktDeadline, fromRecord);
  }

  function isViolationEliminationOverdue(el, akt) {
    if (el?.isEliminated) return false;
    const deadline = getViolationEliminationDeadline(el, akt);
    return isDeadlineExpired(deadline);
  }

  /** Создать / обновить / дедуплицировать записи устранения для акта. */
  function syncViolationEliminationsForAkt(catalog, akt) {
    if (!catalog || !akt) return false;
    const deadline = getEliminationDeadline(akt);
    const all = catalog.violationEliminations || [];
    const violationIds = new Set((akt.violations || []).map((v) => v.id));
    const others = all.filter((e) => !aktIdMatch(e.aktId, akt.id));
    const aktRecords = all.filter(
      (e) => aktIdMatch(e.aktId, akt.id) && violationIds.has(e.violationId)
    );
    const deduped = new Map();
    for (const e of aktRecords) {
      const prev = deduped.get(e.violationId);
      deduped.set(
        e.violationId,
        prev ? findViolationElimination([prev, e], akt.id, e.violationId) : e
      );
    }
    let changed =
      aktRecords.length !== deduped.size ||
      all.length !== others.length + aktRecords.length;

    const next = [...others];
    for (const v of akt.violations || []) {
      let entry = deduped.get(v.id);
      if (!entry) {
        next.push({
          id: uuid(),
          aktId: akt.id,
          aktNumber: akt.number,
          violationId: v.id,
          violationTitle: v.title,
          isEliminated: false,
          originalEliminationDate: deadline,
          deadlineHistory: [],
        });
        changed = true;
        continue;
      }
      const hasExtension =
        extensionDeadlineHistory(entry.deadlineHistory).length > 0 || entry.newEliminationDate;
      const cleaned = extensionDeadlineHistory(entry.deadlineHistory);
      let updated = {
        ...entry,
        violationTitle: v.title,
        deadlineHistory: cleaned.length !== (entry.deadlineHistory || []).length ? cleaned : entry.deadlineHistory,
      };
      if (deadline && !entry.isEliminated) {
        const recordDeadline = getRecordOnlyDeadline(entry);
        if (
          recordDeadline &&
          pickLaterDeadline(deadline, recordDeadline) === deadline &&
          !sameDeadlineDay(deadline, recordDeadline)
        ) {
          updated = {
            ...updated,
            originalEliminationDate: deadline,
            newEliminationDate: null,
          };
          changed = true;
        } else if (!hasExtension && !sameDeadlineDay(entry.originalEliminationDate, deadline)) {
          updated = { ...updated, originalEliminationDate: deadline };
          changed = true;
        }
      }
      if (updated.violationTitle !== entry.violationTitle) changed = true;
      if (updated.deadlineHistory !== entry.deadlineHistory) changed = true;
      next.push(updated);
    }

    if (changed) catalog.violationEliminations = next;
    return changed;
  }

  function parseShortViolationCounts(akt) {
    const counts = {};
    SHORT_VIOLATION_TYPES.forEach((t) => {
      counts[t] = 0;
    });
    for (const v of akt?.violations || []) {
      const vid = String(v.vid || '').trim();
      if (vid && counts[vid] != null) {
        counts[vid] += 1;
        continue;
      }
      if (!isShortViolationTitle(v.title)) continue;
      const raw = String(v.title).replace(/^[^:]+:\s*/, '').trim();
      if (counts[raw] != null) counts[raw] += 1;
    }
    return counts;
  }

  function buildShortViolations(countsByType) {
    const violations = [];
    for (const type of SHORT_VIOLATION_TYPES) {
      const count = Math.max(0, parseInt(countsByType[type], 10) || 0);
      for (let i = 0; i < count; i += 1) {
        violations.push({
          id: uuid(),
          title: `Сокращенный: ${type}`,
          mesto: '',
          urlToPravilo: '',
          photo: [],
          vid: type,
          formulaFromRules: null,
        });
      }
    }
    return violations;
  }

  function addMonthsIso(iso, months) {
    const d = new Date(iso || Date.now());
    if (Number.isNaN(d.getTime())) return new Date().toISOString();
    const out = new Date(d);
    out.setMonth(out.getMonth() + months);
    return out.toISOString();
  }

  function addDaysIso(iso, days) {
    const d = new Date(iso || Date.now());
    if (Number.isNaN(d.getTime())) return new Date().toISOString();
    const out = new Date(d);
    out.setDate(out.getDate() + days);
    return out.toISOString();
  }

  function isWeekendUtc(d) {
    const day = d.getUTCDay();
    return day === 0 || day === 6;
  }

  /** Если дата на субботу/воскресенье — сдвиг на предыдущий рабочий день (пятница и т.д.). */
  function adjustToPrevWorkdayIso(iso) {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return iso;
    while (isWeekendUtc(d)) {
      d.setUTCDate(d.getUTCDate() - 1);
    }
    return d.toISOString();
  }

  /** Флаги ручного изменения дат в шаге «Выводы»; сбрасываются при смене даты проверки. */
  function defaultConclusionDatesManual() {
    return { elim: false, pred: false, utver: false };
  }

  function normalizeConclusionDatesManual(akt) {
    const m = akt?.conclusionDatesManual;
    if (!m || typeof m !== 'object') {
      return { elim: true, pred: true, utver: true };
    }
    return {
      elim: Boolean(m.elim),
      pred: Boolean(m.pred),
      utver: Boolean(m.utver),
    };
  }

  function ensureConclusionDateTracking(akt) {
    if (!akt) return akt;
    if (akt.date && !akt.conclusionDatesInspectionBasis) {
      akt.conclusionDatesInspectionBasis = akt.date;
    }
    if (!akt.conclusionDatesManual) {
      akt.conclusionDatesManual = normalizeConclusionDatesManual(akt);
    }
    return akt;
  }

  /** Даты выводов: +1 мес. (устранение и предоставление), +7 дн. (утверждение); без выходных. */
  function computeConclusionDatesFromInspection(inspectionIso) {
    const base = inspectionIso || new Date().toISOString();
    const elim = adjustToPrevWorkdayIso(addMonthsIso(base, 1));
    const utver = adjustToPrevWorkdayIso(addDaysIso(base, 7));
    return {
      actustranenDate: elim,
      actPredostavlenDate: elim,
      actUtverzdenDate: utver,
    };
  }

  /**
   * Смена даты проверки: при другом календарном дне — полный пересчёт всех дат и сброс ручных флагов.
   * Ручные правки сохраняются, пока дата проверки не изменится снова.
   */
  function applyInspectionDateChange(akt, inspectionIso) {
    if (!akt || !inspectionIso) return akt;
    ensureConclusionDateTracking(akt);
    const basis = akt.conclusionDatesInspectionBasis || akt.date;
    akt.date = inspectionIso;
    if (!sameDeadlineDay(basis, inspectionIso)) {
      const computed = computeConclusionDatesFromInspection(inspectionIso);
      akt.actustranenDate = computed.actustranenDate;
      akt.actPredostavlenDate = computed.actPredostavlenDate;
      akt.actUtverzdenDate = computed.actUtverzdenDate;
      akt.conclusionDatesManual = defaultConclusionDatesManual();
      akt.conclusionDatesInspectionBasis = inspectionIso;
    }
    return akt;
  }

  /** Текущий полный акт для «Продолжить…» / мастера (сокращённые не учитываются). */
  function getFullEditableAkt(catalog) {
    const akt = catalog?.editableAkt?.akt;
    if (!akt || isShortFormat(akt)) return null;
    return akt;
  }

  /** Помечает акт как «текущий» для главной (Продолжить…) и бэкапа — только полные акты. */
  function applyCurrentEditable(catalog, akt) {
    if (!catalog || !akt || isShortFormat(akt)) return catalog;
    const copy = clone(akt);
    const now = new Date().toISOString();
    catalog.editableAkt = {
      akt: copy,
      isEditable: true,
      lastModified: now,
    };
    catalog.editableAktReference = {
      aktId: copy.id,
      aktNumber: copy.number,
      lastModified: now,
    };
    return catalog;
  }

  function isDraft(akt) {
    const url = akt?.urlToFllACT;
    if (url == null || url === '') return true;
    if (typeof url === 'string') {
      if (url.startsWith('web:')) return false;
      return url.length === 0 || url === '/' || url.endsWith('/');
    }
    return false;
  }

  function countPhotos(akt) {
    return (akt?.violations || []).reduce((n, v) => n + (v.photo?.length || 0), 0);
  }

  function photoSrc(photoData) {
    if (!photoData) return '';
    if (typeof photoData === 'string') {
      if (photoData.startsWith('photo:')) return '';
      if (photoData.startsWith('data:')) return photoData;
      return `data:image/jpeg;base64,${photoData}`;
    }
    return '';
  }

  async function photoSrcAsync(photoData) {
    if (!photoData) return '';
    if (typeof PhotoStore !== 'undefined' && PhotoStore.isPhotoId(photoData)) {
      return PhotoStore.resolveDataUrl(photoData);
    }
    return photoSrc(photoData);
  }

  function nextAktNumberForYear(akts, year, excludeId = null) {
    const nums = (akts || [])
      .filter((a) => {
        if (excludeId && a.id === excludeId) return false;
        if (year == null) return true;
        const aktYear = a.date ? new Date(a.date).getFullYear() : null;
        return aktYear === year;
      })
      .map((a) => parseInt(a.number, 10))
      .filter((n) => !Number.isNaN(n));
    const max = nums.length ? Math.max(...nums) : 0;
    return String(max + 1);
  }

  /** Следующий номер по всем годам (для обратной совместимости). */
  function nextAktNumber(akts) {
    const nums = (akts || [])
      .map((a) => parseInt(a.number, 10))
      .filter((n) => !Number.isNaN(n));
    const max = nums.length ? Math.max(...nums) : 0;
    return String(max + 1);
  }

  function occupiedNumbers(akts, excludeId, year) {
    return new Set(
      (akts || [])
        .filter((a) => {
          if (a.id === excludeId) return false;
          if (year == null) return true;
          const aktYear = a.date ? new Date(a.date).getFullYear() : null;
          return aktYear === year;
        })
        .map((a) => String(a.number))
    );
  }

  function defaultOrg(catalog) {
    const orgs = catalog?.organizations || [];
    if (orgs.length) return { ...orgs[0] };
    return { id: uuid(), title: 'Организация не указана', shortTitle: '—' };
  }

  function createEmptyDraft(catalog) {
    const now = new Date();
    const iso = now.toISOString();
    const conclusionDates = computeConclusionDatesFromInspection(iso);

    const year = new Date(iso).getFullYear();
    const number = nextAktNumberForYear(catalog?.akts, year);

    return {
      id: uuid(),
      number,
      date: iso,
      comission: [],
      organization: defaultOrg(catalog),
      objectsCheck: [],
      predstavitelyComission: [],
      violations: [],
      description: '',
      actustranenDate: conclusionDates.actustranenDate,
      actPredostavlenDate: conclusionDates.actPredostavlenDate,
      actUtverzdenDate: conclusionDates.actUtverzdenDate,
      conclusionDatesManual: defaultConclusionDatesManual(),
      conclusionDatesInspectionBasis: iso,
      urlToFllACT: null,
      realDateCreate: iso,
      uniqueID: `${toDateInputValue(iso)}-${number}`,
    };
  }

  function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
  }

  const SKIP_INPUT_TYPES = new Set([
    'search',
    'date',
    'datetime-local',
    'month',
    'week',
    'time',
    'number',
    'email',
    'url',
    'tel',
    'password',
    'file',
    'hidden',
    'checkbox',
    'radio',
    'range',
    'color',
  ]);

  function capitalizeFirstLetter(text) {
    const val = String(text ?? '');
    if (!val) return val;
    const m = val.match(/^(\s*)(\p{Ll})/u);
    if (!m) return val;
    const idx = m[1].length;
    return val.slice(0, idx) + m[2].toLocaleUpperCase('ru-RU') + val.slice(idx + 1);
  }

  function lowercaseFirstLetter(text) {
    const val = String(text ?? '');
    if (!val) return val;
    const m = val.match(/^(\s*)(\p{Lu})/u);
    if (!m) return val;
    const idx = m[1].length;
    return val.slice(0, idx) + m[2].toLocaleLowerCase('ru-RU') + val.slice(idx + 1);
  }

  /** Убирает кавычки в начале/конце строки (шаблон акта добавляет свои). */
  function stripSurroundingQuotes(text) {
    const QUOTE_CHARS = new Set(['«', '»', '"', '"', '"', "'", "'", '„', '‹', '›']);
    let val = String(text ?? '').trim();
    while (val.length && QUOTE_CHARS.has(val[0])) {
      val = val.slice(1).trimStart();
    }
    while (val.length && QUOTE_CHARS.has(val[val.length - 1])) {
      val = val.slice(0, -1).trimEnd();
    }
    return val;
  }

  function isAutoCapitalizeField(el) {
    if (!el || !(el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement)) return false;
    if (el.readOnly || el.disabled) return false;
    if (el.dataset.noCapitalize != null) return false;
    if (el.id === 'backupPasteText') return false;
    const type = (el.type || 'text').toLowerCase();
    return !SKIP_INPUT_TYPES.has(type);
  }

  function applyAutoCapitalize(el) {
    const val = el.value;
    const next = capitalizeFirstLetter(val);
    if (next === val) return;
    const start = el.selectionStart;
    const end = el.selectionEnd;
    el.value = next;
    if (start != null && end != null) {
      el.setSelectionRange(start, end);
    }
  }

  let autoCapitalizeBound = false;

  function bindAutoCapitalize(root = document) {
    if (autoCapitalizeBound) return;
    autoCapitalizeBound = true;
    root.addEventListener('input', (e) => {
      const el = e.target;
      if (!isAutoCapitalizeField(el)) return;
      applyAutoCapitalize(el);
    });
  }

  return {
    uuid,
    toDateInputValue,
    formatDateShort,
    escapeHtml,
    SHORT_VIOLATION_PREFIXES,
    SHORT_VIOLATION_TYPES,
    isShortViolationTitle,
    isShortFormat,
    isFullFormat,
    getFormatKind,
    formatKindLabel,
    getEliminationDeadline,
    aktIdMatch,
    findViolationElimination,
    getViolationEliminationDeadline,
    isViolationEliminationOverdue,
    isDeadlineExpired,
    pickLaterDeadline,
    syncViolationEliminationsForAkt,
    extensionDeadlineHistory,
    sameDeadlineDay,
    parseShortViolationCounts,
    buildShortViolations,
    addMonthsIso,
    addDaysIso,
    adjustToPrevWorkdayIso,
    defaultConclusionDatesManual,
    normalizeConclusionDatesManual,
    ensureConclusionDateTracking,
    computeConclusionDatesFromInspection,
    applyInspectionDateChange,
    getFullEditableAkt,
    applyCurrentEditable,
    isDraft,
    countPhotos,
    photoSrc,
    photoSrcAsync,
    nextAktNumber,
    nextAktNumberForYear,
    occupiedNumbers,
    createEmptyDraft,
    clone,
    defaultOrg,
    capitalizeFirstLetter,
    lowercaseFirstLetter,
    stripSurroundingQuotes,
    isAutoCapitalizeField,
    applyAutoCapitalize,
    bindAutoCapitalize,
  };
})();
