/** Газпром — веб-приложение: навигация, PWA, импорт, экраны */
window.GAZPROM_WEB_BUILD = 'web-' + (window.GAZPROM_ASSET_V || '112');

const syncAppBuildLabel = () => {
  const build = window.GAZPROM_WEB_BUILD;
  if (!build) return;
  const label = `Сборка: ${build}`;
  const el = document.getElementById('appBuildId');
  if (el) el.textContent = label;
  document.querySelectorAll('[data-app-build]').forEach((node) => {
    node.textContent = build;
  });
};
const titles = {
  home: 'Главная',
  wizard: 'Редактируемый акт',
  history: 'История',
  reports: 'Отчёты',
  elimination: 'Устранение',
  settings: 'Настройки',
  trash: 'Корзина',
  violations: 'Реестр нарушений',
  'violation-types': 'Виды нарушений',
};

function goTo(screenId, options = {}) {
  const activeScreen = document.querySelector('.screen.active')?.id?.replace('screen-', '');
  if (
    !options.forceNavigate &&
    hasEditingOverlay() &&
    screenId !== activeScreen
  ) {
    GazpromToast.info('Сначала сохраните или отмените редактирование нарушения');
    return;
  }

  if (screenId === 'home' && tryApplySwUpdate()) return;

  const wasWizard = document.getElementById('screen-wizard')?.classList.contains('active');
  document.documentElement.classList.add('gazprom-navigated');
  document.querySelectorAll('.nav-item, .bottom-nav-item').forEach((n) => {
    n.classList.toggle('active', n.dataset.screen === screenId);
  });
  document.querySelectorAll('.screen').forEach((s) => s.classList.remove('active'));
  document.getElementById('screen-' + screenId)?.classList.add('active');
  document.getElementById('pageTitle').textContent = titles[screenId] || screenId;

  if (screenId === 'wizard' && !options.skipWizardReload) {
    WizardController.open(options.aktId ?? null, {
      preserveStep: options.preserveStep ?? wasWizard,
      preserveDraft: options.preserveDraft ?? wasWizard,
      forceNew: options.forceNew,
    });
  }
  if (screenId === 'violations') {
    ViolationRegistry.renderScreen();
  }
  if (screenId === 'violation-types') {
    ViolationTypesEditor.renderScreen();
  }
  if (screenId === 'reports') {
    void GazpromStore.get().then((data) => ReportsDashboard.render(data));
  }
  requestAnimationFrame(() => {
    GazpromMobileOverlay?.ensureScrollClearance?.('goTo-' + screenId);
  });
}

function bindNavigation() {
  document.querySelectorAll('.nav-item, .bottom-nav-item').forEach((btn) => {
    btn.addEventListener('click', () => {
      const screenId = btn.dataset.screen;
      if (document.getElementById('screen-' + screenId)?.classList.contains('active')) return;
      goTo(screenId);
    });
  });
}

function updateClock() {
  const el = document.getElementById('liveClock');
  if (!el) return;
  el.textContent = new Date().toLocaleString('ru-RU', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function bindHeaderSync() {
  document.getElementById('headerSyncBtn')?.addEventListener('click', () => {
    GazpromUI.refreshAll().catch(console.error);
  });
}

let backupImportInProgress = false;
let swUpdatePending = false;

function hasEditingOverlay() {
  if (window.__gazpromSavingViolation) return true;
  if (document.getElementById('wizardModalRoot')?.classList.contains('show')) return true;
  if (document.querySelector('.vr-form-overlay')) return true;
  if (typeof WizardModals?.isSavingViolation === 'function' && WizardModals.isSavingViolation()) {
    return true;
  }
  return false;
}

function shouldDeferAppReload() {
  if (backupImportInProgress) return true;
  if (hasEditingOverlay()) return true;
  if (document.getElementById('screen-wizard')?.classList.contains('active')) return true;
  return typeof WizardController?.isDirty === 'function' && WizardController.isDirty();
}

function markSwUpdatePending() {
  if (swUpdatePending) return;
  swUpdatePending = true;
}

function tryApplySwUpdate() {
  if (!swUpdatePending || shouldDeferAppReload()) return false;
  swUpdatePending = false;
  location.reload();
  return true;
}

function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) return;
  window.addEventListener('load', () => {
    const isLocal = location.hostname === 'localhost' || location.hostname === '127.0.0.1';
    if (isLocal) {
      navigator.serviceWorker.getRegistrations().then((regs) => {
        Promise.all(regs.map((r) => r.unregister()));
      });
      return;
    }
    navigator.serviceWorker.register('./sw.js?v=178')
      .then((reg) => {
        reg.update();
        document.addEventListener('visibilitychange', () => {
          if (document.visibilityState === 'visible') reg.update();
        });
        reg.addEventListener('updatefound', () => {
          const newSW = reg.installing;
          if (!newSW) return;
          newSW.addEventListener('statechange', () => {
            if (newSW.state === 'activated') markSwUpdatePending();
          });
        });
      })
      .catch((err) => {
        console.warn('SW registration failed', err);
      });
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      markSwUpdatePending();
    });
  });
}

