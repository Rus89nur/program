/**
 * Модальные окна мастера: нарушение, быстрое добавление в справочник.
 */
const WizardModals = (() => {
  let ctx = null;
  let editingViolationId = null;
  let modalPhotos = [];

  function ensureModalRoot() {
    let root = document.getElementById('wizardModalRoot');
    if (root) return root;
    root = document.createElement('div');
    root.id = 'wizardModalRoot';
    root.className = 'modal-root';
    root.hidden = true;
    root.innerHTML = `
      <div class="modal-backdrop" data-close></div>
      <div class="modal-dialog" role="dialog" aria-modal="true">
        <div class="modal-header">
          <h3 id="modalTitle">—</h3>
          <button type="button" class="modal-close" data-close aria-label="Закрыть">×</button>
        </div>
        <div class="modal-body" id="modalBody"></div>
        <div class="modal-footer" id="modalFooter"></div>
      </div>
    `;
    document.body.appendChild(root);
    root.querySelectorAll('[data-close]').forEach((el) => {
      el.addEventListener('click', close);
    });
    return root;
  }

  function open(title, bodyHtml, footerHtml) {
    const root = ensureModalRoot();
    root.hidden = false;
    root.classList.add('show');
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalBody').innerHTML = bodyHtml;
    const footer = document.getElementById('modalFooter');
    footer.innerHTML = footerHtml || '';
    const closeEls = footer.querySelectorAll('[data-close]');
    closeEls.forEach((el) => {
      el.addEventListener('click', close);
    });
  }

  function close() {
    const root = document.getElementById('wizardModalRoot');
    if (root) {
      root.classList.remove('show');
      root.hidden = true;
    }
    editingViolationId = null;
    modalPhotos = [];
  }

  function init(context) {
    ctx = context;
  }

  async function fileToBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const r = reader.result;
        resolve(typeof r === 'string' && r.includes(',') ? r.split(',')[1] : r);
      };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  function objectOptions(objects, selectedTitle) {
    const opts = (objects || [])
      .map(
        (o) =>
          `<option value="${AktUtils.escapeHtml(o.title)}" ${o.title === selectedTitle ? 'selected' : ''}>${AktUtils.escapeHtml(o.title)}${o.subTitle ? ' — ' + AktUtils.escapeHtml(o.subTitle) : ''}</option>`
      )
      .join('');
    return `<option value="">— выберите объект —</option>${opts}`;
  }

  function openViolationEditor(violationId) {
    const draft = ctx.getDraft();
    const catalog = ctx.getCatalog();
    editingViolationId = violationId;
    const v =
      violationId != null
        ? (draft.violations || []).find((x) => x.id === violationId)
        : null;

    modalPhotos = v?.photo ? [...v.photo] : [];

    const templates = ViolationTemplates.collectFromCatalog(catalog);
    const templateOpts = templates.titles
      .map((t) => `<option value="${AktUtils.escapeHtml(t)}">${AktUtils.escapeHtml(t.slice(0, 80))}${t.length > 80 ? '…' : ''}</option>`)
      .join('');

    const vidOpts = ViolationTemplates.VIOLATION_TYPES.map(
      (t) =>
        `<option value="${AktUtils.escapeHtml(t)}" ${v?.vid === t ? 'selected' : ''}>${AktUtils.escapeHtml(t)}</option>`
    ).join('');

    const body = `
      <div class="form-group">
        <label>Шаблон из прошлых актов</label>
        <select class="form-control" id="mvTemplatePick">
          <option value="">— выбрать формулировку —</option>${templateOpts}
        </select>
      </div>
      <div class="form-group">
        <label>Формулировка нарушения</label>
        <textarea class="form-control" id="mvTitle" rows="3" placeholder="Текст нарушения">${AktUtils.escapeHtml(v?.title || '')}</textarea>
      </div>
      <div class="form-group">
        <label>Место нарушения (объект)</label>
        <select class="form-control" id="mvMesto">${objectOptions(draft.objectsCheck, v?.mesto)}</select>
      </div>
      <div class="form-group">
        <label>Вид нарушения</label>
        <select class="form-control" id="mvVid"><option value="">—</option>${vidOpts}</select>
      </div>
      <div class="form-group">
        <label>Пункт / ссылка на правило</label>
        <input class="form-control" id="mvUrl" value="${AktUtils.escapeHtml(v?.urlToPravilo || '')}" placeholder="Номер пункта или URL">
      </div>
      <div class="form-group">
        <label>Формулировка из правил</label>
        <input class="form-control" id="mvFormula" value="${AktUtils.escapeHtml(v?.formulaFromRules || '')}" list="violationFormulas">
        <datalist id="violationFormulas">${templates.formulas.map((f) => `<option value="${AktUtils.escapeHtml(f)}">`).join('')}</datalist>
      </div>
      <div class="form-group">
        <label>Фотофиксация</label>
        <div class="photo-grid" id="mvPhotoGrid">${renderModalPhotos()}</div>
        <label class="btn-ghost mv-upload-label">
          📷 Добавить фото
          <input type="file" id="mvPhotoInput" accept="image/*" multiple hidden>
        </label>
      </div>
    `;

    const footer = `
      ${violationId ? '<button type="button" class="btn-ghost modal-btn-danger" id="mvDelete">Удалить</button>' : ''}
      <button type="button" class="btn-ghost" data-close>Отмена</button>
      <button type="button" class="btn-primary" id="mvSave">Сохранить</button>
    `;

    open(violationId ? 'Редактирование нарушения' : 'Новое нарушение', body, footer);

    document.getElementById('mvTemplatePick')?.addEventListener('change', (e) => {
      if (e.target.value) {
        const ta = document.getElementById('mvTitle');
        if (ta) ta.value = e.target.value;
      }
    });
    document.getElementById('mvSave')?.addEventListener('click', saveViolation);
    document.getElementById('mvDelete')?.addEventListener('click', deleteViolation);
    document.getElementById('mvPhotoInput')?.addEventListener('change', onPhotoPick);
    bindModalPhotoClicks();
    hydrateModalPhotoThumbs();
  }

  function renderModalPhotos() {
    if (!modalPhotos.length) {
      return `<div class="photo-slot wizard-photo-add">Нет фото</div>`;
    }
    return modalPhotos
      .map(
        (p, i) => `
      <div class="photo-slot filled wizard-photo-thumb mv-photo-item" data-pidx="${i}">
        <img src="" data-photo-idx="${i}" alt="">
        <button type="button" class="photo-remove" data-rm="${i}">×</button>
      </div>`
      )
      .join('');
  }

  function bindModalPhotoClicks() {
    document.querySelectorAll('#mvPhotoGrid .photo-remove').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        modalPhotos.splice(parseInt(btn.dataset.rm, 10), 1);
        document.getElementById('mvPhotoGrid').innerHTML = renderModalPhotos();
        bindModalPhotoClicks();
      });
    });
    document.querySelectorAll('#mvPhotoGrid .mv-photo-item').forEach((el) => {
      el.addEventListener('click', (e) => {
        if (e.target.classList.contains('photo-remove')) return;
        const i = parseInt(el.dataset.pidx, 10);
        if (modalPhotos[i]) {
          Promise.all(modalPhotos.map((p) => AktUtils.photoSrcAsync(p))).then((urls) => {
            const g = urls.filter(Boolean);
            if (g.length) ctx.openLightbox(g[i], g);
          });
        }
      });
    });
  }

  async function onPhotoPick(e) {
    const files = [...(e.target.files || [])];
    for (const file of files) {
      if (!file.type.startsWith('image/')) continue;
      if (file.size > 8 * 1024 * 1024) {
        GazpromToast.error(`Файл ${file.name} слишком большой (макс. 8 МБ)`);
        continue;
      }
      modalPhotos.push(await fileToBase64(file));
    }
    document.getElementById('mvPhotoGrid').innerHTML = renderModalPhotos();
    bindModalPhotoClicks();
    hydrateModalPhotoThumbs();
    e.target.value = '';
  }

  async function hydrateModalPhotoThumbs() {
    document.querySelectorAll('#mvPhotoGrid img[data-photo-idx]').forEach(async (img) => {
      const i = parseInt(img.dataset.photoIdx, 10);
      const src = await AktUtils.photoSrcAsync(modalPhotos[i]);
      if (src) img.src = src;
    });
  }

  function saveViolation() {
    const title = document.getElementById('mvTitle')?.value?.trim();
    if (!title) {
      GazpromToast.error('Укажите формулировку нарушения');
      return;
    }
    const mesto = document.getElementById('mvMesto')?.value || '';
    const vid = document.getElementById('mvVid')?.value || '';
    const urlToPravilo = document.getElementById('mvUrl')?.value?.trim() || '';
    const formulaFromRules = document.getElementById('mvFormula')?.value?.trim() || null;

    const draft = ctx.getDraft();
    const payload = {
      id: editingViolationId || AktUtils.uuid(),
      title,
      mesto,
      urlToPravilo,
      photo: [...modalPhotos],
      vid,
      formulaFromRules: formulaFromRules || null,
    };

    if (editingViolationId) {
      draft.violations = (draft.violations || []).map((x) =>
        x.id === editingViolationId ? payload : x
      );
    } else {
      draft.violations = [...(draft.violations || []), payload];
    }

    ctx.setDraft(draft);
    close();
    ctx.onUpdate();
  }

  function deleteViolation() {
    if (!editingViolationId) return;
    GazpromToast.confirm('Удалить это нарушение?').then((ok) => {
      if (!ok) return;
      doDeleteViolation();
    });
    return;
  }

  function doDeleteViolation() {
    const draft = ctx.getDraft();
    draft.violations = (draft.violations || []).filter((x) => x.id !== editingViolationId);
    ctx.setDraft(draft);
    close();
    ctx.onUpdate();
  }

  function openQuickAdd(type) {
    const forms = {
      org: {
        title: 'Новая организация',
        html: `
          <div class="form-group"><label>Наименование</label><input class="form-control" id="qaTitle" placeholder="Например: ООО «Газпром трансгаз»"></div>
          <div class="form-group"><label>Краткое название</label><input class="form-control" id="qaSub" placeholder="Например: КДТГ"></div>
        `,
        save: async () => {
          const title = document.getElementById('qaTitle')?.value?.trim();
          if (!title) { GazpromToast.error('Укажите наименование'); return; }
          const sub = document.getElementById('qaSub')?.value?.trim();
          return CatalogService.addOrganization(title, sub);
        },
      },
      object: {
        title: 'Новый объект',
        html: `
          <div class="form-group"><label>Название объекта</label><input class="form-control" id="qaTitle" placeholder="Например: КС Краснодарская"></div>
          <div class="form-group"><label>Адрес / примечание</label><input class="form-control" id="qaSub" placeholder="Например: ул. Ленина, 1"></div>
        `,
        save: async () => {
          const title = document.getElementById('qaTitle')?.value?.trim();
          if (!title) { GazpromToast.error('Укажите название'); return; }
          const sub = document.getElementById('qaSub')?.value?.trim();
          return CatalogService.addObject(title, sub);
        },
      },
      commission: {
        title: 'Новый член комиссии',
        html: `
          <div class="form-group"><label>ФИО</label><input class="form-control" id="qaTitle" placeholder="Например: Иванов Иван Иванович"></div>
          <div class="form-group"><label>Должность</label><input class="form-control" id="qaSub" placeholder="Например: Начальник участка"></div>
        `,
        save: async () => {
          const fio = document.getElementById('qaTitle')?.value?.trim();
          if (!fio) { GazpromToast.error('Укажите ФИО'); return; }
          const job = document.getElementById('qaSub')?.value?.trim();
          return CatalogService.addCommissionPerson(fio, job);
        },
      },
      pred: {
        title: 'Новый представитель',
        html: `
          <div class="form-group"><label>ФИО</label><input class="form-control" id="qaTitle" placeholder="Например: Петров Пётр Петрович"></div>
          <div class="form-group"><label>Должность</label><input class="form-control" id="qaSub" placeholder="Например: Главный инженер"></div>
          <div class="form-group"><label>Организация</label><input class="form-control" id="qaOrg" value="${AktUtils.escapeHtml(ctx.getDraft().organization?.title || '')}"></div>
        `,
        save: async () => {
          const fio = document.getElementById('qaTitle')?.value?.trim();
          if (!fio) { GazpromToast.error('Укажите ФИО'); return; }
          const job = document.getElementById('qaSub')?.value?.trim();
          const org = document.getElementById('qaOrg')?.value?.trim();
          return CatalogService.addPredstavitely(fio, job, org);
        },
      },
    };

    const f = forms[type];
    if (!f) return;

    open(
      f.title,
      f.html,
      `<button type="button" class="btn-ghost" data-close>Отмена</button>
       <button type="button" class="btn-primary" id="qaSave">Добавить</button>`
    );

    document.getElementById('qaSave')?.addEventListener('click', async () => {
      const item = await f.save();
      if (!item) return;
      await ctx.reloadCatalog();
      close();
      ctx.onQuickAdd(type, item);
    });
  }

  return { init, open, close, openViolationEditor, openQuickAdd };
})();
