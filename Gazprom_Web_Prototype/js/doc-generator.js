/**
 * Генерация Word (.docx): прямая XML-замена маркеров + PizZip.
 * Поддерживаются оба формата шаблона: plain-text маркеры (Number, DateReview…)
 * и docxtemplater {placeholder} синтаксис.
 */
const DocGenerator = (() => {
  const TEMPLATE_KEY = 'wordTemplate';
  const PIZZIP_LOCAL = './assets/vendor/pizzip.min.js';
  const DOCX_LOCAL = './assets/vendor/docxtemplater.js';

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
    await loadScript(PIZZIP_LOCAL, () => typeof PizZip !== 'undefined');
    await loadScript(DOCX_LOCAL, () => Boolean(window.docxtemplater || window.Docxtemplater));
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

  /** Запасной вариант, если в кэше старый akt-utils.js без lowercaseFirstLetter. */
  function lowercaseFirstLetterFallback(text) {
    const val = String(text ?? '');
    if (!val) return val;
    const m = val.match(/^(\s*)(\p{Lu})/u);
    if (!m) return val;
    const idx = m[1].length;
    return val.slice(0, idx) + m[2].toLocaleLowerCase('ru-RU') + val.slice(idx + 1);
  }

  function lowercaseFirstLetter(text) {
    if (typeof AktUtils.lowercaseFirstLetter === 'function') {
      return AktUtils.lowercaseFirstLetter(text);
    }
    return lowercaseFirstLetterFallback(text);
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

    function jobTitleInText(jobTitle) {
      return lowercaseFirstLetter(String(jobTitle || '').trim());
    }

    function jobTitleForSign(jobTitle) {
      return AktUtils.capitalizeFirstLetter(String(jobTitle || '').trim());
    }

    function formatJobFioInText(p) {
      const job = jobTitleInText(p.jobTitle);
      const fio = String(p.fio || '').trim();
      return `${job}${job && fio ? ' - ' : ''}${fio}`;
    }

    function formatSignerLine(p) {
      const fioShort = formatFioForSign(p.fio);
      const jobTitle = jobTitleForSign(p.jobTitle);
      return `${jobTitle || ''}${jobTitle && fioShort ? ' ' : ''}${fioShort || ''}`.trim();
    }

    const commissionList = (akt.comission || []);

    // Описание в тексте акта: должность с маленькой буквы — "должность - ФИО"
    const commissionText = commissionList.map(formatJobFioInText).join(', ');

    const predsAll = (akt.predstavitelyComission || []);
    const pedstavText = predsAll.map(formatJobFioInText).join(', ');

    const pred = predsAll[0];
    const mainObject = (akt.objectsCheck || [])[0];
    const nameObject = AktUtils.stripSurroundingQuotes(mainObject?.title || '');
    const predVoiceLines = commissionList.map(formatSignerLine).filter(Boolean);
    const predVoiceText = predVoiceLines.join('\n\n');

    const pedstavVoiceLines = predsAll.map(formatSignerLine).filter(Boolean);
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

    const commission = commissionList.map((p, i) => {
      const job = jobTitleInText(p.jobTitle);
      const fio = String(p.fio || '').trim();
      return {
        n: i + 1,
        fio,
        job,
        jobFio: `${job}${job && fio ? ' - ' : ''}${fio}`,
      };
    });

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
      Conclusion:       akt.komissijaVyvody || akt.description || '',
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
      predJob:   jobTitleInText(pred?.jobTitle),
      commission,
      objects,
      violationCount: violations.length,
      objectCount:    objects.length,
    };
  }

  /** Текст ячейки Word: переносы строк → w:br, спецсимволы экранируются. */
  function toWordMultilineTextXml(text) {
    const lines = String(text ?? '').split(/\r?\n/).map((s) => xmlEscape(s));
    if (lines.length <= 1) return lines[0] ?? '';
    return lines.join('</w:t><w:br/><w:t>');
  }

  /** Поля нарушений в таблице акта — вставляются как в форме, с переносами. */
  const VIOLATION_TABLE_MULTILINE_MARKERS = new Set([
    'TitleViolatation',
    'ddescrVi',
    'ddescpitVi',
    'urlDoc',
    'formula',
  ]);

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
        const raw = String(item[valueKey] ?? '');
        const val = VIOLATION_TABLE_MULTILINE_MARKERS.has(marker)
          ? toWordMultilineTextXml(raw)
          : xmlEscape(raw);
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

  /** Целевой размер готового акта с фото (байт). Оригиналы в IndexedDB не меняются. */
  const TARGET_ACT_MAX_BYTES = 8_000_000;
  const DOC_PHOTO_MIN_BYTES = 50_000;
  const DOC_PHOTO_MAX_BYTES = 200_000;

  function countViolationPhotos(violations) {
    return (violations || []).reduce((n, v) => n + (v.photo?.length || 0), 0);
  }

  /** Бюджет на одно фото в docx: делим оставшийся лимит на число снимков. */
  function computeDocPhotoByteBudget(violations, templateBytes) {
    const count = countViolationPhotos(violations);
    if (count <= 0) return DOC_PHOTO_MAX_BYTES;
    const tplSize = templateBytes?.byteLength ?? templateBytes?.length ?? 400_000;
    const overhead = Math.min(tplSize + 300_000, 1_800_000);
    const forPhotos = Math.max(500_000, TARGET_ACT_MAX_BYTES - overhead);
    const perPhoto = Math.floor(forPhotos / count);
    return Math.max(DOC_PHOTO_MIN_BYTES, Math.min(DOC_PHOTO_MAX_BYTES, perPhoto));
  }

  async function blobToJpegBytes(blob, maxDim, quality) {
    if (!blob || typeof document === 'undefined') return null;
    let bitmap;
    try {
      if (typeof createImageBitmap === 'function') {
        bitmap = await createImageBitmap(blob);
      } else {
        const dataUrl = await new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = () => resolve(reader.result);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
        bitmap = await new Promise((resolve, reject) => {
          const img = new Image();
          img.onload = () => resolve(img);
          img.onerror = reject;
          img.src = dataUrl;
        });
      }
      const srcW = bitmap.width || bitmap.naturalWidth || 1;
      const srcH = bitmap.height || bitmap.naturalHeight || 1;
      const scale = Math.min(1, maxDim / Math.max(srcW, srcH, 1));
      const w = Math.max(1, Math.round(srcW * scale));
      const h = Math.max(1, Math.round(srcH * scale));
      const canvas = document.createElement('canvas');
      canvas.width = w;
      canvas.height = h;
      const ctx = canvas.getContext('2d');
      if (!ctx) return null;
      ctx.drawImage(bitmap, 0, 0, w, h);
      if (typeof bitmap.close === 'function') bitmap.close();

      return new Promise((resolve) => {
        canvas.toBlob(
          (out) => {
            if (!out) return resolve(null);
            out.arrayBuffer()
              .then((buf) => resolve(new Uint8Array(buf)))
              .catch(() => resolve(null));
          },
          'image/jpeg',
          quality
        );
      });
    } catch {
      if (bitmap && typeof bitmap.close === 'function') bitmap.close();
      return null;
    }
  }

  /**
   * Сжатие только для фототаблицы docx. Оригиналы в PhotoStore / карточках нарушений не трогаем.
   */
  async function compressPhotoForDocx(dataUrl, maxBytes) {
    if (!dataUrl) return null;
    let blob;
    try {
      blob = await fetch(dataUrl).then((r) => r.blob());
    } catch {
      return null;
    }

    const dimSteps =
      maxBytes < 85_000
        ? [600, 500, 400]
        : maxBytes < 130_000
          ? [760, 640, 520]
          : [920, 780, 640];
    const qualities = [0.7, 0.56, 0.44, 0.34];

    let best = null;
    for (const maxDim of dimSteps) {
      for (const q of qualities) {
        const bytes = await blobToJpegBytes(blob, maxDim, q);
        if (!bytes?.length) continue;
        if (!best || bytes.length < best.length) best = bytes;
        if (bytes.length <= maxBytes) return bytes;
      }
    }
    return best;
  }

  async function loadPhotoJpegBytes(photoRef, maxBytes) {
    const dataUrl = await AktUtils.photoSrcAsync(photoRef);
    if (!dataUrl) return null;
    return compressPhotoForDocx(dataUrl, maxBytes);
  }

  /**
   * Фототаблица: tempOne — № п/п (порядок строк в таблице), tempTwo — № пункта по акту (PoradNum),
   * tempThree — JPEG.
   */
  async function processPhotoTable(xml, zip, violations, templateBytes) {
    const match = xml.match(PHOTO_ROW_RE);
    if (!match) return { xml, photoTableEnd: -1 };

    const photoTableEndBefore = findPhotoTableEndPos(xml);
    const photoRowTemplate = match[0];
    const photoByteBudget = computeDocPhotoByteBudget(violations, templateBytes);
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
        const bytes = await loadPhotoJpegBytes(photoRef, photoByteBudget);
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

  const MULTILINE_SCALAR_KEYS = new Set([
    'PredVoice',
    'PedstavVoice',
    'Conclusion',
    'ddescrVi',
    'ddescpitVi',
  ]);

  /** Заменяет скалярные маркеры в XML их значениями */
  function replaceScalarMarkers(xml, data, markerKeys) {
    let result = xml;
    for (const key of markerKeys) {
      const val = MULTILINE_SCALAR_KEYS.has(key)
        ? toWordMultilineTextXml(data[key] || '')
        : xmlEscape(String(data[key] || ''));
      result = replaceScalarMarker(result, key, val);
    }
    return result;
  }

  async function generateFromAkt(akt, catalogOverride) {
    await ensureLibs();

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
      await loadScript(DOCX_LOCAL, () => Boolean(window.docxtemplater || window.Docxtemplater));
      const DocxTemplate = window.docxtemplater || window.Docxtemplater;
      if (!DocxTemplate) throw new Error('Библиотека docxtemplater не загружена');
      const doc = new DocxTemplate(zip, { paragraphLoop: true, linebreaks: true });
      doc.render(tplData);
      const outZip = doc.getZip();
      let xmlOut = outZip.files['word/document.xml']?.asText() || '';
      const photoResult = await processPhotoTable(xmlOut, outZip, akt.violations || [], templateBytes);
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
        formula:          'formula',
      });

      // 2. Фототаблица (tempOne / tempTwo / tempThree)
      const photoResult = await processPhotoTable(xml, zip, akt.violations || [], templateBytes);
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

  return {
    saveTemplate,
    generateFromAkt,
    hasTemplate,
    getTemplateName,
    buildTemplateData,
    toWordMultilineTextXml,
    TEMPLATE_KEY,
  };
})();
