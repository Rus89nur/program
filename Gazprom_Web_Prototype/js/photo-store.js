/**
 * Хранение фото в IndexedDB (Blob), совместимость с base64 в .gazprombackup.
 */
const PhotoStore = (() => {
  const STORE_PHOTOS = 'photos';
  const ID_PREFIX = 'photo:';
  const MAX_BLOB_BYTES = 900_000;
  const B64_FAST_PATH_MAX_RAW = 480_000;
  const YIELD_EVERY_N_PHOTOS = 12;

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
        await new Promise((r) => setTimeout(r, 40 * (attempt + 1)));
      }
    }
    throw lastErr;
  }

  const canvasToJpeg = (canvas, quality) =>
    new Promise((resolve, reject) => {
      canvas.toBlob(
        (b) => (b ? resolve(b) : reject(new Error('toBlob failed'))),
        'image/jpeg',
        quality
      );
    });

  async function compressBlob(blob, maxBytes = MAX_BLOB_BYTES) {
    if (!blob || blob.size <= maxBytes) return blob;
    if (typeof createImageBitmap !== 'function' || typeof document === 'undefined') {
      return blob;
    }
    let bitmap;
    try {
      bitmap = await createImageBitmap(blob);
      const maxEdge = blob.size > 2_500_000 ? 1280 : 1600;
      const scale = Math.min(1, maxEdge / Math.max(bitmap.width, bitmap.height, 1));
      const w = Math.max(1, Math.round(bitmap.width * scale));
      const h = Math.max(1, Math.round(bitmap.height * scale));
      const canvas = document.createElement('canvas');
      canvas.width = w;
      canvas.height = h;
      const ctx = canvas.getContext('2d');
      if (!ctx) return blob;
      ctx.drawImage(bitmap, 0, 0, w, h);
      if (typeof bitmap.close === 'function') bitmap.close();

      let out = await canvasToJpeg(canvas, 0.78);
      if (out.size <= maxBytes) return out;
      out = await canvasToJpeg(canvas, 0.55);
      return out.size <= maxBytes ? out : await canvasToJpeg(canvas, 0.42);
    } catch {
      if (bitmap && typeof bitmap.close === 'function') bitmap.close();
      return blob;
    }
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
    } catch {
      /* ignore */
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

  async function preparePhotoRecord(ref) {
    const id = ID_PREFIX + AktUtils.uuid();
    const b64 = typeof ref === 'string' ? ref : null;
    const raw = b64 ? (b64.includes(',') ? b64.split(',')[1] : b64) : '';
    const estBytes = Math.floor(raw.length * 0.75);

    if (b64 && estBytes <= MAX_BLOB_BYTES && raw.length <= B64_FAST_PATH_MAX_RAW) {
      return { id, record: { b64: raw, mime: 'image/jpeg' }, mode: 'b64', fallbackB64: b64 };
    }

    const blob =
      ref instanceof Blob ? ref : b64 ? await base64ToBlob(b64) : await base64ToBlob(String(ref));
    const compressed = await compressBlob(blob);
    return {
      id,
      record: { blob: compressed, mime: compressed.type || 'image/jpeg' },
      mode: 'blob',
      fallbackB64: b64,
    };
  }

  async function commitPrepared(prepared) {
    if (!prepared) return { id: null, mode: 'failed' };
    try {
      await putRecordWithRetry(prepared.id, prepared.record);
      return { id: prepared.id, mode: prepared.mode };
    } catch (blobErr) {
      if (!prepared.fallbackB64) {
        return { id: null, mode: 'failed' };
      }
      if (typeof GazpromIdb.resetConnection === 'function') GazpromIdb.resetConnection();
      try {
        await putB64Record(prepared.id, prepared.fallbackB64);
        return { id: prepared.id, mode: 'b64' };
      } catch {
        return { id: null, mode: 'failed' };
      }
    }
  }

  async function ingestPhotoRef(ref) {
    if (!ref || isPhotoId(ref)) return { id: ref, mode: 'existing' };
    const prepared = await preparePhotoRecord(ref);
    return commitPrepared(prepared);
  }

  function collectPhotoTasks(catalog) {
    const tasks = [];
    const scan = (list) => {
      for (const a of list || []) {
        for (const v of a.violations || []) {
          if (!v?.photo?.length) continue;
          for (let i = 0; i < v.photo.length; i += 1) {
            const p = v.photo[i];
            if (p && !isPhotoId(p)) tasks.push({ violation: v, index: i, ref: p });
          }
        }
      }
    };
    scan(catalog.akts);
    scan(catalog.trash);
    if (catalog.editableAkt?.akt) scan([catalog.editableAkt.akt]);
    return tasks;
  }

  const IMG_PLACEHOLDER =
    'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

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

    const tasks = collectPhotoTasks(catalog);
    const stats = { total: tasks.length, blob: 0, b64: 0, failed: 0 };
    const t0 = Date.now();

    if (tasks.length === 0) {
      catalog.photoIngestStats = stats;
      lastIngestStats = stats;
      return catalog;
    }

    let upcoming = preparePhotoRecord(tasks[0].ref);
    for (let t = 0; t < tasks.length; t += 1) {
      const task = tasks[t];
      const prepared = await upcoming;
      if (t + 1 < tasks.length) {
        upcoming = preparePhotoRecord(tasks[t + 1].ref);
      }

      const result = await commitPrepared(prepared);
      if (result.id) {
        task.violation.photo[task.index] = result.id;
        if (result.mode === 'blob') stats.blob += 1;
        else if (result.mode === 'b64') stats.b64 += 1;
      } else {
        stats.failed += 1;
      }

      onProgress?.(t + 1, tasks.length);
      if ((t + 1) % YIELD_EVERY_N_PHOTOS === 0) await yieldToMain();
    }

    stats.ms = Date.now() - t0;
    catalog.photoIngestStats = stats;
    lastIngestStats = stats;

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

  const HYDRATE_CONCURRENCY = 8;

  async function hydrateImages(root) {
    if (!root) return;
    const imgs = [...root.querySelectorAll('img[data-photo-ref]')];
    if (!imgs.length) return;

    let cursor = 0;
    const worker = async () => {
      while (cursor < imgs.length) {
        const img = imgs[cursor];
        cursor += 1;
        const ref = img.dataset.photoRef;
        if (!ref || img.dataset.photoHydrated === '1') continue;
        const url = (await resolveDataUrl(ref)) || AktUtils.photoSrc(ref);
        if (!url || !img.isConnected) continue;
        img.src = url;
        img.dataset.photoHydrated = '1';
      }
    };

    await Promise.all(
      Array.from({ length: Math.min(HYDRATE_CONCURRENCY, imgs.length) }, () => worker())
    );
  }

  return {
    isPhotoId,
    IMG_PLACEHOLDER,
    ingestCatalog,
    ingestCatalogInPlace,
    ingestCatalogChunked,
    countInlinePhotos,
    countStoredPhotoIds,
    getLastIngestStats,
    expandCatalog,
    ingestPhotoRef,
    resolveDataUrl,
    hydrateImages,
    clearAll,
    deleteBlob,
  };
})();
