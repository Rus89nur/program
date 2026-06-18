/**
 * ML по фотографиям нарушений — порт iOS ViolationImageMLService.
 * Признаки: 32×32 grayscale (аналог fallback Vision на iOS).
 */
const MlImageService = (() => {
  const STORE_SAMPLES = 'mlSamples';
  const META_KEY = 'mlTrainingMeta';
  const FEATURE_SIDE = 32;
  const DISTANCE_EPSILON_SAME = 0.5;
  const DISTANCE_THRESHOLD_UNKNOWN = 3.0;
  const MAX_CONFIDENCE_UNKNOWN = 0.7;
  const MAX_ACCURACY_SAMPLES = 500;

  let entriesCache = null;
  let centroidCache = null;

  function uuid() {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }

  function distanceBetween(f1, f2) {
    const a = f1 instanceof Float32Array ? f1 : new Float32Array(f1);
    const b = f2 instanceof Float32Array ? f2 : new Float32Array(f2);
    const count = Math.min(a.length, b.length);
    if (!count) return Number.POSITIVE_INFINITY;
    let sumSq = 0;
    for (let i = 0; i < count; i += 1) {
      const d = a[i] - b[i];
      sumSq += d * d;
    }
    return Math.sqrt(sumSq);
  }

  function distanceToConfidence(distance) {
    const sigma = 10;
    return 1 / (1 + distance / sigma);
  }

  function averageFeatureVectors(vectors) {
    if (!vectors.length) return null;
    const first = vectors[0] instanceof Float32Array ? vectors[0] : new Float32Array(vectors[0]);
    const count = first.length;
    const sum = new Float32Array(count);
    vectors.forEach((vec) => {
      const v = vec instanceof Float32Array ? vec : new Float32Array(vec);
      for (let i = 0; i < count; i += 1) sum[i] += v[i];
    });
    const n = vectors.length;
    for (let i = 0; i < count; i += 1) sum[i] /= n;
    return sum;
  }

  function serializeFeature(feature) {
    return Array.from(feature instanceof Float32Array ? feature : new Float32Array(feature));
  }

  function deserializeFeature(arr) {
    return new Float32Array(arr);
  }

  async function sha256Hex(data) {
    if (typeof crypto === 'undefined' || !crypto.subtle) {
      let h = 0;
      for (let i = 0; i < data.length; i += 1) h = (h * 31 + data.charCodeAt(i)) | 0;
      return String(h);
    }
    const buf = typeof data === 'string' ? new TextEncoder().encode(data) : data;
    const hash = await crypto.subtle.digest('SHA-256', buf);
    return Array.from(new Uint8Array(hash))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
  }

  async function blobToArrayBuffer(blob) {
    if (blob instanceof ArrayBuffer) return blob;
    if (blob?.arrayBuffer) return blob.arrayBuffer();
    return new Response(blob).arrayBuffer();
  }

  async function extractFeatureFromDataUrl(dataUrl) {
    if (typeof document === 'undefined') return null;
    return new Promise((resolve) => {
      const img = new Image();
      img.onload = () => {
        try {
          const canvas = document.createElement('canvas');
          canvas.width = FEATURE_SIDE;
          canvas.height = FEATURE_SIDE;
          const ctx = canvas.getContext('2d', { willReadFrequently: true });
          if (!ctx) {
            resolve(null);
            return;
          }
          ctx.drawImage(img, 0, 0, FEATURE_SIDE, FEATURE_SIDE);
          const { data } = ctx.getImageData(0, 0, FEATURE_SIDE, FEATURE_SIDE);
          const out = new Float32Array(FEATURE_SIDE * FEATURE_SIDE);
          for (let i = 0, p = 0; i < data.length; i += 4, p += 1) {
            out[p] = (0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2]) / 255;
          }
          resolve(out);
        } catch (_) {
          resolve(null);
        }
      };
      img.onerror = () => resolve(null);
      img.src = dataUrl;
    });
  }

  function normalizePhotoRef(ref) {
    if (!ref) return null;
    if (typeof ref === 'string') return ref;
    if (typeof ref === 'object' && ref.id) return String(ref.id);
    return null;
  }

  async function ensurePhotoRef(ref, dataUrl) {
    const normalized = normalizePhotoRef(ref);
    if (normalized?.startsWith('photo:')) return normalized;
    const ingestSource = dataUrl || normalized;
    if (!ingestSource) return null;
    if (typeof PhotoStore !== 'undefined' && PhotoStore.ingestPhotoRef) {
      const result = await PhotoStore.ingestPhotoRef(ingestSource);
      if (typeof result === 'string') return result;
      if (result?.id) return result.id;
    }
    return typeof ingestSource === 'string' && ingestSource.startsWith('data:') ? ingestSource : normalized;
  }

  async function resolvePhotoDataUrl(ref) {
    const normalized = normalizePhotoRef(ref);
    if (!normalized) return null;
    if (typeof AktUtils !== 'undefined' && AktUtils.photoSrcAsync) {
      const url = await AktUtils.photoSrcAsync(normalized);
      if (url) return url;
    }
    if (typeof PhotoStore !== 'undefined' && PhotoStore.resolveDataUrl) {
      const url = await PhotoStore.resolveDataUrl(normalized);
      if (url) return url;
    }
    if (normalized.startsWith('data:') || normalized.startsWith('blob:')) return normalized;
    if (normalized.startsWith('photo:')) return null;
    return `data:image/jpeg;base64,${normalized}`;
  }

  function collectAllAkts(catalog) {
    const seen = new Set();
    const out = [];
    const push = (akt) => {
      if (!akt || seen.has(akt.id)) return;
      seen.add(akt.id);
      out.push(akt);
    };
    for (const akt of catalog?.akts || []) push(akt);
    if (catalog?.editableAkt?.akt) push(catalog.editableAkt.akt);
    return out;
  }

  async function readMeta() {
    return GazpromIdb.transaction('app', 'readonly', (tx) =>
      new Promise((resolve, reject) => {
        const req = tx.objectStore('app').get(META_KEY);
        req.onsuccess = () => resolve(req.result || { cardIndex: 0, lastTrainingDate: null });
        req.onerror = () => reject(req.error);
      })
    );
  }

  async function writeMeta(meta) {
    await GazpromIdb.transaction('app', 'readwrite', (tx) => {
      tx.objectStore('app').put(meta, META_KEY);
    });
  }

  async function loadAllEntries() {
    if (entriesCache) return entriesCache;
    const list = await GazpromIdb.transaction(STORE_SAMPLES, 'readonly', (tx) =>
      new Promise((resolve, reject) => {
        const store = tx.objectStore(STORE_SAMPLES);
        const req = store.getAll();
        req.onsuccess = () => resolve(req.result || []);
        req.onerror = () => reject(req.error);
      })
    );
    entriesCache = list.map((e) => ({
      ...e,
      photoRef: normalizePhotoRef(e.photoRef) || e.photoRef,
      feature: deserializeFeature(e.feature),
    }));
    return entriesCache;
  }

  function invalidateCache() {
    entriesCache = null;
    centroidCache = null;
  }

  async function saveEntry(entry) {
    const stored = {
      id: entry.id,
      violationTitle: entry.violationTitle,
      photoRef: entry.photoRef,
      feature: serializeFeature(entry.feature),
      source: entry.source,
      createdAt: entry.createdAt,
      photoHash: entry.photoHash || null,
    };
    await GazpromIdb.transaction(STORE_SAMPLES, 'readwrite', (tx) => {
      tx.objectStore(STORE_SAMPLES).put(stored, entry.id);
    });
    invalidateCache();
  }

  async function deleteEntry(id) {
    await GazpromIdb.transaction(STORE_SAMPLES, 'readwrite', (tx) => {
      tx.objectStore(STORE_SAMPLES).delete(id);
    });
    invalidateCache();
  }

  function updateCentroidCache(entries) {
    const byTitle = new Map();
    entries.forEach((entry) => {
      if (!entry.feature) return;
      const list = byTitle.get(entry.violationTitle) || [];
      list.push(entry.feature);
      byTitle.set(entry.violationTitle, list);
    });
    const out = new Map();
    byTitle.forEach((vectors, title) => {
      const centroid = averageFeatureVectors(vectors);
      if (centroid) out.set(title, centroid);
    });
    centroidCache = out;
    return out;
  }

  function getCentroids(entries) {
    if (centroidCache) return centroidCache;
    return updateCentroidCache(entries);
  }

  function minDistanceAndMatchingTitles(queryFeature, entries) {
    let minDist = Number.POSITIVE_INFINITY;
    entries.forEach((entry) => {
      if (!entry.feature) return;
      const d = distanceBetween(queryFeature, entry.feature);
      if (d < minDist) minDist = d;
    });
    const titles = new Set();
    if (minDist < DISTANCE_EPSILON_SAME) {
      entries.forEach((entry) => {
        if (!entry.feature) return;
        const d = distanceBetween(queryFeature, entry.feature);
        if (d < DISTANCE_EPSILON_SAME) titles.add(entry.violationTitle);
      });
    }
    return { minDist, titles };
  }

  async function getRegistryViolations() {
    if (typeof ViolationRegistry !== 'undefined' && ViolationRegistry.getAll) {
      const list = await ViolationRegistry.getAll();
      return (list || []).filter((v) => v.number != null);
    }
    const catalog = await GazpromStore.get();
    return (catalog?.violationRegistry || []).filter((v) => v.number != null);
  }

  function findMatchingViolationTitle(aktViolationTitle, violations) {
    const t = String(aktViolationTitle || '').trim();
    if (!t) return null;
    if (violations.some((v) => v.title === t)) return t;
    const colonIdx = t.indexOf(':');
    if (colonIdx >= 0) {
      const suffix = t.slice(colonIdx + 1).trim();
      const match = violations.find((v) =>
        String(v.title || '').toLowerCase().includes(suffix.toLowerCase())
      );
      if (match) return match.title;
    }
    const match = violations.find((v) => {
      const vt = String(v.title || '').toLowerCase();
      const q = t.toLowerCase();
      return vt.includes(q) || q.includes(vt);
    });
    return match?.title || null;
  }

  function registryOrderNumber(title, registry) {
    const matched = registry.find((v) => v.title === title);
    if (matched?.number != null) return matched.number;
    const idx = registry.findIndex((v) => v.title === title);
    return idx >= 0 ? idx + 1 : null;
  }

  async function predictFromFeature(queryFeature, entries, registry) {
    const { minDist, titles: matchingTitles } = minDistanceAndMatchingTitles(queryFeature, entries);

    if (matchingTitles.size > 0) {
      const sortedTitles = [...matchingTitles].sort();
      const equalConf = 1 / Math.max(1, sortedTitles.length);
      return sortedTitles.slice(0, 4).map((title) => ({
        violationTitle: title,
        registryOrderNumber: registryOrderNumber(title, registry),
        confidence: equalConf,
      }));
    }

    const centroids = getCentroids(entries);
    const source = centroids.size > 0 ? centroids : fallbackFeaturesByTitle(entries);
    const scores = [];
    source.forEach((featureData, title) => {
      const dist = distanceBetween(queryFeature, featureData);
      scores.push({ title, conf: distanceToConfidence(dist) });
    });
    scores.sort((a, b) => b.conf - a.conf);
    const top = scores.slice(0, 4);
    const total = top.reduce((s, x) => s + x.conf, 0) || 1;
    const isUnknown = minDist > DISTANCE_THRESHOLD_UNKNOWN;
    let results = top.map(({ title, conf }) => {
      let rawConf = conf / total;
      if (isUnknown && top[0]?.conf > 0) {
        rawConf = Math.min(1, rawConf * (MAX_CONFIDENCE_UNKNOWN / (top[0].conf / total || 1)));
      }
      return {
        violationTitle: title,
        registryOrderNumber: registryOrderNumber(title, registry),
        confidence: rawConf,
      };
    });
    results.sort((a, b) => b.confidence - a.confidence);
    return results;
  }

  function fallbackFeaturesByTitle(entries) {
    const out = new Map();
    entries.forEach((entry) => {
      if (!out.has(entry.violationTitle) && entry.feature) {
        out.set(entry.violationTitle, entry.feature);
      }
    });
    return out;
  }

  async function predict(dataUrl) {
    const entries = await loadAllEntries();
    const feature = await extractFeatureFromDataUrl(dataUrl);
    if (!feature) return [];
    const registry = await getRegistryViolations();
    return predictFromFeature(feature, entries, registry);
  }

  async function hashFromDataUrl(dataUrl) {
    if (!dataUrl || typeof dataUrl !== 'string') return '';
    const buf = dataUrl.startsWith('data:')
      ? Uint8Array.from(atob(dataUrl.split(',')[1] || ''), (c) => c.charCodeAt(0))
      : new TextEncoder().encode(dataUrl);
    return sha256Hex(buf);
  }

  async function addPhoto(violationTitle, dataUrlOrRef, source = 'manual', photoHash = null, originalRef = null) {
    const title = String(violationTitle || '').trim();
    if (!title) return null;
    const dataUrl =
      typeof dataUrlOrRef === 'string' && dataUrlOrRef.startsWith('data:')
        ? dataUrlOrRef
        : await resolvePhotoDataUrl(originalRef || dataUrlOrRef);
    if (!dataUrl) return null;
    const feature = await extractFeatureFromDataUrl(dataUrl);
    if (!feature) return null;
    const photoRef = await ensurePhotoRef(originalRef || dataUrlOrRef, dataUrl);
    if (!photoRef) return null;
    const id = uuid();
    const entry = {
      id,
      violationTitle: title,
      photoRef,
      feature,
      source,
      createdAt: new Date().toISOString(),
      photoHash: photoHash || (await hashFromDataUrl(dataUrl)),
    };
    await saveEntry(entry);
    return id;
  }

  async function loadFromActs(onProgress) {
    const catalog = await GazpromStore.get();
    const registry = await getRegistryViolations();
    const allAkts = collectAllAkts(catalog);
    const totalAkts = allAkts.length;
    let entries = await loadAllEntries();

    const photoKey = (hash, title) => `${hash}|${title}`;
    const jobs = [];
    const currentPhotoSet = new Set();
    let scannedPhotos = 0;

    for (const akt of allAkts) {
      for (const violation of akt.violations || []) {
        const photos = violation.photo || [];
        if (!photos.length) continue;
        let normalizedTitle = findMatchingViolationTitle(violation.title, registry);
        if (!normalizedTitle) {
          const trimmed = String(violation.title || '').trim();
          normalizedTitle = trimmed || null;
        }
        if (!normalizedTitle) continue;
        for (const ref of photos) {
          if (!ref) continue;
          scannedPhotos += 1;
          const originalRef = normalizePhotoRef(ref) || ref;
          const dataUrl = await resolvePhotoDataUrl(originalRef);
          if (!dataUrl) continue;
          const hash = await hashFromDataUrl(dataUrl);
          currentPhotoSet.add(photoKey(hash, normalizedTitle));
          jobs.push({ dataUrl, title: normalizedTitle, hash, originalRef });
        }
      }
    }

    const toRemove = entries.filter(
      (e) => e.source === 'akt' && !currentPhotoSet.has(photoKey(e.photoHash || '', e.violationTitle))
    );
    for (const entry of toRemove) {
      await deleteEntry(entry.id);
    }
    entries = await loadAllEntries();

    const existingSet = new Set(
      entries
        .filter((e) => e.source === 'akt')
        .map((e) => photoKey(e.photoHash || '', e.violationTitle))
    );
    const jobsToProcess = jobs.filter((j) => !existingSet.has(photoKey(j.hash, j.title)));

    let added = entries.filter((e) => e.source === 'akt').length;

    if (typeof onProgress === 'function') {
      onProgress(0, totalAkts, added);
    }

    if (!jobsToProcess.length) {
      const meta = await readMeta();
      meta.lastTrainingDate = new Date().toISOString();
      await writeMeta(meta);
      const stats = await getStatistics();
      if (typeof onProgress === 'function') onProgress(totalAkts, totalAkts, added, stats);
      return stats;
    }

    let jobIndex = 0;
    for (const job of jobsToProcess) {
      jobIndex += 1;
      const id = await addPhoto(job.title, job.dataUrl, 'akt', job.hash, job.originalRef);
      if (id) added += 1;
      if (typeof onProgress === 'function') {
        onProgress(totalAkts, totalAkts, added, null, jobIndex, jobsToProcess.length, scannedPhotos);
      }
      if (jobIndex % 5 === 0) await new Promise((r) => setTimeout(r, 0));
    }

    const meta = await readMeta();
    meta.lastTrainingDate = new Date().toISOString();
    await writeMeta(meta);
    const stats = await getStatistics();
    if (typeof onProgress === 'function') onProgress(totalAkts, totalAkts, added, stats);
    return stats;
  }

  async function computeAccuracy(entries) {
    const list =
      entries.length <= MAX_ACCURACY_SAMPLES
        ? entries
        : [...entries].sort(() => Math.random() - 0.5).slice(0, MAX_ACCURACY_SAMPLES);
    if (list.length < 2) return null;
    const registry = await getRegistryViolations();
    let correct = 0;
    let evaluated = 0;
    for (const query of list) {
      if (!query.feature) continue;
      const others = entries.filter((e) => e.id !== query.id);
      const preds = await predictFromFeature(query.feature, others, registry);
      evaluated += 1;
      if (preds[0]?.violationTitle === query.violationTitle) correct += 1;
    }
    if (!evaluated) return null;
    return correct / evaluated;
  }

  async function getStatistics() {
    const entries = await loadAllEntries();
    const meta = await readMeta();
    const violationSet = new Set(entries.map((e) => e.violationTitle));
    const autoCount = entries.filter((e) => e.source === 'akt').length;
    const manualCount = entries.filter((e) => e.source === 'manual').length;
    const catalog = await GazpromStore.get();
    const allAkts = collectAllAkts(catalog);
    const processedAktsCount = allAkts.filter((a) =>
      (a.violations || []).some((v) => (v.photo || []).length > 0)
    ).length;
    const accuracy = await computeAccuracy(entries);
    return {
      totalPhotos: entries.length,
      violationCount: violationSet.size,
      lastTrainingDate: meta.lastTrainingDate,
      autoCount,
      manualCount,
      processedAktsCount,
      accuracy,
      cardIndex: meta.cardIndex || 0,
    };
  }

  async function resetAll() {
    const entries = await loadAllEntries();
    for (const entry of entries) {
      await deleteEntry(entry.id);
    }
    await writeMeta({ cardIndex: 0, lastTrainingDate: null });
    invalidateCache();
  }

  async function allTrainingEntries() {
    return loadAllEntries();
  }

  async function violationsWithPhotoCounts() {
    const entries = await loadAllEntries();
    const registry = await getRegistryViolations();
    const counts = new Map();
    const numbers = new Map();
    entries.forEach((entry) => {
      const canonical = findMatchingViolationTitle(entry.violationTitle, registry) || entry.violationTitle;
      counts.set(canonical, (counts.get(canonical) || 0) + 1);
      if (!numbers.has(canonical)) {
        const num = registry.find((v) => v.title === canonical)?.number;
        if (num != null) numbers.set(canonical, num);
      }
    });
    return [...counts.entries()]
      .map(([title, count]) => ({
        title,
        count,
        number: numbers.get(title) ?? null,
      }))
      .sort((a, b) => String(a.title).localeCompare(String(b.title), 'ru'));
  }

  async function photosFor(canonicalTitle) {
    const entries = await loadAllEntries();
    const registry = await getRegistryViolations();
    const canonical = String(canonicalTitle || '').trim();
    return entries.filter(
      (e) => (findMatchingViolationTitle(e.violationTitle, registry) || e.violationTitle) === canonical
    );
  }

  async function updateViolationTitle(entryId, newTitle) {
    const entries = await loadAllEntries();
    const idx = entries.findIndex((e) => e.id === entryId);
    if (idx < 0) return false;
    const entry = entries[idx];
    await saveEntry({
      ...entry,
      violationTitle: String(newTitle || '').trim(),
    });
    return true;
  }

  async function removePhoto(id) {
    await deleteEntry(id);
    return true;
  }

  async function setCardIndex(index) {
    const meta = await readMeta();
    meta.cardIndex = Math.max(0, index | 0);
    await writeMeta(meta);
  }

  async function getCardIndex() {
    const meta = await readMeta();
    return meta.cardIndex || 0;
  }

  async function massAutoBind(files, onProgress) {
    const results = { added: 0, total: files.length };
    for (let i = 0; i < files.length; i += 1) {
      const file = files[i];
      const dataUrl = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });
      const preds = await predict(dataUrl);
      const title = preds[0]?.violationTitle || '—';
      if (title !== '—') {
        const id = await addPhoto(title, dataUrl, 'manual');
        if (id) results.added += 1;
      }
      if (typeof onProgress === 'function') onProgress(i + 1, files.length, results.added);
      await new Promise((r) => setTimeout(r, 0));
    }
    return results;
  }

  return {
    FEATURE_SIDE,
    distanceBetween,
    distanceToConfidence,
    averageFeatureVectors,
    findMatchingViolationTitle,
    predict,
    predictFromFeature,
    extractFeatureFromDataUrl,
    addPhoto,
    loadFromActs,
    getStatistics,
    resetAll,
    allTrainingEntries,
    violationsWithPhotoCounts,
    photosFor,
    updateViolationTitle,
    removePhoto,
    setCardIndex,
    getCardIndex,
    massAutoBind,
    resolvePhotoDataUrl,
    normalizePhotoRef,
    collectAllAkts,
    invalidateCache,
  };
})();
