/**
 * Хранилище данных веб-версии (IndexedDB).
 * Формат совместим с iOS AppBackup (.gazprombackup).
 */
const GazpromStore = (() => {
  const STORE = 'app';
  const KEY = 'current';
  /** Лёгкий черновик мастера — без перезаписи всего каталога с сотнями фото. */
  const DRAFT_KEY = 'wizardDraft';

  let cache = null;

  function emptyCatalog() {
    return {
      akts: [],
      comissionPeople: [],
      organizations: [],
      objects: [],
      predstavitely: [],
      scheduleItems: [],
      violationEliminations: [],
      violationRegistry: [],
      violationTypes: [],
      typeMappings: {},
      dismissedMappingSeeds: [],
      trash: [],
      editableAkt: null,
      editableAktReference: null,
      descriptionTemplates: ['', '', ''],
    };
  }

  function mergeWizardDraft(catalog, draftRec) {
    if (!draftRec?.akt) return catalog;
    const akt = draftRec.akt;
    if (typeof AktUtils !== 'undefined' && AktUtils.isShortFormat(akt)) return catalog;
    const out = { ...catalog, akts: [...(catalog.akts || [])] };
    out.editableAkt = {
      akt,
      isEditable: true,
      lastModified: draftRec.lastModified || new Date().toISOString(),
    };
    if (draftRec.reference) out.editableAktReference = draftRec.reference;
    const idx = out.akts.findIndex((a) => a.id === akt.id);
    if (idx >= 0) out.akts[idx] = akt;
    else out.akts.push(akt);
    return out;
  }

  async function readCatalogFromDb() {
    return GazpromIdb.transaction(STORE, 'readonly', (tx) =>
      new Promise((resolve, reject) => {
        const store = tx.objectStore(STORE);
        const mainReq = store.get(KEY);
        const draftReq = store.get(DRAFT_KEY);
        let main = null;
        let draftRec = null;
        let pending = 2;
        const finish = () => {
          pending -= 1;
          if (pending > 0) return;
          resolve(mergeWizardDraft(main || emptyCatalog(), draftRec));
        };
        mainReq.onsuccess = () => {
          main = mainReq.result;
          finish();
        };
        mainReq.onerror = () => reject(mainReq.error);
        draftReq.onsuccess = () => {
          draftRec = draftReq.result;
          finish();
        };
        draftReq.onerror = () => reject(draftReq.error);
      })
    );
  }

  async function attachWordTemplateSidecar(catalog) {
    if (!catalog?.wordTemplateOffloaded) return catalog;
    try {
      const sidecar = await GazpromIdb.transaction('app', 'readonly', (tx) =>
        new Promise((resolve, reject) => {
          const req = tx.objectStore('app').get('wordTemplateSidecar');
          req.onsuccess = () => resolve(req.result);
          req.onerror = () => reject(req.error);
        })
      );
      if (sidecar?.data) {
        catalog.wordTemplate = sidecar.data;
        catalog.wordTemplateName = sidecar.name || catalog.wordTemplateName;
      }
    } catch {
      /* ignore */
    }
    return catalog;
  }

  async function get() {
    if (cache) return cache;
    cache = await readCatalogFromDb();
    cache = await attachWordTemplateSidecar(cache);
    return cache;
  }

  async function set(data, { skipPhotoIngest = true, verifyWrite = false } = {}) {
    let toSave = data;
    if (!skipPhotoIngest && data && typeof PhotoStore !== 'undefined') {
      toSave = await PhotoStore.ingestCatalog(AktUtils.clone(data));
    }
    try {
      await GazpromIdb.transaction(STORE, 'readwrite', (tx) => {
        tx.objectStore(STORE).put(toSave, KEY);
        tx.objectStore(STORE).delete(DRAFT_KEY);
      });
    } catch (putErr) {
      throw putErr;
    }
    cache = toSave;

    if (!verifyWrite) return;

    invalidateCache();
    const fromDb = await readCatalogFromDb();
    const verified = verifyCatalogWrite(toSave, fromDb);
    if (!verified) {
      cache = null;
      throw new Error(
        'Данные не сохранились в браузере после импорта. На iPhone: выйдите из режима «частная сессия», освободите память или используйте «Вставить текст» для небольшой копии.'
      );
    }
    cache = fromDb;
  }

  /** Быстрое сохранение только текущего черновика акта (для мастера на телефоне). */
  async function saveWizardDraft(akt, reference = null) {
    const record = {
      akt,
      lastModified: new Date().toISOString(),
      reference,
    };
    await GazpromIdb.transaction(STORE, 'readwrite', (tx) => {
      tx.objectStore(STORE).put(record, DRAFT_KEY);
    });
    if (cache) {
      cache = mergeWizardDraft(cache, record);
    }
  }

  /** Полная запись каталога (импорт, справочники, завершение акта). */
  async function persistCatalog(data, opts = {}) {
    await set(data ?? (await get()), opts);
  }

  async function clear() {
    await GazpromIdb.transaction(STORE, 'readwrite', (tx) => {
      tx.objectStore(STORE).delete(KEY);
      tx.objectStore(STORE).delete(DRAFT_KEY);
    });
    if (typeof PhotoStore !== 'undefined') {
      await PhotoStore.clearAll();
    }
    const empty = emptyCatalog();
    await GazpromIdb.transaction(STORE, 'readwrite', (tx) => {
      tx.objectStore(STORE).put(empty, KEY);
    });
    cache = empty;
  }

  async function getForExport() {
    const data = await get();
    if (!data || typeof PhotoStore === 'undefined') return data;
    return PhotoStore.expandCatalog(AktUtils.clone(data));
  }

  /** Есть сохранённые акты или метка импорта бэкапа (для merge/отчётов). */
  function hasData(data) {
    if (!data || !Array.isArray(data.akts)) return false;
    return data.akts.length > 0 || !!data.importedAt || !!data.timestamp || !!data.sourceFileName;
  }

  /** Каталог инициализирован (можно открыть мастер с пустыми справочниками). */
  function isReady(data) {
    return Boolean(data && Array.isArray(data.akts));
  }

  function updateCache(data) {
    cache = data;
  }

  function invalidateCache() {
    cache = null;
  }

  /** Запросить у браузера постоянное хранилище (важно для iOS Safari). */
  async function requestPersistence() {
    if (!navigator.storage?.persist) return false;
    try {
      return await navigator.storage.persist();
    } catch {
      return false;
    }
  }

  /** Сбросить кэш в IndexedDB перед закрытием вкладки. */
  async function flushToDisk() {
    if (!cache) return;
    await set(cache, { skipPhotoIngest: true });
  }

  function catalogFingerprint(data) {
    if (!data) return '';
    return [
      (data.akts || []).length,
      (data.organizations || []).length,
      data.importedAt || '',
      data.timestamp || '',
      data.sourceFileName || '',
    ].join('|');
  }

  function verifyCatalogWrite(expected, actual) {
    if (!actual || !Array.isArray(actual.akts)) return false;
    if (hasData(expected) && !hasData(actual)) return false;
    if (expected.importedWithoutPhotos || expected.mobileStrippedTemplate) {
      return (expected.akts || []).length === (actual.akts || []).length;
    }
    return catalogFingerprint(expected) === catalogFingerprint(actual);
  }

  return {
    get,
    set,
    saveWizardDraft,
    persistCatalog,
    clear,
    hasData,
    isReady,
    updateCache,
    invalidateCache,
    getForExport,
    requestPersistence,
    flushToDisk,
  };
})();
