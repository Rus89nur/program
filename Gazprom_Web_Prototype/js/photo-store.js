/**
 * Хранение фото в IndexedDB (Blob), совместимость с base64 в .gazprombackup.
 */
const PhotoStore = (() => {
  const DB_NAME = 'gazprom-web';
  const DB_VERSION = 2;
  const STORE_PHOTOS = 'photos';
  const ID_PREFIX = 'photo:';

  const dataUrlCache = new Map();

  function isPhotoId(ref) {
    return typeof ref === 'string' && ref.startsWith(ID_PREFIX);
  }

  async function putBlob(id, blob) {
    await GazpromStore.withTransaction(STORE_PHOTOS, 'readwrite', (tx) => {
      tx.objectStore(STORE_PHOTOS).put({ blob, mime: blob.type || 'image/jpeg' }, id);
    });
  }

  async function getBlob(id) {
    const row = await GazpromStore.withTransaction(STORE_PHOTOS, 'readonly', (tx) =>
      new Promise((resolve, reject) => {
        const req = tx.objectStore(STORE_PHOTOS).get(id);
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error);
      })
    );
    return row?.blob || null;
  }

  async function deleteBlob(id) {
    await GazpromStore.withTransaction(STORE_PHOTOS, 'readwrite', (tx) => {
      tx.objectStore(STORE_PHOTOS).delete(id);
    });
    dataUrlCache.delete(id);
  }

  async function clearAll() {
    await GazpromStore.withTransaction(STORE_PHOTOS, 'readwrite', (tx) => {
      tx.objectStore(STORE_PHOTOS).clear();
    });
    dataUrlCache.clear();
  }

  function base64ToBlob(b64, mime = 'image/jpeg') {
    const raw = b64.includes(',') ? b64.split(',')[1] : b64;
    const bin = atob(raw);
    const arr = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
    return new Blob([arr], { type: mime });
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
    const id = ID_PREFIX + AktUtils.uuid();
    const blob = typeof ref === 'string' ? base64ToBlob(ref) : ref;
    await putBlob(id, blob instanceof Blob ? blob : base64ToBlob(String(ref)));
    return id;
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

  async function ingestCatalog(catalog) {
    if (!catalog) return catalog;
    const akts = [];
    for (const a of catalog.akts || []) akts.push(await ingestAkt(a));
    const trash = [];
    for (const a of catalog.trash || []) trash.push(await ingestAkt(a));
    let editableAkt = catalog.editableAkt;
    if (editableAkt?.akt) {
      editableAkt = { ...editableAkt, akt: await ingestAkt(editableAkt.akt) };
    }
    return { ...catalog, akts, trash, editableAkt };
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
    expandCatalog,
    ingestPhotoRef,
    resolveDataUrl,
    clearAll,
    deleteBlob,
  };
})();