// ——— Импорт резервных копий ———

function setBackupMessage(text, type = '') {
  const el = document.getElementById('backupImportMessage');
  if (!el) return;
  el.textContent = text;
  el.className = 'backup-import-message' + (type ? ` backup-import-message--${type}` : '');
}

function showBackupPreview(stats, fileName, fileSize) {
  const box = document.getElementById('backupPreview');
  if (!box) return;
  box.hidden = false;
  box.innerHTML = `
    <strong>Предпросмотр: ${fileName}</strong> (${GazpromBackup.formatBytes(fileSize)})
    <ul>
      <li>Версия: ${stats.version}</li>
      <li>Дата копии: ${GazpromBackup.formatDate(stats.timestamp)}</li>
      <li>Актов: ${stats.akts} · организаций: ${stats.organizations}</li>
      <li>Комиссия: ${stats.comission} · фото: ${stats.photos}</li>
    </ul>
  `;
}

function setBackupLoading(on, text = 'Импорт…') {
  const box = document.getElementById('backupLoading');
  const label = document.getElementById('backupLoadingText');
  if (box) box.hidden = !on;
  if (label) label.textContent = text;
}

function openBackupFilePicker() {
  document.getElementById('backupFileInput')?.click();
}

function openBackupModal() {
  const modal = document.getElementById('backupModal');
  if (!modal) return;
  modal.hidden = false;
  GazpromMobileOverlay.lock();
}

function closeBackupModal() {
  const modal = document.getElementById('backupModal');
  if (!modal || modal.hidden) return;
  modal.hidden = true;
  GazpromMobileOverlay.unlock();
}

async function handleBackupFile(file, { parsed: preParsed = null } = {}) {
  if (!file && !preParsed) return;

  const merge = document.getElementById('backupMergeCheckbox')?.checked ?? false;
  backupImportInProgress = true;
  setBackupLoading(true, 'Чтение файла…');
  setBackupMessage('');

  try {
    if (file?.size > 80 * 1024 * 1024) {
      const ok = await GazpromToast.confirm(
        `Файл большой (${GazpromBackup.formatBytes(file.size)}). Импорт может занять несколько минут. Продолжить?`
      );
      if (!ok) return;
    }

    setBackupLoading(true, 'Разбор JSON…');
    const preview = preParsed || (await GazpromBackup.parseFile(file));
    const previewName = file?.name || preview.sourceFileName || 'backup.json';
    const previewSize = file?.size ?? 0;
    showBackupPreview(GazpromBackup.getStats(preview), previewName, previewSize);

    setBackupLoading(true, 'Сохранение в браузер…');
    const importWithoutPhotos =
      document.getElementById('backupSkipPhotosCheckbox')?.checked ?? false;
    const { stats } = await GazpromBackup.importFile(file, {
      replace: !merge,
      parsed: preview,
      importWithoutPhotos,
    });

    GazpromStore.invalidateCache();
    await GazpromUI.refreshAll();
    const photoMsg =
      stats.photosIngestTotal != null
        ? `, фото в браузере: ${stats.photosStored ?? 0} из ${stats.photosIngestTotal}`
        : `, фото: ${stats.photos}`;
    setBackupMessage(
      `Готово: ${stats.akts} актов, ${stats.organizations} организаций${photoMsg}.`,
      'ok'
    );
    const toastPhoto =
      stats.photosIngestTotal != null
        ? ` (${stats.photosStored ?? 0}/${stats.photosIngestTotal} фото)`
        : '';
    GazpromToast.success(`Резервная копия загружена${toastPhoto}`);
    closeBackupModal();
    goTo('home');
    void ViolationTypesEditor.maybePromptAfterImport();
  } catch (err) {
    console.error(err);
    setBackupMessage(err.message || 'Ошибка импорта', 'error');
    GazpromToast.error(err.message || 'Ошибка импорта');
  } finally {
    backupImportInProgress = false;
    setBackupLoading(false);
  }
}

