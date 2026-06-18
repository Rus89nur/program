/**
 * Общий UI шага «Нарушения» для мастера акта и справки.
 */
const WizardViolationsUI = (() => {
  function photoImgTag(ref, violationId, photoIdx) {
    const ph =
      (typeof PhotoStore !== 'undefined' && PhotoStore.IMG_PLACEHOLDER) ||
      'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
    if (!ref) return '<img alt="" loading="lazy" decoding="async">';
    if (typeof PhotoStore !== 'undefined' && PhotoStore.isPhotoId(ref)) {
      const safe = AktUtils.escapeHtml(String(ref));
      return `<img data-photo-ref="${safe}" src="${ph}" alt="" loading="lazy" decoding="async">`;
    }
    if (violationId != null && photoIdx != null) {
      const safeVid = AktUtils.escapeHtml(String(violationId));
      return `<img data-viol-vid="${safeVid}" data-viol-pidx="${photoIdx}" src="${ph}" alt="" loading="lazy" decoding="async">`;
    }
    return `<img src="${ph}" alt="" loading="lazy" decoding="async">`;
  }

  function create(ctx) {
    const {
      ids,
      editClass,
      delClass,
      getDraft,
      getViolSearchQuery,
      setViolSearchQuery,
      getStep,
      violationsStep,
      panelsHost,
      scheduleAutosave,
      render,
      updateSummary,
      openLightbox,
      docLabel,
      photoSectionTitle,
      renderStepExtra,
      formatViolationTitle,
      getViolationFormat,
    } = ctx;

    function resolveViolationFormat() {
      return typeof getViolationFormat === 'function'
        ? getViolationFormat()
        : null;
    }

    function isViolFiltering() {
      return !!String(getViolSearchQuery()).trim();
    }

    function filterViolations(violations, query) {
      return ViolationSearch.filterActViolations(violations, query);
    }

    function violIndexInDoc(violationId, allViolations) {
      const idx = (allViolations || []).findIndex((v) => v.id === violationId);
      return idx >= 0 ? idx + 1 : '?';
    }

    function renderViolCardHtml(v, displayNum) {
      const fmt = resolveViolationFormat();
      const normalizedFmt = fmt && typeof SpravkaUtils?.normalizeViolationFormat === 'function'
        ? SpravkaUtils.normalizeViolationFormat(fmt)
        : null;
      const displayTitle = typeof formatViolationTitle === 'function'
        ? formatViolationTitle(v)
        : (v.title || '');
      const photos = v.photo?.length || 0;
      const vidBadge = v.vid
        ? `<span class="viol-card-badge" title="${AktUtils.escapeHtml(v.vid)}">${AktUtils.escapeHtml(v.vid)}</span>`
        : '';
      const ruleRef = typeof SpravkaUtils?.getViolationRuleRef === 'function'
        ? SpravkaUtils.getViolationRuleRef(v)
        : (v.urlToPravilo || '');
      const refLine = ruleRef && !(normalizedFmt?.includeRuleRef)
        ? `<div class="viol-card-subtitle">📄 ${AktUtils.escapeHtml(ruleRef)}</div>`
        : '';
      const showMestoLine = !normalizedFmt?.includeMesto;
      const maxThumbs = 5;
      const thumbsHtml = photos
        ? `<div class="viol-card-thumbs">
            ${(v.photo || []).slice(0, maxThumbs).map((p, idx) =>
              `<div class="viol-card-thumb wizard-photo-thumb photo-slot filled" data-vid="${v.id}" data-pidx="${idx}">
                ${photoImgTag(p, v.id, idx)}
              </div>`
            ).join('')}
            ${photos > maxThumbs ? `<div class="viol-card-thumb viol-card-thumb-more">+${photos - maxThumbs}</div>` : ''}
          </div>`
        : '';
      return `<div class="viol-card" data-violation-id="${v.id}" role="button" tabindex="0" title="Открыть карточку нарушения" draggable="true">
        <div class="viol-card-num">${displayNum}</div>
        <div class="viol-card-body">
          <div class="viol-card-title">${AktUtils.escapeHtml(displayTitle)}</div>
          ${refLine}
          <div class="viol-card-meta">
            ${showMestoLine
              ? `<span class="viol-card-mesto">📍 ${v.mesto ? AktUtils.escapeHtml(v.mesto) : '<span style="color:var(--border)">—</span>'}</span>`
              : ''}
            ${vidBadge}
          </div>
          ${thumbsHtml}
        </div>
        <div class="viol-card-actions">
          <button type="button" class="btn-ghost btn-sm ${editClass}" data-vid="${v.id}" title="Редактировать">✏️</button>
          <button type="button" class="btn-ghost btn-sm modal-btn-danger ${delClass}" data-vid="${v.id}" title="Удалить">🗑</button>
        </div>
      </div>`;
    }

    function renderViolCardsListInnerHtml(allViolations, filteredViolations) {
      if (!allViolations.length) {
        return `<div class="viol-empty">
          <div class="viol-empty-icon">⚠️</div>
          <div class="viol-empty-text">Нарушения не добавлены</div>
          <div class="viol-empty-hint">Нажмите круглую кнопку «+» внизу справа, чтобы зафиксировать нарушение</div>
        </div>`;
      }
      if (!filteredViolations.length) {
        const hint = String(getViolSearchQuery()).trim();
        return `<div class="viol-empty viol-empty--filter">
          <div class="viol-empty-icon">🔍</div>
          <div class="viol-empty-text">Ничего не найдено</div>
          <div class="viol-empty-hint">По запросу «${AktUtils.escapeHtml(hint)}» нет совпадений среди ${allViolations.length} нарушений ${docLabel}</div>
        </div>`;
      }
      return filteredViolations
        .map((v) => renderViolCardHtml(v, violIndexInDoc(v.id, allViolations)))
        .join('');
    }

    function renderViolPhotoSectionHtml(violations) {
      const allPhotos = (violations || []).flatMap((v) =>
        (v.photo || []).map((p, idx) => ({ v, idx, ref: p }))
      );
      if (!allPhotos.length) return '';
      return `<div id="${ids.photoSection}">
        <h3 style="margin-top:4px;font-size:14px;margin-bottom:12px">${photoSectionTitle}</h3>
        <div class="photo-grid" id="${ids.photoGrid}">${
          allPhotos
            .slice(0, 16)
            .map(
              ({ ref, v, idx }) =>
                `<div class="photo-slot filled wizard-photo-thumb" data-vid="${v.id}" data-pidx="${idx}" title="${AktUtils.escapeHtml(v.title)}">
                  ${photoImgTag(ref, v.id, idx)}
                </div>`
            )
            .join('') + (allPhotos.length > 16 ? `<div class="photo-slot">+${allPhotos.length - 16}</div>` : '')
        }</div>
      </div>`;
    }

    function renderViolCountBadgeText(allCount, filteredCount) {
      if (isViolFiltering() && filteredCount !== allCount) {
        return `${filteredCount} из ${allCount}`;
      }
      return String(allCount);
    }

    function refreshViolList() {
      const draft = getDraft();
      if (getStep() !== violationsStep || !draft) return;
      const allViolations = draft.violations || [];
      const filtered = filterViolations(allViolations, getViolSearchQuery());
      const listEl = document.getElementById(ids.list);
      if (!listEl) return;

      listEl.innerHTML = renderViolCardsListInnerHtml(allViolations, filtered);

      const badgeEl = document.getElementById(ids.badge);
      if (badgeEl) badgeEl.textContent = renderViolCountBadgeText(allViolations.length, filtered.length);

      const photoHost = document.getElementById(ids.photoSection);
      const photoHtml = renderViolPhotoSectionHtml(isViolFiltering() ? filtered : allViolations);
      if (photoHost) {
        if (photoHtml) photoHost.outerHTML = photoHtml;
        else photoHost.remove();
      } else if (photoHtml) {
        listEl.insertAdjacentHTML('afterend', photoHtml);
      }

      bindViolationListEvents();
      hydrateViolationThumbs();
    }

    function renderStepViolations() {
      const draft = getDraft();
      const allViolations = draft?.violations || [];
      const filtered = filterViolations(allViolations, getViolSearchQuery());
      const cards = renderViolCardsListInnerHtml(allViolations, filtered);
      const photoSection = renderViolPhotoSectionHtml(isViolFiltering() ? filtered : allViolations);
      const extraBlock = typeof renderStepExtra === 'function' ? renderStepExtra() : '';

      const searchToolbar = allViolations.length
        ? `<div class="viol-search-toolbar">
            <input type="search"
              class="form-control"
              id="${ids.search}"
              placeholder="🔍 Поиск по формулировке, месту, документу, виду…"
              value="${AktUtils.escapeHtml(getViolSearchQuery())}"
              autocomplete="off"
              aria-label="Поиск нарушений">
          </div>`
        : '';

      return `
        ${extraBlock}
        <div class="viol-step-header">
          <h3 style="margin:0">Нарушения <span class="viol-total-badge" id="${ids.badge}">${renderViolCountBadgeText(allViolations.length, filtered.length)}</span></h3>
        </div>
        ${searchToolbar}
        <div class="viol-cards-list" id="${ids.list}">${cards}</div>
        ${photoSection}
      `;
    }

    function bindViolationDragDrop() {
      const container = document.getElementById(ids.list);
      if (!container) return;

      let dragSrcId = null;

      function getCards() {
        return [...container.querySelectorAll('.viol-card[data-violation-id]')];
      }

      function clearDropIndicators() {
        container.querySelectorAll('.viol-card--drag-over-top, .viol-card--drag-over-bottom')
          .forEach((el) => {
            el.classList.remove('viol-card--drag-over-top', 'viol-card--drag-over-bottom');
          });
      }

      getCards().forEach((card) => {
        card.addEventListener('dragstart', (e) => {
          dragSrcId = card.dataset.violationId;
          container.dataset.dragging = '1';
          e.dataTransfer.effectAllowed = 'move';
          e.dataTransfer.setData('text/plain', dragSrcId);
          setTimeout(() => card.classList.add('viol-card--dragging'), 0);
        });

        card.addEventListener('dragend', () => {
          card.classList.remove('viol-card--dragging');
          clearDropIndicators();
          dragSrcId = null;
          setTimeout(() => { delete container.dataset.dragging; }, 0);
        });

        card.addEventListener('dragover', (e) => {
          e.preventDefault();
          e.dataTransfer.dropEffect = 'move';
          if (card.dataset.violationId === dragSrcId) return;
          clearDropIndicators();
          const rect = card.getBoundingClientRect();
          const mid = rect.top + rect.height / 2;
          if (e.clientY < mid) {
            card.classList.add('viol-card--drag-over-top');
          } else {
            card.classList.add('viol-card--drag-over-bottom');
          }
        });

        card.addEventListener('dragleave', (e) => {
          if (!card.contains(e.relatedTarget)) {
            card.classList.remove('viol-card--drag-over-top', 'viol-card--drag-over-bottom');
          }
        });

        card.addEventListener('drop', (e) => {
          e.preventDefault();
          if (!dragSrcId || card.dataset.violationId === dragSrcId) return;

          const draft = getDraft();
          const violations = [...(draft.violations || [])];
          const srcIdx = violations.findIndex((v) => v.id === dragSrcId);
          const tgtIdx = violations.findIndex((v) => v.id === card.dataset.violationId);
          if (srcIdx === -1 || tgtIdx === -1) return;

          const rect = card.getBoundingClientRect();
          const mid = rect.top + rect.height / 2;
          const insertAfter = e.clientY >= mid;

          const [moved] = violations.splice(srcIdx, 1);
          const newTgtIdx = violations.findIndex((v) => v.id === card.dataset.violationId);
          violations.splice(insertAfter ? newTgtIdx + 1 : newTgtIdx, 0, moved);

          draft.violations = violations;
          scheduleAutosave();
          render();
          updateSummary?.();
        });
      });
    }

    function bindViolationListEvents() {
      bindViolationDragDrop();

      panelsHost()?.querySelectorAll('.viol-card[data-violation-id]').forEach((card) => {
        const openCard = () => WizardModals.openViolationEditor(card.dataset.violationId);
        card.addEventListener('click', (e) => {
          if (e.target.closest('.viol-card-actions')) return;
          if (e.target.closest('.viol-card-thumbs')) return;
          if (document.getElementById(ids.list)?.dataset.dragging) return;
          openCard();
        });
        card.addEventListener('keydown', (e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            openCard();
          }
        });
      });

      panelsHost()?.querySelectorAll(`.${editClass}`).forEach((btn) => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          WizardModals.openViolationEditor(btn.dataset.vid);
        });
      });

      panelsHost()?.querySelectorAll(`.${delClass}`).forEach((btn) => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const draft = getDraft();
          const v = (draft.violations || []).find((x) => x.id === btn.dataset.vid);
          GazpromToast.confirm(`Удалить нарушение?\n«${(v?.title || '').slice(0, 80)}»`, { confirmLabel: 'Удалить', danger: true }).then((ok) => {
            if (!ok) return;
            draft.violations = (draft.violations || []).filter((x) => x.id !== btn.dataset.vid);
            scheduleAutosave();
            render();
            updateSummary?.();
          });
        });
      });

      panelsHost()?.querySelectorAll('.wizard-photo-thumb').forEach((el) => {
        el.addEventListener('click', async () => {
          const vid = el.dataset.vid;
          const pidx = parseInt(el.dataset.pidx, 10);
          const fromDocGrid = !!el.closest(`#${ids.photoGrid}`);

          const buildGallery = async (refs, matchIdx) => {
            const urls = await Promise.all(refs.map((p) => AktUtils.photoSrcAsync(p)));
            const gallery = [];
            let start = 0;
            urls.forEach((url, i) => {
              if (!url) return;
              if (i === matchIdx) start = gallery.length;
              gallery.push(url);
            });
            return { gallery, start };
          };

          const draft = getDraft();

          if (fromDocGrid) {
            const sourceViolations = isViolFiltering()
              ? filterViolations(draft.violations || [], getViolSearchQuery())
              : draft.violations || [];
            const items = sourceViolations.flatMap((vi) =>
              (vi.photo || []).map((ref, i) => ({ vid: vi.id, pidx: i, ref }))
            );
            if (!items.length) return;
            const urls = await Promise.all(items.map((x) => AktUtils.photoSrcAsync(x.ref)));
            const gallery = [];
            let start = 0;
            urls.forEach((url, i) => {
              if (!url) return;
              if (items[i].vid === vid && items[i].pidx === pidx) start = gallery.length;
              gallery.push(url);
            });
            if (!gallery.length) {
              GazpromToast.info('Не удалось открыть фото');
              return;
            }
            openLightbox(gallery[start], gallery);
            return;
          }

          const v = (draft.violations || []).find((x) => x.id === vid);
          if (!v?.photo?.length) return;
          const { gallery, start } = await buildGallery(v.photo, Number.isNaN(pidx) ? 0 : pidx);
          if (!gallery.length) {
            GazpromToast.info('Не удалось открыть фото');
            return;
          }
          openLightbox(gallery[start], gallery);
        });
      });
    }

    function bindViolSearchEvents() {
      const searchEl = document.getElementById(ids.search);
      if (!searchEl) return;
      searchEl.addEventListener('input', () => {
        setViolSearchQuery(searchEl.value);
        refreshViolList();
      });
    }

    async function hydrateViolationThumbs() {
      const host = panelsHost();
      if (!host) return;

      const lazyViolImgs = [...host.querySelectorAll('img[data-viol-vid][data-viol-pidx]')];
      const hydrateOne = async (img) => {
        if (img.dataset.photoHydrated === '1') return;
        const vid = img.dataset.violVid;
        const pidx = parseInt(img.dataset.violPidx, 10);
        const draft = getDraft();
        const v = (draft?.violations || []).find((x) => x.id === vid);
        const ref = v?.photo?.[pidx];
        if (!ref) return;
        const url = (await PhotoStore.resolveDataUrl(ref)) || AktUtils.photoSrc(ref);
        if (!url || !img.isConnected) return;
        img.src = url;
        img.dataset.photoHydrated = '1';
      };
      const batchSize = 3;
      for (let i = 0; i < lazyViolImgs.length; i += batchSize) {
        await Promise.all(lazyViolImgs.slice(i, i + batchSize).map(hydrateOne));
      }

      if (typeof PhotoStore?.hydrateImages === 'function') {
        await PhotoStore.hydrateImages(host);
        return;
      }
      host.querySelectorAll('img[data-photo-ref]').forEach(async (img) => {
        const ref = img.dataset.photoRef;
        img.src = (await PhotoStore.resolveDataUrl(ref)) || AktUtils.photoSrc(ref);
      });
    }

    return {
      renderStepViolations,
      refreshViolList,
      bindViolationListEvents,
      bindViolSearchEvents,
      hydrateViolationThumbs,
    };
  }

  return { create };
})();
