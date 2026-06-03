/**
 * Импорт резервных копий iOS (.gazprombackup = JSON AppBackup).
 */
const GazpromBackup = (() => {
  /** Десктоп: расширения + MIME. */
  const ACCEPT = '.gazprombackup,.json,application/json,text/json,text/plain,application/octet-stream';
  /**
   * Телефон (iOS Safari): без image/* и video/* — иначе меню «Медиатека / Снять фото / Файл».
   * .gazprombackup часто приходит как application/octet-stream; .json — application/json.
   */
  const ACCEPT_MOBILE =
    '.gazprombackup,application/json,.json,text/json,text/plain,application/octet-stream';

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
      const akt = normalizeAkt(editableAkt.akt);
      editableAkt = AktUtils.isShortFormat(akt)
        ? null
        : { ...editableAkt, akt };
    }

    const templateKey =
      typeof DocGenerator !== 'undefined' && DocGenerator.TEMPLATE_KEY
        ? DocGenerator.TEMPLATE_KEY
        : 'wordTemplate';
    const templates = raw.descriptionTemplates;
    const descriptionTemplates = Array.isArray(templates)
      ? templates.slice(0, 3).concat(['', '', '']).slice(0, 3)
      : ['', '', ''];

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
      violationRegistry: raw.violationRegistry || [],
      descriptionTemplates,
      [templateKey]: raw[templateKey] || raw.wordTemplate || null,
      wordTemplateName: raw.wordTemplateName || null,
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

    if (akt && !AktUtils.isShortFormat(akt)) {
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
      registry: (backup.violationRegistry || []).length,
      photos: photoCount(backup.akts) + photoCount(backup.trash),
      editable: backup.editableAkt ? `№${backup.editableAkt.akt?.number}` : '—',
    };
  }

  /** Чтение текста файла: iOS Safari теряет доступ к File после сброса input.value. */
  async function readFileText(file) {
    // #region agent log
    if (typeof DebugAgent !== 'undefined') {
      DebugAgent.log('backup-import.js:readFileText', 'read start', {
        name: file?.name,
        size: file?.size,
        type: file?.type,
      }, 'A');
    }
    // #endregion
    const viaReader = () =>
      new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(String(reader.result ?? ''));
        reader.onerror = () => reject(reader.error || new Error('Не удалось прочитать файл'));
        reader.readAsText(file);
      });

    let text = '';
    if (typeof file.text === 'function') {
      try {
        text = await file.text();
      } catch {
        text = await viaReader();
      }
    } else {
      text = await viaReader();
    }

    text = text.replace(/^\uFEFF/, '').trim();
    if (!text) {
      throw new Error('Файл пустой или не удалось прочитать содержимое');
    }
    // #region agent log
    if (typeof DebugAgent !== 'undefined') {
      DebugAgent.log('backup-import.js:readFileText', 'read ok', {
        textLen: text.length,
        head: text.slice(0, 40),
      }, 'A');
    }
    // #endregion
    return text;
  }

  function parseJsonText(text, fileName) {
    const cleaned = String(text).replace(/^\uFEFF/, '').trim();
    let raw;
    try {
      raw = JSON.parse(cleaned);
    } catch {
      throw new Error('Файл не является корректным JSON');
    }
    const backup = normalizeBackup(raw);
    if (fileName) backup.sourceFileName = fileName;
    restoreEditableReference(backup);
    // #region agent log
    if (typeof DebugAgent !== 'undefined') {
      DebugAgent.log('backup-import.js:parseJsonText', 'parse ok', {
        akts: backup.akts.length,
        version: backup.version,
      }, 'B');
    }
    // #endregion
    return backup;
  }

  async function parseFile(file) {
    const text = await readFileText(file);
    return parseJsonText(text, file.name);
  }

  async function importFile(file, { replace = true, parsed = null } = {}) {
    const incoming = parsed || await parseFile(file);
    let merged = incoming;

    if (!replace) {
      const existing = await GazpromStore.get();
      if (GazpromStore.hasData(existing)) {
        merged = mergeBackups(existing, incoming);
        restoreEditableReference(merged);
      }
    }

    await requestStoragePersistence();

    const fileBytes = file?.size > 0 ? file.size : 0;
    const inlineBytes = approximateInlinePhotoBytes(merged);
    const sizeHint = fileBytes || inlineBytes;
    const useChunkedPhotos =
      typeof PhotoStore !== 'undefined' &&
      (fileBytes > 12 * 1024 * 1024 || inlineBytes > 12 * 1024 * 1024);

    // #region agent log
    if (typeof DebugAgent !== 'undefined') {
      DebugAgent.log('backup-import.js:importFile', 'before save', {
        replace,
        sizeHint,
        fileBytes,
        inlineBytes,
        useChunkedPhotos,
        akts: merged.akts?.length,
      }, 'C');
    }
    // #endregion

    if (sizeHint > 40 * 1024 * 1024 && typeof GazpromToast !== 'undefined') {
      const ok = await GazpromToast.confirm(
        useChunkedPhotos
          ? `Копия большая (${formatBytes(sizeHint)}). Фото будут сохранены по частям — это займёт несколько минут. Продолжить?`
          : `Копия большая (≈${formatBytes(sizeHint)}). Продолжить?`
      );
      if (!ok) throw new Error('Импорт отменён');
    }

    if (useChunkedPhotos) {
      if (replace && typeof PhotoStore.clearAll === 'function') {
        await PhotoStore.clearAll();
      }
      const loadingLabel = document.getElementById('backupLoadingText');
      merged = await PhotoStore.ingestCatalogChunked(merged, {
        onProgress: (done, total) => {
          if (loadingLabel && total > 0) {
            loadingLabel.textContent = `Сохранение фото ${done}/${total}…`;
          }
        },
      });
      // #region agent log
      if (typeof DebugAgent !== 'undefined') {
        DebugAgent.log('backup-import.js:importFile', 'chunked photos done', {
          inlineAfter: approximateInlinePhotoBytes(merged),
        }, 'C');
      }
      // #endregion
    }

    await GazpromStore.set(merged, { skipPhotoIngest: true, verifyWrite: true });
    // #region agent log
    if (typeof DebugAgent !== 'undefined') {
      DebugAgent.log('backup-import.js:importFile', 'set ok', {
        akts: merged.akts?.length,
      }, 'C');
    }
    // #endregion
    return { backup: merged, stats: getStats(merged) };
  }

  /** Оценка без JSON.stringify всего каталога (на iPhone ~200MB копия роняет вкладку). */
  function approximateInlinePhotoBytes(backup) {
    if (!backup) return 0;
    let bytes = 12000;
    const scan = (list) => {
      for (const a of list || []) {
        bytes += 400;
        for (const v of a.violations || []) {
          bytes += 200;
          for (const p of v.photo || []) {
            if (typeof p === 'string' && !p.startsWith('photo:')) bytes += p.length;
          }
        }
      }
    };
    scan(backup.akts);
    scan(backup.trash);
    if (backup.editableAkt?.akt) scan([backup.editableAkt.akt]);
    return bytes;
  }

  async function requestStoragePersistence() {
    if (!navigator.storage?.persist) return;
    try {
      await navigator.storage.persist();
    } catch {
      /* ignore */
    }
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

    const violationRegistry = [...(current.violationRegistry || [])];
    (incoming.violationRegistry || []).forEach((x) => byId(violationRegistry, x));

    const templateKey =
      typeof DocGenerator !== 'undefined' && DocGenerator.TEMPLATE_KEY
        ? DocGenerator.TEMPLATE_KEY
        : 'wordTemplate';
    const mergedTemplates = [...(current.descriptionTemplates || ['', '', ''])];
    const incomingTemplates = incoming.descriptionTemplates || ['', '', ''];
    for (let i = 0; i < 3; i += 1) {
      const t = incomingTemplates[i];
      if (t && String(t).trim()) mergedTemplates[i] = t;
    }

    const wordTemplate = incoming[templateKey] || current[templateKey] || null;
    const wordTemplateName = incoming.wordTemplateName || current.wordTemplateName || null;

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
      violationRegistry,
      descriptionTemplates: mergedTemplates,
      [templateKey]: wordTemplate,
      wordTemplateName,
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
    ACCEPT_MOBILE,
    readFileText,
    parseFile,
    parseJsonText,
    importFile,
    getStats,
    formatBytes,
    formatDate,
    normalizeBackup,
    mergeBackups,
  };
})();
