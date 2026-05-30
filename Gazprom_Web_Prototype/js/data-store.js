/**
 * Хранилище данных веб-версии (IndexedDB).
 * Формат совместим с iOS AppBackup (.gazprombackup).
 */
const GazpromStore = (() => {
  const DB_NAME = 'gazprom-web';
  const DB_VERSION = 2;
  const STORE = 'app';
  const KEY = 'current';

  let dbPromise = null;
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
      trash: [],
      editableAkt: null,
      editableAktReference: null,
    };
  }

  function openDb() {
    if (dbPromise) return dbPromise;
    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onerror = () => reject(req.error);
      req.onsuccess = () => resolve(req.result);
      req.onupgradeneeded = (e) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains(STORE)) {
          db.createObjectStore(STORE);
        }
        if (!db.objectStoreNames.contains('photos')) {
          db.createObjectStore('photos');
        }
      };
    });
    return dbPromise;
  }

  async function get() {
    if (cache) return cache;
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, 'readonly');
      const req = tx.objectStore(STORE).get(KEY);
      req.onsuccess = () => {
        cache = req.result || emptyCatalog();
        resolve(cache);
      };
      req.onerror = () => reject(req.error);
    });
  }

  async function set(data, { skipPhotoIngest = false } = {}) {
    let toSave = data;
    if (!skipPhotoIngest && data && typeof PhotoStore !== 'undefined') {
      toSave = await PhotoStore.ingestCatalog(AktUtils.clone(data));
    }
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, 'readwrite');
      tx.objectStore(STORE).put(toSave, KEY);
      tx.oncomplete = () => {
        cache = toSave;
        resolve();
      };
      tx.onerror = () => reject(tx.error);
    });
  }

  async function clear() {
    const db = await openDb();
    await new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, 'readwrite');
      tx.objectStore(STORE).delete(KEY);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
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
    return data && Array.isArray(data.akts);
  }

  function invalidateCache() {
    cache = null;
  }

  return { get, set, clear, hasData, invalidateCache, getForExport };
})();
