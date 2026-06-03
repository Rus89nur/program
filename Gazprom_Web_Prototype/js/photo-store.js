/**
 * Хранение фото в IndexedDB (Blob), совместимость с base64 в .gazprombackup.
 */
const PhotoStore = (() => {
  const STORE_PHOTOS = 'photos';
  const ID_PREFIX = 'photo:';
  const MAX_BLOB_BYTES = 900_000;

  const dataUrlCache = new Map();
  let lastIngestStats = null;

  function isPhotoId(ref) {
    return typeof ref === 'string' && ref.startsWith(ID_PREFIX);
  }

  const yieldToMain = () => new Promise((resolve) => setTimeout(resolve, 0));

  async function getPhotoRecord(id) {
    return GazpromIdb.transaction(STORE_PHOTOS, 'readonly', (tx) =>
      new Promise((resolve, reject) => {
        const req = tx.objectStore(STORE_PHOTOS).get(id);
        req.onsuccess = () => resolve(req.result || null);
        req.onerror = () => reject(req.error);
      })
    );
  }

  async function putRecordWithRetry(id, record) {
    let lastErr;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        await GazpromIdb.transaction(STORE_PHOTOS, 'readwrite', (tx) => {
          tx.objectStore(STORE_PHOTOS).put(record, id);
        });
        return;
      } catch (err) {
        lastErr = err;
        if (typeof GazpromIdb.resetConnection === 'function') {
          GazpromIdb.resetConnection();
        }
        await new Promise((r) => setTimeout(r, 100 * (attempt + 1)));
      }
    }
    throw lastErr;
  }

  async function compressBlob(blob, maxBytes = MAX_BLOB_BYTES) {
    if (!blob || blob.size <= maxBytes) return blob;
    if (typeof createImageBitmap !== 'function' || typeof document === 'undefined') {
      return blob;
    }
    let bitmap;
    try {
      bitmap = await createImageBitmap(blob);
      const scale = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height, 1));
      const w = Math.max(1, Math.round(bitmap.width * scale));
      const h = Math.max(1, Math.round(bitmap.height * scale));
      const canvas = document.createElement('canvas');
      canvas.width = w;
      canvas.height = h;
      const ctx = canvas.getContext('2d');
      if (!ctx) return blob;
      ctx.drawImage(bitmap, 0, 0, w, h);
      if (typeof bitmap.close === 'function') bitmap.close();
      const qualities = [0.85, 0.72, 0.58, 0.45];
      for (const q of qualities) {
        const out = await new Promise((resolve, reject) => {
          canvas.toBlob(
            (b) => (b ? resolve(b) : reject(new Error('toBlob failed'))),
            'image/jpeg',
            q
          );
        });
        if (out.size <= maxBytes) return out;
      }
      return await new Promise((resolve, reject) => {
        canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('toBlob failed'))), 'image/jpeg', 0.4);
      });
    } catch {
      if (bitmap && typeof bitmap.close === 'function') bitmap.close();
      return blob;
    }
  }

  async function putBlob(id, blob) {
    const compressed = await compressBlob(blob);
    await putRecordWithRetry(id, { blob: compressed, mime: compressed.type || 'image/jpeg' });
  }

  async function putB64Record(id, b64) {
    const raw = String(b64).includes(',') ? String(b64).split(',')[1] : String(b64);
    await putRecordWithRetry(id, { b64: raw, mime: 'image/jpeg' });
  }

  async function getBlob(id) {
    const rec = await getPhotoRecord(id);
    return rec?.blob || null;
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
    const bin = atob(raw);
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
    if (!ref || isPhotoId(ref)) return { id: ref, mode: 'existing' };

    const id = ID_PREFIX + AktUtils.uuid();
    const b64 = typeof ref === 'string' ? ref : null;

    try {
      const blob =
        ref instanceof Blob ? ref : b64 ? await base64ToBlob(b64) : await base64ToBlob(String(ref));
      await putBlob(id, blob);
      return { id, mode: 'blob' };
    } catch (blobErr) {
      if (!b64) {
        // #region agent log
        if (typeof DebugAgent !== 'undefined') {
          DebugAgent.log('photo-store.js:ingestPhotoRef', 'failed no b64', {
            msg: blobErr?.message,
          }, 'D');
        }
        // #endregion
        return { id: null, mode: 'failed' };
      }
      try {
        if (typeof GazpromIdb.resetConnection === 'function') GazpromIdb.resetConnection();
        await yieldToMain();
        await putB64Record(id, b64);
        return { id, mode: 'b64' };
      } catch (b64Err) {
        // #region agent log
        if (typeof DebugAgent !== 'undefined') {
          DebugAgent.log('photo-store.js:ingestPhotoRef', 'blob and b64 failed', {
            blobMsg: blobErr?.message,
            b64Msg: b64Err?.message,
            len: b64.length,
          }, 'D');
        }
        // #endregion
        return { id: null, mode: 'failed' };
      }
    }
  }

  async function resolveDataUrl(ref) {
    if (!ref) return '';
    if (typeof ref === 'string' && ref.startsWith('data:')) return ref;
    if (!isPhotoId(ref)) return AktUtils.photoSrc(ref);
    if (dataUrlCache.has(ref)) return dataUrlCache.get(ref);

    const rec = await getPhotoRecord(ref);
    if (rec?.b64) {
      const url = `data:image/jpeg;base64,${rec.b64}`;
      dataUrlCache.set(ref, url);
      return url;
    }
    const blob = rec?.blob || null;
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
    const rec = await getPhotoRecord(ref);
    if (rec?.b64) return rec.b64;
    const blob = rec?.blob || null;
    if (!blob) return null;
    return blobToBase64(blob);
  }

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

  function countStoredPhotoIds(catalog) {
    let n = 0;
    const scan = (list) => {
      for (const a of list || []) {
        for (const v of a.violations || []) {
          for (const p of v.photo || []) {
            if (isPhotoId(p)) n += 1;
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
   * Заменяет base64 на photo:id на месте; при сбое blob пробует b64 в IDB.
   */
  async function ingestCatalogInPlace(catalog, { onProgress } = {}) {
    if (!catalog) return catalog;

    const photoTotal = countInlinePhotos(catalog);
    const stats = { total: photoTotal, blob: 0, b64: 0, failed: 0 };
    let photoDone = 0;
    const isMobile = window.matchMedia('(pointer: coarse)').matches;

    const processViolationPhotos = async (violation) => {
      if (!violation?.photo?.length) return;
      for (let i = 0; i < violation.photo.length; i += 1) {
        const p = violation.photo[i];
        if (!p || isPhotoId(p)) continue;

        const result = await ingestPhotoRef(p);
        if (result.id) {
          violation.photo[i] = result.id;
          if (result.mode === 'blob') stats.blob += 1;
          else if (result.mode === 'b64') stats.b64 += 1;
        } else {
          stats.failed += 1;
        }

        photoDone += 1;
        onProgress?.(photoDone, photoTotal);
        if (isMobile) await new Promise((r) => setTimeout(r, 50));
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

    catalog.photoIngestStats = stats;
    lastIngestStats = stats;
    onProgress?.(photoTotal, photoTotal);

    // #region agent log
    if (typeof DebugAgent !== 'undefined') {
      DebugAgent.log('photo-store.js:ingestCatalogInPlace', 'stats', stats, 'C');
    }
    // #endregion

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

  async function ingestViolationPhotos(violation) {
    if (!violation?.photo?.length) return violation;
    const photo = [];
    for (const p of violation.photo) {
      const r = await ingestPhotoRef(p);
      if (r.id) photo.push(r.id);
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

  function getLastIngestStats() {
    return lastIngestStats;
  }

  return {
    isPhotoId,
    ingestCatalog,
    ingestCatalogInPlace,
    ingestCatalogChunked,
    countInlinePhotos,
    countStoredPhotoIds,
    getLastIngestStats,
    expandCatalog,
    ingestPhotoRef,
    resolveDataUrl,
    clearAll,
    deleteBlob,
  };
})();
