/**
 * Импорт резервных копий iOS (.gazprombackup = JSON AppBackup).
 */
const GazpromBackup = (() => {
  /** Подсказка для десктопного диалога; на touch-устройствах accept не задаём — iOS/Android блокируют .gazprombackup. */
  const ACCEPT = '.gazprombackup,.json,application/json,text/json,text/plain,application/octet-stream';

  function normalizePhotoArray(photos) {
    if (!Array.isArray(photos)) return [];
    return photos.map((p) => {
      if (typeof p === 'string') return p;
      if (p && typeof p === 'object' && p.data) return p.data;
      return null;
    }).filter(Boolean);
  }

  function normalizeViolation(v) {
    if (!v || typeof v !== 'object') return v;
    return { ...v, photo: normalizePhotoArray(v.photo) };
  }

  function normalizeAkt(akt) {
    if (!akt || typeof akt !== 'object') return akt;
    const violations = (akt.violations || []).map(normalizeViolation);
    return { ...akt, violations };
  }

  /** Нормализация после JSON.parse (даты ISO, фото base64). */
  function normalizeBackup(raw) {
    if (!raw || typeof raw !== 'object') {
      throw new Error('Файл не содержит данных резервной копии');
    }
    if (!Array.isArray(raw.akts)) {
      throw new Error('Неверный формат: нет списка актов (akts)');
    }

    const akts = raw.akts.map(normalizeAkt);
    const trash = (raw.trash || []).map(normalizeAkt);

    let editableAkt = raw.editableAkt || null;
    if (editableAkt && editableAkt.akt) {
      editableAkt = {
        ...editableAkt,
        akt: normalizeAkt(editableAkt.akt),
      };
    }

    return {
      version: raw.version || '1.0',
      timestamp: raw.timestamp || new Date().toISOString(),
      akts,
      comissionPeople: raw.comissionPeople || [],
      organizations: raw.organizations || [],
      objects: raw.objects || [],
      predstavitely: raw.predstavitely || [],
      trash,
      editableAkt,
      editableAktReference: raw.editableAktReference || null,
      scheduleItems: raw.scheduleItems || [],
      violationEliminations: raw.violationEliminations || [],
      importedAt: new Date().toISOString(),
      sourceFileName: raw.sourceFileName || null,
    };
  }

  function restoreEditableReference(backup) {
    if (backup.editableAkt) return backup;

    const ref = backup.editableAktReference;
    if (!ref) return backup;

    const akt =
      backup.akts.find((a) => a.id === ref.aktId) ||
      backup.akts.find((a) => String(a.number) === String(ref.aktNumber));

    if (akt) {
      backup.editableAkt = {
        akt,
        isEditable: true,
        lastModified: ref.lastModified || new Date().toISOString(),
      };
    }
    return backup;
  }

  function getStats(backup) {
    const photoCount = (list) =>
      list.reduce(
        (n, a) =>
          n + (a.violations || []).reduce((s, v) => s + (v.photo?.length || 0), 0),
        0
      );

    return {
      version: backup.version,
      timestamp: backup.timestamp,
      akts: backup.akts.length,
      trash: backup.trash.length,
      comission: backup.comissionPeople.length,
      organizations: backup.organizations.length,
      objects: backup.objects.length,
      predstavitely: backup.predstavitely.length,
      schedule: backup.scheduleItems.length,
      eliminations: backup.violationEliminations.length,
      photos: photoCount(backup.akts) + photoCount(backup.trash),
      editable: backup.editableAkt ? `№${backup.editableAkt.akt?.number}` : '—',
    };
  }

  async function parseFile(file) {
    const text = await file.text();
    let raw;
    try {
      raw = JSON.parse(text);
    } catch {
      throw new Error('Файл не является корректным JSON');
    }
    const backup = normalizeBackup(raw);
    backup.sourceFileName = file.name;
    restoreEditableReference(backup);
    return backup;
  }

  async function importFile(file, { replace = true } = {}) {
    const incoming = await parseFile(file);
    let merged = incoming;

    if (!replace) {
      const existing = await GazpromStore.get();
      if (GazpromStore.hasData(existing)) {
        merged = mergeBackups(existing, incoming);
        restoreEditableReference(merged);
      }
    }

    await GazpromStore.set(merged);
    return { backup: merged, stats: getStats(merged) };
  }

  function mergeBackups(current, incoming) {
    const byId = (arr, item) => {
      if (!arr.some((x) => x.id === item.id)) arr.push(item);
    };

    const akts = [...current.akts];
    incoming.akts.forEach((a) => byId(akts, a));

    const comissionPeople = [...current.comissionPeople];
    incoming.comissionPeople.forEach((x) => byId(comissionPeople, x));

    const organizations = [...current.organizations];
    incoming.organizations.forEach((x) => byId(organizations, x));

    const objects = [...current.objects];
    incoming.objects.forEach((x) => byId(objects, x));

    const predstavitely = [...current.predstavitely];
    incoming.predstavitely.forEach((x) => byId(predstavitely, x));

    const scheduleItems = [...current.scheduleItems];
    incoming.scheduleItems.forEach((x) => byId(scheduleItems, x));

    const violationEliminations = [...current.violationEliminations];
    incoming.violationEliminations.forEach((x) => byId(violationEliminations, x));

    return {
      ...incoming,
      akts,
      comissionPeople,
      organizations,
      objects,
      predstavitely,
      trash: incoming.trash,
      scheduleItems,
      violationEliminations,
      importedAt: new Date().toISOString(),
      sourceFileName: incoming.sourceFileName,
    };
  }

  function formatBytes(n) {
    if (n < 1024) return `${n} Б`;
    if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} КБ`;
    return `${(n / (1024 * 1024)).toFixed(1)} МБ`;
  }

  function formatDate(iso) {
    if (!iso) return '—';
    try {
      return new Date(iso).toLocaleString('ru-RU', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return String(iso);
    }
  }

  return {
    ACCEPT,
    parseFile,
    importFile,
    getStats,
    formatBytes,
    formatDate,
    normalizeBackup,
  };
})();