function scrollToBackupImport() {
  goTo('settings');
  document.querySelector('.backup-import-card')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function bindHistory() {
  const pills = document.querySelectorAll('#screen-history .filter-pill[data-filter]');
  const subPills = () => [...pills].filter((p) => p.dataset.filter !== 'all');
  const allPill = () => document.querySelector('#screen-history .filter-pill[data-filter="all"]');

  const applyFiltersFromPills = async () => {
    GazpromUI.setHistoryFilter(AktSearch.filterFromActivePills(subPills()));
    const data = await GazpromStore.get();
    GazpromUI.renderHistory(data);
  };

  const syncAllPill = () => {
    const all = allPill();
    if (!all) return;
    const subs = subPills();
    const allSubActive = subs.length > 0 && subs.every((p) => p.classList.contains('active'));
    const noneSubActive = subs.every((p) => !p.classList.contains('active'));
    all.classList.toggle('active', allSubActive || noneSubActive);
  };

  pills.forEach((btn) => {
    btn.addEventListener('click', async () => {
      if (btn.dataset.filter === 'all') {
        const subs = subPills();
        const allSubActive = subs.every((p) => p.classList.contains('active'));
        subs.forEach((p) => p.classList.toggle('active', !allSubActive));
        syncAllPill();
        await applyFiltersFromPills();
        return;
      }
      btn.classList.toggle('active');
      syncAllPill();
      await applyFiltersFromPills();
    });
  });

  document.getElementById('historySearch')?.addEventListener('input', async (e) => {
    GazpromUI.setHistoryQuery(e.target.value);
    const data = await GazpromStore.get();
    GazpromUI.renderHistory(data);
  });

  const openHistoryAkt = async (row) => {
    const aktId = row?.dataset?.aktId;
    if (!aktId) return;
    await CatalogService.rememberLastOpenedAkt(aktId);
    if (row.dataset.aktShort === '1') {
      ShortAktForm.open(aktId);
      return;
    }
    goTo('wizard', { aktId });
  };

  document.getElementById('historyList')?.addEventListener('click', async (e) => {
    const trashBtn = e.target.closest('[data-history-trash]');
    if (trashBtn) {
      e.stopPropagation();
      const id = trashBtn.dataset.historyTrash;
      if (!id) return;
      const catalog = await GazpromStore.get();
      if (!catalog) return;
      const akt = (catalog.akts || []).find((a) => a.id === id);
      if (!akt) return;
      const ok = await GazpromToast.confirm(
        `Переместить акт № ${akt.number} в корзину? Его можно будет восстановить в настройках.`
      );
      if (!ok) return;
      catalog.akts = (catalog.akts || []).filter((a) => a.id !== id);
      catalog.trash = [...(catalog.trash || []), akt];
      if (catalog.editableAkt?.akt?.id === id) {
        catalog.editableAkt = null;
        catalog.editableAktReference = null;
      }
      await GazpromStore.set(catalog);
      GazpromStore.invalidateCache();
      await GazpromUI.refreshAll();
      GazpromToast.success(`Акт № ${akt.number} перемещён в корзину`);
      return;
    }
    const row = e.target.closest('.history-row[data-akt-id]');
    if (!row) return;
    await openHistoryAkt(row);
  });

  document.getElementById('historyList')?.addEventListener('keydown', async (e) => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    const row = e.target.closest('.history-row[data-akt-id]');
    if (!row) return;
    e.preventDefault();
    await openHistoryAkt(row);
  });

  document.getElementById('homeShortAktBtn')?.addEventListener('click', () => {
    ShortAktForm.open();
  });
  document.getElementById('homeSubAction')?.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-short-continue]');
    if (!btn) return;
    ShortAktForm.open(btn.dataset.shortContinue);
  });

  const historySortToolbar = document.querySelector('#screen-history .history-list-toolbar');
  const handleHistorySort = async (btn) => {
    if (!btn?.dataset.sortKey) return;
    GazpromUI.toggleHistorySort(btn.dataset.sortKey);
    const data = await GazpromStore.get();
    GazpromUI.renderHistory(data);
  };
  historySortToolbar?.addEventListener('click', (e) => {
    const btn = e.target.closest('.history-sort-btn[data-sort-key]');
    if (!btn) return;
    handleHistorySort(btn);
  });
  historySortToolbar?.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    const btn = e.target.closest('.history-sort-btn[data-sort-key]');
    if (!btn) return;
    e.preventDefault();
    handleHistorySort(btn);
  });
}

