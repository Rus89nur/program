/** Газпром — веб-приложение: навигация, PWA, импорт, экраны */
const titles = {
  home: 'Главная',
  wizard: 'Новый акт',
  history: 'История',
  reports: 'Отчёты',
  elimination: 'Устранение',
  settings: 'Настройки',
  trash: 'Корзина',
  violations: 'Реестр нарушений',
};

function goTo(screenId, options = {}) {
  document.querySelectorAll('.nav-item, .bottom-nav-item').forEach((n) => {
    n.classList.toggle('active', n.dataset.screen === screenId);
  });
  document.querySelectorAll('.screen').forEach((s) => s.classList.remove('active'));
  document.getElementById('screen-' + screenId)?.classList.add('active');
  document.getElementById('pageTitle').textContent = titles[screenId] || screenId;

  if (screenId === 'wizard' && !options.skipWizardReload) {
    WizardController.open(options.aktId ?? null);
  }
  if (screenId === 'violations') {
    ViolationRegistry.renderScreen();
  }
}

function bindNavigation() {
  document.querySelectorAll('.nav-item, .bottom-nav-item').forEach((btn) => {
    btn.addEventListener('click', () => goTo(btn.dataset.screen));
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
    navigator.serviceWorker.register('./sw.js')
      .then((reg) => {
        reg.update();
        reg.addEventListener('updatefound', () => {
          const newSW = reg.installing;
          if (!newSW) return;
          newSW.addEventListener('statechange', () => {
            if (newSW.state === 'activated') location.reload();
          });
        });
      })
      .catch((err) => {
        console.warn('SW registration failed', err);
      });
    navigator.serviceWorker.addEventListener('controllerchange', () => location.reload());
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

async function handleBackupFile(file) {
  if (!file) return;

  const merge = document.getElementById('backupMergeCheckbox')?.checked ?? false;
  setBackupLoading(true, 'Чтение файла…');
  setBackupMessage('');

  try {
    if (file.size > 80 * 1024 * 1024) {
      const ok = await GazpromToast.confirm(
        `Файл большой (${GazpromBackup.formatBytes(file.size)}). Импорт может занять несколько минут. Продолжить?`
      );
      if (!ok) return;
    }

    setBackupLoading(true, 'Разбор JSON…');
    const preview = await GazpromBackup.parseFile(file);
    showBackupPreview(GazpromBackup.getStats(preview), file.name, file.size);

    setBackupLoading(true, 'Сохранение в браузер…');
    const { stats } = await GazpromBackup.importFile(file, { replace: !merge, parsed: preview });

    GazpromStore.invalidateCache();
    await GazpromUI.refreshAll();
    setBackupMessage(
      `Готово: ${stats.akts} актов, ${stats.organizations} организаций, ${stats.photos} фото.`,
      'ok'
    );
    GazpromToast.success('Резервная копия загружена');
    const backupModal = document.getElementById('backupModal');
    if (backupModal) backupModal.hidden = true;
    goTo('home');
  } catch (err) {
    console.error(err);
    setBackupMessage(err.message || 'Ошибка импорта', 'error');
    GazpromToast.error(err.message || 'Ошибка импорта');
  } finally {
    setBackupLoading(false);
  }
}

function scrollToBackupImport() {
  goTo('settings');
  document.querySelector('.backup-import-card')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function bindHistory() {
  const pills = document.querySelectorAll('#screen-history .filter-pill');
  pills.forEach((btn) => {
    btn.addEventListener('click', async () => {
      pills.forEach((p) => p.classList.remove('active'));
      btn.classList.add('active');
      const parsed = AktSearch.parseFilterPill(btn.textContent);
      GazpromUI.setHistoryFilter(parsed);
      const data = await GazpromStore.get();
      GazpromUI.renderHistory(data);
    });
  });

  document.getElementById('historySearch')?.addEventListener('input', async (e) => {
    GazpromUI.setHistoryQuery(e.target.value);
    const data = await GazpromStore.get();
    GazpromUI.renderHistory(data);
  });

  document.getElementById('historyExportBtn')?.addEventListener('click', async () => {
    try {
      await ReportExporter.exportHistory();
    } catch (e) {
      GazpromToast.error(e.message);
    }
  });

  document.getElementById('historyTableBody')?.addEventListener('click', async (e) => {
    const btn = e.target.closest('[data-akt-open]');
    if (!btn) return;
    goTo('wizard', { aktId: btn.dataset.aktOpen });
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
  const tiles = document.querySelectorAll('#screen-reports .stat-card--clickable');
  const actions = [
    () => ReportExporter.exportViolationsReport(),
    () => ScheduleEditor.open(),
    () => ReportExporter.exportHistory(),
  ];
  tiles.forEach((tile, i) => {
    tile.addEventListener('click', async () => {
      try {
        if (actions[i]) await actions[i]();
      } catch (e) {
        GazpromToast.error(e.message);
      }
    });
  });
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

function bindTemplateUpload() {
  document.querySelector('.settings-tile--template')?.addEventListener('click', () => {
    document.getElementById('wordTemplateInput')?.click();
  });
  document.getElementById('wordTemplateInput')?.addEventListener('change', async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      await DocGenerator.saveTemplate(file);
      await GazpromUI.refreshAll();
    } catch (err) {
      GazpromToast.error(err.message);
    }
    e.target.value = '';
  });
}

function init() {
  bindNavigation();
  updateClock();
  setInterval(updateClock, 30000);
  registerServiceWorker();

  document.querySelectorAll('[data-go]').forEach((el) => {
    el.addEventListener('click', () => goTo(el.dataset.go));
  });

  document.querySelector('.settings-tile--backup')?.addEventListener('click', () => {
    document.getElementById('backupModal').hidden = false;
  });
  document.getElementById('backupModalClose')?.addEventListener('click', () => {
    document.getElementById('backupModal').hidden = true;
  });
  document.getElementById('backupModal')?.addEventListener('click', (e) => {
    if (e.target === e.currentTarget) e.currentTarget.hidden = true;
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
    if (!isCoarsePointer) backupFileInput.accept = GazpromBackup.ACCEPT;
  }
  document.getElementById('backupFileSelectBtn')?.addEventListener('click', () => {
    backupFileInput?.click();
  });
  backupFileInput?.addEventListener('change', (e) => {
    const input = e.target;
    const file = input.files?.[0];
    if (!file) return;
    handleBackupFile(file).finally(() => {
      input.value = '';
    });
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

  bindHistory();
  bindGlobalSearch();
  bindReports();
  bindTrash();
  bindTemplateUpload();
  CatalogEditor.bindSettingsTiles();
  ViolationRegistry.bindScreen();
  EliminationEditor.bindFilters();
  EliminationEditor.bindTableActions();

  GazpromUI.refreshAll().catch(console.error);
}

init();
