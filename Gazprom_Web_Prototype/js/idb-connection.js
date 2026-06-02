/**
 * Одно подключение к IndexedDB + очередь записей (iOS Safari падает при параллельных tx).
 */
const GazpromIdb = (() => {
  const DB_NAME = 'gazprom-web';
  const DB_VERSION = 2;
  let dbPromise = null;
  let writeChain = Promise.resolve();

  function resetConnection() {
    dbPromise = null;
  }

  function isClosingError(err) {
    const msg = String(err?.message || err);
    return /closing|abort|terminated/i.test(msg);
  }

  function openDb() {
    if (dbPromise) return dbPromise;
    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onerror = () => {
        resetConnection();
        reject(req.error);
      };
      req.onupgradeneeded = (e) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains('app')) db.createObjectStore('app');
        if (!db.objectStoreNames.contains('photos')) db.createObjectStore('photos');
      };
      req.onsuccess = () => {
        const db = req.result;
        db.onversionchange = () => {
          db.close();
          resetConnection();
        };
        db.onclose = () => resetConnection();
        resolve(db);
      };
    });
    return dbPromise;
  }

  async function withDb(fn, { allowRetry = true } = {}) {
    try {
      return await fn(await openDb());
    } catch (err) {
      if (allowRetry && isClosingError(err)) {
        resetConnection();
        return withDb(fn, { allowRetry: false });
      }
      throw err;
    }
  }

  function transaction(storeNames, mode, callback) {
    const stores = Array.isArray(storeNames) ? storeNames : [storeNames];
    const run = (db) =>
      new Promise((resolve, reject) => {
        let txResult;
        try {
          const tx = db.transaction(stores, mode);
          txResult = callback(tx);
          tx.oncomplete = () => resolve(txResult);
          tx.onerror = () => reject(tx.error);
          tx.onabort = () => reject(tx.error || new Error('Transaction aborted'));
        } catch (err) {
          reject(err);
        }
      });

    if (mode === 'readonly') return withDb(run);
    const op = writeChain.then(() => withDb(run), () => withDb(run));
    writeChain = op.catch(() => {});
    return op;
  }

  return { transaction, resetConnection, DB_NAME, DB_VERSION };
})();
