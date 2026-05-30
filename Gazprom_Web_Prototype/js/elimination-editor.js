/**
 * Устранение нарушений — отметка, фото, перенос срока.
 */
const EliminationEditor = (() => {
  let filterMode = 'open';

  function bindFilters() {
    const pills = document.querySelectorAll('#screen-elimination .filter-pill');
    pills.forEach((btn) => {
      btn.addEventListener('click', () => {
        pills.forEach((p) => p.classList.remove('active'));
        btn.classList.add('active');
        filterMode = btn.textContent.includes('Устранено') && !btn.textContent.includes('Не')
          ? 'done'
          : 'open';
        GazpromStore.get().then((d) => GazpromUI.renderElimination(d, { filterMode }));
      });
    });
  }

  function openMarkForm(elimination, catalog) {
    const form = document.createElement('div');
    form.className = 'catalog-form-overlay';
    form.innerHTML = `
      <div class="catalog-form-dialog card" style="max-width:520px">
        <h3>Устранение — акт № ${AktUtils.escapeHtml(elimination.aktNumber)}</h3>
        <p style="font-size:13px;color:var(--text-muted);margin-bottom:12px">${AktUtils.escapeHtml(elimination.violationTitle || '')}</p>
        <div class="form-group">
          <label><input type="checkbox" id="elMarkDone" ${elimination.isEliminated ? 'checked' : ''}> Отмечено как устранено</label>
        </div>
        <div class="form-group">
          <label>Новый срок устранения</label>
          <input type="date" class="form-control" id="elNewDate" value="${AktUtils.toDateInputValue(elimination.newEliminationDate || elimination.originalEliminationDate)}">
        </div>
        <div class="form-group">
          <label>Комментарий</label>
          <textarea class="form-control" id="elComment" rows="2">${AktUtils.escapeHtml(elimination.comment || '')}</textarea>
        </div>
        <div class="form-group">
          <label>Фото «после»</label>
          <input type="file" id="elPhotoAfter" accept="image/*" multiple>
        </div>
        <div class="catalog-form-actions">
          <button type="button" class="btn-ghost" data-cancel>Отмена</button>
          <button type="button" class="btn-primary" data-save>Сохранить</button>
        </div>
      </div>
    `;
    document.body.appendChild(form);
    const remove = () => form.remove();
    form.querySelector('[data-cancel]').onclick = remove;

    form.querySelector('[data-save]').onclick = async () => {
      const list = [...(catalog.violationEliminations || [])];
      const idx = list.findIndex((e) => e.id === elimination.id);
      if (idx < 0) return;
      const rec = { ...list[idx] };
      rec.isEliminated = document.getElementById('elMarkDone').checked;
      const nd = document.getElementById('elNewDate').value;
      if (nd) {
        rec.newEliminationDate = new Date(nd + 'T12:00:00').toISOString();
        rec.deadlineHistory = [
          ...(rec.deadlineHistory || []),
          {
            deadlineDate: rec.newEliminationDate,
            changedAt: new Date().toISOString(),
          },
        ];
      }
      rec.comment = document.getElementById('elComment').value.trim();
      const files = document.getElementById('elPhotoAfter').files;
      if (files?.length) {
        rec.afterPhotos = rec.afterPhotos || [];
        for (const f of files) {
          const b64 = await fileToBase64(f);
          rec.afterPhotos.push(await PhotoStore.ingestPhotoRef(b64));
        }
      }
      if (rec.isEliminated) rec.eliminatedAt = new Date().toISOString();
      list[idx] = rec;
      catalog.violationEliminations = list;
      await GazpromStore.set(catalog);
      GazpromStore.invalidateCache();
      await GazpromUI.refreshAll();
      GazpromToast.success('Сохранено');
      remove();
    };
  }

  function fileToBase64(file) {
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

  function bindTableActions() {
    document.getElementById('eliminationTableBody')?.addEventListener('click', async (e) => {
      const btn = e.target.closest('[data-elim-mark]');
      if (!btn) return;
      const id = btn.dataset.elimMark;
      const catalog = await GazpromStore.get();
      const item = (catalog.violationEliminations || []).find((x) => x.id === id);
      if (item) openMarkForm(item, catalog);
    });
  }

  return { bindFilters, bindTableActions, filterMode: () => filterMode };
})();
