/**
 * Модель и утилиты для справки по производственной безопасности.
 */
const SpravkaUtils = (() => {
  function isDraft(spravka) {
    if (!spravka) return true;
    const url = spravka.urlToFllACT;
    if (typeof url === 'string' && url.length > 0) return false;
    return spravka.isDraft !== false;
  }

  function getEditableSpravka(catalog) {
    return catalog?.editableSpravka?.spravka || null;
  }

  function createEmpty(catalog) {
    const now = new Date().toISOString();
    return {
      id: AktUtils.uuid(),
      docKind: 'spravka',
      date: now,
      objectsCheck: [],
      subcontractorsList: '',
      workerRows: [],
      violations: [],
      remarksRMM: '',
      conclusion: '',
      urlToFllACT: null,
      isDraft: true,
      realDateCreate: now,
    };
  }

  function clone(spravka) {
    return JSON.parse(JSON.stringify(spravka || {}));
  }

  function applyCurrentEditable(catalog, spravka) {
    catalog.editableSpravka = {
      spravka,
      lastModified: new Date().toISOString(),
    };
  }

  function upsertInCatalog(catalog, spravka) {
    if (!catalog.spravkas) catalog.spravkas = [];
    const idx = catalog.spravkas.findIndex((s) => s.id === spravka.id);
    if (idx >= 0) catalog.spravkas[idx] = spravka;
    else catalog.spravkas.push(spravka);
    applyCurrentEditable(catalog, spravka);
  }

  function normalizeObjectEntry(obj) {
    return {
      id: obj.id,
      title: obj.title || '',
      subTitle: obj.subTitle || '',
      objectCode: obj.objectCode || '',
      gpLine: obj.gpLine || '',
    };
  }

  function ensureObjectFields(list) {
    return (list || []).map(normalizeObjectEntry);
  }

  function normalizeWorkerRow(row) {
    return {
      id: row.id || AktUtils.uuid(),
      orgId: row.orgId || '',
      orgName: row.orgName || '',
      pbCount: Number.isFinite(Number(row.pbCount)) ? Number(row.pbCount) : 0,
      workersCount: Number.isFinite(Number(row.workersCount)) ? Number(row.workersCount) : 0,
    };
  }

  function workerTotals(rows) {
    const list = rows || [];
    return list.reduce(
      (acc, row) => {
        acc.pb += Number(row.pbCount) || 0;
        acc.workers += Number(row.workersCount) || 0;
        return acc;
      },
      { pb: 0, workers: 0 }
    );
  }

  function toAktShapeForDoc(spravka) {
    return {
      date: spravka.date,
      objectsCheck: ensureObjectFields(spravka.objectsCheck),
      violations: spravka.violations || [],
      description: spravka.remarksRMM || '',
      komissijaVyvody: spravka.conclusion || '',
      subcontractorsList: spravka.subcontractorsList || '',
      workerRows: (spravka.workerRows || []).map(normalizeWorkerRow),
    };
  }

  function formatTitle(spravka) {
    const date = AktUtils.formatDateShort(spravka?.date);
    const objects = (spravka?.objectsCheck || []).map((o) => o.title).filter(Boolean);
    const objLabel = objects.length ? objects[0] : 'без объекта';
    return `Справка от ${date} — ${objLabel}`;
  }

  return {
    isDraft,
    getEditableSpravka,
    createEmpty,
    clone,
    applyCurrentEditable,
    upsertInCatalog,
    ensureObjectFields,
    normalizeObjectEntry,
    normalizeWorkerRow,
    workerTotals,
    toAktShapeForDoc,
    formatTitle,
  };
})();
