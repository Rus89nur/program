/**
 * Встроенные и пользовательские пресеты: реестр нарушений и Word-шаблон.
 * Визуальный выбор карточками в настройках и на экране реестра.
 */
const DefaultsBootstrap = (() => {
  const MANIFEST_URL = './assets/defaults/manifest.json';
  const LEGACY_REGISTRY_JSON = './assets/defaults/violation-registry.json';
  const LEGACY_TEMPLATE_DOCX = './assets/defaults/akt-template.docx';
  const LEGACY_SPRAVKA_TEMPLATE_DOCX = './assets/defaults/Шаблон_справки_ПБ.docx';

  let manifestCache = null;
  const registryJsonCache = new Map();
  const templateB64Cache = new Map();

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

  async function loadManifest() {
    if (manifestCache) return manifestCache;
    const res = await fetch(MANIFEST_URL, { cache: 'no-cache' });
    if (!res.ok) throw new Error('Не удалось загрузить каталог пресетов');
    manifestCache = await res.json();
    return manifestCache;
  }

  function ensureLibraries(catalog) {
    if (!Array.isArray(catalog.savedTemplates)) catalog.savedTemplates = [];
    if (!Array.isArray(catalog.savedSpravkaTemplates)) catalog.savedSpravkaTemplates = [];
    if (!Array.isArray(catalog.savedRegistries)) catalog.savedRegistries = [];
    return catalog;
  }

  function migrateCatalog(catalog) {
    ensureLibraries(catalog);
    let changed = false;
    const defaultTemplateId = manifestCache?.templates?.[0]?.id || 'builtin-template-v1';
    const defaultRegistryId = manifestCache?.registries?.[0]?.id || 'builtin-registry-v1';
    const defaultSpravkaTemplateId = manifestCache?.spravkaTemplates?.[0]?.id || 'builtin-spravka-v1';

    if (!catalog.activeTemplatePresetId) {
      if (catalog.wordTemplateSource === 'builtin') {
        catalog.activeTemplatePresetId = defaultTemplateId;
        changed = true;
      } else if (catalog.wordTemplateName) {
        const key = DocGenerator?.TEMPLATE_KEY || 'wordTemplate';
        const data = catalog[key] || catalog.wordTemplate;
        if (data && catalog.savedTemplates.length === 0) {
          catalog.savedTemplates.push({
            id: AktUtils.uuid(),
            name: catalog.wordTemplateName,
            data,
            createdAt: new Date().toISOString(),
          });
          catalog.activeTemplatePresetId = catalog.savedTemplates[0].id;
          changed = true;
        }
      }
    }

    if (!catalog.activeRegistryPresetId) {
      if (catalog.violationRegistrySource === 'builtin') {
        catalog.activeRegistryPresetId = defaultRegistryId;
        changed = true;
      } else if ((catalog.violationRegistry || []).length && catalog.savedRegistries.length === 0) {
        catalog.savedRegistries.push({
          id: AktUtils.uuid(),
          name: catalog.violationRegistryLabel || 'Мой реестр',
          label: catalog.violationRegistryLabel || 'Импорт',
          items: AktUtils.clone(catalog.violationRegistry || []),
          createdAt: new Date().toISOString(),
        });
        catalog.activeRegistryPresetId = catalog.savedRegistries[0].id;
        changed = true;
      }
    }

    if (!catalog.activeSpravkaTemplatePresetId) {
      const spravkaKey = DocGenerator?.SPRAVKA_TEMPLATE_KEY || 'spravkaTemplate';
      if (catalog.spravkaTemplateSource === 'builtin') {
        catalog.activeSpravkaTemplatePresetId = defaultSpravkaTemplateId;
        changed = true;
      } else if (catalog.spravkaTemplateName && catalog[spravkaKey]) {
        if (catalog.savedSpravkaTemplates.length === 0) {
          catalog.savedSpravkaTemplates.push({
            id: AktUtils.uuid(),
            name: catalog.spravkaTemplateName,
            data: catalog[spravkaKey],
            createdAt: new Date().toISOString(),
          });
          catalog.activeSpravkaTemplatePresetId = catalog.savedSpravkaTemplates[0].id;
          changed = true;
        }
      }
    }

    return changed;
  }

  async function fetchRegistryPayload(url) {
    if (registryJsonCache.has(url)) return registryJsonCache.get(url);
    const res = await fetch(url, { cache: 'no-cache' });
    if (!res.ok) throw new Error('Не удалось загрузить реестр');
    const payload = await res.json();
    registryJsonCache.set(url, payload);
    return payload;
  }

  async function fetchTemplateBase64(url) {
    if (templateB64Cache.has(url)) return templateB64Cache.get(url);
    const res = await fetch(url, { cache: 'no-cache' });
    if (!res.ok) throw new Error('Не удалось загрузить шаблон Word');
    const buf = await res.arrayBuffer();
    const bytes = new Uint8Array(buf);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    const b64 = btoa(binary);
    templateB64Cache.set(url, b64);
    return b64;
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

  function cloneRegistryItems(items) {
    return (items || []).map((item, index) => ({
      ...item,
      id: AktUtils.uuid(),
      number: item.number || index + 1,
    }));
  }

  async function getBuiltinRegistryMeta(id) {
    const manifest = await loadManifest();
    return manifest.registries?.find((r) => r.id === id)
      || manifest.registries?.[0]
      || { id: 'builtin-registry-v1', json: LEGACY_REGISTRY_JSON, name: 'Реестр_нарушений-2' };
  }

  async function getBuiltinTemplateMeta(id) {
    const manifest = await loadManifest();
    return manifest.templates?.find((t) => t.id === id)
      || manifest.templates?.[0]
      || { id: 'builtin-template-v1', docx: LEGACY_TEMPLATE_DOCX, name: 'Шаблон_12.10.25.docx' };
  }

  async function loadBuiltinRegistryItems(presetId) {
    const meta = await getBuiltinRegistryMeta(presetId);
    const payload = await fetchRegistryPayload(meta.json || LEGACY_REGISTRY_JSON);
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

  async function writeTemplateToCatalog(catalog, b64, name, { presetId, source }) {
    const templateKey = DocGenerator?.TEMPLATE_KEY || 'wordTemplate';
    catalog[templateKey] = b64;
    catalog.wordTemplate = b64;
    catalog.wordTemplateName = name;
    catalog.wordTemplateSource = source;
    catalog.wordTemplatePreset = source === 'builtin' ? presetId : null;
    catalog.activeTemplatePresetId = presetId;
    catalog.wordTemplateOffloaded = false;
    catalog.mobileStrippedTemplate = false;
    await clearTemplateSidecar();

    if (isCoarsePointer() && b64.length > 50000) {
      await GazpromIdb.transaction('app', 'readwrite', (tx) => {
        tx.objectStore('app').put({ data: b64, name }, 'wordTemplateSidecar');
      });
      catalog[templateKey] = null;
      catalog.wordTemplate = null;
      catalog.wordTemplateOffloaded = true;
    }
    return catalog;
  }

  async function applyTemplatePreset(presetId) {
    const catalog = ensureLibraries(await GazpromStore.get());
    const manifest = await loadManifest();
    const builtin = manifest.templates?.find((t) => t.id === presetId);

    if (builtin) {
      const b64 = await fetchTemplateBase64(builtin.docx || LEGACY_TEMPLATE_DOCX);
      await writeTemplateToCatalog(catalog, b64, builtin.name, { presetId: builtin.id, source: 'builtin' });
    } else {
      const saved = catalog.savedTemplates.find((t) => t.id === presetId);
      if (!saved?.data) throw new Error('Шаблон не найден');
      await writeTemplateToCatalog(catalog, saved.data, saved.name, { presetId: saved.id, source: 'custom' });
    }

    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
    await GazpromUI?.refreshAll?.();
  }

  async function getBuiltinSpravkaTemplateMeta(id) {
    const manifest = await loadManifest();
    return manifest.spravkaTemplates?.find((t) => t.id === id)
      || manifest.spravkaTemplates?.[0]
      || { id: 'builtin-spravka-v1', docx: LEGACY_SPRAVKA_TEMPLATE_DOCX, name: 'Шаблон_справки_ПБ.docx' };
  }

  async function writeSpravkaTemplateToCatalog(catalog, b64, name, { presetId, source }) {
    const templateKey = DocGenerator?.SPRAVKA_TEMPLATE_KEY || 'spravkaTemplate';
    catalog[templateKey] = b64;
    catalog.spravkaTemplateName = name;
    catalog.spravkaTemplateSource = source;
    catalog.spravkaTemplatePreset = source === 'builtin' ? presetId : null;
    catalog.activeSpravkaTemplatePresetId = presetId;
    catalog.spravkaTemplateOffloaded = false;
    return catalog;
  }

  async function applySpravkaTemplatePreset(presetId) {
    const catalog = ensureLibraries(await GazpromStore.get());
    const manifest = await loadManifest();
    const builtin = manifest.spravkaTemplates?.find((t) => t.id === presetId);

    if (builtin) {
      const b64 = await fetchTemplateBase64(builtin.docx || LEGACY_SPRAVKA_TEMPLATE_DOCX);
      await writeSpravkaTemplateToCatalog(catalog, b64, builtin.name, { presetId: builtin.id, source: 'builtin' });
    } else {
      const saved = catalog.savedSpravkaTemplates.find((t) => t.id === presetId);
      if (!saved?.data) throw new Error('Шаблон справки не найден');
      await writeSpravkaTemplateToCatalog(catalog, saved.data, saved.name, { presetId: saved.id, source: 'custom' });
    }

    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
    await GazpromUI?.refreshAll?.();
  }

  async function applyRegistryPreset(presetId, { merge = false } = {}) {
    const catalog = ensureLibraries(await GazpromStore.get());
    const manifest = await loadManifest();
    const builtin = manifest.registries?.find((r) => r.id === presetId);
    let items = [];

    if (builtin) {
      items = await loadBuiltinRegistryItems(builtin.id);
      catalog.violationRegistrySource = 'builtin';
      catalog.violationRegistryLabel = builtin.name;
    } else {
      const saved = catalog.savedRegistries.find((r) => r.id === presetId);
      if (!saved?.items?.length) throw new Error('Реестр не найден');
      items = cloneRegistryItems(saved.items);
      catalog.violationRegistrySource = 'custom';
      catalog.violationRegistryLabel = saved.label || saved.name;
    }

    if (merge && (catalog.violationRegistry || []).length) {
      const merged = [...catalog.violationRegistry];
      for (const item of items) {
        const dup = merged.find((x) => x.title === item.title && x.subTitle === item.subTitle);
        if (!dup) merged.push(item);
      }
      catalog.violationRegistry = merged;
    } else {
      catalog.violationRegistry = items;
    }

    catalog.activeRegistryPresetId = presetId;
    catalog.violationRegistryPreset = builtin ? presetId : null;
    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
    await GazpromUI?.refreshAll?.();
    return catalog.violationRegistry.length;
  }

  async function hasWordTemplate(catalog) {
    const c = catalog || (await GazpromStore.get());
    const key = DocGenerator?.TEMPLATE_KEY || 'wordTemplate';
    return Boolean(c?.[key] || c?.wordTemplate || c?.wordTemplateOffloaded);
  }

  async function ensureSeeded() {
    await loadManifest();
    let catalog = ensureLibraries(await GazpromStore.get());
    if (!GazpromStore.isReady(catalog)) return catalog;

    catalog = ensureLibraries(catalog);
    const migrated = migrateCatalog(catalog);
    let changed = migrated;
    const registry = catalog.violationRegistry || [];
    const defaultRegistryId = manifestCache.registries?.[0]?.id || 'builtin-registry-v1';
    const defaultTemplateId = manifestCache.templates?.[0]?.id || 'builtin-template-v1';

    if (registry.length === 0 && catalog.violationRegistrySource !== 'custom') {
      try {
        const items = await loadBuiltinRegistryItems(defaultRegistryId);
        if (items.length) {
          catalog.violationRegistry = items;
          catalog.violationRegistrySource = 'builtin';
          catalog.activeRegistryPresetId = defaultRegistryId;
          catalog.violationRegistryLabel = manifestCache.registries[0].name;
          changed = true;
        }
      } catch (err) {
        console.warn('[DefaultsBootstrap] registry seed failed:', err);
      }
    }

    if (!(await hasWordTemplate(catalog)) && catalog.wordTemplateSource !== 'custom') {
      try {
        await applyTemplatePreset(defaultTemplateId);
        changed = false;
      } catch (err) {
        console.warn('[DefaultsBootstrap] template seed failed:', err);
      }
    }

    if (!hasSpravkaTemplate(catalog) && catalog.spravkaTemplateSource !== 'custom') {
      try {
        const defaultSpravkaId = manifestCache.spravkaTemplates?.[0]?.id || 'builtin-spravka-v1';
        await applySpravkaTemplatePreset(defaultSpravkaId);
      } catch (err) {
        console.warn('[DefaultsBootstrap] spravka template seed failed:', err);
      }
    }

    if (changed) {
      await GazpromStore.set(catalog, { skipPhotoIngest: true });
      GazpromStore.invalidateCache();
    }

    return catalog;
  }

  async function listTemplatePresets(catalog) {
    const manifest = await loadManifest();
    const c = ensureLibraries(catalog || (await GazpromStore.get()));
    migrateCatalog(c);
    const activeId = c.activeTemplatePresetId || manifest.templates?.[0]?.id;
    const builtins = (manifest.templates || []).map((t) => ({
      id: t.id,
      name: t.name,
      label: t.label || 'Встроенный',
      subtitle: t.subtitle || 'Word .docx',
      kind: 'builtin',
      active: t.id === activeId,
    }));
    const customs = (c.savedTemplates || []).map((t) => ({
      id: t.id,
      name: t.name,
      label: 'Свой шаблон',
      subtitle: t.name,
      kind: 'custom',
      active: t.id === activeId,
    }));
    return [...builtins, ...customs];
  }

  function hasSpravkaTemplate(catalog) {
    if (typeof DocGenerator?.hasSpravkaTemplate === 'function') {
      return DocGenerator.hasSpravkaTemplate(catalog);
    }
    const key = DocGenerator?.SPRAVKA_TEMPLATE_KEY || 'spravkaTemplate';
    return Boolean(catalog?.[key] || catalog?.spravkaTemplateOffloaded || catalog?.spravkaTemplateSource === 'builtin');
  }

  async function listSpravkaTemplatePresets(catalog) {
    const manifest = await loadManifest();
    const c = ensureLibraries(catalog || (await GazpromStore.get()));
    migrateCatalog(c);
    const activeId = c.activeSpravkaTemplatePresetId || manifest.spravkaTemplates?.[0]?.id;
    const builtins = (manifest.spravkaTemplates || []).map((t) => ({
      id: t.id,
      name: t.name,
      label: t.label || 'Встроенный',
      subtitle: t.subtitle || 'Справка по ПБ',
      kind: 'builtin',
      active: t.id === activeId,
    }));
    const customs = (c.savedSpravkaTemplates || []).map((t) => ({
      id: t.id,
      name: t.name,
      label: 'Свой шаблон',
      subtitle: t.name,
      kind: 'custom',
      active: t.id === activeId,
    }));
    return [...builtins, ...customs];
  }

  async function listRegistryPresets(catalog) {
    const manifest = await loadManifest();
    const c = ensureLibraries(catalog || (await GazpromStore.get()));
    migrateCatalog(c);
    const activeId = c.activeRegistryPresetId || manifest.registries?.[0]?.id;
    const builtins = (manifest.registries || []).map((r) => ({
      id: r.id,
      name: r.name,
      label: r.label || 'Встроенный',
      subtitle: r.subtitle || `${r.count || 0} записей`,
      count: r.count || 0,
      previewRows: r.previewRows || [],
      kind: 'builtin',
      active: r.id === activeId,
    }));
    const customs = (c.savedRegistries || []).map((r) => ({
      id: r.id,
      name: r.name,
      label: r.label || 'Свой реестр',
      subtitle: `${(r.items || []).length} записей`,
      count: (r.items || []).length,
      previewRows: (r.items || []).slice(0, 3).map((x) => x.title),
      kind: 'custom',
      active: r.id === activeId,
    }));
    return [...builtins, ...customs];
  }

  function renderDocThumb() {
    return `
      <div class="preset-thumb preset-thumb--doc" aria-hidden="true">
        <div class="preset-doc-sheet">
          <div class="preset-doc-sheet__head"></div>
          <div class="preset-doc-sheet__line"></div>
          <div class="preset-doc-sheet__line preset-doc-sheet__line--mid"></div>
          <div class="preset-doc-sheet__line preset-doc-sheet__line--short"></div>
          <span class="preset-doc-sheet__badge">W</span>
        </div>
      </div>`;
  }

  function renderRegistryThumb(preset) {
    const rows = (preset.previewRows || []).slice(0, 3);
    const body = rows.length
      ? rows.map((row, i) => `
          <div class="preset-registry-row">
            <span class="preset-registry-row__num">${i + 1}</span>
            <span class="preset-registry-row__text">${escHtml(String(row).slice(0, 32))}</span>
          </div>`).join('')
      : `
          <div class="preset-registry-row"><span class="preset-registry-row__num">1</span><span class="preset-registry-row__text">…</span></div>
          <div class="preset-registry-row"><span class="preset-registry-row__num">2</span><span class="preset-registry-row__text">…</span></div>`;
    return `<div class="preset-thumb preset-thumb--registry" aria-hidden="true">${body}</div>`;
  }

  function renderPresetCard(preset, type) {
    const isDocType = type === 'template' || type === 'spravka-template';
    const thumb = isDocType ? renderDocThumb() : renderRegistryThumb(preset);
    const meta = type === 'registry' && preset.count ? `${preset.count} зап.` : preset.subtitle;
    const deleteBtn = preset.kind === 'custom'
      ? `<button type="button" class="preset-card__delete" data-preset-delete="${escHtml(preset.id)}" data-preset-type="${type}" title="Удалить" aria-label="Удалить ${escHtml(preset.name)}">×</button>`
      : '';
    return `
      <div class="preset-card-wrap">
        <button
          type="button"
          class="preset-card preset-card--${type}${preset.active ? ' preset-card--active' : ''}"
          data-preset-id="${escHtml(preset.id)}"
          data-preset-kind="${escHtml(preset.kind)}"
          aria-pressed="${preset.active ? 'true' : 'false'}"
          aria-label="${escHtml(preset.label)}: ${escHtml(preset.name)}"
        >
          ${thumb}
          <span class="preset-card__label">${escHtml(preset.label)}</span>
          <span class="preset-card__name">${escHtml(preset.name)}</span>
          <span class="preset-card__meta">${escHtml(meta)}</span>
          ${preset.active ? '<span class="preset-card__check" aria-hidden="true">✓</span>' : ''}
          ${preset.kind === 'custom' ? '<span class="preset-card__tag">свой</span>' : '<span class="preset-card__tag preset-card__tag--builtin">встроенный</span>'}
        </button>
        ${deleteBtn}
      </div>`;
  }

  function renderAddCard(type, label) {
    return `
      <button type="button" class="preset-card preset-card--add preset-card--${type}" data-preset-add="${type}" aria-label="${escHtml(label)}">
        <span class="preset-card__add-icon" aria-hidden="true">+</span>
        <span class="preset-card__name">${escHtml(label)}</span>
      </button>`;
  }

  function getDocGenerator() {
    if (typeof window !== 'undefined' && window.DocGenerator) return window.DocGenerator;
    if (typeof DocGenerator !== 'undefined') return DocGenerator;
    return null;
  }

  function renderTemplateMarkersGuide() {
    const host = document.getElementById('templateMarkersGuide');
    if (!host) return;

    const gen = getDocGenerator();
    if (!gen || typeof gen.getMarkerGuide !== 'function') {
      host.innerHTML =
        '<p class="backup-import-hint">Справочник маркеров загружается… Если таблица пустая — закройте окно и откройте снова.</p>';
      return;
    }

    const groups = gen.getMarkerGuide();
    host.innerHTML = groups
      .map(
        (group) => `
      <details class="template-markers-group" open>
        <summary class="template-markers-group__title">${escHtml(group.title)}</summary>
        ${group.hint ? `<p class="template-markers-group__hint">${escHtml(group.hint)}</p>` : ''}
        <div class="template-markers-table-wrap">
          <table class="template-markers-table">
            <thead>
              <tr>
                <th>Маркер</th>
                <th>Что подставится</th>
                <th>Откуда в приложении</th>
              </tr>
            </thead>
            <tbody>
              ${group.items
                .map(
                  (item) => `
                <tr>
                  <td><code class="template-marker-code">${escHtml(item.key)}</code></td>
                  <td>${escHtml(item.label)}</td>
                  <td>${escHtml(item.source)}</td>
                </tr>`
                )
                .join('')}
            </tbody>
          </table>
        </div>
      </details>`
      )
      .join('');
  }

  function renderSpravkaTemplateMarkersGuide() {
    const host = document.getElementById('spravkaTemplateMarkersGuide');
    if (!host) return;

    const gen = getDocGenerator();
    if (!gen || typeof gen.getSpravkaMarkerGuide !== 'function') {
      host.innerHTML =
        '<p class="backup-import-hint">Справочник маркеров справки загружается… Если таблица пустая — закройте окно и откройте снова.</p>';
      return;
    }

    const groups = gen.getSpravkaMarkerGuide();
    host.innerHTML = groups
      .map(
        (group) => `
      <details class="template-markers-group" open>
        <summary class="template-markers-group__title">${escHtml(group.title)}</summary>
        ${group.hint ? `<p class="template-markers-group__hint">${escHtml(group.hint)}</p>` : ''}
        <div class="template-markers-table-wrap">
          <table class="template-markers-table">
            <thead>
              <tr>
                <th>Маркер</th>
                <th>Что подставится</th>
                <th>Откуда в приложении</th>
              </tr>
            </thead>
            <tbody>
              ${group.items
                .map(
                  (item) => `
                <tr>
                  <td><code class="template-marker-code">${escHtml(item.key)}</code></td>
                  <td>${escHtml(item.label)}</td>
                  <td>${escHtml(item.source)}</td>
                </tr>`
                )
                .join('')}
            </tbody>
          </table>
        </div>
      </details>`
      )
      .join('');
  }

  async function deleteTemplatePreset(id) {
    const catalog = ensureLibraries(await GazpromStore.get());
    const idx = catalog.savedTemplates.findIndex((t) => t.id === id);
    if (idx < 0) throw new Error('Свой шаблон не найден');
    const name = catalog.savedTemplates[idx].name;
    const wasActive = catalog.activeTemplatePresetId === id;
    catalog.savedTemplates.splice(idx, 1);

    if (wasActive) {
      const defaultId = manifestCache?.templates?.[0]?.id || 'builtin-template-v1';
      const builtin = manifestCache?.templates?.find((t) => t.id === defaultId);
      const b64 = await fetchTemplateBase64(builtin?.docx || LEGACY_TEMPLATE_DOCX);
      await writeTemplateToCatalog(catalog, b64, builtin?.name || 'Шаблон', { presetId: defaultId, source: 'builtin' });
    }

    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
    await GazpromUI?.refreshAll?.();
    return name;
  }

  async function deleteSpravkaTemplatePreset(id) {
    const catalog = ensureLibraries(await GazpromStore.get());
    const idx = catalog.savedSpravkaTemplates.findIndex((t) => t.id === id);
    if (idx < 0) throw new Error('Свой шаблон справки не найден');
    const name = catalog.savedSpravkaTemplates[idx].name;
    const wasActive = catalog.activeSpravkaTemplatePresetId === id;
    catalog.savedSpravkaTemplates.splice(idx, 1);

    if (wasActive) {
      const defaultId = manifestCache?.spravkaTemplates?.[0]?.id || 'builtin-spravka-v1';
      const builtin = manifestCache?.spravkaTemplates?.find((t) => t.id === defaultId)
        || { docx: LEGACY_SPRAVKA_TEMPLATE_DOCX, name: 'Шаблон_справки_ПБ.docx', id: defaultId };
      const b64 = await fetchTemplateBase64(builtin.docx || LEGACY_SPRAVKA_TEMPLATE_DOCX);
      await writeSpravkaTemplateToCatalog(catalog, b64, builtin.name, { presetId: defaultId, source: 'builtin' });
    }

    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
    await GazpromUI?.refreshAll?.();
    return name;
  }

  async function deleteRegistryPreset(id) {
    const catalog = ensureLibraries(await GazpromStore.get());
    const idx = catalog.savedRegistries.findIndex((r) => r.id === id);
    if (idx < 0) throw new Error('Свой реестр не найден');
    const name = catalog.savedRegistries[idx].name;
    const wasActive = catalog.activeRegistryPresetId === id;
    catalog.savedRegistries.splice(idx, 1);

    if (wasActive) {
      const defaultId = manifestCache?.registries?.[0]?.id || 'builtin-registry-v1';
      const items = await loadBuiltinRegistryItems(defaultId);
      catalog.violationRegistry = items;
      catalog.violationRegistrySource = 'builtin';
      catalog.violationRegistryLabel = manifestCache?.registries?.[0]?.name || name;
      catalog.activeRegistryPresetId = defaultId;
      catalog.violationRegistryPreset = defaultId;
    }

    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
    await GazpromUI?.refreshAll?.();
    return name;
  }

  function bindPresetDeleteHandlers(container, type, { onDeleted } = {}) {
    if (!container) return;
    container.querySelectorAll('[data-preset-delete]').forEach((btn) => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        e.preventDefault();
        const id = btn.dataset.presetDelete;
        const presetType = btn.dataset.presetType || type;
        const label = presetType === 'template' || presetType === 'spravka-template' ? 'шаблон' : 'реестр';
        const ok = await GazpromToast.confirm(
          `Удалить свой ${label} из списка?\nФайл останется только в уже созданных документах.`,
          { confirmLabel: 'Удалить', danger: true }
        );
        if (!ok) return;
        try {
          const deletedName = presetType === 'template'
            ? await deleteTemplatePreset(id)
            : presetType === 'spravka-template'
              ? await deleteSpravkaTemplatePreset(id)
              : await deleteRegistryPreset(id);
          GazpromToast.success(`Удалено: ${deletedName}`);
          if (typeof onDeleted === 'function') await onDeleted();
        } catch (err) {
          GazpromToast.error(err.message);
        }
      });
    });
  }

  async function renderTemplatePicker(container) {
    if (!container) return;
    const presets = await listTemplatePresets();
    container.innerHTML = `
      <div class="preset-picker-grid" role="listbox" aria-label="Выбор шаблона акта">
        ${presets.map((p) => renderPresetCard(p, 'template')).join('')}
        ${renderAddCard('template-builder', 'Мастер шаблона')}
        ${renderAddCard('template-create', 'Создать шаблон')}
        ${renderAddCard('template', 'Загрузить .docx')}
      </div>`;

    container.querySelectorAll('[data-preset-id]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        if (btn.classList.contains('preset-card--active')) return;
        try {
          GazpromToast.info('Применяю шаблон…');
          await applyTemplatePreset(btn.dataset.presetId);
          await renderTemplatePicker(container);
          await refreshAktTemplateModal();
          GazpromToast.success('Шаблон выбран');
        } catch (err) {
          GazpromToast.error(err.message);
        }
      });
    });

    bindPresetDeleteHandlers(container, 'template', {
      onDeleted: async () => {
        await renderTemplatePicker(container);
        await refreshAktTemplateModal();
      },
    });

    container.querySelector('[data-preset-add="template"]')?.addEventListener('click', () => {
      GazpromFileUtils?.triggerFilePicker?.(document.getElementById('wordTemplateInput'));
    });

    container.querySelector('[data-preset-add="template-builder"]')?.addEventListener('click', () => {
      closeAktTemplateModal();
      TemplateBuilderWizard?.open?.({ templateType: 'akt' });
    });

    container.querySelector('[data-preset-add="template-create"]')?.addEventListener('click', async () => {
      try {
        const gen = getDocGenerator();
        if (!gen || typeof gen.downloadBlankTemplate !== 'function') {
          throw new Error('Модуль Word не загружен. Обновите страницу (сборка web-199+).');
        }
        GazpromToast.info('Создаю шаблон Word…');
        const mode = await gen.downloadBlankTemplate();
        if (mode === 'shared') {
          GazpromToast.success('Выберите Word в меню «Поделиться»');
          return;
        }
        if (mode === 'cancelled') return;
        GazpromToast.success(
          'Шаблон создан — откройте в Word (в конце файла памятка по маркерам). Затем загрузите через «Загрузить .docx»'
        );
      } catch (err) {
        GazpromToast.error(err?.message || 'Не удалось создать шаблон');
      }
    });
  }

  async function renderSpravkaTemplatePicker(container) {
    if (!container) return;
    const presets = await listSpravkaTemplatePresets();
    container.innerHTML = `
      <div class="preset-picker-grid" role="listbox" aria-label="Выбор шаблона справки">
        ${presets.map((p) => renderPresetCard(p, 'spravka-template')).join('')}
        ${renderAddCard('spravka-template-builder', 'Мастер шаблона')}
        ${renderAddCard('spravka-template-create', 'Создать шаблон')}
        ${renderAddCard('spravka-template', 'Загрузить .docx')}
      </div>`;

    container.querySelectorAll('[data-preset-id]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        if (btn.classList.contains('preset-card--active')) return;
        try {
          GazpromToast.info('Применяю шаблон справки…');
          await applySpravkaTemplatePreset(btn.dataset.presetId);
          await renderSpravkaTemplatePicker(container);
          await refreshSpravkaTemplateModal();
          GazpromToast.success('Шаблон справки выбран');
        } catch (err) {
          GazpromToast.error(err.message);
        }
      });
    });

    bindPresetDeleteHandlers(container, 'spravka-template', {
      onDeleted: async () => {
        await renderSpravkaTemplatePicker(container);
        await refreshSpravkaTemplateModal();
      },
    });

    container.querySelector('[data-preset-add="spravka-template"]')?.addEventListener('click', () => {
      GazpromFileUtils?.triggerFilePicker?.(document.getElementById('spravkaTemplateInput'));
    });

    container.querySelector('[data-preset-add="spravka-template-builder"]')?.addEventListener('click', () => {
      closeSpravkaTemplateModal();
      TemplateBuilderWizard?.open?.({ templateType: 'spravka' });
    });

    container.querySelector('[data-preset-add="spravka-template-create"]')?.addEventListener('click', async () => {
      try {
        const gen = getDocGenerator();
        if (!gen || typeof gen.downloadBlankSpravkaTemplate !== 'function') {
          throw new Error('Модуль Word не загружен. Обновите страницу.');
        }
        GazpromToast.info('Создаю шаблон справки Word…');
        const mode = await gen.downloadBlankSpravkaTemplate();
        if (mode === 'shared') {
          GazpromToast.success('Выберите Word в меню «Поделиться»');
          return;
        }
        if (mode === 'cancelled') return;
        GazpromToast.success(
          'Шаблон справки создан — откройте в Word (в конце файла памятка по маркерам). Затем загрузите через «Загрузить .docx»'
        );
      } catch (err) {
        GazpromToast.error(err?.message || 'Не удалось создать шаблон справки');
      }
    });
  }

  async function renderRegistryPicker(container, { onSelected = null } = {}) {
    if (!container) return;
    const presets = await listRegistryPresets();
    container.innerHTML = `
      <div class="preset-picker-grid" role="listbox" aria-label="Выбор реестра нарушений">
        ${presets.map((p) => renderPresetCard(p, 'registry')).join('')}
        ${renderAddCard('registry', 'Импорт Excel')}
      </div>`;

    const finishSelect = () => {
      if (typeof onSelected === 'function') onSelected();
    };

    container.querySelectorAll('[data-preset-id]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const presetId = btn.dataset.presetId;
        const presetName = btn.querySelector('.preset-card__name')?.textContent || 'реестр';

        if (btn.classList.contains('preset-card--active')) {
          finishSelect();
          return;
        }

        const merge = document.getElementById('vrPickerMergeCheckbox')?.checked ?? false;
        const ok = await GazpromToast.confirm(
          merge
            ? `Добавить записи из «${presetName}» к текущим?`
            : `Открыть реестр «${presetName}»?\nТекущие записи в таблице будут заменены.`,
          { confirmLabel: merge ? 'Объединить' : 'Открыть' }
        );
        if (!ok) return;

        try {
          GazpromToast.info('Загрузка реестра…');
          await applyRegistryPreset(presetId, { merge });
          await refreshRegistryModal();
          GazpromToast.success('Реестр выбран');
          finishSelect();
        } catch (err) {
          GazpromToast.error(err.message);
        }
      });
    });

    bindPresetDeleteHandlers(container, 'registry', {
      onDeleted: async () => {
        await refreshRegistryModal();
        if (typeof ViolationRegistry !== 'undefined') {
          await ViolationRegistry.renderScreen?.('', '');
        }
      },
    });

    container.querySelector('[data-preset-add="registry"]')?.addEventListener('click', () => {
      GazpromFileUtils?.triggerFilePicker?.(document.getElementById('vrPickerImportInput'));
      const opts = document.getElementById('vrPickerImportOptions');
      if (opts) opts.hidden = false;
    });
  }

  async function renderSettingsTilePreviews() {
    /* Превью на плитках настроек отключено — выбор только в модале / экране реестра. */
  }

  async function saveCustomTemplate(file) {
    const buf = await file.arrayBuffer();
    const bytes = new Uint8Array(buf);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    const b64 = btoa(binary);
    const catalog = ensureLibraries((await GazpromStore.get()) || { akts: [] });

    let saved = catalog.savedTemplates.find((t) => t.name === file.name);
    if (!saved) {
      saved = { id: AktUtils.uuid(), name: file.name, data: b64, createdAt: new Date().toISOString() };
      catalog.savedTemplates.push(saved);
    } else {
      saved.data = b64;
      saved.createdAt = new Date().toISOString();
    }

    await writeTemplateToCatalog(catalog, b64, file.name, { presetId: saved.id, source: 'custom' });
    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
  }

  async function saveCustomSpravkaTemplate(file) {
    const buf = await file.arrayBuffer();
    const bytes = new Uint8Array(buf);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    const b64 = btoa(binary);
    const catalog = ensureLibraries((await GazpromStore.get()) || { akts: [] });

    let saved = catalog.savedSpravkaTemplates.find((t) => t.name === file.name);
    if (!saved) {
      saved = { id: AktUtils.uuid(), name: file.name, data: b64, createdAt: new Date().toISOString() };
      catalog.savedSpravkaTemplates.push(saved);
    } else {
      saved.data = b64;
      saved.createdAt = new Date().toISOString();
    }

    await writeSpravkaTemplateToCatalog(catalog, b64, file.name, { presetId: saved.id, source: 'custom' });
    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
  }

  async function blobToBase64(blob) {
    const buf = await blob.arrayBuffer();
    const bytes = new Uint8Array(buf);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    return btoa(binary);
  }

  async function saveBuilderTemplate(blob, fileName, templateType) {
    const b64 = await blobToBase64(blob);
    const catalog = ensureLibraries((await GazpromStore.get()) || { akts: [] });
    const type = templateType === 'spravka' ? 'spravka' : 'akt';

    if (type === 'spravka') {
      let saved = catalog.savedSpravkaTemplates.find((t) => t.name === fileName);
      if (!saved) {
        saved = { id: AktUtils.uuid(), name: fileName, data: b64, createdAt: new Date().toISOString() };
        catalog.savedSpravkaTemplates.push(saved);
      } else {
        saved.data = b64;
        saved.createdAt = new Date().toISOString();
      }
      await writeSpravkaTemplateToCatalog(catalog, b64, fileName, { presetId: saved.id, source: 'custom' });
    } else {
      let saved = catalog.savedTemplates.find((t) => t.name === fileName);
      if (!saved) {
        saved = { id: AktUtils.uuid(), name: fileName, data: b64, createdAt: new Date().toISOString() };
        catalog.savedTemplates.push(saved);
      } else {
        saved.data = b64;
        saved.createdAt = new Date().toISOString();
      }
      await writeTemplateToCatalog(catalog, b64, fileName, { presetId: saved.id, source: 'custom' });
    }

    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
    await GazpromUI?.refreshAll?.();
    if (type === 'spravka') await refreshSpravkaTemplateModal();
    else await refreshAktTemplateModal();
  }

  async function saveCustomRegistryPreset(name, items) {
    const catalog = ensureLibraries(await GazpromStore.get());
    const label = name || 'Импорт Excel';
    let saved = catalog.savedRegistries.find((r) => r.name === label);
    const snapshot = cloneRegistryItems(items);

    if (!saved) {
      saved = {
        id: AktUtils.uuid(),
        name: label,
        label,
        items: snapshot,
        createdAt: new Date().toISOString(),
      };
      catalog.savedRegistries.push(saved);
    } else {
      saved.items = snapshot;
      saved.label = label;
      saved.createdAt = new Date().toISOString();
    }

    catalog.violationRegistry = snapshot;
    catalog.violationRegistrySource = 'custom';
    catalog.violationRegistryLabel = label;
    catalog.activeRegistryPresetId = saved.id;
    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromStore.invalidateCache();
  }

  function markRegistryCustom(catalog) {
    catalog.violationRegistrySource = 'custom';
    catalog.violationRegistryPreset = null;
    return catalog;
  }

  function registrySourceLabel(catalog) {
    const active = catalog?.activeRegistryPresetId;
    if (active?.startsWith('builtin-')) {
      const name = catalog?.violationRegistryLabel || manifestCache?.registries?.[0]?.name || 'Стандартный';
      return `Стандартный (${name})`;
    }
    if (catalog?.violationRegistrySource === 'custom') return catalog.violationRegistryLabel || 'Свой реестр';
    const n = catalog?.violationRegistry?.length || 0;
    return n ? 'Загруженный' : 'Не задан';
  }

  function spravkaTemplateSourceLabel(catalog) {
    if (catalog?.spravkaTemplateSource === 'builtin') {
      return `Встроенный (${catalog.spravkaTemplateName || manifestCache?.spravkaTemplates?.[0]?.name || 'шаблон'})`;
    }
    if (catalog?.spravkaTemplateSource === 'custom') return catalog?.spravkaTemplateName || 'Свой шаблон';
    return catalog?.spravkaTemplateName ? catalog.spravkaTemplateName : 'Не загружен';
  }

  function templateSourceLabel(catalog) {
    if (catalog?.wordTemplateSource === 'builtin') {
      return `Встроенный (${catalog.wordTemplateName || manifestCache?.templates?.[0]?.name || 'шаблон'})`;
    }
    if (catalog?.wordTemplateSource === 'custom') return catalog?.wordTemplateName || 'Свой шаблон';
    return catalog?.wordTemplateName ? catalog.wordTemplateName : 'Не загружен';
  }

  function closeRegistryModal() {
    const modal = document.getElementById('registryModal');
    if (!modal) return;
    modal.hidden = true;
    window.GazpromMobileOverlay?.unlock?.();
    const opts = document.getElementById('vrPickerImportOptions');
    if (opts) opts.hidden = true;
  }

  function afterRegistrySelected() {
    closeRegistryModal();
    const onViolations = document.getElementById('screen-violations')?.classList.contains('active');
    if (onViolations) {
      void ViolationRegistry?.renderScreen?.('', '');
    } else if (typeof goTo === 'function') {
      goTo('violations');
    }
  }

  async function refreshRegistryModal() {
    const statusEl = document.getElementById('registryModalStatus');
    const pickerEl = document.getElementById('registryPresetPicker');

    try {
      const catalog = await GazpromStore.get();
      const count = catalog?.violationRegistry?.length || 0;
      const label = registrySourceLabel(catalog);

      if (statusEl) {
        statusEl.textContent = count
          ? `✅ Активный: ${label} (${count} записей)`
          : 'Выберите реестр для работы';
        statusEl.className = `defaults-status ${count ? 'defaults-status--ok' : 'defaults-status--warn'}`;
      }

      await renderRegistryPicker(pickerEl, {
        onSelected: afterRegistrySelected,
      });
    } catch (err) {
      console.error('[RegistryModal] refresh error:', err);
      if (statusEl) {
        statusEl.textContent = '⚠️ Не удалось загрузить список реестров';
        statusEl.className = 'defaults-status defaults-status--warn';
      }
      if (pickerEl) {
        pickerEl.innerHTML = '<p class="backup-import-hint">Обновите страницу или проверьте подключение к интернету.</p>';
      }
      GazpromToast?.error?.('Не удалось открыть выбор реестра');
    }
  }

  function openRegistryModal() {
    const modal = document.getElementById('registryModal');
    if (!modal) {
      GazpromToast?.error?.('Окно выбора реестра недоступно. Обновите страницу.');
      return;
    }
    modal.hidden = false;
    window.GazpromMobileOverlay?.lock?.();
    void refreshRegistryModal();
  }

  function bindRegistryModal() {
    const modal = document.getElementById('registryModal');
    if (!modal || modal.dataset.bound === '1') return;
    modal.dataset.bound = '1';

    document.getElementById('registryModalClose')?.addEventListener('click', closeRegistryModal);
    modal.addEventListener('click', (e) => {
      if (e.target === modal) closeRegistryModal();
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && modal && !modal.hidden) closeRegistryModal();
    });

    document.getElementById('vrOpenRegistryModalBtn')?.addEventListener('click', () => {
      openRegistryModal();
    });

    document.getElementById('vrPickerImportInput')?.addEventListener('change', async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      const merge = document.getElementById('vrPickerMergeCheckbox')?.checked ?? false;
      const opts = document.getElementById('vrPickerImportOptions');
      if (opts) opts.hidden = true;

      try {
        if (typeof ViolationRegistry === 'undefined') throw new Error('Модуль реестра недоступен');
        GazpromToast.info('Читаю файл…');
        const count = await ViolationRegistry.importFromExcel(file, { replace: !merge });
        GazpromToast.success(`Импортировано нарушений: ${count}`);
        await refreshRegistryModal();
        afterRegistrySelected();
      } catch (err) {
        console.error('[RegistryModal] import error:', err);
        GazpromToast.error('Ошибка импорта: ' + (err.message || String(err)));
      } finally {
        e.target.value = '';
      }
    });
  }

  function closeAllTemplateModals() {
    ['aktTemplateModal', 'spravkaTemplateModal'].forEach((id) => {
      const modal = document.getElementById(id);
      if (modal) modal.hidden = true;
    });
    window.GazpromMobileOverlay?.unlock?.();
  }

  function closeAktTemplateModal() {
    const modal = document.getElementById('aktTemplateModal');
    if (!modal) return;
    modal.hidden = true;
    if (document.getElementById('spravkaTemplateModal')?.hidden !== false) {
      window.GazpromMobileOverlay?.unlock?.();
    }
  }

  function closeSpravkaTemplateModal() {
    const modal = document.getElementById('spravkaTemplateModal');
    if (!modal) return;
    modal.hidden = true;
    if (document.getElementById('aktTemplateModal')?.hidden !== false) {
      window.GazpromMobileOverlay?.unlock?.();
    }
  }

  async function refreshAktTemplateModal() {
    const catalog = await GazpromStore.get();
    const statusEl = document.getElementById('aktTemplateModalStatus');
    const has = await hasWordTemplate(catalog);

    if (statusEl) {
      statusEl.textContent = has
        ? `✅ Акт: ${catalog.wordTemplateName || 'шаблон'}`
        : '⚠️ Шаблон акта не выбран';
      statusEl.className = `defaults-status ${has ? 'defaults-status--ok' : 'defaults-status--warn'}`;
    }

    await renderTemplatePicker(document.getElementById('templatePresetPicker'));
    renderTemplateMarkersGuide();
    await renderSettingsTilePreviews(catalog);
  }

  async function refreshSpravkaTemplateModal() {
    const catalog = await GazpromStore.get();
    const spravkaStatusEl = document.getElementById('spravkaTemplateModalStatus');
    const hasSpravka = hasSpravkaTemplate(catalog);

    if (spravkaStatusEl) {
      spravkaStatusEl.textContent = hasSpravka
        ? `✅ Справка: ${catalog.spravkaTemplateName || 'Шаблон_справки_ПБ.docx'}`
        : '⚠️ Шаблон справки не выбран';
      spravkaStatusEl.className = `defaults-status ${hasSpravka ? 'defaults-status--ok' : 'defaults-status--warn'}`;
    }

    await renderSpravkaTemplatePicker(document.getElementById('spravkaTemplatePresetPicker'));
    renderSpravkaTemplateMarkersGuide();
    await renderSettingsTilePreviews(catalog);
  }

  async function refreshTemplateModal() {
    await refreshAktTemplateModal();
    await refreshSpravkaTemplateModal();
  }

  function openAktTemplateModal() {
    closeAllTemplateModals();
    const modal = document.getElementById('aktTemplateModal');
    if (!modal) return;
    modal.hidden = false;
    window.GazpromMobileOverlay?.lock?.();
    void refreshAktTemplateModal().then(() => {
      requestAnimationFrame(() => {
        renderTemplateMarkersGuide();
      });
    });
  }

  function openSpravkaTemplateModal() {
    closeAllTemplateModals();
    const modal = document.getElementById('spravkaTemplateModal');
    if (!modal) return;
    modal.hidden = false;
    window.GazpromMobileOverlay?.lock?.();
    void refreshSpravkaTemplateModal().then(() => {
      requestAnimationFrame(() => {
        renderSpravkaTemplateMarkersGuide();
      });
    });
  }

  function openTemplateModal() {
    openAktTemplateModal();
  }

  function bindTemplateModal() {
    if (document.body.dataset.templateModalsBound === '1') return;
    document.body.dataset.templateModalsBound = '1';

    document.querySelectorAll('[data-template-modal-close]').forEach((btn) => {
      btn.addEventListener('click', () => {
        if (btn.dataset.templateModalClose === 'spravka') closeSpravkaTemplateModal();
        else closeAktTemplateModal();
      });
    });

    ['aktTemplateModal', 'spravkaTemplateModal'].forEach((id) => {
      const modal = document.getElementById(id);
      if (!modal) return;
      modal.addEventListener('click', (e) => {
        if (e.target !== modal) return;
        if (id === 'spravkaTemplateModal') closeSpravkaTemplateModal();
        else closeAktTemplateModal();
      });
    });

    document.addEventListener('keydown', (e) => {
      if (e.key !== 'Escape') return;
      const aktOpen = document.getElementById('aktTemplateModal')?.hidden === false;
      const spravkaOpen = document.getElementById('spravkaTemplateModal')?.hidden === false;
      if (spravkaOpen) closeSpravkaTemplateModal();
      else if (aktOpen) closeAktTemplateModal();
    });

    document.getElementById('wordTemplateInput')?.addEventListener('change', async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      try {
        GazpromToast.info('Сохранение шаблона…');
        await saveCustomTemplate(file);
        await GazpromUI?.refreshAll?.();
        await refreshAktTemplateModal();
        GazpromToast.success('Шаблон акта добавлен и выбран');
      } catch (err) {
        GazpromToast.error(err.message);
      } finally {
        e.target.value = '';
      }
    });

    document.getElementById('spravkaTemplateInput')?.addEventListener('change', async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      try {
        GazpromToast.info('Сохранение шаблона справки…');
        await saveCustomSpravkaTemplate(file);
        await GazpromUI?.refreshAll?.();
        await refreshSpravkaTemplateModal();
        GazpromToast.success('Шаблон справки добавлен и выбран');
      } catch (err) {
        GazpromToast.error(err.message);
      } finally {
        e.target.value = '';
      }
    });
  }

  return {
    ensureSeeded,
    applyTemplatePreset,
    applySpravkaTemplatePreset,
    applyRegistryPreset,
    saveCustomTemplate,
    saveCustomSpravkaTemplate,
    saveBuilderTemplate,
    saveCustomRegistryPreset,
    markRegistryCustom,
    registrySourceLabel,
    templateSourceLabel,
    spravkaTemplateSourceLabel,
    hasWordTemplate,
    hasSpravkaTemplate,
    openRegistryModal,
    closeRegistryModal,
    bindRegistryModal,
    openTemplateModal,
    openAktTemplateModal,
    openSpravkaTemplateModal,
    closeAktTemplateModal,
    closeSpravkaTemplateModal,
    bindTemplateModal,
    deleteTemplatePreset,
    deleteSpravkaTemplatePreset,
    deleteRegistryPreset,
    renderRegistryPicker,
    renderSettingsTilePreviews,
    listTemplatePresets,
    listSpravkaTemplatePresets,
    listRegistryPresets,
    renderDocThumb,
    renderRegistryThumb,
    escHtml,
    restoreBuiltinRegistry: ({ replace = true } = {}) =>
      applyRegistryPreset(manifestCache?.registries?.[0]?.id || 'builtin-registry-v1', { merge: !replace }),
    restoreBuiltinTemplate: () =>
      applyTemplatePreset(manifestCache?.templates?.[0]?.id || 'builtin-template-v1'),
    restoreBuiltinSpravkaTemplate: () =>
      applySpravkaTemplatePreset(manifestCache?.spravkaTemplates?.[0]?.id || 'builtin-spravka-v1'),
  };
})();
