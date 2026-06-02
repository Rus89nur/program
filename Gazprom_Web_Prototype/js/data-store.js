/**
 * Хранилище данных веб-версии (IndexedDB).
 * Формат совместим с iOS AppBackup (.gazprombackup).
 */
const GazpromStore = (() => {
  const DB_NAME = 'gazprom-web';
  const DB_VERSION = 2;
  const STORE = 'app';
  const KEY = 'current';

  let dbInstance = null;
  let dbPromise = null;
  let cache = null;
  /** Последовательная очередь — без параллельных транзакций (iOS «connection is closing»). */
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

  function runTransaction(storeNames, mode, fn) {
    const names = Array.isArray(storeNames) ? storeNames : [storeNames];

    const attemptOnce = async () => {
      const db = await openDb();
      return new Promise((resolve, reject) => {
        let tx;
        try {
          tx = db.transaction(names, mode);
        } catch (e) {
          reject(e);
          return;
        }
        tx.onerror = () => reject(tx.error);
        tx.onabort = () => reject(tx.error || new Error('Transaction aborted'));
        let settled = false;
        const done = (value) => {
          if (settled) return;
          settled = true;
          resolve(value);
        };
        const fail = (err) => {
          if (settled) return;
          settled = true;
          try {
            tx.abort();
          } catch (_) {
            /* ignore */
          }
          reject(err);
        };
        tx.oncomplete = () => done(undefined);
        try {
          const out = fn(tx, db);
          if (out && typeof out.then === 'function') {
            settled = true;
            tx.oncomplete = null;
            out.then(done, fail);
          }
        } catch (e) {
          fail(e);
        }
      });
    };

    return (async () => {
      for (let i = 0; i < 3; i++) {
        try {
          return await attemptOnce();
        } catch (e) {
          if (isClosingError(e) && i < 2) {
            resetConnection();
            continue;
          }
          throw e;
        }
      }
      throw new Error('IndexedDB недоступна');
    })();
  }

  function enqueue(fn) {
    const job = opChain.then(() => fn());
    opChain = job.catch(() => {});
    return job;
  }

  async function withTransaction(storeNames, mode, fn) {
    return enqueue(() => runTransaction(storeNames, mode, fn));
  }

  async function get() {
    return enqueue(async () => {
      if (cache) return cache;
      const data = await runTransaction(STORE, 'readonly', (tx) =>
        new Promise((resolve, reject) => {
          const req = tx.objectStore(STORE).get(KEY);
          req.onsuccess = () => resolve(req.result || emptyCatalog());
          req.onerror = () => reject(req.error);
        })
      );
      cache = data;
      return cache;
    });
  }

  async function set(data, { skipPhotoIngest = false } = {}) {
    return enqueue(async () => {
      let toSave = data;
      if (!skipPhotoIngest && data && typeof PhotoStore !== 'undefined') {
        toSave = await PhotoStore.ingestCatalog(AktUtils.clone(data));
      }
      await runTransaction(STORE, 'readwrite', (tx) => {
        tx.objectStore(STORE).put(toSave, KEY);
      });
      cache = toSave;
    });
  }

  async function clear() {
    return enqueue(async () => {
      await runTransaction(STORE, 'readwrite', (tx) => {
        tx.objectStore(STORE).delete(KEY);
      });
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
