/**
 * Одно подключение к IndexedDB + очередь всех операций (iOS Safari падает при параллельных tx).
 */
const GazpromIdb = (() => {
  const DB_NAME = 'gazprom-web';
  const DB_VERSION = 2;
  let dbInstance = null;
  let dbPromise = null;
  let opChain = Promise.resolve();

  function resetConnection() {
    dbInstance = null;
    dbPromise = null;
  }

  function isClosingError(err) {
    const msg = String(err?.message || err);
    return /closing|abort|terminated|invalid state/i.test(msg);
  }

  function attachDb(db) {
    db.onversionchange = () => {
      db.close();
      resetConnection();
    };
    db.onclose = () => resetConnection();
    dbInstance = db;
    return db;
  }

  async function ensureDb() {
    if (dbInstance) return dbInstance;
    if (!dbPromise) {
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
        req.onsuccess = () => resolve(attachDb(req.result));
      });
    }
    try {
      return await dbPromise;
    } catch (err) {
      resetConnection();
      throw err;
    }
  }

  function enqueue(fn) {
    const run = async () => {
      let lastErr;
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          const db = await ensureDb();
          return await fn(db);
        } catch (err) {
          lastErr = err;
          if (!isClosingError(err) || attempt >= 2) throw err;
          resetConnection();
          await new Promise((r) => setTimeout(r, 40 * (attempt + 1)));
        }
      }
      throw lastErr;
    };
    const result = opChain.then(run, run);
    opChain = result.catch(() => {});
    return result;
  }

  function transaction(storeNames, mode, callback) {
    const stores = Array.isArray(storeNames) ? storeNames : [storeNames];
    return enqueue(
      (db) =>
        new Promise((resolve, reject) => {
          try {
            const tx = db.transaction(stores, mode);
            const txResult = callback(tx);
            tx.oncomplete = () => resolve(txResult);
            tx.onerror = () => reject(tx.error);
            tx.onabort = () => reject(tx.error || new Error('Transaction aborted'));
          } catch (err) {
            reject(err);
          }
        })
    );
  }

  return { transaction, resetConnection, DB_NAME, DB_VERSION };
})();
