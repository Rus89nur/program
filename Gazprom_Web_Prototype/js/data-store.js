/**
 * Хранилище данных веб-версии (IndexedDB).
 * Формат совместим с iOS AppBackup (.gazprombackup).
 */
const GazpromStore = (() => {
  const DB_NAME = 'gazprom-web';
  const DB_VERSION = 2;
  const STORE = 'app';
  const KEY = 'current';
  const SET_TIMEOUT_MS = 120000;

  let dbInstance = null;
  let dbPromise = null;
  let cache = null;
  let queueDepth = 0;
  let opChain = Promise.resolve();

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

  function isClosingError(err) {
    const msg = String(err?.message || err || '');
    return err?.name === 'InvalidStateError' || /closing|closed|abort/i.test(msg);
  }

  function resetConnection() {
    dbPromise = null;
    if (!dbInstance) return;
    dbInstance.onclose = null;
    dbInstance.onversionchange = null;
    try {
      dbInstance.close();
    } catch (_) {
      /* ignore */
    }
    dbInstance = null;
  }

  function openDb() {
    if (dbPromise) return dbPromise;
    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onerror = () => {
        dbPromise = null;
        reject(req.error);
      };
      req.onupgradeneeded = (e) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains(STORE)) {
          db.createObjectStore(STORE);
        }
        if (!db.objectStoreNames.contains('photos')) {
          db.createObjectStore('photos');
        }
      };
      req.onsuccess = () => {
        dbInstance = req.result;
        dbInstance.onclose = () => resetConnection();
        dbInstance.onversionchange = () => resetConnection();
        resolve(dbInstance);
      };
    });
    return dbPromise;
  }

  function idbRequest(req) {
    return new Promise((resolve, reject) => {
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  async function runTransaction(storeNames, mode, fn) {
    const names = Array.isArray(storeNames) ? storeNames : [storeNames];
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const db = await openDb();
        return await new Promise((resolve, reject) => {
          let tx;
          try {
            tx = db.transaction(names, mode);
          } catch (e) {
            reject(e);
            return;
          }
          tx.onerror = () => reject(tx.error);
          tx.onabort = () => reject(tx.error || new Error('Transaction aborted'));
          tx.oncomplete = () => resolve();
          try {
            const out = fn(tx);
            if (out && typeof out.then === 'function') {
              out.catch((e) => {
                try {
                  tx.abort();
                } catch (_) {
                  /* ignore */
                }
                reject(e);
              });
            }
          } catch (e) {
            reject(e);
          }
        });
      } catch (e) {
        if (isClosingError(e) && attempt < 2) {
          resetConnection();
          continue;
        }
        throw e;
      }
    }
    throw new Error('IndexedDB недоступна');
  }

  function enqueue(fn) {
    const job = opChain.then(async () => {
      queueDepth += 1;
      try {
        return await fn();
      } finally {
        queueDepth -= 1;
      }
    });
    opChain = job.catch(() => {});
    return job;
  }

  async function withTransaction(storeNames, mode, fn) {
    if (queueDepth > 0) {
      return runTransaction(storeNames, mode, fn);
    }
    return enqueue(() => runTransaction(storeNames, mode, fn));
  }

  async function get() {
    return enqueue(async () => {
      if (cache) return cache;
      await runTransaction(STORE, 'readonly', (tx) => {
        return idbRequest(tx.objectStore(STORE).get(KEY)).then(
          (val) => {
            cache = val || emptyCatalog();
          }
        );
      });
      return cache;
    });
  }

  async function set(data, { skipPhotoIngest = false } = {}) {
    return enqueue(async () => {
      const work = async () => {
        let toSave = data;
        if (!skipPhotoIngest && data && typeof PhotoStore !== 'undefined') {
          toSave = await PhotoStore.ingestCatalog(AktUtils.clone(data));
        }
        await runTransaction(STORE, 'readwrite', (tx) =>
          idbRequest(tx.objectStore(STORE).put(toSave, KEY))
        );
        cache = toSave;
      };

      let timer;
      const timeout = new Promise((_, reject) => {
        timer = setTimeout(
          () => reject(new Error('Сохранение заняло слишком много времени. Попробуйте снова или «Вставить текст».')),
          SET_TIMEOUT_MS
        );
      });

      try {
        await Promise.race([work(), timeout]);
      } finally {
        clearTimeout(timer);
      }
    });
  }

  async function clear() {
    return enqueue(async () => {
      await runTransaction(STORE, 'readwrite', (tx) =>
        idbRequest(tx.objectStore(STORE).delete(KEY))
      );
      if (typeof PhotoStore !== 'undefined') {
        await PhotoStore.clearAll();
      }
      cache = null;
    });
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

  return {
    get,
    set,
    clear,
    hasData,
    invalidateCache,
    getForExport,
    withTransaction,
  };
})();
