/**
 * Встроенные по умолчанию реестр нарушений и Word-шаблон акта.
 * Подстановка при первом запуске; восстановление из Настроек / экрана реестра.
 */
const DefaultsBootstrap = (() => {
  const REGISTRY_JSON = './assets/defaults/violation-registry.json';
  const TEMPLATE_DOCX = './assets/defaults/akt-template.docx';
  const BUILTIN_TEMPLATE_NAME = 'Шаблон_12.10.25.docx';
  const BUILTIN_REGISTRY_LABEL = 'Реестр_нарушений-2';
  const PRESET_ID = 'default';

  let registryCache = null;
  let templateB64Cache = null;

  function escHtml(s) {
    return String(s ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function isCoarsePointer() {
    return window.matchMedia('(pointer: coarse)').matches;
  }

  async function fetchRegistryPayload() {
    if (registryCache) return registryCache;
    const res = await fetch(REGISTRY_JSON, { cache: 'no-cache' });
    if (!res.ok) throw new Error('Не удалось загрузить стандартный реестр');
    registryCache = await res.json();
    return registryCache;
  }

  async function fetchTemplateBase64() {
    if (templateB64Cache) return templateB64Cache;
    const res = await fetch(TEMPLATE_DOCX, { cache: 'no-cache' });
    if (!res.ok) throw new Error('Не удалось загрузить стандартный шаблон Word');
    const buf = await res.arrayBuffer();
    const bytes = new Uint8Array(buf);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    templateB64Cache = btoa(binary);
    return templateB64Cache;
  }

  function mapRegistryItems(rawItems) {
    return (rawItems || []).map((item, index) => ({
      id: AktUtils.uuid(),
      number: item.number || index + 1,
      title: String(item.title || '').trim(),
      subTitle: String(item.subTitle || '').trim(),
      description: String(item.description || '').trim(),
      vid: String(item.vid || '').trim(),
      formulaFromRules: String(item.formulaFromRules || '').trim(),
    })).filter((x) => x.title);
  }

  async function loadBuiltinRegistryItems() {
    const payload = await fetchRegistryPayload();
    return mapRegistryItems(payload.items || []);
  }

  async function clearTemplateSidecar() {
    try {
      await GazpromIdb.transaction('app', 'readwrite', (tx) => {
        tx.objectStore('app').delete('wordTemplateSidecar');
      });
    } catch {
      /* ignore */
    }
  }

  async function applyBuiltinTemplateToCatalog(catalog) {
    const b64 = await fetchTemplateBase64();
    const templateKey = DocGenerator?.TEMPLATE_KEY || 'wordTemplate';
    catalog[templateKey] = b64;
    catalog.wordTemplate = b64;
    catalog.wordTemplateName = BUILTIN_TEMPLATE_NAME;
    catalog.wordTemplateSource = 'builtin';
    catalog.wordTemplatePreset = PRESET_ID;
    catalog.wordTemplateOffloaded = false;
    catalog.mobileStrippedTemplate = false;
    await clearTemplateSidecar();
    return catalog;
  }

  async function hasWordTemplate(catalog) {
    const c = catalog || (await GazpromStore.get());
    const key = DocGenerator?.TEMPLATE_KEY || 'wordTemplate';
    return Boolean(c?.[key] || c?.wordTemplate || c?.wordTemplateOffloaded);
  }

  async function ensureSeeded() {
    const catalog = await GazpromStore.get();
    if (!GazpromStore.isReady(catalog)) return catalog;

    let changed = false;
    const registry = catalog.violationRegistry || [];

    if (registry.length === 0 && catalog.violationRegistrySource !== 'custom') {
      try {
        const items = await loadBuiltinRegistryItems();
        if (items.length) {
          catalog.violationRegistry = items;
          catalog.violationRegistrySource = 'builtin';
          catalog.violationRegistryPreset = PRESET_ID;
          catalog.violationRegistryLabel = BUILTIN_REGISTRY_LABEL;
          changed = true;
        }
      } catch (err) {
        console.warn('[DefaultsBootstrap] registry seed failed:', err);
      }
    }

    if (!(await hasWordTemplate(catalog)) && catalog.wordTemplateSource !== 'custom') {
      try {
        await applyBuiltinTemplateToCatalog(catalog);
        changed = true;
      } catch (err) {
        console.warn('[DefaultsBootstrap] template seed failed:', err);
      }
    }

    if (changed) {
      await GazpromStore.set(catalog, { skipPhotoIngest: true });
      GazpromStore.invalidateCache();
    }

    return catalog;
  }

  async function restoreBuiltinRegistry({ replace = true } = {}) {
    const items = await loadBuiltinRegistryItems();
    if (!items.length) throw new Error('Стандартный реестр пуст');

    const catalog = await GazpromStore.get();
    if (replace) {
      catalog.violationRegistry = items;
    } else {
      const merged = [...(catalog.violationRegistry || [])];
      for (const item of items) {
        const dup = merged.find((x) => x.title === item.title && x.subTitle === item.subTitle);
        if (!dup) merged.push(item);
      }
      catalog.violationRegistry = merged;
    }
    catalog.violationRegistrySource = 'builtin';
    catalog.violationRegistryPreset = PRESET_ID;
    catalog.violationRegistryLabel = BUILTIN_REGISTRY_LABEL;
    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
    await GazpromUI?.refreshAll?.();
    return catalog.violationRegistry.length;
  }

  async function restoreBuiltinTemplate() {
    const catalog = await GazpromStore.get();
    await applyBuiltinTemplateToCatalog(catalog);
    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
    await GazpromUI?.refreshAll?.();
  }

  async function saveCustomTemplate(file) {
    const buf = await file.arrayBuffer();
    const bytes = new Uint8Array(buf);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    const b64 = btoa(binary);
    const catalog = (await GazpromStore.get()) || { akts: [] };
    const templateKey = DocGenerator?.TEMPLATE_KEY || 'wordTemplate';
    catalog[templateKey] = b64;
    catalog.wordTemplate = b64;
    catalog.wordTemplateName = file.name;
    catalog.wordTemplateSource = 'custom';
    catalog.wordTemplatePreset = null;
    catalog.wordTemplateOffloaded = false;
    catalog.mobileStrippedTemplate = false;
    await clearTemplateSidecar();

    if (isCoarsePointer() && b64.length > 50000) {
      await GazpromIdb.transaction('app', 'readwrite', (tx) => {
        tx.objectStore('app').put({ data: b64, name: file.name }, 'wordTemplateSidecar');
      });
      catalog[templateKey] = null;
      catalog.wordTemplate = null;
      catalog.wordTemplateOffloaded = true;
    }

    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
  }

  function markRegistryCustom(catalog) {
    catalog.violationRegistrySource = 'custom';
    catalog.violationRegistryPreset = null;
    return catalog;
  }

  function registrySourceLabel(catalog) {
    const src = catalog?.violationRegistrySource;
    if (src === 'builtin') return `Стандартный (${catalog.violationRegistryLabel || BUILTIN_REGISTRY_LABEL})`;
    if (src === 'custom') return 'Свой реестр';
    const n = catalog?.violationRegistry?.length || 0;
    return n ? 'Загруженный' : 'Не задан';
  }

  function templateSourceLabel(catalog) {
    const src = catalog?.wordTemplateSource;
    if (src === 'builtin') return `Встроенный (${BUILTIN_TEMPLATE_NAME})`;
    if (src === 'custom') return catalog?.wordTemplateName || 'Свой шаблон';
    return catalog?.wordTemplateName ? catalog.wordTemplateName : 'Не загружен';
  }

  /* ——— Модал: шаблон акта ——— */

  function closeTemplateModal() {
    const modal = document.getElementById('templateModal');
    if (!modal) return;
    modal.hidden = true;
    GazpromMobileOverlay?.unlock?.();
  }

  async function refreshTemplateModal() {
    const catalog = await GazpromStore.get();
    const nameEl = document.getElementById('templateModalCurrentName');
    const sourceEl = document.getElementById('templateModalCurrentSource');
    const statusEl = document.getElementById('templateModalStatus');
    const has = await hasWordTemplate(catalog);

    if (nameEl) {
      nameEl.textContent = has
        ? (catalog.wordTemplateName || BUILTIN_TEMPLATE_NAME)
        : '—';
    }
    if (sourceEl) {
      sourceEl.textContent = templateSourceLabel(catalog);
    }
    if (statusEl) {
      statusEl.textContent = has ? '✅ Готов к генерации актов' : '⚠️ Шаблон не загружен';
      statusEl.className = `defaults-status ${has ? 'defaults-status--ok' : 'defaults-status--warn'}`;
    }
  }

  function openTemplateModal() {
    const modal = document.getElementById('templateModal');
    if (!modal) return;
    modal.hidden = false;
    GazpromMobileOverlay?.lock?.();
    void refreshTemplateModal();
  }

  function bindTemplateModal() {
    const modal = document.getElementById('templateModal');
    if (!modal || modal.dataset.bound === '1') return;
    modal.dataset.bound = '1';

    document.getElementById('templateModalClose')?.addEventListener('click', closeTemplateModal);
    modal.addEventListener('click', (e) => {
      if (e.target === modal) closeTemplateModal();
    });

    document.getElementById('templateModalUploadBtn')?.addEventListener('click', () => {
      document.getElementById('wordTemplateInput')?.click();
    });

    document.getElementById('templateModalRestoreBtn')?.addEventListener('click', async () => {
      const ok = await GazpromToast.confirm(
        'Вернуть стандартный шаблон акта?\nТекущий файл будет заменён.',
        { confirmLabel: 'Вернуть стандартный' }
      );
      if (!ok) return;
      try {
        GazpromToast.info('Загрузка стандартного шаблона…');
        await restoreBuiltinTemplate();
        await refreshTemplateModal();
        GazpromToast.success('Стандартный шаблон восстановлен');
      } catch (err) {
        GazpromToast.error(err.message);
      }
    });

    document.getElementById('wordTemplateInput')?.addEventListener('change', async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      try {
        GazpromToast.info('Сохранение шаблона…');
        await saveCustomTemplate(file);
        await GazpromUI?.refreshAll?.();
        await refreshTemplateModal();
        GazpromToast.success('Шаблон Word сохранён');
      } catch (err) {
        GazpromToast.error(err.message);
      } finally {
        e.target.value = '';
      }
    });
  }

  return {
    ensureSeeded,
    restoreBuiltinRegistry,
    restoreBuiltinTemplate,
    saveCustomTemplate,
    markRegistryCustom,
    registrySourceLabel,
    templateSourceLabel,
    hasWordTemplate,
    openTemplateModal,
    bindTemplateModal,
    BUILTIN_TEMPLATE_NAME,
    BUILTIN_REGISTRY_LABEL,
    escHtml,
  };
})();
