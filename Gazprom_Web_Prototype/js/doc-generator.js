/**
 * Генерация Word (.docx) через docxtemplater (CDN, ленивая загрузка).
 */
const DocGenerator = (() => {
  const TEMPLATE_KEY = 'wordTemplate';
  const PIZZIP_CDN = 'https://unpkg.com/pizzip@3.2.0/dist/pizzip.js';
  const DOCX_CDN   = 'https://unpkg.com/docxtemplater@3.68.7/build/docxtemplater.js';

  function loadScript(url, checkFn) {
    return new Promise((resolve, reject) => {
      if (checkFn()) return resolve();
      const s = document.createElement('script');
      s.src = url;
      const timer = setTimeout(() => {
        reject(new Error('Время ожидания загрузки библиотеки истекло. Проверьте интернет-соединение.'));
      }, 20000);
      s.onload = () => { clearTimeout(timer); resolve(); };
      s.onerror = () => { clearTimeout(timer); reject(new Error(`Не удалось загрузить: ${url}`)); };
      document.head.appendChild(s);
    });
  }

  async function ensureLibs() {
    if (typeof PizZip === 'undefined' || !(window.docxtemplater || window.Docxtemplater)) {
      GazpromToast.info('Загрузка библиотек для Word…');
    }
    await loadScript(PIZZIP_CDN, () => typeof PizZip !== 'undefined');
    await loadScript(DOCX_CDN,   () => Boolean(window.docxtemplater || window.Docxtemplater));
  }

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
    // Комиссия как форматированная строка
    const commissionList = (akt.comission || []);
    const commissionText = commissionList
      .map((p) => `${p.fio || ''}${p.jobTitle ? ' (' + p.jobTitle + ')' : ''}`)
      .join(', ');

    // Первый представитель
    const pred = akt.predstavitelyComission?.[0];
    const pedstavText = pred
      ? `${pred.fio || ''}${pred.jobTitle ? ', ' + pred.jobTitle : ''}`
      : '';

    // Первый объект
    const mainObject = (akt.objectsCheck || [])[0];
    const nameObject = mainObject?.title || '';

    // Нарушения для таблицы (цикл в шаблоне)
    const violations = (akt.violations || []).map((v, i) => ({
      PoradNum:        i + 1,
      TitleViolatation: v.title || '',
      ddescrVi:        v.mesto || '',
      urlDoc:          v.formulaFromRules || v.formula || '',
      // запасные имена
      n: i + 1, title: v.title || '', mesto: v.mesto || '',
      vid: v.vid || '', formula: v.formulaFromRules || v.formula || '',
    }));

    // Объекты для цикла
    const objects = (akt.objectsCheck || []).map((o, i) => ({
      n: i + 1, title: o.title || '', subtitle: o.subTitle || '',
    }));

    // Члены комиссии для цикла
    const commission = commissionList.map((p, i) => ({
      n: i + 1, fio: p.fio || '', job: p.jobTitle || '',
    }));

    return {
      // ——— Имена из шаблона пользователя ———
      Number:          akt.number || '',
      DateReview:      AktUtils.formatDateShort(akt.date),
      NameObject:      nameObject,
      ReviewObject:    akt.organization?.title || '',
      Comission:       commissionText,
      Pedstav:         pedstavText,
      Conclusion:      akt.description || akt.komissijaVyvody || '',
      ustranenDate:    AktUtils.formatDateShort(akt.actustranenDate),
      predostavlenDate: AktUtils.formatDateShort(akt.actPredostavlenDate),
      PredVoice:       pedstavText,
      violations,
      // ——— Запасные имена (старый формат) ———
      number:    akt.number || '',
      date:      AktUtils.formatDateShort(akt.date),
      org:       akt.organization?.title || '',
      orgShort:  akt.organization?.shortTitle || '',
      description: akt.description || '',
      elimDate:  AktUtils.formatDateShort(akt.actustranenDate),
      predDate:  AktUtils.formatDateShort(akt.actPredostavlenDate),
      utverDate: AktUtils.formatDateShort(akt.actUtverzdenDate),
      predFio:   pred?.fio || '',
      predJob:   pred?.jobTitle || '',
      commission,
      objects,
      violationCount: violations.length,
      objectCount:    objects.length,
    };
  }

  async function generateFromAkt(akt) {
    // #region agent log
    fetch('http://127.0.0.1:7931/ingest/e73f326d-990a-4349-ab2b-115a1dec68c8',{method:'POST',headers:{'Content-Type':'application/json','X-Debug-Session-Id':'149aeb'},body:JSON.stringify({sessionId:'149aeb',location:'doc-generator.js:generate-start',message:'generateFromAkt called (v3 fixed urls)',data:{aktId:akt?.id,pizzipUrl:PIZZIP_CDN,docxUrl:DOCX_CDN,pizzipDefined:typeof PizZip!=='undefined',docxDefined:!!(window.docxtemplater||window.Docxtemplater)},timestamp:Date.now(),hypothesisId:'D'})}).catch(()=>{});
    // #endregion
    try {
      await ensureLibs();
    } catch (loadErr) {
      // #region agent log
      fetch('http://127.0.0.1:7931/ingest/e73f326d-990a-4349-ab2b-115a1dec68c8',{method:'POST',headers:{'Content-Type':'application/json','X-Debug-Session-Id':'149aeb'},body:JSON.stringify({sessionId:'149aeb',location:'doc-generator.js:ensureLibs-error',message:'ensureLibs threw',data:{error:String(loadErr)},timestamp:Date.now(),hypothesisId:'D'})}).catch(()=>{});
      // #endregion
      throw loadErr;
    }

    const DocxTemplate = window.docxtemplater || window.Docxtemplater;
    // #region agent log
    fetch('http://127.0.0.1:7931/ingest/e73f326d-990a-4349-ab2b-115a1dec68c8',{method:'POST',headers:{'Content-Type':'application/json','X-Debug-Session-Id':'149aeb'},body:JSON.stringify({sessionId:'149aeb',location:'doc-generator.js:after-ensureLibs',message:'after ensureLibs',data:{pizzipDefined:typeof PizZip!=='undefined',docxDefined:!!DocxTemplate,docxKeys:DocxTemplate?Object.keys(DocxTemplate).slice(0,5):[]},timestamp:Date.now(),hypothesisId:'D'})}).catch(()=>{});
    // #endregion
    if (typeof PizZip === 'undefined' || !DocxTemplate) {
      throw new Error('Библиотеки docxtemplater не загружены. Проверьте интернет-соединение.');
    }

    const templateBytes = await loadTemplateBlob();
    if (!templateBytes) {
      throw new Error('Загрузите шаблон Word (.docx) в Настройках → Шаблон акта');
    }

    const zip = new PizZip(templateBytes);
    // #region agent log — inspect raw template XML
    try {
      const xmlRaw = zip.files['word/document.xml']?.asText() || '';
      const snippet = xmlRaw.slice(0, 3000);
      // Find where placeholder-like tokens appear
      const curly = (xmlRaw.match(/\{[^}]{1,40}\}/g) || []).slice(0, 20);
      const plainNames = ['Number','DateReview','NameObject','ReviewObject','Comission','Pedstav','Conclusion','ustranenDate','PoradNum','TitleViolatation'].filter(n => xmlRaw.includes(n));
      fetch('http://127.0.0.1:7931/ingest/e73f326d-990a-4349-ab2b-115a1dec68c8',{method:'POST',headers:{'Content-Type':'application/json','X-Debug-Session-Id':'149aeb'},body:JSON.stringify({sessionId:'149aeb',location:'doc-generator.js:xml-inspect',message:'template XML inspection',data:{xmlLen:xmlRaw.length,curlyBraceTokens:curly,plainNamesFound:plainNames,xmlSnippet:snippet},timestamp:Date.now(),hypothesisId:'I'})}).catch(()=>{});
    } catch(e) {
      fetch('http://127.0.0.1:7931/ingest/e73f326d-990a-4349-ab2b-115a1dec68c8',{method:'POST',headers:{'Content-Type':'application/json','X-Debug-Session-Id':'149aeb'},body:JSON.stringify({sessionId:'149aeb',location:'doc-generator.js:xml-inspect-err',message:'failed to inspect XML',data:{err:String(e)},timestamp:Date.now(),hypothesisId:'I'})}).catch(()=>{});
    }
    // #endregion
    const doc = new DocxTemplate(zip, {
      paragraphLoop: true,
      linebreaks: true,
    });
    const tplData = buildTemplateData(akt);
    // #region agent log
    fetch('http://127.0.0.1:7931/ingest/e73f326d-990a-4349-ab2b-115a1dec68c8',{method:'POST',headers:{'Content-Type':'application/json','X-Debug-Session-Id':'149aeb'},body:JSON.stringify({sessionId:'149aeb',location:'doc-generator.js:render-data',message:'data passed to doc.render() v4 mapped keys',data:{Number:tplData.Number,DateReview:tplData.DateReview,NameObject:tplData.NameObject,ReviewObject:tplData.ReviewObject,Comission:tplData.Comission?.slice(0,60),Pedstav:tplData.Pedstav,Conclusion:tplData.Conclusion?.slice(0,60),ustranenDate:tplData.ustranenDate,predostavlenDate:tplData.predostavlenDate,PredVoice:tplData.PredVoice,violationsLen:tplData.violations?.length,violations0:tplData.violations?.[0]},timestamp:Date.now(),hypothesisId:'H'})}).catch(()=>{});
    // #endregion
    doc.render(tplData);
    const out = typeof doc.toBlob === 'function'
      ? doc.toBlob()
      : doc.getZip().generate({
          type: 'blob',
          mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(out);
    a.download = `Акт_${akt.number}_${AktUtils.toDateInputValue(akt.date)}.docx`;
    a.click();
    URL.revokeObjectURL(a.href);
    GazpromToast.success(`Акт № ${akt.number} сформирован и скачан`);
  }

  function hasTemplate() {
    return GazpromStore.get().then((c) => Boolean(c?.[TEMPLATE_KEY]));
  }

  async function getTemplateName() {
    const c = await GazpromStore.get();
    return c?.wordTemplateName || null;
  }

  return { saveTemplate, generateFromAkt, hasTemplate, getTemplateName, buildTemplateData, TEMPLATE_KEY };
})();
