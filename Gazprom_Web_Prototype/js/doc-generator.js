/**
 * Генерация Word (.docx): прямая XML-замена маркеров + PizZip.
 * Поддерживаются оба формата шаблона: plain-text маркеры (Number, DateReview…)
 * и docxtemplater {placeholder} синтаксис.
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

  async function loadTemplateBlob(catalogOverride) {
    const catalog = catalogOverride || (await GazpromStore.get());
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
    function formatFioForSign(fio) {
      const raw = String(fio || '').trim();
      if (!raw) return '';
      const parts = raw.split(/\s+/).filter(Boolean);
      if (parts.length >= 3) {
        const [lastName, firstName, middleName] = parts;
        const first = firstName?.[0] ? `${firstName[0]}.` : '';
        const middle = middleName?.[0] ? `${middleName[0]}.` : '';
        return `${first}${middle} ${lastName}`.trim();
      }
      return raw;
    }

    function capitalizeFirst(text) {
      const s = String(text || '').trim();
      if (!s) return '';
      return s.charAt(0).toUpperCase() + s.slice(1);
    }

    const commissionList = (akt.comission || []);

    // FIX 1: Формат комиссии — "должность - ФИО"
    const commissionText = commissionList
      .map((p) => `${p.jobTitle || ''}${p.jobTitle && p.fio ? ' - ' : ''}${p.fio || ''}`)
      .join(', ');

    // FIX 2: Все представители, не только первый
    const predsAll = (akt.predstavitelyComission || []);
    const pedstavText = predsAll
      .map((p) => `${p.jobTitle || ''}${p.jobTitle && p.fio ? ' - ' : ''}${p.fio || ''}`)
      .join('; ');

    const pred = predsAll[0];
    const mainObject = (akt.objectsCheck || [])[0];
    const nameObject = mainObject?.title || '';
    const predVoiceLines = commissionList
      .map((p) => {
        const fioShort = formatFioForSign(p.fio);
        const jobTitle = capitalizeFirst(p.jobTitle);
        return `${jobTitle || ''}${jobTitle && fioShort ? ' — ' : ''}${fioShort || ''}`;
      })
      .filter(Boolean);
    const predVoiceText = predVoiceLines.join('\n\n');

    const pedstavVoiceLines = predsAll
      .map((p) => {
        const fioShort = formatFioForSign(p.fio);
        const jobTitle = capitalizeFirst(p.jobTitle);
        return `${jobTitle || ''}${jobTitle && fioShort ? ' — ' : ''}${fioShort || ''}`;
      })
      .filter(Boolean);
    const pedstavVoiceText = pedstavVoiceLines.join('\n\n');

    // Нарушения для таблицы
    const violations = (akt.violations || []).map((v, i) => ({
      PoradNum:          i + 1,
      TitleViolatation:  v.mesto || '',                     // только место нарушения
      ddescrVi:          v.title || '',                     // формулировка нарушения (карточка)
      ddescpitVi:        v.title || '',                     // формулировка нарушения (карточка)
      urlDoc:            v.urlToPravilo || '',               // ссылка на нормативный документ
      n: i + 1, title: v.title || '', mesto: v.mesto || '',
      vid: v.vid || '',
      formula: v.formulaFromRules || '',
      urlToPravilo: v.urlToPravilo || '',
    }));

    const objects = (akt.objectsCheck || []).map((o, i) => ({
      n: i + 1, title: o.title || '', subtitle: o.subTitle || '',
    }));

    const commission = commissionList.map((p, i) => ({
      n: i + 1,
      fio: p.fio || '',
      job: p.jobTitle || '',
      jobFio: `${p.jobTitle || ''}${p.jobTitle && p.fio ? ' - ' : ''}${p.fio || ''}`,
    }));

    return {
      Number:           akt.number || '',
      DateReview:       AktUtils.formatDateShort(akt.date),
      NameObject:       nameObject,
      ReviewObject:     akt.organization?.title || '',
      Comission:        commissionText,
      Pedstav:          pedstavText,
      PredVoice:        predVoiceText,
      predVoiceLines,
      PedstavVoice:     pedstavVoiceText,
      pedstavVoiceLines,
      Conclusion:       akt.description || akt.komissijaVyvody || '',
      ustranenDate:     AktUtils.formatDateShort(akt.actustranenDate),
      predostavlenDate: AktUtils.formatDateShort(akt.actPredostavlenDate),
      violations,
      // запасные имена
      number:    akt.number || '',
      date:      AktUtils.formatDateShort(akt.date),
      org:       akt.organization?.title || '',
      orgShort:  akt.organization?.shortTitle || '',
      description: akt.description || '',
      elimDate:  AktUtils.formatDateShort(akt.actustranenDate),
      predDate:  AktUtils.formatDateShort(akt.actPredostavlenDate),
      utverDate: AktUtils.formatDateShort(akt.actUtverzdenDate),
      UtverzderDate: AktUtils.formatDateShort(akt.actUtverzdenDate),
      utverzderDate: AktUtils.formatDateShort(akt.actUtverzdenDate),
      predFio:   pred?.fio || '',
      predJob:   pred?.jobTitle || '',
      commission,
      objects,
      violationCount: violations.length,
      objectCount:    objects.length,
    };
  }

  function toWordMultilineTextXml(text) {
    const lines = String(text || '').split(/\r?\n/).map((s) => xmlEscape(s));
    return lines.join('</w:t><w:br/><w:t>');
  }

  function buildSignatureTableXml(lines) {
    const signers = (lines || []).filter(Boolean);
    if (!signers.length) return '';

    // 1 cm ≈ 567 twips
    const w1 = 5103; // 9.00 cm
    const w2 = 425;  // 0.75 cm
    const w3 = 4099; // 7.23 cm

    const rows = signers.map((line) => {
      const signer = xmlEscape(line);
      return [
        '<w:tr>',
        `<w:tc><w:tcPr><w:tcW w:w="${w1}" w:type="dxa"/><w:tcBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/></w:tcBorders></w:tcPr><w:p><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr><w:t>${signer}</w:t></w:r></w:p></w:tc>`,
        `<w:tc><w:tcPr><w:tcW w:w="${w2}" w:type="dxa"/><w:tcBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/></w:tcBorders></w:tcPr><w:p/></w:tc>`,
        `<w:tc><w:tcPr><w:tcW w:w="${w3}" w:type="dxa"/><w:tcBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:right w:val="nil"/><w:bottom w:val="single" w:sz="8" w:space="0" w:color="auto"/></w:tcBorders></w:tcPr><w:p/></w:tc>`,
        '</w:tr>',
        '<w:tr>',
        `<w:tc><w:tcPr><w:tcW w:w="${w1}" w:type="dxa"/><w:tcBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/></w:tcBorders></w:tcPr><w:p/></w:tc>`,
        `<w:tc><w:tcPr><w:tcW w:w="${w2}" w:type="dxa"/><w:tcBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/></w:tcBorders></w:tcPr><w:p/></w:tc>`,
        `<w:tc><w:tcPr><w:tcW w:w="${w3}" w:type="dxa"/><w:tcBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/></w:tcBorders></w:tcPr><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr><w:t>(подпись)</w:t></w:r></w:p></w:tc>`,
        '</w:tr>',
      ].join('');
    }).join('');

    return [
      `<w:tbl>`,
      `<w:tblPr><w:tblW w:w="${w1 + w2 + w3}" w:type="dxa"/><w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders></w:tblPr>`,
      `<w:tblGrid><w:gridCol w:w="${w1}"/><w:gridCol w:w="${w2}"/><w:gridCol w:w="${w3}"/></w:tblGrid>`,
      rows,
      `</w:tbl>`,
    ].join('');
  }

  /** Все вхождения маркера (в шаблоне их два: до и после фототаблицы). */
  function replaceAllMarkersWithSignatureTable(xml, marker, lines) {
    const hasLines = (lines || []).some(Boolean);
    let result = xml;
    let tableEndPos = -1;
    let found = false;
    while (result.indexOf(marker) !== -1) {
      const next = replaceMarkerWithSignatureTable(
        result,
        marker,
        hasLines ? lines : []
      );
      if (!next.found) break;
      found = true;
      result = next.xml;
      if (next.tableEndPos > 0) tableEndPos = next.tableEndPos;
      if (hasLines && next.tableEndPos < 0) break;
    }
    return { xml: result, tableEndPos, found };
  }

  function replaceMarkerWithSignatureTable(xml, marker, lines) {
    const pos = xml.indexOf(marker);
    if (pos === -1) return { xml, tableEndPos: -1, found: false };

    const beforeMarker = xml.slice(0, pos);
    const wtMatch = beforeMarker.match(/<w:t(?:\s[^>]*)?>[^<]*$/);
    if (wtMatch) {
      const tStart = beforeMarker.length - wtMatch[0].length;
      const tOpenEnd = xml.indexOf('>', tStart);
      const tEnd = tOpenEnd === -1 ? -1 : xml.indexOf('</w:t>', tOpenEnd);
      if (tOpenEnd !== -1 && tEnd !== -1) {
        const tBody = xml.slice(tOpenEnd + 1, tEnd).split(marker).join('');
        xml = xml.slice(0, tOpenEnd + 1) + tBody + xml.slice(tEnd);
      } else {
        xml = xml.split(marker).join('');
      }
    } else {
      xml = xml.split(marker).join('');
    }

    const pEndTag = '</w:p>';
    const pEnd = xml.indexOf(pEndTag, pos);
    if (pEnd === -1) return { xml, tableEndPos: -1, found: true };

    const tableXml = buildSignatureTableXml(lines);
    if (!tableXml) return { xml, tableEndPos: -1, found: true };

    const insertPos = pEnd + pEndTag.length;
    const newXml = xml.slice(0, insertPos) + tableXml + xml.slice(insertPos);
    return { xml: newXml, tableEndPos: insertPos + tableXml.length, found: true };
  }

  /** Конец внешней таблицы с маркером tempOne (фототаблица шаблона). */
  function findPhotoTableEndPos(xml) {
    const match = xml.match(PHOTO_ROW_RE);
    if (!match) return -1;
    const rowStart = xml.indexOf(match[0]);
    if (rowStart === -1) return -1;
    const before = xml.slice(0, rowStart);
    let depth =
      (before.match(/<w:tbl[\s>]/g) || []).length -
      (before.match(/<\/w:tbl>/g) || []).length;
    if (depth <= 0) return -1;
    let pos = rowStart + match[0].length;
    while (depth > 0) {
      const close = xml.indexOf('</w:tbl>', pos);
      if (close === -1) return -1;
      depth -= 1;
      pos = close + '</w:tbl>'.length;
    }
    return pos;
  }

  function nextRelationshipIds(relsXML, count) {
    let maxNum = 0;
    for (const m of relsXML.matchAll(/Id="rId(\d+)"/g)) {
      maxNum = Math.max(maxNum, parseInt(m[1], 10));
    }
    return Array.from({ length: count }, (_, i) => `rId${maxNum + 1 + i}`);
  }

  /** Проверка document.xml перед упаковкой docx (как scripts/validate-docx-xml.mjs). */
  function validateDocumentXml(xml) {
    const issues = [];
    const WT_OPEN = /<w:t(?:\s|>|\/)/g;
    for (const m of xml.matchAll(WT_OPEN)) {
      const start = m.index;
      const openEnd = xml.indexOf('>', start);
      const end = xml.indexOf('</w:t>', openEnd);
      if (end === -1) continue;
      const body = xml.slice(openEnd + 1, end);
      if (
        body.includes('<w:drawing') ||
        body.includes('<w:tbl') ||
        body.includes('<w:p ') ||
        body.includes('<w:p>') ||
        body.includes('<w:r ')
      ) {
        issues.push('элементы внутри w:t');
        break;
      }
    }
    const tblOpen = (xml.match(/<w:tbl[\s>]/g) || []).length;
    const tblClose = (xml.match(/<\/w:tbl>/g) || []).length;
    if (tblOpen !== tblClose) {
      issues.push(`несбалансированные таблицы (${tblOpen}/${tblClose})`);
    }
    return issues;
  }

  function assertValidDocumentXml(xml) {
    const issues = validateDocumentXml(xml);
    if (issues.length) {
      throw new Error(
        'Ошибка структуры Word-документа. Пересоздайте акт. Детали: ' + issues.join('; ')
      );
    }
  }

  /** Подписи комиссии (PredVoice) и представителей (PedstavVoice) — по всем маркерам в шаблоне. */
  function applySignatureTables(xml, tplData, photoTableEnd = -1) {
    let result = xml;
    const commLines = tplData.predVoiceLines || [];
    const repLines = tplData.pedstavVoiceLines || [];

    const commission = replaceAllMarkersWithSignatureTable(result, 'PredVoice', commLines);
    result = commission.xml;

    const representatives = replaceAllMarkersWithSignatureTable(result, 'PedstavVoice', repLines);
    result = representatives.xml;

    if (repLines.length && !representatives.found && commission.tableEndPos > 0) {
      const repTableXml = buildSignatureTableXml(repLines);
      if (repTableXml) {
        return (
          result.slice(0, commission.tableEndPos) +
          repTableXml +
          result.slice(commission.tableEndPos)
        );
      }
    }

    if (commLines.length && !commission.found) {
      const endPos =
        photoTableEnd > 0 ? photoTableEnd : findPhotoTableEndPos(result);
      const commTableXml = buildSignatureTableXml(commLines);
      const repTableXml = buildSignatureTableXml(repLines);
      if (endPos > 0 && commTableXml) {
        const block = commTableXml + (repTableXml || '');
        return result.slice(0, endPos) + block + result.slice(endPos);
      }
    }

    return result;
  }

  function replacePredVoiceWithTable(xml, lines) {
    return replaceMarkerWithSignatureTable(xml, 'PredVoice', lines).xml;
  }

  /** Экранирует спецсимволы XML в значениях */
  function xmlEscape(str) {
    return String(str || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  /**
   * Находит строку таблицы <w:tr> содержащую маркер rowKey,
   * дублирует её для каждого элемента массива rows и подставляет fieldMap.
   */
  function expandTableRows(xml, rowKey, rows, fieldMap) {
    const keyPos = xml.indexOf(rowKey);
    if (keyPos === -1 || !rows.length) return xml;

    // Найти начало строки: последний <w:tr перед позицией маркера
    const trOpenA = xml.lastIndexOf('<w:tr ', keyPos);
    const trOpenB = xml.lastIndexOf('<w:tr>', keyPos);
    const rowStart = Math.max(trOpenA, trOpenB);
    if (rowStart === -1) return xml;

    // Найти конец строки: первый </w:tr> после маркера
    const rowEnd = xml.indexOf('</w:tr>', keyPos) + '</w:tr>'.length;
    if (rowEnd < '</w:tr>'.length) return xml;

    const templateRow = xml.slice(rowStart, rowEnd);

    const expandedRows = rows.map((item) => {
      let row = templateRow;
      for (const [marker, valueKey] of Object.entries(fieldMap)) {
        const val = xmlEscape(String(item[valueKey] ?? ''));
        row = row.split(marker).join(val);
      }
      return row;
    }).join('');

    return xml.slice(0, rowStart) + expandedRows + xml.slice(rowEnd);
  }

  const PHOTO_ROW_RE = /<w:tr[^>]*>(?:(?!<\/w:tr>)[\s\S])*?tempOne[\s\S]*?<\/w:tr>/;
  const TEMP_THREE_RUN_RE =
    /<w:r\b[^>]*>(?:(?!<\/w:r>)[\s\S])*?tempThree(?:(?!<\/w:r>)[\s\S])*?<\/w:r>/;

  function buildImageEmbedXml(relId, imageIndex) {
    return `<w:r><w:drawing><wp:inline><wp:extent cx="2880000" cy="2880000"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:docPr id="${imageIndex}" name="Image${imageIndex}"/><wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="0" name="image${imageIndex}.jpg"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="${relId}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="2880000" cy="2880000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>`;
  }

  function replaceTempThreeInRow(row, imageRunsXml) {
    if (TEMP_THREE_RUN_RE.test(row)) {
      return row.replace(TEMP_THREE_RUN_RE, imageRunsXml || '');
    }
    return row.split('tempThree').join(imageRunsXml || '');
  }

  function ensureImageContentTypes(zip) {
    const path = '[Content_Types].xml';
    let ct = zip.files[path]?.asText() || '';
    if (/Extension="jpe?g"/i.test(ct)) return;
    const insert =
      '<Default Extension="jpeg" ContentType="image/jpeg"/>' +
      '<Default Extension="jpg" ContentType="image/jpeg"/>';
    if (ct.includes('<Default Extension="xml"')) {
      ct = ct.replace('<Default Extension="xml"', insert + '<Default Extension="xml"');
    } else {
      ct = ct.replace('</Types>', insert + '</Types>');
    }
    zip.file(path, ct);
  }

  /** Сжатие фото для вставки в docx (как в iOS GenerateViewModel). */
  function compressDataUrlToJpeg(dataUrl, maxDim = 1200, quality = 0.82) {
    return new Promise((resolve) => {
      const img = new Image();
      img.onload = () => {
        let w = img.naturalWidth;
        let h = img.naturalHeight;
        const scale = Math.min(1, maxDim / Math.max(w, h, 1));
        w = Math.max(1, Math.round(w * scale));
        h = Math.max(1, Math.round(h * scale));
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        canvas.getContext('2d').drawImage(img, 0, 0, w, h);
        canvas.toBlob(
          (blob) => {
            if (!blob) return resolve(null);
            blob.arrayBuffer().then((buf) => resolve(new Uint8Array(buf))).catch(() => resolve(null));
          },
          'image/jpeg',
          quality
        );
      };
      img.onerror = () => resolve(null);
      img.src = dataUrl;
    });
  }

  async function loadPhotoJpegBytes(photoRef) {
    const dataUrl = await AktUtils.photoSrcAsync(photoRef);
    if (!dataUrl) return null;
    return compressDataUrlToJpeg(dataUrl);
  }

  /**
   * Фототаблица: tempOne — № п/п (порядок строк в таблице), tempTwo — № пункта по акту (PoradNum),
   * tempThree — JPEG.
   */
  async function processPhotoTable(xml, zip, violations) {
    const match = xml.match(PHOTO_ROW_RE);
    if (!match) return { xml, photoTableEnd: -1 };

    const photoTableEndBefore = findPhotoTableEndPos(xml);
    const photoRowTemplate = match[0];
    let allPhotoRows = '';
    const pendingImages = [];
    let rowIndex = 0;

    for (let i = 0; i < (violations || []).length; i++) {
      const violation = violations[i];
      if (!violation.photo?.length) continue;
      rowIndex += 1;
      const poradNum = i + 1;
      let row = photoRowTemplate;
      row = row.split('tempOne').join(`${rowIndex}.`);
      row = row.split('tempTwo').join(`${poradNum}.`);

      let imageXMLSnippets = '';
      for (const photoRef of violation.photo) {
        const bytes = await loadPhotoJpegBytes(photoRef);
        if (!bytes?.length) continue;
        pendingImages.push({ bytes });
        const imageIndex = pendingImages.length;
        imageXMLSnippets += buildImageEmbedXml(`__REL_${imageIndex}__`, imageIndex);
      }

      row = replaceTempThreeInRow(row, imageXMLSnippets);
      allPhotoRows += row;
    }

    if (!allPhotoRows) {
      return { xml, photoTableEnd: photoTableEndBefore };
    }

    const relsPath = 'word/_rels/document.xml.rels';
    let relsXML = zip.files[relsPath]?.asText() || '';
    const relIds = nextRelationshipIds(relsXML, pendingImages.length);

    pendingImages.forEach((item, i) => {
      const relId = relIds[i];
      const imageName = `image_gen_${i + 1}.jpg`;
      item.relId = relId;
      item.imageName = imageName;
      zip.file(`word/media/${imageName}`, item.bytes);
    });

    allPhotoRows = allPhotoRows.replace(/__REL_(\d+)__/g, (_, n) => {
      const item = pendingImages[parseInt(n, 10) - 1];
      return item?.relId || '';
    });

    xml = xml.replace(PHOTO_ROW_RE, allPhotoRows);
    let photoTableEnd = findPhotoTableEndPos(xml);
    if (photoTableEnd < 0 && photoTableEndBefore > 0) {
      photoTableEnd = photoTableEndBefore;
    }

    if (relsXML && pendingImages.length) {
      const relsSnippets = pendingImages
        .map(
          (item) =>
            `<Relationship Id="${item.relId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${item.imageName}"/>`
        )
        .join('');
      relsXML = relsXML.replace('</Relationships>', relsSnippets + '</Relationships>');
      zip.file(relsPath, relsXML);
      ensureImageContentTypes(zip);
    }

    return { xml, photoTableEnd };
  }

  /** Заменяет скалярный маркер; Pedstav не затрагивает PedstavVoice. */
  function replaceScalarMarker(xml, key, val) {
    if (key === 'Pedstav') {
      return xml.replace(/Pedstav(?!Voice)/g, val);
    }
    return xml.split(key).join(val);
  }

  /** Заменяет скалярные маркеры в XML их значениями */
  function replaceScalarMarkers(xml, data, markerKeys) {
    let result = xml;
    for (const key of markerKeys) {
      const val = key === 'PredVoice' || key === 'PedstavVoice'
        ? toWordMultilineTextXml(data[key] || '')
        : xmlEscape(String(data[key] || ''));
      result = replaceScalarMarker(result, key, val);
    }
    return result;
  }

  async function generateFromAkt(akt, catalogOverride) {
    await loadScript(PIZZIP_CDN, () => typeof PizZip !== 'undefined');

    const templateBytes = await loadTemplateBlob(catalogOverride);
    if (!templateBytes) {
      throw new Error('Загрузите шаблон Word (.docx) в Настройках → Шаблон акта');
    }

    const zip = new PizZip(templateBytes);
    let xml = zip.files['word/document.xml']?.asText() || '';

    const hasCurlyTokens = /\{[a-zA-Z]/.test(xml);

    const tplData = buildTemplateData(akt);
    let blob;

    if (hasCurlyTokens) {
      // Шаблон использует {placeholder} — docxtemplater
      await loadScript(DOCX_CDN, () => Boolean(window.docxtemplater || window.Docxtemplater));
      const DocxTemplate = window.docxtemplater || window.Docxtemplater;
      if (!DocxTemplate) throw new Error('Библиотека docxtemplater не загружена');
      const doc = new DocxTemplate(zip, { paragraphLoop: true, linebreaks: true });
      doc.render(tplData);
      const outZip = doc.getZip();
      let xmlOut = outZip.files['word/document.xml']?.asText() || '';
      const photoResult = await processPhotoTable(xmlOut, outZip, akt.violations || []);
      xmlOut = applySignatureTables(photoResult.xml, tplData, photoResult.photoTableEnd);
      assertValidDocumentXml(xmlOut);
      outZip.file('word/document.xml', xmlOut);
      blob = outZip.generate({
        type: 'blob',
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      });
    } else {
      // Шаблон использует plain-text маркеры — прямая XML-замена
      // 1. Сначала раскрываем строки таблицы нарушений
      xml = expandTableRows(xml, 'PoradNum', tplData.violations, {
        PoradNum:         'PoradNum',
        TitleViolatation: 'TitleViolatation',
        ddescrVi:         'ddescrVi',
        ddescpitVi:       'ddescpitVi',   // FIX 4: алиас на опечатку в шаблоне
        urlDoc:           'urlDoc',
      });

      // 2. Фототаблица (tempOne / tempTwo / tempThree)
      const photoResult = await processPhotoTable(xml, zip, akt.violations || []);
      xml = photoResult.xml;

      // 3. Подписи комиссии и представителей
      xml = applySignatureTables(xml, tplData, photoResult.photoTableEnd);

      // 4. Заменяем скалярные маркеры
      xml = replaceScalarMarkers(xml, tplData, [
        'Number', 'DateReview', 'NameObject', 'ReviewObject',
        'Comission', 'Pedstav', 'Conclusion',
        'ustranenDate', 'predostavlenDate',
        'UtverzderDate', 'utverzderDate',
        'ddescrVi', 'ddescpitVi',  // FIX 4: чистим если остались вне таблицы
      ]);

      assertValidDocumentXml(xml);
      zip.file('word/document.xml', xml);
      blob = zip.generate({
        type: 'blob',
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      });
    }

    // Скачиваем файл — автоматически открывается в Word на Mac/Windows
    const blobUrl = URL.createObjectURL(blob);
    const fileName = `Акт_${akt.number}_${AktUtils.toDateInputValue(akt.date)}.docx`;
    const a = document.createElement('a');
    a.href = blobUrl;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(blobUrl), 10000);
    GazpromToast.success(`Акт № ${akt.number} сформирован — открывается в Word`);
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
