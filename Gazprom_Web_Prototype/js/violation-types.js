/**
 * Классификатор видов нарушений: активные, архив, соответствия старый → новый.
 */
const ViolationTypes = (() => {
  const STATUS_ACTIVE = 'active';
  const STATUS_ARCHIVED = 'archived';
  const STATUS_PENDING = 'pending';
  /** Слева в «Сопоставить»: новый вид без устаревшего предшественника. */
  const STANDALONE_MAP_FROM = '__vt_standalone__';

  function getTypes(catalog) {
    return catalog?.violationTypes || [];
  }

  function getMappings(catalog) {
    return catalog?.typeMappings && typeof catalog.typeMappings === 'object'
      ? catalog.typeMappings
      : {};
  }

  function findById(catalog, id) {
    if (!id) return null;
    return getTypes(catalog).find((t) => t.id === id) || null;
  }

  function findByTitle(catalog, title) {
    const t = String(title || '').trim();
    if (!t) return null;
    return getTypes(catalog).find((x) => x.title === t) || null;
  }

  function builtinTypeTitles() {
    const legacy =
      typeof ViolationTemplates !== 'undefined' && Array.isArray(ViolationTemplates.VIOLATION_TYPES)
        ? ViolationTemplates.VIOLATION_TYPES
        : [];
    const seeds = mappingSeedTypes();
    return new Set([...legacy, ...seeds].map((t) => String(t || '').trim()).filter(Boolean));
  }

  /** Однократно убрать зашитые 17+13 видов — дальше только ручное добавление и привязки из реестра. */
  function purgeBuiltinDefaults(catalog) {
    if (!catalog || catalog.violationTypesPurgedV2) return false;
    const builtin = builtinTypeTitles();
    const kept = getTypes(catalog).filter((t) => !builtin.has(t.title));
    catalog.violationTypes = kept;
    catalog.violationTypesPurgedV2 = true;
    const dismissed = getDismissedMappingSeeds(catalog);
    for (const title of mappingSeedTypes()) {
      dismissed.add(String(title || '').trim());
    }
    catalog.dismissedMappingSeeds = [...dismissed];
    return true;
  }

  /** Цепочка replacedBy/typeMappings без ensureCatalog (для purgeBuiltinRegistryVids). */
  function resolveVidChain(catalog, vid) {
    const raw = String(vid || '').trim();
    if (!raw) return '';
    if (!catalog) return raw;

    let current = findByTitle(catalog, raw);
    if (!current) return raw;

    const mappings = getMappings(catalog);
    const visited = new Set();
    while (current) {
      if (visited.has(current.id)) break;
      visited.add(current.id);

      if (current.status === STATUS_ACTIVE) return current.title;

      const nextId = current.replacedBy || mappings[current.id];
      if (!nextId) return current.title;

      current = findById(catalog, nextId);
      if (!current) return raw;
    }
    return raw;
  }

  /** Однократно сбросить устаревшие виды в записях реестра (из встроенного Excel). */
  function purgeBuiltinRegistryVids(catalog) {
    if (!catalog || catalog.registryBuiltinVidsPurgedV2) return false;
    const builtin = builtinTypeTitles();
    let changed = false;
    for (const item of catalog.violationRegistry || []) {
      const raw = String(item.vid || '').trim();
      if (!raw) continue;
      const resolved = resolveVidChain(catalog, raw);
      if (builtin.has(raw) || builtin.has(resolved)) {
        item.vid = '';
        changed = true;
      }
    }
    catalog.registryBuiltinVidsPurgedV2 = true;
    return changed;
  }

  function isBuiltinVidTitle(vid) {
    const s = String(vid || '').trim();
    if (!s) return false;
    return builtinTypeTitles().has(s);
  }

  function mappingSeedTypes() {
    return typeof ViolationTemplates !== 'undefined' &&
      Array.isArray(ViolationTemplates.MAPPING_SEED_TYPES)
      ? ViolationTemplates.MAPPING_SEED_TYPES
      : [];
  }

  function getDismissedMappingSeeds(catalog) {
    if (!Array.isArray(catalog?.dismissedMappingSeeds)) {
      if (catalog) catalog.dismissedMappingSeeds = [];
      return new Set();
    }
    return new Set(
      catalog.dismissedMappingSeeds.map((t) => String(t || '').trim()).filter(Boolean)
    );
  }

  function dismissMappingSeed(catalog, title) {
    const normalized = String(title || '').trim();
    if (!normalized || !catalog) return false;
    const dismissed = getDismissedMappingSeeds(catalog);
    if (dismissed.has(normalized)) return false;
    catalog.dismissedMappingSeeds = [...dismissed, normalized];
    return true;
  }

  function collectVidCounts(catalog) {
    const counts = new Map();
    const add = (value) => {
      const s = String(value || '').trim();
      if (!s) return;
      counts.set(s, (counts.get(s) || 0) + 1);
    };
    const scanAkts = (akts) => {
      (akts || []).forEach((akt) => {
        (akt.violations || []).forEach((v) => add(v.vid));
      });
    };
    scanAkts(catalog?.akts);
    scanAkts(catalog?.trash);
    if (catalog?.editableAkt?.akt) scanAkts([catalog.editableAkt.akt]);
    (catalog?.violationRegistry || []).forEach((r) => add(r.vid));
    return counts;
  }

  function syncOrphanVids(catalog) {
    const counts = collectVidCounts(catalog);
    const types = getTypes(catalog);
    const titles = new Set(types.map((t) => t.title));
    let changed = false;

    for (const vid of counts.keys()) {
      if (titles.has(vid)) continue;
      types.push({
        id: AktUtils.uuid(),
        title: vid,
        status: STATUS_ARCHIVED,
      });
      titles.add(vid);
      changed = true;
    }

    if (changed) catalog.violationTypes = types;
    return changed;
  }

  function syncMappingsFromTypes(catalog) {
    const mappings = { ...getMappings(catalog) };
    let changed = false;
    for (const t of getTypes(catalog)) {
      if (t.replacedBy && mappings[t.id] !== t.replacedBy) {
        mappings[t.id] = t.replacedBy;
        changed = true;
      }
    }
    if (changed) catalog.typeMappings = mappings;
    return changed;
  }

  function syncMappingSeedTypes(catalog) {
    const seeds = mappingSeedTypes();
    if (!seeds.length) return false;
    const types = getTypes(catalog);
    const existingTitles = new Set(types.map((t) => t.title));
    const dismissed = getDismissedMappingSeeds(catalog);
    let changed = false;
    for (const title of seeds) {
      const normalized = String(title || '').trim();
      if (!normalized || existingTitles.has(normalized) || dismissed.has(normalized)) continue;
      types.push({
        id: AktUtils.uuid(),
        title: normalized,
        status: STATUS_PENDING,
      });
      existingTitles.add(normalized);
      changed = true;
    }
    if (changed) catalog.violationTypes = types;
    return changed;
  }

  function ensureCatalog(catalog) {
    if (!catalog) return false;
    let changed = false;

    if (!Array.isArray(catalog.violationTypes)) {
      catalog.violationTypes = [];
      changed = true;
    }
    if (!catalog.typeMappings || typeof catalog.typeMappings !== 'object') {
      catalog.typeMappings = {};
      changed = true;
    }
    if (!Array.isArray(catalog.dismissedMappingSeeds)) {
      catalog.dismissedMappingSeeds = [];
      changed = true;
    }

    if (purgeBuiltinDefaults(catalog)) changed = true;
    if (purgeBuiltinRegistryVids(catalog)) changed = true;
    if (syncOrphanVids(catalog)) changed = true;
    if (syncMappingsFromTypes(catalog)) changed = true;

    return changed;
  }

  function getActiveTypes(catalog) {
    ensureCatalog(catalog);
    return getTypes(catalog).filter((t) => t.status === STATUS_ACTIVE);
  }

  function getPendingTypes(catalog) {
    ensureCatalog(catalog);
    return getTypes(catalog).filter((t) => t.status === STATUS_PENDING);
  }

  /** Активные + ожидающие привязки — правая колонка «Сопоставить». */
  function getMapTargetTypes(catalog) {
    ensureCatalog(catalog);
    return getTypes(catalog).filter(
      (t) => t.status === STATUS_ACTIVE || t.status === STATUS_PENDING
    );
  }

  function getArchivedTypes(catalog) {
    ensureCatalog(catalog);
    return getTypes(catalog).filter((t) => t.status === STATUS_ARCHIVED);
  }

  function getActiveTitles(catalog) {
    return getActiveTypes(catalog)
      .map((t) => t.title)
      .sort((a, b) => a.localeCompare(b, 'ru'));
  }

  function isMappedToActive(catalog, type) {
    if (!type) return false;
    const targetId = type.replacedBy || getMappings(catalog)[type.id];
    if (!targetId) return false;
    const target = findById(catalog, targetId);
    return !!(target && target.status === STATUS_ACTIVE);
  }

  function getUnmappedArchived(catalog) {
    ensureCatalog(catalog);
    return getArchivedTypes(catalog).filter((t) => !isMappedToActive(catalog, t));
  }

  function resolveVid(catalog, vid) {
    const raw = String(vid || '').trim();
    if (!raw) return '';
    if (!catalog) return raw;

    ensureCatalog(catalog);
    return resolveVidChain(catalog, vid);
  }

  function usageCount(catalog, typeOrId) {
    ensureCatalog(catalog);
    let type = null;
    if (typeof typeOrId === 'object' && typeOrId?.title) {
      type = typeOrId;
    } else {
      type = findById(catalog, typeOrId) || findByTitle(catalog, typeOrId);
    }
    if (!type) return 0;
    return collectVidCounts(catalog).get(type.title) || 0;
  }

  function addType(catalog, title, { forMapping = false } = {}) {
    const t = String(title || '').trim();
    if (!t) return null;
    ensureCatalog(catalog);
    const existing = findByTitle(catalog, t);
    if (existing) {
      if (forMapping && existing.status === STATUS_ARCHIVED) {
        existing.status = STATUS_PENDING;
        delete existing.replacedBy;
        return existing;
      }
      if (existing.status === STATUS_ARCHIVED) {
        existing.status = STATUS_ACTIVE;
        delete existing.replacedBy;
      }
      return existing;
    }
    const item = {
      id: AktUtils.uuid(),
      title: t,
      status: forMapping ? STATUS_PENDING : STATUS_ACTIVE,
    };
    catalog.violationTypes = [...getTypes(catalog), item];
    return item;
  }

  function activateType(catalog, id) {
    const t = findById(catalog, id);
    if (!t || t.status !== STATUS_PENDING) return false;
    t.status = STATUS_ACTIVE;
    return true;
  }

  function deleteType(catalog, id) {
    const t = findById(catalog, id);
    if (!t) return { ok: false, reason: 'not_found' };

    const usage = usageCount(catalog, t);
    if (usage > 0) {
      return { ok: false, reason: 'in_use', count: usage };
    }

    const seedTitles = new Set(mappingSeedTypes());
    if (t.status === STATUS_PENDING && seedTitles.has(t.title)) {
      dismissMappingSeed(catalog, t.title);
    }

    const types = getTypes(catalog).filter((x) => x.id !== id);
    for (const item of types) {
      if (item.replacedBy === id) delete item.replacedBy;
    }

    const mappings = { ...getMappings(catalog) };
    delete mappings[id];
    for (const key of Object.keys(mappings)) {
      if (mappings[key] === id) delete mappings[key];
    }

    catalog.violationTypes = types;
    catalog.typeMappings = mappings;
    return { ok: true };
  }

  function archiveType(catalog, id) {
    const t = findById(catalog, id);
    if (!t || t.status === STATUS_ARCHIVED) return false;
    t.status = STATUS_ARCHIVED;
    return true;
  }

  function isStandaloneMapFrom(fromId) {
    return fromId === STANDALONE_MAP_FROM;
  }

  function countMappedFrom(catalog, toId) {
    if (!toId) return 0;
    const mappings = getMappings(catalog);
    return getArchivedTypes(catalog).filter(
      (t) => t.replacedBy === toId || mappings[t.id] === toId
    ).length;
  }

  function getMappedFromTitles(catalog, toId) {
    if (!toId) return [];
    const mappings = getMappings(catalog);
    return getArchivedTypes(catalog)
      .filter((t) => t.replacedBy === toId || mappings[t.id] === toId)
      .map((t) => t.title);
  }

  function activateStandaloneType(catalog, toId) {
    ensureCatalog(catalog);
    const to = findById(catalog, toId);
    if (!to) return false;
    if (to.status !== STATUS_PENDING && to.status !== STATUS_ACTIVE) return false;
    to.status = STATUS_ACTIVE;
    to.standalone = true;
    return true;
  }

  function restoreType(catalog, id) {
    const t = findById(catalog, id);
    if (!t || t.status !== STATUS_ARCHIVED) {
      return { ok: false, reason: 'not_archived' };
    }

    const duplicate = getActiveTypes(catalog).find(
      (x) => x.id !== t.id && x.title === t.title
    );
    if (duplicate) {
      return { ok: false, reason: 'duplicate', title: t.title };
    }

    t.status = STATUS_ACTIVE;
    delete t.replacedBy;

    const mappings = { ...getMappings(catalog) };
    delete mappings[id];
    catalog.typeMappings = mappings;

    return { ok: true };
  }

  function setMapping(catalog, fromId, toId) {
    if (!fromId || !toId || fromId === toId) return false;
    ensureCatalog(catalog);
    const from = findById(catalog, fromId);
    const to = findById(catalog, toId);
    if (!from || !to) return false;
    if (to.status === STATUS_PENDING) {
      to.status = STATUS_ACTIVE;
    } else if (to.status !== STATUS_ACTIVE) {
      return false;
    }
    delete to.standalone;

    from.status = STATUS_ARCHIVED;
    from.replacedBy = toId;
    catalog.typeMappings = { ...getMappings(catalog), [fromId]: toId };
    return true;
  }

  function clearMapping(catalog, fromId) {
    const from = findById(catalog, fromId);
    if (!from) return false;
    delete from.replacedBy;
    const mappings = { ...getMappings(catalog) };
    delete mappings[fromId];
    catalog.typeMappings = mappings;
    return true;
  }

  function buildKindStats(catalog, { resolve = true } = {}) {
    const stats = new Map();
    const addViolation = (v) => {
      const raw = String(v?.vid || '').trim();
      if (!raw) return;
      const kind = resolve ? resolveVid(catalog, raw) : raw;
      if (!kind) return;
      stats.set(kind, (stats.get(kind) || 0) + 1);
    };
    const scan = (akts) => {
      (akts || []).forEach((akt) => {
        (akt.violations || []).forEach(addViolation);
      });
    };
    scan(catalog?.akts);
    scan(catalog?.trash);
    if (catalog?.editableAkt?.akt) scan([catalog.editableAkt.akt]);
    return stats;
  }

  function migrateStoredVids(catalog) {
    ensureCatalog(catalog);
    let updated = 0;

    const rewrite = (v) => {
      const raw = String(v?.vid || '').trim();
      if (!raw) return;
      const resolved = resolveVid(catalog, raw);
      if (resolved && resolved !== raw) {
        v.vid = resolved;
        updated += 1;
      }
    };

    const scanAkts = (akts) => {
      (akts || []).forEach((akt) => {
        (akt.violations || []).forEach(rewrite);
      });
    };
    scanAkts(catalog.akts);
    scanAkts(catalog.trash);
    if (catalog.editableAkt?.akt) scanAkts([catalog.editableAkt.akt]);
    (catalog.violationRegistry || []).forEach(rewrite);

    return updated;
  }

  function formatVidDisplay(catalog, vid) {
    const raw = String(vid || '').trim();
    if (!raw) return { display: '', original: '', migrated: false };
    const resolved = resolveVid(catalog, raw);
    return {
      display: resolved || raw,
      original: raw,
      migrated: !!(resolved && resolved !== raw),
    };
  }

  /** Уникальные виды, уже привязанные в реестре (для выбора в форме нарушения). */
  function getRegistryVidTitles(catalog) {
    ensureCatalog(catalog);
    const titles = new Set();
    (catalog?.violationRegistry || []).forEach((r) => {
      const v = resolveVid(catalog, r.vid);
      if (v) titles.add(v);
    });
    return [...titles].sort((a, b) => a.localeCompare(b, 'ru'));
  }

  /** Список для select: только активные виды классификатора + текущее значение. */
  function getVidSelectTitles(catalog, rawVid) {
    ensureCatalog(catalog);
    const resolved = resolveVid(catalog, rawVid);
    const active = getActiveTitles(catalog);
    if (resolved && !active.includes(resolved) && !isBuiltinVidTitle(resolved)) {
      return [resolved, ...active];
    }
    return active;
  }

  /** Добавить вид в классификатор при сохранении привязки (если ещё нет). */
  function ensureActiveType(catalog, title) {
    const t = String(title || '').trim();
    if (!t) return null;
    return addType(catalog, t);
  }

  return {
    STATUS_ACTIVE,
    STATUS_ARCHIVED,
    STATUS_PENDING,
    STANDALONE_MAP_FROM,
    isStandaloneMapFrom,
    ensureCatalog,
    getTypes,
    getMappings,
    getActiveTypes,
    getPendingTypes,
    getMapTargetTypes,
    getArchivedTypes,
    getActiveTitles,
    getUnmappedArchived,
    findById,
    findByTitle,
    resolveVid,
    usageCount,
    collectVidCounts,
    addType,
    activateType,
    deleteType,
    archiveType,
    restoreType,
    setMapping,
    clearMapping,
    countMappedFrom,
    getMappedFromTitles,
    activateStandaloneType,
    isMappedToActive,
    dismissMappingSeed,
    buildKindStats,
    migrateStoredVids,
    formatVidDisplay,
    getRegistryVidTitles,
    getVidSelectTitles,
    ensureActiveType,
    purgeBuiltinDefaults,
    purgeBuiltinRegistryVids,
    isBuiltinVidTitle,
    builtinTypeTitles,
  };
})();