function bindGlobalSearch() {
  const input = document.getElementById('globalSearch');
  if (!input) return;
  let timer = null;
  input.addEventListener('input', () => {
    clearTimeout(timer);
    timer = setTimeout(async () => {
      const q = input.value.trim();
      if (!q) return;
      GazpromUI.setHistoryQuery(q);
      const data = await GazpromStore.get();
      if (!GazpromStore.hasData(data)) return;
      goTo('history');
      const histInput = document.getElementById('historySearch');
      if (histInput) histInput.value = q;
      GazpromUI.renderHistory(data);
    }, 300);
  });
}

function bindReports() {
  ReportsDashboard.init();
}

function bindTrash() {
  document.querySelector('.settings-tile--trash')?.addEventListener('click', () => goTo('trash'));

  document.getElementById('trashTableBody')?.addEventListener('click', async (e) => {
    const restore = e.target.closest('[data-trash-restore]');
    const del = e.target.closest('[data-trash-delete]');
    const catalog = await GazpromStore.get();
    if (!catalog) return;

    if (restore) {
      const id = restore.dataset.trashRestore;
      const akt = (catalog.trash || []).find((a) => a.id === id);
      if (!akt) return;
      catalog.trash = catalog.trash.filter((a) => a.id !== id);
      catalog.akts = [...(catalog.akts || []), akt];
      await GazpromStore.set(catalog);
      GazpromStore.invalidateCache();
      await GazpromUI.refreshAll();
      GazpromToast.success(`Акт № ${akt.number} восстановлен`);
    }

    if (del) {
      const id = del.dataset.trashDelete;
      const ok = await GazpromToast.confirm('Удалить акт безвозвратно?');
      if (!ok) return;
      catalog.trash = (catalog.trash || []).filter((a) => a.id !== id);
      await GazpromStore.set(catalog);
      GazpromStore.invalidateCache();
      await GazpromUI.refreshAll();
      GazpromToast.success('Удалено из корзины');
    }
  });
}

function bindTemplateSettings() {
  document.querySelector('.settings-tile--template')?.addEventListener('click', () => {
    DefaultsBootstrap.openTemplateModal();
  });
  document.querySelector('.settings-tile--template')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      DefaultsBootstrap.openTemplateModal();
    }
  });
  DefaultsBootstrap.bindTemplateModal();
}

