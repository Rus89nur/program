/**
 * Хранение фото в IndexedDB (Blob), совместимость с base64 в .gazprombackup.
 */
const PhotoStore = (() => {
  const STORE_PHOTOS = 'photos';
  const ID_PREFIX = 'photo:';

  const dataUrlCache = new Map();

  function isPhotoId(ref) {
    return typeof ref === 'string' && ref.startsWith(ID_PREFIX);
  }

  async function putBlob(id, blob) {
    await GazpromIdb.transaction(STORE_PHOTOS, 'readwrite', (tx) => {
      tx.objectStore(STORE_PHOTOS).put({ blob, mime: blob.type || 'image/jpeg' }, id);
    });
  }

  async function getBlob(id) {
    return GazpromIdb.transaction(STORE_PHOTOS, 'readonly', (tx) =>
      new Promise((resolve, reject) => {
        const req = tx.objectStore(STORE_PHOTOS).get(id);
        req.onsuccess = () => resolve(req.result?.blob || null);
        req.onerror = () => reject(req.error);
      })
    );
  }

  async function deleteBlob(id) {
    await GazpromIdb.transaction(STORE_PHOTOS, 'readwrite', (tx) => {
      tx.objectStore(STORE_PHOTOS).delete(id);
    });
    dataUrlCache.delete(id);
  }

  async function clearAll() {
    try {
      await GazpromIdb.transaction(STORE_PHOTOS, 'readwrite', (tx) => {
        tx.objectStore(STORE_PHOTOS).clear();
      });
    } catch (err) {
      // #region agent log
      if (typeof DebugAgent !== 'undefined') {
        DebugAgent.log('photo-store.js:clearAll', 'clear failed (ignored)', {
          msg: err?.message,
          name: err?.name,
        }, 'D');
      }
      // #endregion
    }
    dataUrlCache.clear();
  }

  function base64ToBlobSync(b64, mime = 'image/jpeg') {
    const raw = b64.includes(',') ? b64.split(',')[1] : b64;
    let bin;
    try {
      bin = atob(raw);
    } catch {
      throw new Error('Некорректные данные фото (base64)');
    }
    const arr = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
    return new Blob([arr], { type: mime });
  }

  async function base64ToBlob(b64, mime = 'image/jpeg') {
    const raw = b64.includes(',') ? b64.split(',')[1] : b64;
    if (raw.length > 3_500_000) {
      const res = await fetch(`data:${mime};base64,${raw}`);
      return res.blob();
    }
    return base64ToBlobSync(b64, mime);
  }

  async function blobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const r = reader.result;
        resolve(typeof r === 'string' && r.includes(',') ? r.split(',')[1] : r);
      };
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  }

  async function ingestPhotoRef(ref) {
    if (!ref || isPhotoId(ref)) return ref;
    try {
      const id = ID_PREFIX + AktUtils.uuid();
      const blob =
        ref instanceof Blob
          ? ref
          : typeof ref === 'string'
            ? await base64ToBlob(ref)
            : await base64ToBlob(String(ref));
      await putBlob(id, blob);
      return id;
    } catch (err) {
      // #region agent log
      if (typeof DebugAgent !== 'undefined') {
        DebugAgent.log('photo-store.js:ingestPhotoRef', 'skip photo', {
          msg: err?.message,
          len: typeof ref === 'string' ? ref.length : 0,
        }, 'D');
      }
      // #endregion
      return null;
    }
  }

  async function resolveDataUrl(ref) {
    if (!ref) return '';
    if (typeof ref === 'string' && ref.startsWith('data:')) return ref;
    if (!isPhotoId(ref)) return AktUtils.photoSrc(ref);
    if (dataUrlCache.has(ref)) return dataUrlCache.get(ref);
    const blob = await getBlob(ref);
    if (!blob) return '';
    const url = URL.createObjectURL(blob);
    dataUrlCache.set(ref, url);
    return url;
  }

  async function expandPhotoRef(ref) {
    if (!ref) return null;
    if (!isPhotoId(ref)) {
      if (typeof ref === 'string' && ref.startsWith('data:')) {
        return ref.includes(',') ? ref.split(',')[1] : ref;
      }
      return ref;
    }
    const blob = await getBlob(ref);
    if (!blob) return null;
    return blobToBase64(blob);
  }

  async function ingestViolationPhotos(violation) {
    if (!violation?.photo?.length) return violation;
    const photo = [];
    for (const p of violation.photo) {
      photo.push(await ingestPhotoRef(p));
    }
    return { ...violation, photo };
  }

  async function expandViolationPhotos(violation) {
    if (!violation?.photo?.length) return violation;
    const photo = [];
    for (const p of violation.photo) {
      const expanded = await expandPhotoRef(p);
      if (expanded) photo.push(expanded);
    }
    return { ...violation, photo };
  }

  async function ingestAkt(akt) {
    if (!akt) return akt;
    const violations = [];
    for (const v of akt.violations || []) {
      violations.push(await ingestViolationPhotos({ ...v }));
    }
    return { ...akt, violations };
  }

  async function expandAkt(akt) {
    if (!akt) return akt;
    const violations = [];
    for (const v of akt.violations || []) {
      violations.push(await expandViolationPhotos({ ...v }));
    }
    return { ...akt, violations };
  }

  const yieldToMain = () => new Promise((resolve) => setTimeout(resolve, 0));

  function countInlinePhotos(catalog) {
    let n = 0;
    const scan = (list) => {
      for (const a of list || []) {
        for (const v of a.violations || []) {
          for (const p of v.photo || []) {
            if (p && !isPhotoId(p)) n += 1;
          }
        }
      }
    };
    scan(catalog.akts);
    scan(catalog.trash);
    if (catalog.editableAkt?.akt) scan([catalog.editableAkt.akt]);
    return n;
  }

  /**
   * Заменяет base64 на photo:id на месте (без копии каталога и без clearAll).
   * Освобождает память перед записью каталога в IndexedDB.
   */
  async function ingestCatalogInPlace(catalog, { onProgress } = {}) {
    if (!catalog) return catalog;

    const photoTotal = countInlinePhotos(catalog);
    let photoDone = 0;

    const processViolationPhotos = async (violation) => {
      if (!violation?.photo?.length) return;
      for (let i = 0; i < violation.photo.length; i += 1) {
        const p = violation.photo[i];
        if (!p || isPhotoId(p)) continue;
        const id = await ingestPhotoRef(p);
        if (id) violation.photo[i] = id;
        else {
          violation.photo.splice(i, 1);
          i -= 1;
        }
        photoDone += 1;
        onProgress?.(photoDone, photoTotal);
        await yieldToMain();
      }
    };

    const processAkt = async (akt) => {
      if (!akt) return;
      for (const v of akt.violations || []) {
        await processViolationPhotos(v);
      }
      await yieldToMain();
    };

    for (const a of catalog.akts || []) await processAkt(a);
    for (const a of catalog.trash || []) await processAkt(a);
    if (catalog.editableAkt?.akt) await processAkt(catalog.editableAkt.akt);

    onProgress?.(photoTotal, photoTotal);
    return catalog;
  }

  async function ingestCatalogChunked(catalog, opts) {
    return ingestCatalogInPlace(catalog, opts);
  }

  async function ingestCatalog(catalog) {
    return ingestCatalogInPlace(catalog);
  }

  async function expandCatalog(catalog) {
    if (!catalog) return catalog;
    const akts = [];
    for (const a of catalog.akts || []) akts.push(await expandAkt(a));
    const trash = [];
    for (const a of catalog.trash || []) trash.push(await expandAkt(a));
    let editableAkt = catalog.editableAkt;
    if (editableAkt?.akt) {
      editableAkt = { ...editableAkt, akt: await expandAkt(editableAkt.akt) };
    }
    return { ...catalog, akts, trash, editableAkt };
  }

  return {
    isPhotoId,
    ingestCatalog,
    ingestCatalogInPlace,
    ingestCatalogChunked,
    countInlinePhotos,
    expandCatalog,
    ingestPhotoRef,
    resolveDataUrl,
    clearAll,
    deleteBlob,
  };
})();
