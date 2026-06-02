/**
 * Хранилище данных веб-версии (IndexedDB).
 * Формат совместим с iOS AppBackup (.gazprombackup).
 */
const GazpromStore = (() => {
  const STORE = 'app';
  const KEY = 'current';

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
      trash: [],
      editableAkt: null,
      editableAktReference: null,
      descriptionTemplates: ['', '', ''],
    };
  }

  async function get() {
    if (cache) return cache;
    const data = await GazpromIdb.transaction(STORE, 'readonly', (tx) =>
      new Promise((resolve, reject) => {
        const req = tx.objectStore(STORE).get(KEY);
        req.onsuccess = () => resolve(req.result || emptyCatalog());
        req.onerror = () => reject(req.error);
      })
    );
    cache = data;
    return cache;
  }

  async function set(data, { skipPhotoIngest = true } = {}) {
    let toSave = data;
    if (!skipPhotoIngest && data && typeof PhotoStore !== 'undefined') {
      toSave = await PhotoStore.ingestCatalog(AktUtils.clone(data));
    }
    await GazpromIdb.transaction(STORE, 'readwrite', (tx) => {
      tx.objectStore(STORE).put(toSave, KEY);
    });
    cache = toSave;
  }

  async function clear() {
    await GazpromIdb.transaction(STORE, 'readwrite', (tx) => {
      tx.objectStore(STORE).delete(KEY);
    });
    if (typeof PhotoStore !== 'undefined') {
      await PhotoStore.clearAll();
    }
    cache = null;
  }

  async function getForExport() {
    const data = await get();
    if (!data || typeof PhotoStore === 'undefined') return data;
    return PhotoStore.expandCatalog(AktUtils.clone(data));
  }

  function hasData(data) {
    if (!data || !Array.isArray(data.akts)) return false;
    return data.akts.length > 0 || !!data.importedAt;
  }

  function invalidateCache() {
    cache = null;
  }

  return { get, set, clear, hasData, invalidateCache, getForExport };
})();
