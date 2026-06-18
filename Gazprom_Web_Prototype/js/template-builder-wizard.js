/**
 * Мастер создания Word-шаблонов: выбор типа/структуры, визуальный редактор, экспорт .docx.
 */
const TemplateBuilderWizard = (() => {
  let modalEl = null;
  let step = 0;
  let templateType = 'akt';
  let structureId = 'akt-text';
  let model = null;
  let activeBlockId = null;
  let activeCell = null; // { blockId, rowIdx, cellIdx }
  let formatState = {
    font: 'Times New Roman',
    sizePt: 12,
    bold: false,
    align: 'left',
  };

  const escHtml = (s) =>
    String(s ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');

  function getDocGen() {
    return typeof DocGenerator !== 'undefined' ? DocGenerator : window.DocGenerator;
  }

  function ensureModal() {
    if (modalEl) return modalEl;
    modalEl = document.getElementById('templateBuilderModal');
    return modalEl;
  }

  function close() {
    const el = ensureModal();
    if (!el) return;
    el.hidden = true;
    document.body.classList.remove('template-builder-open');
    GazpromMobileOverlay?.unlock?.();
  }

  function setStep(next) {
    step = next;
    render();
  }

  function cloneModel(src) {
    return JSON.parse(JSON.stringify(src));
  }

  function findBlock(blockId) {
    return model?.blocks?.find((b) => b.id === blockId) || null;
  }

  function getMarkerGuideForType() {
    const gen = getDocGen();
    if (!gen) return [];
    const guide =
      templateType === 'spravka' ? gen.getSpravkaMarkerGuide() : gen.getMarkerGuide();
    return guide.filter((g) => g.id !== 'curly');
  }

  function getMarkerLabel(key) {
    const gen = getDocGen();
    if (!gen?.getMarkerLabel) return key;
    return gen.getMarkerLabel(key, templateType);
  }

  function markerChipTitle(item) {
    return `${item.label} (${item.key}) — ${item.source}`;
  }

  function renderStepper() {
    const labels = ['Тип и структура', 'Редактор', 'Сохранение'];
    return `
      <div class="template-builder-stepper" role="tablist">
        ${labels
          .map(
            (label, i) => `
          <div class="template-builder-stepper__item${i === step ? ' template-builder-stepper__item--active' : ''}${i < step ? ' template-builder-stepper__item--done' : ''}" role="tab" aria-selected="${i === step}">
            <span class="template-builder-stepper__num">${i + 1}</span>
            <span class="template-builder-stepper__label">${label}</span>
          </div>`
          )
          .join('')}
      </div>`;
  }

  function renderTypeChoice() {
    return `
      <div class="template-builder-type-grid">
        <button type="button" class="template-builder-type-card${templateType === 'akt' ? ' template-builder-type-card--active' : ''}" data-tb-type="akt">
          <span class="template-builder-type-card__icon">📄</span>
          <strong>Акт проверки</strong>
          <span class="template-builder-type-card__hint">Номер, дата, объект, нарушения…</span>
        </button>
        <button type="button" class="template-builder-type-card${templateType === 'spravka' ? ' template-builder-type-card__active' : ''}" data-tb-type="spravka">
          <span class="template-builder-type-card__icon">📋</span>
          <strong>Справка по ПБ</strong>
          <span class="template-builder-type-card__hint">Объекты, организации, нарушения…</span>
        </button>
      </div>`;
  }

  function renderStructureCards() {
    const gen = getDocGen();
    const presets = gen?.getBuilderStructurePresets?.(templateType) || [];
    return `
      <h4 class="template-builder-subtitle">Структура шаблона</h4>
      <div class="template-builder-structure-grid" role="listbox">
        ${presets
          .map(
            (p) => `
          <button type="button" class="template-builder-structure-card${structureId === p.id ? ' template-builder-structure-card--active' : ''}"
            data-tb-structure="${escHtml(p.id)}" role="option" aria-selected="${structureId === p.id}">
            <div class="template-builder-structure-card__preview">${p.previewHtml}</div>
            <div class="template-builder-structure-card__meta">
              <strong>${escHtml(p.title)}</strong>
              <span>${escHtml(p.description)}</span>
            </div>
          </button>`
          )
          .join('')}
      </div>`;
  }

  function renderStep1() {
    return `
      <div class="template-builder-step template-builder-step--setup">
        <p class="template-builder-lead">Выберите тип документа и структуру. Справа на карточках — мини-превью будущего шаблона с маркерами.</p>
        ${renderTypeChoice()}
        ${renderStructureCards()}
      </div>`;
  }

  function renderMarkerPalette() {
    const groups = getMarkerGuideForType();
    return `
      <aside class="template-builder-palette" aria-label="Маркеры шаблона">
        <h4 class="template-builder-palette__title">Маркеры</h4>
        <p class="template-builder-palette__hint">Перетащите поле в документ или нажмите для вставки. В Word сохранится служебный маркер автоматически.</p>
        ${groups
          .map(
            (group) => `
          <details class="template-builder-palette__group" open>
            <summary>${escHtml(group.title)}</summary>
            <div class="template-builder-palette__chips">
              ${group.items
                .map(
                  (item) => `
                <span class="template-builder-marker-chip"
                  draggable="true"
                  data-marker-key="${escHtml(item.key)}"
                  title="${escHtml(markerChipTitle(item))}">${escHtml(item.label)}</span>`
                )
                .join('')}
            </div>
          </details>`
          )
          .join('')}
      </aside>`;
  }

  function renderRunHtml(run) {
    if (run.kind === 'marker') {
      const label = getMarkerLabel(run.key);
      return `<span class="template-builder-doc-marker" contenteditable="false" data-marker-key="${escHtml(run.key)}" title="${escHtml(run.key)}">${escHtml(label)}</span>`;
    }
    const style = [
      run.bold ? 'font-weight:bold' : '',
      run.font ? `font-family:${run.font}` : '',
      run.sizePt ? `font-size:${run.sizePt}pt` : '',
    ]
      .filter(Boolean)
      .join(';');
    return `<span data-run-kind="text"${style ? ` style="${style}"` : ''}>${escHtml(run.text)}</span>`;
  }

  function renderBlockHtml(block, index) {
    if (block.type === 'table') {
      return `
        <div class="template-builder-block template-builder-block--table" data-block-id="${escHtml(block.id)}" data-block-index="${index}">
          <div class="template-builder-block__toolbar">
            <span class="template-builder-block__label">Таблица</span>
            <button type="button" class="btn-ghost btn-xs" data-tb-remove-block="${escHtml(block.id)}" title="Удалить">✕</button>
          </div>
          <table class="template-builder-doc-table">
            <tbody>
              ${(block.rows || [])
                .map(
                  (row, ri) => `
                <tr>
                  ${row
                    .map(
                      (cell, ci) => `
                    <td class="template-builder-doc-cell"
                      contenteditable="true"
                      data-block-id="${escHtml(block.id)}"
                      data-row="${ri}"
                      data-cell="${ci}"
                      data-placeholder="Ячейка">${(cell.runs || []).map(renderRunHtml).join('')}</td>`
                    )
                    .join('')}
                </tr>`
                )
                .join('')}
            </tbody>
          </table>
        </div>`;
    }

    const align = block.align || 'left';
    return `
      <div class="template-builder-block template-builder-block--paragraph" data-block-id="${escHtml(block.id)}" data-block-index="${index}">
        <div class="template-builder-block__toolbar">
          <span class="template-builder-block__label">Абзац</span>
          <button type="button" class="btn-ghost btn-xs" data-tb-remove-block="${escHtml(block.id)}" title="Удалить">✕</button>
        </div>
        <div class="template-builder-doc-paragraph"
          contenteditable="true"
          data-block-id="${escHtml(block.id)}"
          data-align="${escHtml(align)}"
          style="text-align:${escHtml(align)}"
          data-placeholder="Введите текст…">${(block.runs || []).map(renderRunHtml).join('')}</div>
      </div>`;
  }

  function renderFormatToolbar() {
    return `
      <div class="template-builder-format-bar" role="toolbar" aria-label="Форматирование">
        <label class="template-builder-format-bar__field">
          <span class="sr-only">Шрифт</span>
          <select id="tbFontSelect" class="template-builder-select">
            <option value="Times New Roman">Times New Roman</option>
            <option value="Arial">Arial</option>
          </select>
        </label>
        <label class="template-builder-format-bar__field">
          <span class="sr-only">Размер</span>
          <select id="tbSizeSelect" class="template-builder-select">
            <option value="10">10</option>
            <option value="11">11</option>
            <option value="12">12</option>
            <option value="14">14</option>
          </select>
        </label>
        <div class="template-builder-format-bar__align" role="group" aria-label="Выравнивание">
          <button type="button" class="template-builder-format-btn${formatState.align === 'left' ? ' template-builder-format-btn--active' : ''}" data-tb-align="left" title="По левому">≡</button>
          <button type="button" class="template-builder-format-btn${formatState.align === 'center' ? ' template-builder-format-btn--active' : ''}" data-tb-align="center" title="По центру">≡</button>
          <button type="button" class="template-builder-format-btn${formatState.align === 'right' ? ' template-builder-format-btn--active' : ''}" data-tb-align="right" title="По правому">≡</button>
        </div>
        <button type="button" class="template-builder-format-btn${formatState.bold ? ' template-builder-format-btn--active' : ''}" id="tbBoldBtn" title="Жирный"><strong>B</strong></button>
      </div>`;
  }

  function renderEditorCanvas() {
    return `
      <div class="template-builder-editor">
        ${renderFormatToolbar()}
        <div class="template-builder-editor__actions">
          <button type="button" class="btn-secondary btn-sm" id="tbAddParagraph">+ Абзац</button>
          <button type="button" class="btn-secondary btn-sm" id="tbAddTable">+ Таблица 3×2</button>
        </div>
        <div class="template-builder-page" id="tbEditorPage">
          ${(model?.blocks || []).map(renderBlockHtml).join('')}
        </div>
      </div>`;
  }

  function renderStep2() {
    return `
      <div class="template-builder-step template-builder-step--editor">
        <div class="template-builder-layout">
          ${renderMarkerPalette()}
          ${renderEditorCanvas()}
        </div>
      </div>`;
  }

  function renderStep3() {
    const defaultName =
      templateType === 'spravka' ? 'Мой_шаблон_справки.docx' : 'Мой_шаблон_акта.docx';
    const markerCount = getDocGen()?.countMarkersInBuilderModel?.(model) ?? 0;
    return `
      <div class="template-builder-step template-builder-step--save">
        <p class="template-builder-lead">Проверьте название и сохраните шаблон. Полей для подстановки: <strong>${markerCount}</strong>.</p>
        <label class="template-builder-save-field">
          <span>Название файла</span>
          <input type="text" id="tbTemplateName" class="template-builder-input" value="${escHtml(defaultName)}" autocomplete="off">
        </label>
        ${markerCount === 0 ? '<p class="template-builder-warn">⚠ Добавьте хотя бы одно поле (объект, дата и т.д.) — иначе шаблон не будет подставлять данные.</p>' : ''}
        <div class="template-builder-save-actions">
          <button type="button" class="btn-primary" id="tbSaveApply">Сохранить и применить</button>
          <button type="button" class="btn-secondary" id="tbDownloadOnly">Скачать .docx</button>
        </div>
      </div>`;
  }

  function renderFooter() {
    if (step === 0) {
      return `
        <button type="button" class="btn-ghost" data-tb-close>Отмена</button>
        <button type="button" class="btn-primary" id="tbNextStep1">Далее →</button>`;
    }
    if (step === 1) {
      return `
        <button type="button" class="btn-ghost" id="tbBackStep2">← Назад</button>
        <button type="button" class="btn-primary" id="tbNextStep2">Далее →</button>`;
    }
    return `
      <button type="button" class="btn-ghost" id="tbBackStep3">← Назад</button>
      <button type="button" class="btn-ghost" data-tb-close>Закрыть</button>`;
  }

  function render() {
    const el = ensureModal();
    if (!el) return;
    const body = el.querySelector('#templateBuilderBody');
    const footer = el.querySelector('#templateBuilderFooter');
    if (!body || !footer) return;

    let stepHtml = '';
    if (step === 0) stepHtml = renderStep1();
    else if (step === 1) stepHtml = renderStep2();
    else stepHtml = renderStep3();

    body.innerHTML = renderStepper() + stepHtml;
    footer.innerHTML = renderFooter();
    bindStepEvents();
  }

  function syncFormatControlsFromState() {
    const fontSel = document.getElementById('tbFontSelect');
    const sizeSel = document.getElementById('tbSizeSelect');
    if (fontSel) fontSel.value = formatState.font;
    if (sizeSel) sizeSel.value = String(formatState.sizePt);
  }

  function parseRunsFromEditable(el) {
    const runs = [];
    const walk = (node) => {
      if (node.nodeType === Node.TEXT_NODE) {
        const text = node.textContent || '';
        if (text) {
          runs.push({
            kind: 'text',
            text,
            font: formatState.font,
            sizePt: formatState.sizePt,
            bold: formatState.bold,
          });
        }
        return;
      }
      if (node.nodeType !== Node.ELEMENT_NODE) return;
      if (node.classList?.contains('template-builder-doc-marker')) {
        const key = node.dataset.markerKey;
        if (key) runs.push({ kind: 'marker', key });
        return;
      }
      if (node.dataset?.runKind === 'text') {
        runs.push({
          kind: 'text',
          text: node.textContent || '',
          font: node.style.fontFamily?.replace(/"/g, '') || formatState.font,
          sizePt: parseInt(node.style.fontSize, 10) || formatState.sizePt,
          bold: node.style.fontWeight === 'bold' || node.querySelector('b,strong') != null,
        });
        return;
      }
      node.childNodes.forEach(walk);
    };
    el.childNodes.forEach(walk);

    const merged = [];
    runs.forEach((run) => {
      if (run.kind === 'text' && merged.length && merged[merged.length - 1].kind === 'text') {
        const prev = merged[merged.length - 1];
        if (prev.font === run.font && prev.sizePt === run.sizePt && prev.bold === run.bold) {
          prev.text += run.text;
          return;
        }
      }
      merged.push(run);
    });
    return merged.length ? merged : [{ kind: 'text', text: '', font: formatState.font, sizePt: formatState.sizePt, bold: false }];
  }

  function syncModelFromDom() {
    if (!model) return;
    document.querySelectorAll('.template-builder-doc-paragraph').forEach((el) => {
      const block = findBlock(el.dataset.blockId);
      if (!block) return;
      block.runs = parseRunsFromEditable(el);
      block.align = el.dataset.align || el.style.textAlign || 'left';
    });
    document.querySelectorAll('.template-builder-doc-cell').forEach((el) => {
      const block = findBlock(el.dataset.blockId);
      if (!block) return;
      const ri = parseInt(el.dataset.row, 10);
      const ci = parseInt(el.dataset.cell, 10);
      if (!block.rows?.[ri]?.[ci]) return;
      block.rows[ri][ci].runs = parseRunsFromEditable(el);
    });
  }

  function insertMarkerAtSelection(markerKey) {
    const sel = window.getSelection();
    if (!sel?.rangeCount) return false;
    const range = sel.getRangeAt(0);
    let container = range.commonAncestorContainer;
    if (container.nodeType === Node.TEXT_NODE) container = container.parentElement;
    const editable = container?.closest?.('.template-builder-doc-paragraph, .template-builder-doc-cell');
    if (!editable) {
      GazpromToast.info('Сначала кликните в абзац или ячейку таблицы');
      return false;
    }
    range.deleteContents();
    const chip = document.createElement('span');
    chip.className = 'template-builder-doc-marker';
    chip.contentEditable = 'false';
    chip.dataset.markerKey = markerKey;
    chip.title = markerKey;
    chip.textContent = getMarkerLabel(markerKey);
    range.insertNode(chip);
    range.setStartAfter(chip);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
    syncModelFromDom();
    return true;
  }

  function applyFormatToSelection() {
    const sel = window.getSelection();
    if (!sel?.rangeCount || sel.isCollapsed) return;
    const range = sel.getRangeAt(0);
    const span = document.createElement('span');
    span.dataset.runKind = 'text';
    span.style.fontFamily = formatState.font;
    span.style.fontSize = `${formatState.sizePt}pt`;
    if (formatState.bold) span.style.fontWeight = 'bold';
    try {
      range.surroundContents(span);
    } catch (_) {
      const text = range.extractContents();
      span.appendChild(text);
      range.insertNode(span);
    }
    syncModelFromDom();
  }

  function applyAlignToActiveBlock(align) {
    formatState.align = align;
    let target = null;
    if (activeBlockId) {
      target = document.querySelector(`.template-builder-doc-paragraph[data-block-id="${activeBlockId}"]`);
    }
    if (!target) {
      target = document.querySelector('.template-builder-doc-paragraph:focus');
    }
    if (target) {
      target.style.textAlign = align;
      target.dataset.align = align;
      const block = findBlock(target.dataset.blockId);
      if (block) block.align = align;
    }
    document.querySelectorAll('[data-tb-align]').forEach((btn) => {
      btn.classList.toggle('template-builder-format-btn--active', btn.dataset.tbAlign === align);
    });
  }

  function bindMarkerDragDrop() {
    document.querySelectorAll('.template-builder-marker-chip').forEach((chip) => {
      chip.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', chip.dataset.markerKey);
        e.dataTransfer.effectAllowed = 'copy';
      });
      chip.addEventListener('click', () => {
        insertMarkerAtSelection(chip.dataset.markerKey);
      });
    });

    document.querySelectorAll('.template-builder-doc-paragraph, .template-builder-doc-cell').forEach((zone) => {
      zone.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'copy';
      });
      zone.addEventListener('drop', (e) => {
        e.preventDefault();
        const key = e.dataTransfer.getData('text/plain');
        if (!key) return;
        zone.focus();
        const range = document.caretRangeFromPoint?.(e.clientX, e.clientY);
        if (range) {
          const sel = window.getSelection();
          sel.removeAllRanges();
          sel.addRange(range);
        }
        insertMarkerAtSelection(key);
      });
      zone.addEventListener('focus', () => {
        activeBlockId = zone.dataset.blockId;
        if (zone.classList.contains('template-builder-doc-cell')) {
          activeCell = {
            blockId: zone.dataset.blockId,
            rowIdx: parseInt(zone.dataset.row, 10),
            cellIdx: parseInt(zone.dataset.cell, 10),
          };
        } else {
          activeCell = null;
        }
      });
      zone.addEventListener('input', () => syncModelFromDom());
    });
  }

  function bindStepEvents() {
    const el = ensureModal();
    el.querySelector('[data-tb-close]')?.addEventListener('click', close);

    if (step === 0) {
      el.querySelectorAll('[data-tb-type]').forEach((btn) => {
        btn.addEventListener('click', () => {
          templateType = btn.dataset.tbType;
          const presets = getDocGen()?.getBuilderStructurePresets?.(templateType) || [];
          structureId = presets[0]?.id || (templateType === 'spravka' ? 'spravka-text' : 'akt-text');
          render();
        });
      });
      el.querySelectorAll('[data-tb-structure]').forEach((btn) => {
        btn.addEventListener('click', () => {
          structureId = btn.dataset.tbStructure;
          render();
        });
      });
      el.querySelector('#tbNextStep1')?.addEventListener('click', () => {
        const gen = getDocGen();
        if (!gen?.buildInitialBuilderModel) {
          GazpromToast.error('Модуль Word не загружен');
          return;
        }
        model = gen.buildInitialBuilderModel(templateType, structureId);
        setStep(1);
      });
      return;
    }

    if (step === 1) {
      syncFormatControlsFromState();
      bindMarkerDragDrop();

      el.querySelector('#tbBackStep2')?.addEventListener('click', () => setStep(0));
      el.querySelector('#tbNextStep2')?.addEventListener('click', () => {
        syncModelFromDom();
        setStep(2);
      });

      el.querySelector('#tbFontSelect')?.addEventListener('change', (e) => {
        formatState.font = e.target.value;
      });
      el.querySelector('#tbSizeSelect')?.addEventListener('change', (e) => {
        formatState.sizePt = parseInt(e.target.value, 10) || 12;
      });
      el.querySelector('#tbBoldBtn')?.addEventListener('click', () => {
        formatState.bold = !formatState.bold;
        el.querySelector('#tbBoldBtn')?.classList.toggle('template-builder-format-btn--active', formatState.bold);
        applyFormatToSelection();
      });
      el.querySelectorAll('[data-tb-align]').forEach((btn) => {
        btn.addEventListener('click', () => applyAlignToActiveBlock(btn.dataset.tbAlign));
      });

      el.querySelector('#tbAddParagraph')?.addEventListener('click', () => {
        const gen = getDocGen();
        model.blocks.push(gen.builderParagraph([gen.builderTextRun('')]));
        renderStep2Partial();
      });

      el.querySelector('#tbAddTable')?.addEventListener('click', () => {
        const gen = getDocGen();
        const empty = [gen.builderTextRun('')];
        model.blocks.push(
          gen.builderTable([
            [gen.builderTextRun('Столбец 1', { bold: true }), gen.builderTextRun('Столбец 2', { bold: true }), gen.builderTextRun('Столбец 3', { bold: true })],
            [empty, empty, empty],
          ])
        );
        renderStep2Partial();
      });

      el.querySelectorAll('[data-tb-remove-block]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.dataset.tbRemoveBlock;
          model.blocks = model.blocks.filter((b) => b.id !== id);
          renderStep2Partial();
        });
      });
      return;
    }

    if (step === 2) {
      el.querySelector('#tbBackStep3')?.addEventListener('click', () => setStep(1));
      el.querySelector('#tbSaveApply')?.addEventListener('click', () => void handleSave(true));
      el.querySelector('#tbDownloadOnly')?.addEventListener('click', () => void handleSave(false));
    }
  }

  function renderStep2Partial() {
    const page = document.getElementById('tbEditorPage');
    if (!page || !model) return;
    page.innerHTML = model.blocks.map(renderBlockHtml).join('');
    bindMarkerDragDrop();
    const modal = ensureModal();
    modal.querySelectorAll('[data-tb-remove-block]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.tbRemoveBlock;
        model.blocks = model.blocks.filter((b) => b.id !== id);
        renderStep2Partial();
      });
    });
  }

  async function handleSave(applyToCatalog) {
    syncModelFromDom();
    const gen = getDocGen();
    if (!gen?.buildDocxBlobFromBuilderModel) {
      GazpromToast.error('Модуль Word не загружен');
      return;
    }
    const markerCount = gen.countMarkersInBuilderModel(model);
    if (markerCount === 0) {
      const ok = await GazpromToast.confirm('В шаблоне нет маркеров. Всё равно сохранить?', {
        confirmLabel: 'Сохранить',
      });
      if (!ok) return;
    }

    let fileName = document.getElementById('tbTemplateName')?.value?.trim();
    if (!fileName) {
      fileName = templateType === 'spravka' ? 'Мой_шаблон_справки.docx' : 'Мой_шаблон_акта.docx';
    }
    if (!/\.docx$/i.test(fileName)) fileName += '.docx';

    try {
      GazpromToast.info('Создаю шаблон Word…');
      const blob = await gen.buildDocxBlobFromBuilderModel(model);
      if (applyToCatalog) {
        if (typeof DefaultsBootstrap?.saveBuilderTemplate !== 'function') {
          throw new Error('Сохранение шаблона недоступно');
        }
        await DefaultsBootstrap.saveBuilderTemplate(blob, fileName, templateType);
        GazpromToast.success(`Шаблон «${fileName}» сохранён и выбран`);
        close();
        return;
      }
      if (typeof GazpromFileUtils !== 'undefined') {
        GazpromFileUtils.downloadBlob(blob, fileName);
      } else {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = fileName;
        a.click();
        URL.revokeObjectURL(url);
      }
      GazpromToast.success(`Файл «${fileName}» скачан`);
    } catch (err) {
      GazpromToast.error(err?.message || 'Не удалось создать шаблон');
    }
  }

  let modalBound = false;

  function bindModalOnce() {
    if (modalBound) return;
    modalBound = true;
    const el = ensureModal();
    if (!el) return;
    el.addEventListener('click', (e) => {
      if (e.target === el) close();
    });
    document.addEventListener('keydown', (e) => {
      if (e.key !== 'Escape') return;
      if (el.hidden) return;
      close();
    });
  }

  function open(options = {}) {
    bindModalOnce();
    const el = ensureModal();
    if (!el) {
      GazpromToast.error('Мастер шаблонов не найден в разметке');
      return;
    }
    step = 0;
    templateType = options.templateType === 'spravka' ? 'spravka' : 'akt';
    const presets = getDocGen()?.getBuilderStructurePresets?.(templateType) || [];
    structureId =
      options.structureId ||
      presets[0]?.id ||
      (templateType === 'spravka' ? 'spravka-text' : 'akt-text');
    model = null;
    activeBlockId = null;
    activeCell = null;
    formatState = { font: 'Times New Roman', sizePt: 12, bold: false, align: 'left' };
    el.hidden = false;
    document.body.classList.add('template-builder-open');
    GazpromMobileOverlay?.lock?.();
    render();
  }

  return { open, close };
})();

if (typeof window !== 'undefined') {
  window.TemplateBuilderWizard = TemplateBuilderWizard;
}
