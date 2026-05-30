/**
 * Генерация Word (.docx) через docxtemplater (CDN).
 */
const DocGenerator = (() => {
  const TEMPLATE_KEY = 'wordTemplate';

  async function loadTemplateBlob() {
    const catalog = await GazpromStore.get();
    const b64 = catalog?.[TEMPLATE_KEY];
    if (!b64) return null;
    const bin = atob(b64);
    const arr = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
    return arr;
  }

  async function saveTemplate(file) {
    const buf = await file.arrayBuffer();
    const bytes = new Uint8Array(buf);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    const b64 = btoa(binary);
    const catalog = (await GazpromStore.get()) || { akts: [] };
    catalog[TEMPLATE_KEY] = b64;
    catalog.wordTemplateName = file.name;
    await GazpromStore.set(catalog, { skipPhotoIngest: true });
    GazpromToast.success('Шаблон Word сохранён');
  }

  function buildTemplateData(akt) {
    const violations = (akt.violations || []).map((v, i) => ({
      n: i + 1,
      title: v.title || '',
      mesto: v.mesto || '',
      vid: v.vid || '',
      formula: v.formulaFromRules || '',
    }));
    const commission = (akt.comission || []).map((p, i) => ({
      n: i + 1,
      fio: p.fio || '',
      job: p.jobTitle || '',
    }));
    const objects = (akt.objectsCheck || []).map((o, i) => ({
      n: i + 1,
      title: o.title || '',
      subtitle: o.subTitle || '',
    }));
    const pred = akt.predstavitelyComission?.[0];
    return {
      number: akt.number || '',
      date: AktUtils.formatDateShort(akt.date),
      org: akt.organization?.title || '',
      orgShort: akt.organization?.shortTitle || '',
      description: akt.description || '',
      elimDate: AktUtils.formatDateShort(akt.actustranenDate),
      predDate: AktUtils.formatDateShort(akt.actPredostavlenDate),
      utverDate: AktUtils.formatDateShort(akt.actUtverzdenDate),
      predFio: pred?.fio || '',
      predJob: pred?.jobTitle || '',
      violations,
      commission,
      objects,
      violationCount: violations.length,
      objectCount: objects.length,
    };
  }

  async function generateFromAkt(akt) {
    const DocxTemplate = window.docxtemplater || window.Docxtemplater;
    if (typeof PizZip === 'undefined' || !DocxTemplate) {
      throw new Error('Библиотеки docxtemplater не загружены. Проверьте подключение CDN.');
    }
    const templateBytes = await loadTemplateBlob();
    if (!templateBytes) {
      throw new Error('Загрузите шаблон Word (.docx) в Настройках → Шаблон акта');
    }

    const zip = new PizZip(templateBytes);
    const doc = new DocxTemplate(zip, {
      paragraphLoop: true,
      linebreaks: true,
    });
    doc.render(buildTemplateData(akt));
    const out = doc.getZip().generate({
      type: 'blob',
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(out);
    a.download = `Акт_${akt.number}_${AktUtils.toDateInputValue(akt.date)}.docx`;
    a.click();
    URL.revokeObjectURL(a.href);
    GazpromToast.success(`Акт № ${akt.number} сформирован`);
  }

  function hasTemplate() {
    return GazpromStore.get().then((c) => Boolean(c?.[TEMPLATE_KEY]));
  }

  return { saveTemplate, generateFromAkt, hasTemplate, buildTemplateData, TEMPLATE_KEY };
})();