function init() {
  syncAppBuildLabel();
  bindNavigation();
  updateClock();
  setInterval(updateClock, 30000);
  registerServiceWorker();

  document.addEventListener('click', async (e) => {
    const el = e.target.closest('[data-go]');
    if (!el) return;
    const opts = {};
    if (el.dataset.wizardNew === '1') opts.forceNew = true;
    if (el.dataset.aktId) opts.aktId = el.dataset.aktId;
    const target = el.dataset.go;
    if (target === 'wizard' && opts.forceNew) {
      goTo('wizard', opts);
      return;
    }
    goTo(target, opts);
  });

  const backupTile = document.querySelector('.settings-tile--backup');
  backupTile?.addEventListener('click', () => openBackupModal());
  backupTile?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      openBackupModal();
    }
  });
  document.getElementById('backupModalClose')?.addEventListener('click', closeBackupModal);
  document.getElementById('backupModal')?.addEventListener('click', (e) => {
    if (e.target === e.currentTarget) closeBackupModal();
  });
  document.getElementById('backupExportBtn')?.addEventListener('click', async () => {
    try {
      await CatalogService.exportBackup();
      GazpromToast.show('Резервная копия скачана', 'success');
    } catch (e) {
      GazpromToast.show('Ошибка экспорта: ' + e.message, 'error');
    }
  });
  document.querySelector('.settings-tile--schedule')?.addEventListener('click', () => ScheduleEditor.open());

  const backupFileInput = document.getElementById('backupFileInput');
  if (backupFileInput) {
    const isCoarsePointer = window.matchMedia('(pointer: coarse)').matches;
    backupFileInput.accept = isCoarsePointer ? GazpromBackup.ACCEPT_MOBILE : GazpromBackup.ACCEPT;
  }
  backupFileInput?.addEventListener('change', (e) => {
    const input = e.target;
    const file = input.files?.[0];
    if (!file) return;
    const fileName = file.name || 'backup.json';
    void (async () => {
      try {
        const text = await GazpromBackup.readFileText(file);
        const parsed = GazpromBackup.parseJsonText(text, fileName);
        await handleBackupFile(file, { parsed });
      } catch (err) {
        console.error(err);
        setBackupMessage(err.message || 'Ошибка чтения файла', 'error');
        GazpromToast.error(err.message || 'Ошибка чтения файла');
      } finally {
        input.value = '';
      }
    })();
  });

  const pasteArea = document.getElementById('backupPasteArea');
  document.getElementById('backupPasteBtn')?.addEventListener('click', () => {
    if (pasteArea) pasteArea.hidden = false;
    document.getElementById('backupPasteText')?.focus();
  });
  document.getElementById('backupPasteCancelBtn')?.addEventListener('click', () => {
    if (pasteArea) pasteArea.hidden = true;
    const ta = document.getElementById('backupPasteText');
    if (ta) ta.value = '';
  });
  document.getElementById('backupPasteImportBtn')?.addEventListener('click', () => {
    const text = document.getElementById('backupPasteText')?.value?.trim();
    if (!text) { setBackupMessage('Вставьте содержимое файла резервной копии', 'error'); return; }
    const file = new File([text], 'backup-paste.json', { type: 'application/json' });
    if (pasteArea) pasteArea.hidden = true;
    const ta = document.getElementById('backupPasteText');
    if (ta) ta.value = '';
    handleBackupFile(file);
  });

  document.getElementById('backupClearBtn')?.addEventListener('click', async () => {
    const ok = await GazpromToast.confirm('Удалить все загруженные данные из браузера?');
    if (!ok) return;
    await GazpromStore.clear();
    GazpromStore.invalidateCache();
    await GazpromUI.refreshAll();
    const preview = document.getElementById('backupPreview');
    if (preview) preview.hidden = true;
    setBackupMessage('Данные очищены', 'ok');
    GazpromToast.success('Данные очищены');
  });

  const importCard = document.querySelector('.backup-import-card');
  if (importCard) {
    ['dragenter', 'dragover'].forEach((ev) => {
      importCard.addEventListener(ev, (e) => {
        e.preventDefault();
        importCard.classList.add('backup-import-card--drag');
      });
    });
    ['dragleave', 'drop'].forEach((ev) => {
      importCard.addEventListener(ev, (e) => {
        e.preventDefault();
        importCard.classList.remove('backup-import-card--drag');
      });
    });
    importCard.addEventListener('drop', (e) => {
      const file = e.dataTransfer?.files?.[0];
      if (file) handleBackupFile(file);
    });
  }

  AktUtils.bindAutoCapitalize();

  bindHeaderSync();
  bindHistory();
  bindGlobalSearch();
  bindReports();
  bindTrash();
  bindTemplateSettings();
  document.getElementById('homeRestoreBackupBtn')?.addEventListener('click', () => {
    goTo('settings');
    requestAnimationFrame(() => openBackupModal());
  });
  CatalogEditor.bindSettingsTiles();
  ViolationTypesEditor.init();
  ViolationRegistry.bindScreen();
  DefaultsBootstrap.bindRegistryModal();
  EliminationEditor.bindFilters();
  EliminationEditor.bindBulkActions();
  EliminationEditor.bindTableActions();

  const handleAppBackground = () => {
    if (hasEditingOverlay()) {
      return;
    }
    if (typeof WizardController?.flushSave === 'function') void WizardController.flushSave();
    if (typeof EliminationEditor?.flushPersist === 'function') void EliminationEditor.flushPersist();
    void GazpromStore.flushToDisk();
  };

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') handleAppBackground();
  });
  window.addEventListener('pagehide', handleAppBackground);

  void GazpromStore.requestPersistence();

  void DefaultsBootstrap.ensureSeeded()
    .then(() => GazpromUI.refreshAll())
    .catch(console.error);
}

init();
