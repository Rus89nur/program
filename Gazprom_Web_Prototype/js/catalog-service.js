/** Добавление записей в справочники (сохранение в GazpromStore). */
const CatalogService = (() => {
  async function load() {
    return GazpromStore.get();
  }

  async function save(catalog) {
    await GazpromStore.set(catalog);
  }

  /**
   * Запомнить последний открытый акт (полный или сокращённый) — для «Продолжить» на главной.
   * @param {object|string} aktOrId — акт или его id
   */
  async function rememberLastOpenedAkt(aktOrId) {
    const catalog = await load();
    let akt = aktOrId;
    if (typeof aktOrId === 'string') {
      akt = (catalog.akts || []).find((a) => a.id === aktOrId);
    }
    if (!akt) return false;

    AktUtils.applyCurrentEditable(catalog, akt);
    await save(catalog);
    if (typeof GazpromUI !== 'undefined') {
      GazpromUI.renderHome(catalog);
    }
    return true;
  }

  async function addOrganization(title, shortTitle) {
    const catalog = await load();
    const org = {
      id: AktUtils.uuid(),
      title: title.trim(),
      shortTitle: (shortTitle || title).trim(),
    };
    catalog.organizations = [...(catalog.organizations || []), org];
    await save(catalog);
    return org;
  }

  async function addObject(title, subTitle) {
    const catalog = await load();
    const obj = {
      id: AktUtils.uuid(),
      title: title.trim(),
      subTitle: (subTitle || '').trim(),
    };
    catalog.objects = [...(catalog.objects || []), obj];
    await save(catalog);
    return obj;
  }

  async function addCommissionPerson(fio, jobTitle) {
    const catalog = await load();
    const person = {
      id: AktUtils.uuid(),
      fio: fio.trim(),
      jobTitle: (jobTitle || '').trim(),
    };
    catalog.comissionPeople = [...(catalog.comissionPeople || []), person];
    await save(catalog);
    return person;
  }

  async function addPredstavitely(fio, jobTitle, organization) {
    const catalog = await load();
    const p = {
      id: AktUtils.uuid(),
      fio: fio.trim(),
      jobTitle: (jobTitle || '').trim(),
      organization: (organization || '').trim(),
    };
    catalog.predstavitely = [...(catalog.predstavitely || []), p];
    await save(catalog);
    return p;
  }

  async function exportBackup(catalog) {
    const data = catalog ? await PhotoStore.expandCatalog(AktUtils.clone(catalog)) : await GazpromStore.getForExport();
    if (!data) throw new Error('Нет данных для экспорта');
    const templateKey =
      typeof DocGenerator !== 'undefined' && DocGenerator.TEMPLATE_KEY
        ? DocGenerator.TEMPLATE_KEY
        : 'wordTemplate';
    const exportData = {
      version: '1.3',
      timestamp: new Date().toISOString(),
      akts: data.akts || [],
      comissionPeople: data.comissionPeople || [],
      organizations: data.organizations || [],
      objects: data.objects || [],
      predstavitely: data.predstavitely || [],
      trash: data.trash || [],
      editableAkt: data.editableAkt || null,
      editableAktReference: data.editableAktReference || null,
      scheduleItems: data.scheduleItems || [],
      violationEliminations: data.violationEliminations || [],
      violationRegistry: data.violationRegistry || [],
      descriptionTemplates: data.descriptionTemplates || ['', '', ''],
      [templateKey]: data[templateKey] || null,
      wordTemplateName: data.wordTemplateName || null,
    };
    const blob = new Blob([JSON.stringify(exportData, null, 2)], {
      type: 'application/json',
    });
    const a = document.createElement('a');
    const date = new Date().toISOString().slice(0, 19).replace(/[:-]/g, '').replace('T', '_');
    a.href = URL.createObjectURL(blob);
    a.download = `gazprom_${date}.gazprombackup`;
    a.click();
    URL.revokeObjectURL(a.href);
  }

  return {
    addOrganization,
    addObject,
    addCommissionPerson,
    addPredstavitely,
    exportBackup,
    load,
    save,
    rememberLastOpenedAkt,
  };
})();
