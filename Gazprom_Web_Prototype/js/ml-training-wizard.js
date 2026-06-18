/**
 * Мастер обучения ML (вариант B): 3 шага из Настроек → Обучение модели.
 */
const MlTrainingWizard = (() => {
  const STEPS = [
    { key: 'data', label: 'Сбор данных' },
    { key: 'cards', label: 'Проверка карточек' },
    { key: 'test', label: 'Тест и реестр' },
  ];

  let currentStep = 0;
  let stats = null;
  let entries = [];
  let cardIndex = 0;
  let pendingTitle = null;
  let currentPredictions = [];
  let testPhotos = [];
  let testPredictions = [];
  let selectedTestTitle = null;
  let datasetSort = 'number';
  let datasetQuery = '';
  let detailTitle = null;
  let bound = false;
  let loading = false;
  let loadCancelled = false;
  let loadProgressMessage = '';
  let loadOverlayEl = null;
  let cardPhotoUrl = null;
  let detailPhotoUrls = [];
  let photoLightboxBound = false;

  const flushUi = () =>
    new Promise((resolve) => {
      requestAnimationFrame(() => requestAnimationFrame(resolve));
    });

  const withTimeout = (promise, ms, label) =>
    Promise.race([
      promise,
      new Promise((_, reject) => {
        setTimeout(() => reject(new Error(`Таймаут: ${label}`)), ms);
      }),
    ]);

  function hideLoadOverlay() {
    loadOverlayEl?.remove();
    loadOverlayEl = null;
  }

  function updateLoadOverlay(message) {
    loadProgressMessage = String(message || '');
    const textEl = document.getElementById('mlLoadOverlayText');
    if (textEl) textEl.textContent = loadProgressMessage;
  }

  function showLoadOverlay(message) {
    hideLoadOverlay();
    loadOverlayEl = document.createElement('div');
    loadOverlayEl.id = 'mlLoadOverlay';
    loadOverlayEl.className = 'confirm-overlay ml-load-overlay';
    loadOverlayEl.innerHTML = `
      <div class="confirm-dialog ml-load-dialog" role="status" aria-live="polite" aria-busy="true">
        <div class="ml-spinner" aria-hidden="true"></div>
        <p id="mlLoadOverlayText">${esc(message || 'Загрузка…')}</p>
        <button type="button" class="btn-ghost btn-sm" id="mlLoadOverlayCancel">Отмена</button>
      </div>`;
    document.body.appendChild(loadOverlayEl);
    loadOverlayEl.querySelector('#mlLoadOverlayCancel')?.addEventListener('click', () => {
      handleLoadCancel();
    });
  }

  function handleLoadCancel() {
    loadCancelled = true;
    MlImageService.cancelLoadFromActs?.();
    loading = false;
    hideLoadOverlay();
    void paint({ force: true });
  }

  function esc(s) {
    return AktUtils.escapeHtml(String(s ?? ''));
  }

  function setPhotoElement(container, url, imgClass) {
    if (!container) return;
    container.textContent = '';
    if (!url) {
      container.textContent = '🖼';
      return;
    }
    const img = document.createElement('img');
    img.src = url;
    img.alt = 'Фото нарушения';
    if (imgClass) img.className = imgClass;
    container.appendChild(img);
  }

  function ensurePhotoLightbox() {
    let box = document.getElementById('mlPhotoLightbox');
    if (box) return box;

    box = document.createElement('div');
    box.id = 'mlPhotoLightbox';
    box.className = 'photo-lightbox ml-photo-lightbox';
    box.innerHTML = `
      <button type="button" class="photo-lightbox-close" aria-label="Закрыть">×</button>
      <div class="photo-lightbox-inner">
        <div class="photo-lightbox-viewport" aria-label="Просмотр фото">
          <div class="photo-lightbox-stage">
            <img class="photo-lightbox-img" alt="" draggable="false">
          </div>
        </div>
        <div class="photo-lightbox-controls">
          <button type="button" class="photo-lightbox-nav photo-lightbox-prev photo-lightbox-chip photo-lightbox-nav-btn" aria-label="Предыдущее фото">‹</button>
          <span class="photo-lightbox-counter photo-lightbox-chip" aria-live="polite"></span>
          <button type="button" class="photo-lightbox-nav photo-lightbox-next photo-lightbox-chip photo-lightbox-nav-btn" aria-label="Следующее фото">›</button>
        </div>
      </div>`;
    document.body.appendChild(box);

    const hideLightbox = () => {
      if (!box.classList.contains('show')) return;
      box.classList.remove('show');
      GazpromMobileOverlay?.unlock?.();
      GazpromMobileOverlay?.scheduleRecoverViewportLayout?.();
    };

    box.querySelector('.photo-lightbox-close')?.addEventListener('click', (e) => {
      e.stopPropagation();
      hideLightbox();
    });
    box.querySelector('.photo-lightbox-inner')?.addEventListener('click', (e) => {
      e.stopPropagation();
    });
    box.addEventListener('click', (e) => {
      if (e.target === box) hideLightbox();
    });

    if (!photoLightboxBound) {
      photoLightboxBound = true;
      document.addEventListener('keydown', (e) => {
        const lb = document.getElementById('mlPhotoLightbox');
        if (e.key === 'Escape' && lb?.classList.contains('show')) {
          lb.classList.remove('show');
          GazpromMobileOverlay?.unlock?.();
        }
      });
    }

    box._mlHide = hideLightbox;
    return box;
  }

  function resolvePhotoUrlFromEl(el) {
    if (!el) return '';
    const fromData = el.dataset?.mlPhotoUrl || el.querySelector('[data-ml-photo-url]')?.dataset?.mlPhotoUrl;
    if (fromData) return fromData;
    const img = el.querySelector('img');
    return img?.currentSrc || img?.src || '';
  }

  function openPhotoLightboxFromEl(el) {
    const url = resolvePhotoUrlFromEl(el);
    if (!url) return;
    if (el.classList.contains('ml-grid-photo')) {
      openPhotoLightbox(url, detailPhotoUrls);
      return;
    }
    if (el.classList.contains('ml-thumb')) {
      openPhotoLightbox(url, testPhotos);
      return;
    }
    openPhotoLightbox(url);
  }

  function openPhotoLightbox(src, gallery) {
    const url = String(src || '').trim();
    if (!url) return;
    const box = ensurePhotoLightbox();
    const imgs = (gallery || []).filter(Boolean);
    const list = imgs.length ? imgs : [url];
    let idx = list.indexOf(url);
    if (idx < 0) idx = 0;

    const imgEl = box.querySelector('.photo-lightbox-img');
    const counterEl = box.querySelector('.photo-lightbox-counter');
    const prevBtn = box.querySelector('.photo-lightbox-prev');
    const nextBtn = box.querySelector('.photo-lightbox-next');

    const showAt = (i) => {
      idx = (i + list.length) % list.length;
      if (imgEl) imgEl.src = list[idx];
      const multi = list.length > 1;
      if (counterEl) counterEl.textContent = multi ? `${idx + 1} / ${list.length}` : '';
      if (prevBtn) prevBtn.style.visibility = multi ? 'visible' : 'hidden';
      if (nextBtn) nextBtn.style.visibility = multi ? 'visible' : 'hidden';
    };

    showAt(idx);
    if (prevBtn) {
      prevBtn.onclick = (e) => {
        e.stopPropagation();
        showAt(idx - 1);
      };
    }
    if (nextBtn) {
      nextBtn.onclick = (e) => {
        e.stopPropagation();
        showAt(idx + 1);
      };
    }

    if (!box.classList.contains('show')) {
      GazpromMobileOverlay?.lock?.();
    }
    box.classList.add('show');
    requestAnimationFrame(() => {
      if (imgEl && list[idx]) imgEl.src = list[idx];
    });
  }

  function markPhotoOpenable(container, url) {
    if (!container) return;
    container.classList.add('ml-photo-open');
    if (url) container.dataset.mlPhotoUrl = url;
    container.setAttribute('role', 'button');
    container.setAttribute('tabindex', '0');
    container.setAttribute('aria-label', 'Открыть фото');
  }

  function confColor(pct) {
    if (pct >= 70) return 'var(--success)';
    if (pct >= 40) return 'var(--warning)';
    return 'var(--danger)';
  }

  function formatDate(iso) {
    if (!iso) return '—';
    try {
      return new Date(iso).toLocaleString('ru-RU', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch (_) {
      return '—';
    }
  }

  function formatStats(s) {
    if (!s) return 'Загрузка статистики…';
    const acc = s.accuracy != null ? `${Math.round(s.accuracy * 100)}%` : '—';
    const manual =
      s.manualCount > 0 ? `, привязано вручную: ${s.manualCount} фото` : '';
    return (
      `Обработано актов: ${s.processedAktsCount}, загружено фото: ${s.totalPhotos}` +
      ` (из актов: ${s.autoCount}${manual}), нарушений в базе: ${s.violationCount}, точность: ${acc}.` +
      `<br>Последняя загрузка из актов: ${formatDate(s.lastTrainingDate)}`
    );
  }

  async function refreshData() {
    stats = await MlImageService.getStatistics({ skipAccuracy: true });
    entries = await MlImageService.allTrainingEntries();
    cardIndex = Math.min(await MlImageService.getCardIndex(), Math.max(0, entries.length - 1));
    if (cardIndex < 0) cardIndex = 0;
  }

  function host() {
    return document.getElementById('mlTrainingHost');
  }

  function renderStepper() {
    return `<div class="ml-wizard-steps" role="tablist" aria-label="Шаги обучения">
      ${STEPS.map((step, i) => {
        const cls = [
          'ml-wizard-step',
          i === currentStep ? 'active' : '',
          i < currentStep ? 'done' : '',
        ]
          .filter(Boolean)
          .join(' ');
        const num = i < currentStep ? '✓' : String(i + 1);
        return `<div class="${cls}" role="tab" aria-selected="${i === currentStep}">
          <span class="ml-wizard-step__num">${num}</span>${esc(step.label)}
        </div>`;
      }).join('')}
    </div>`;
  }

  function renderPredCards(predictions, selectedTitle) {
    if (!predictions?.length) {
      return '<p class="ml-muted">Добавьте фото — появятся варианты нарушений.</p>';
    }
    return predictions
      .map((pred, idx) => {
        const pct = Math.round((pred.confidence || 0) * 100);
        const selected = selectedTitle === pred.violationTitle;
        const num = pred.registryOrderNumber != null ? `п.${pred.registryOrderNumber}` : '';
        return `<button type="button" class="ml-pred-card${selected ? ' ml-pred-card--selected' : ''}" data-ml-pick="${esc(pred.violationTitle)}">
          <span class="ml-pred-rank">${idx + 1}</span>
          <span class="ml-pred-body">
            <span class="ml-pred-title">${esc(pred.violationTitle)}</span>
            <span class="ml-pred-meta" style="color:${confColor(pct)}">${num ? `${num} · ` : ''}${pct}%</span>
            <span class="ml-pred-bar"><span style="width:${pct}%;background:${confColor(pct)}"></span></span>
          </span>
        </button>`;
      })
      .join('');
  }

  function renderStepData() {
    return `
      <div class="ml-step-intro card">
        <h3>Сбор обучающих данных</h3>
        <p>Загрузите фото из актов или добавьте вручную. Модель сравнивает изображения по визуальным признакам и предлагает нарушения из реестра.</p>
      </div>
      <div class="ml-stats-bar card">${formatStats(stats)}</div>
      <div class="ml-wizard-grid">
        <div class="card ml-action-card">
          <h4>📥 Загрузить из актов</h4>
          <p>Инкрементально: только новые фото из истории и текущего акта. Удалённые из актов — убираются из базы.</p>
          <button type="button" class="btn-primary" id="mlLoadActsBtn" ${loading ? 'disabled' : ''}>Загрузить</button>
          <div id="mlLoadProgress" class="ml-progress-box"${loading ? '' : ' hidden'}>
            <div class="ml-spinner" aria-hidden="true"></div>
            <p id="mlLoadProgressText">${esc(loadProgressMessage || 'Обработка…')}</p>
            <button type="button" class="btn-ghost btn-sm" id="mlLoadCancelBtn">Отмена</button>
          </div>
        </div>
        <div class="card ml-action-card">
          <h4>📦 Массовая загрузка</h4>
          <p>Выберите много фото — каждое привяжется к лучшему прогнозу модели.</p>
          <button type="button" class="btn-secondary" id="mlMassPickBtn" ${loading ? 'disabled' : ''}>Выбрать фото</button>
          <button type="button" class="btn-primary" id="mlMassBindBtn" hidden>Привязать автоматически</button>
          <p id="mlMassCount" class="ml-muted"></p>
        </div>
      </div>
      <div class="ml-danger-row">
        <button type="button" class="btn-ghost btn-sm ml-danger-btn" id="mlResetBtn">🗑 Очистить все данные обучения</button>
      </div>`;
  }

  function renderStepCards() {
    const entry = entries[cardIndex];
    const total = entries.length;
    const reviewed = cardIndex;
    const effectiveTitle = pendingTitle || entry?.violationTitle || '—';
    const progressPct = total ? Math.round((reviewed / total) * 100) : 0;

    return `
      <div class="ml-wizard-grid">
        <div class="card ml-training-card">
          <p class="ml-counter">Карточка ${total ? cardIndex + 1 : 0} из ${total}</p>
          <div class="ml-big-photo ml-photo-open" id="mlCardPhoto" role="button" tabindex="0" aria-label="Открыть фото">${entry ? '🖼' : '—'}</div>
          <div class="ml-current-title">${esc(effectiveTitle)}</div>
          <div id="mlCardPreds">${renderPredCards(currentPredictions, pendingTitle || entry?.violationTitle)}</div>
          <p class="ml-muted ml-swipe-hint">Кнопки «Назад» / «Далее» или свайп по фото</p>
          <div class="ml-card-actions">
            <button type="button" class="btn-secondary" id="mlCardManualBtn" ${entry ? '' : 'disabled'}>Привязать вручную</button>
            <button type="button" class="btn-primary" id="mlCardOkBtn" ${entry ? '' : 'disabled'}>✓ ОК — следующее фото</button>
          </div>
          <div class="ml-card-nav">
            <button type="button" class="btn-ghost btn-sm" id="mlCardPrevBtn" ${cardIndex > 0 ? '' : 'disabled'}>← Назад</button>
            <button type="button" class="btn-ghost btn-sm" id="mlCardStartBtn">В начало</button>
            <button type="button" class="btn-ghost btn-sm" id="mlCardEndBtn">В конец</button>
            <button type="button" class="btn-ghost btn-sm" id="mlCardSkipBtn" ${entry ? '' : 'disabled'}>Пропустить →</button>
          </div>
        </div>
        <div class="card">
          <h4>Что происходит на этом шаге</h4>
          <p class="ml-muted">Проверьте привязки из актов и массовой загрузки. Если верно — «ОК». Если нет — выберите другое нарушение.</p>
          <p><span class="ml-badge ml-badge--akt">из акта</span> <span class="ml-badge ml-badge--manual">вручную</span></p>
          <h4 style="margin-top:16px">Прогресс проверки</h4>
          <div class="ml-pred-bar ml-pred-bar--lg"><span style="width:${progressPct}%"></span></div>
          <p class="ml-muted">Проверено: ${reviewed} из ${total}</p>
        </div>
      </div>`;
  }

  function renderDatasetList(items) {
    if (!items.length) {
      return '<p class="ml-muted">Нет привязок. Вернитесь к шагу 1 и загрузите данные.</p>';
    }
    return items
      .map((item) => {
        const num = item.number != null ? `п.${item.number} ` : '';
        return `<button type="button" class="ml-binding-row" data-ml-detail="${esc(item.title)}">
          <span class="ml-binding-info">
            <span class="ml-binding-title">${esc(num + item.title)}</span>
            <span class="ml-binding-count">${item.count} фото</span>
          </span>
          <span class="ml-binding-chevron">›</span>
        </button>`;
      })
      .join('');
  }

  function renderStepTest() {
  if (detailTitle) {
      return `
        <button type="button" class="btn-ghost btn-sm" id="mlDetailBack">← К списку</button>
        <h3 class="ml-detail-title">${esc(detailTitle)}</h3>
        <div class="ml-photo-grid" id="mlDetailGrid">Загрузка…</div>`;
    }

    return `
      <div class="ml-test-grid">
        <div class="card">
          <h4>🧪 Лаборатория — тест фото</h4>
          <div class="ml-photo-row" id="mlTestPhotoRow"></div>
          <button type="button" class="btn-secondary btn-sm" id="mlTestPickBtn">+ Добавить фото</button>
          <div class="ml-section-title">Результаты распознавания</div>
          <div id="mlTestPreds">${renderPredCards(testPredictions, selectedTestTitle)}</div>
          <div class="ml-test-actions">
            <button type="button" class="btn-secondary" id="mlTestManualBtn">Привязать вручную</button>
            <button type="button" class="btn-primary" id="mlTestConfirmBtn">✓ Подтвердить привязку</button>
          </div>
        </div>
        <div class="card">
          <h4>📋 Реестр привязок</h4>
          <input type="search" class="ml-search" id="mlDatasetSearch" placeholder="Поиск нарушений…" value="${esc(datasetQuery)}">
          <div class="ml-sort-pills">
            <button type="button" class="ml-sort-pill${datasetSort === 'number' ? ' active' : ''}" data-ml-sort="number">По нумерации</button>
            <button type="button" class="ml-sort-pill${datasetSort === 'count' ? ' active' : ''}" data-ml-sort="count">По кол-ву фото</button>
          </div>
          <div id="mlDatasetList"></div>
        </div>
      </div>`;
  }

  function renderFooter() {
    return `<div class="ml-wizard-footer">
      <button type="button" class="btn-ghost" id="mlWizardBackBtn" ${currentStep === 0 ? 'disabled' : ''}>
        ← ${currentStep > 0 ? esc(STEPS[currentStep - 1].label) : 'Назад'}
      </button>
      <button type="button" class="btn-ghost" data-go="settings">К настройкам</button>
      <button type="button" class="btn-primary" id="mlWizardNextBtn">
        ${currentStep < STEPS.length - 1 ? `${esc(STEPS[currentStep + 1].label)} →` : 'Готово'}
      </button>
    </div>`;
  }

  async function paint(options = {}) {
    if (loading && !options.force) return;
    const root = host();
    if (!root) return;
    await refreshData();
    root.innerHTML = `
      <div class="ml-wizard">
        ${renderStepper()}
        <div class="ml-wizard-body">
          ${currentStep === 0 ? renderStepData() : ''}
          ${currentStep === 1 ? renderStepCards() : ''}
          ${currentStep === 2 ? renderStepTest() : ''}
        </div>
        ${renderFooter()}
      </div>`;
    bindStepEvents();
    if (currentStep === 1) await hydrateCard();
    if (currentStep === 2 && !detailTitle) await hydrateDataset();
    if (currentStep === 2 && detailTitle) await hydrateDetail();
    if (currentStep === 2) await hydrateTestPhotos();
  }

  let massFiles = [];

  async function handleLoadActs() {
    if (loading) return;
    if (typeof MlImageService === 'undefined' || typeof MlImageService.loadFromActs !== 'function') {
      GazpromToast.error('Модуль ML не загружен. Обновите приложение (Настройки → Обновить).');
      return;
    }

    loading = true;
    loadCancelled = false;
    loadProgressMessage = 'Подготовка…';
    showLoadOverlay(loadProgressMessage);
    await flushUi();

    const onLoadProgress = (_cur, total, added, _stats, jobIdx, jobTotal, scanned, phase) => {
      if (loadCancelled) return;
      let message = loadProgressMessage;
      if (phase === 'start') message = 'Чтение актов…';
      else if (phase === 'scan') message = `Сканирование актов… найдено ${scanned} фото`;
      else if (phase === 'ready') {
        message =
          jobTotal > 0
            ? `Актов: ${total}. Найдено ${scanned} фото. К загрузке: ${jobTotal}`
            : scanned > 0
              ? `Актов: ${total}. Все ${scanned} фото уже в базе`
              : `Актов: ${total}. В актах нет фото`;
      } else if (phase === 'import' && jobTotal > 0) {
        message = `Загрузка: ${jobIdx} из ${jobTotal} (в базе: ${added})`;
      } else if (total > 0) {
        message = `Актов: ${total}. Фото в базе ML: ${added}`;
      }
      updateLoadOverlay(message);
    };

    try {
      const result = await withTimeout(
        MlImageService.loadFromActs(onLoadProgress),
        120000,
        'загрузка из актов'
      );
      if (loadCancelled || MlImageService.isLoadFromActsAborted?.() || result === null) {
        GazpromToast.info('Загрузка отменена');
        return;
      }
      const s = result || (await MlImageService.getStatistics({ skipAccuracy: true }));
      if (s.totalPhotos > 0) {
        GazpromToast.success(`Загружено: ${s.autoCount} фото из ${s.processedAktsCount} актов`);
      } else if (s.processedAktsCount > 0) {
        GazpromToast.info('Фото в актах есть, но не удалось прочитать изображения');
      } else {
        GazpromToast.info('В актах нет фото с нарушениями');
      }
    } catch (err) {
      console.error('[MlTrainingWizard] loadFromActs', err);
      GazpromToast.error(err?.message || 'Ошибка загрузки из актов');
    } finally {
      loading = false;
      loadProgressMessage = '';
      hideLoadOverlay();
      await paint({ force: true });
    }
  }

  async function hydrateCard() {
    const entry = entries[cardIndex];
    pendingTitle = null;
    const photoEl = document.getElementById('mlCardPhoto');
    if (!entry || !photoEl) {
      cardPhotoUrl = null;
      currentPredictions = [];
      return;
    }
    const url = await MlImageService.resolvePhotoDataUrl(entry.photoRef);
    cardPhotoUrl = url || null;
    setPhotoElement(photoEl, url, 'ml-big-photo__img');
    if (url && photoEl) {
      markPhotoOpenable(photoEl, url);
    }
    currentPredictions = url ? await MlImageService.predict(url) : [];
    const predsHost = document.getElementById('mlCardPreds');
    if (predsHost) {
      predsHost.innerHTML = renderPredCards(currentPredictions, entry.violationTitle);
      bindPredPick(predsHost, (title) => {
        pendingTitle = title;
        const titleEl = document.querySelector('.ml-current-title');
        if (titleEl) titleEl.textContent = title;
      });
    }
  }

  function bindPredPick(root, onPick) {
    root.querySelectorAll('[data-ml-pick]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const title = btn.getAttribute('data-ml-pick');
        onPick(title);
        root.innerHTML = renderPredCards(
          root.id === 'mlTestPreds' ? testPredictions : currentPredictions,
          title
        );
        bindPredPick(root, onPick);
      });
    });
  }

  async function hydrateDataset() {
    let items = await MlImageService.violationsWithPhotoCounts();
    const q = datasetQuery.trim().toLowerCase();
    if (q) {
      items = items.filter(
        (it) =>
          it.title.toLowerCase().includes(q) ||
          (it.number != null && String(it.number).includes(q))
      );
    }
    if (datasetSort === 'number') {
      items.sort((a, b) => (a.number ?? 1e9) - (b.number ?? 1e9));
    } else {
      items.sort((a, b) => b.count - a.count);
    }
    const list = document.getElementById('mlDatasetList');
    if (list) list.innerHTML = renderDatasetList(items);
    list?.querySelectorAll('[data-ml-detail]').forEach((btn) => {
      btn.addEventListener('click', () => {
        detailTitle = btn.getAttribute('data-ml-detail');
        void paint();
      });
    });
  }

  async function hydrateDetail() {
    const grid = document.getElementById('mlDetailGrid');
    if (!grid || !detailTitle) return;
    const photos = await MlImageService.photosFor(detailTitle);
    if (!photos.length) {
      grid.innerHTML = '<p class="ml-muted">Нет фото</p>';
      return;
    }
    detailPhotoUrls = [];
    const cells = await Promise.all(
      photos.map(async (entry) => {
        const url = await MlImageService.resolvePhotoDataUrl(entry.photoRef);
        if (url) detailPhotoUrls.push(url);
        const wrap = document.createElement('div');
        wrap.className = 'ml-grid-photo ml-photo-open';
        wrap.dataset.mlDel = entry.id;
        wrap.dataset.mlPhotoUrl = url || '';
        wrap.setAttribute('role', 'button');
        wrap.setAttribute('tabindex', '0');
        wrap.setAttribute('aria-label', 'Открыть фото');
        setPhotoElement(wrap, url, '');
        const wrapImg = wrap.querySelector('img');
        if (wrapImg) {
          wrapImg.style.width = '100%';
          wrapImg.style.height = '100%';
          wrapImg.style.objectFit = 'cover';
        }
        const del = document.createElement('button');
        del.type = 'button';
        del.className = 'ml-grid-del';
        del.setAttribute('aria-label', 'Удалить');
        del.textContent = '×';
        wrap.appendChild(del);
        return wrap;
      })
    );
    grid.textContent = '';
    cells.forEach((cell) => grid.appendChild(cell));
    grid.querySelectorAll('.ml-grid-del').forEach((btn) => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const wrap = btn.closest('.ml-grid-photo');
        const id = wrap?.dataset?.mlDel;
        if (!id) return;
        await MlImageService.removePhoto(id);
        GazpromToast.success('Фото удалено');
        await paint();
      });
    });
  }

  async function hydrateTestPhotos() {
    const row = document.getElementById('mlTestPhotoRow');
    if (!row) return;
    row.textContent = '';
    if (!testPhotos.length) {
      const span = document.createElement('span');
      span.className = 'ml-muted';
      span.textContent = 'Нет тестовых фото';
      row.appendChild(span);
      return;
    }
    testPhotos.forEach((url, i) => {
      const wrap = document.createElement('div');
      wrap.className = 'ml-thumb ml-photo-open';
      wrap.dataset.mlTestIdx = String(i);
      wrap.dataset.mlPhotoUrl = url;
      wrap.setAttribute('role', 'button');
      wrap.setAttribute('tabindex', '0');
      wrap.setAttribute('aria-label', 'Открыть фото');
      setPhotoElement(wrap, url, '');
      const img = wrap.querySelector('img');
      if (img) {
        img.style.width = '100%';
        img.style.height = '100%';
        img.style.objectFit = 'cover';
      }
      const del = document.createElement('button');
      del.type = 'button';
      del.className = 'ml-thumb-del';
      del.dataset.mlTestDel = String(i);
      del.textContent = '×';
      wrap.appendChild(del);
      row.appendChild(wrap);
    });
    row.querySelectorAll('[data-ml-test-del]').forEach((btn) => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const idx = Number(btn.getAttribute('data-ml-test-del'));
        testPhotos.splice(idx, 1);
        await runTestPredict();
        await hydrateTestPhotos();
        const preds = document.getElementById('mlTestPreds');
        if (preds) {
          preds.innerHTML = renderPredCards(testPredictions, selectedTestTitle);
          bindPredPick(preds, (title) => {
            selectedTestTitle = title;
          });
        }
      });
    });
  }

  async function runTestPredict() {
    if (!testPhotos.length) {
      testPredictions = [];
      selectedTestTitle = null;
      return;
    }
    testPredictions = await MlImageService.predict(testPhotos[0]);
    selectedTestTitle = testPredictions[0]?.violationTitle || null;
  }

  function renderPickItemHtml(v) {
    const num = v?.number != null ? String(v.number) : '';
    const rule = String(v?.subTitle || v?.formulaFromRules || '').trim();
    const ruleHtml = rule
      ? `<span class="ml-pick-item__rule">${esc(rule)}</span>`
      : '<span class="ml-pick-item__rule ml-pick-item__rule--empty">Пункт правил не указан</span>';
    return `<button type="button" class="ml-pick-item" data-title="${esc(v.title)}">
      <span class="ml-pick-item__top">
        ${num ? `<span class="ml-pick-item__num">${esc(num)}</span>` : ''}
        <span class="ml-pick-item__title">${esc(v.title)}</span>
      </span>
      ${ruleHtml}
    </button>`;
  }

  async function openManualPick(onSelect) {
    const registry = await ViolationRegistry.getAll();
    const overlay = document.createElement('div');
    overlay.className = 'catalog-form-overlay ml-pick-overlay';
    overlay.innerHTML = `
      <div class="catalog-form-panel ml-pick-panel" role="dialog" aria-modal="true" aria-labelledby="mlPickTitle">
        <div class="catalog-form-header ml-pick-header">
          <h3 id="mlPickTitle">Выбор нарушения из реестра</h3>
          <button type="button" class="modal-close" id="mlPickClose" aria-label="Закрыть">×</button>
        </div>
        <div class="catalog-form-body ml-pick-body">
          <input type="search" class="ml-search" id="mlPickSearch" placeholder="Поиск по названию, номеру или пункту правил…">
          <div class="ml-pick-list" id="mlPickList"></div>
        </div>
      </div>`;
    document.body.appendChild(overlay);
    window.GazpromMobileOverlay?.lock?.();

    const close = () => {
      overlay.remove();
      window.GazpromMobileOverlay?.unlock?.();
    };
    overlay.querySelector('#mlPickClose')?.addEventListener('click', close);
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) close();
    });

    const renderList = (q) => {
      let list = registry || [];
      if (typeof ViolationSearch !== 'undefined') {
        list = ViolationSearch.filterRegistry(list, q, { catalog: null });
      } else if (q) {
        const qq = q.toLowerCase();
        list = list.filter(
          (v) =>
            String(v.title || '').toLowerCase().includes(qq) ||
            String(v.subTitle || '').toLowerCase().includes(qq) ||
            String(v.formulaFromRules || '').toLowerCase().includes(qq) ||
            (v.number != null && String(v.number).includes(qq))
        );
      }
      const hostList = overlay.querySelector('#mlPickList');
      if (!hostList) return;
      if (!list.length) {
        hostList.innerHTML = '<p class="ml-pick-empty">Ничего не найдено</p>';
        return;
      }
      hostList.innerHTML = list.slice(0, 200).map((v) => renderPickItemHtml(v)).join('');
      hostList.querySelectorAll('.ml-pick-item').forEach((btn) => {
        btn.addEventListener('click', () => {
          onSelect(btn.getAttribute('data-title'));
          close();
        });
      });
    };
    renderList('');
    overlay.querySelector('#mlPickSearch')?.addEventListener('input', (e) => {
      renderList(e.target.value);
    });
  }

  function bindStepEvents() {
    document.getElementById('mlWizardBackBtn')?.addEventListener('click', () => {
      if (currentStep > 0) {
        currentStep -= 1;
        detailTitle = null;
        void paint();
      }
    });
    document.getElementById('mlWizardNextBtn')?.addEventListener('click', () => {
      if (currentStep < STEPS.length - 1) {
        currentStep += 1;
        detailTitle = null;
        void paint();
      } else {
        GazpromToast.success('Обучение завершено');
        if (typeof goTo === 'function') goTo('settings');
      }
    });

    if (currentStep === 0) bindDataStep();
    if (currentStep === 1) bindCardsStep();
    if (currentStep === 2) bindTestStep();
  }

  function bindDataStep() {
    document.getElementById('mlLoadCancelBtn')?.addEventListener('click', () => {
      handleLoadCancel();
    });
    document.getElementById('mlResetBtn')?.addEventListener('click', async () => {
      const ok = await GazpromToast.confirm('Все данные обучения будут удалены. Продолжить?');
      if (!ok) return;
      await MlImageService.resetAll();
      testPhotos = [];
      GazpromToast.success('Данные очищены');
      await paint();
    });

    const massInput = document.getElementById('mlMassInput');
    document.getElementById('mlMassPickBtn')?.addEventListener('click', () => {
      GazpromFileUtils?.triggerFilePicker?.(massInput);
    });
    if (massInput && !massInput.dataset.bound) {
      massInput.dataset.bound = '1';
      massInput.addEventListener('change', () => {
        massFiles = [...(massInput.files || [])];
        const countEl = document.getElementById('mlMassCount');
        const bindBtn = document.getElementById('mlMassBindBtn');
        if (countEl) countEl.textContent = massFiles.length ? `Выбрано: ${massFiles.length} фото` : '';
        if (bindBtn) bindBtn.hidden = !massFiles.length;
        massInput.value = '';
      });
    }
    document.getElementById('mlMassBindBtn')?.addEventListener('click', async () => {
      if (!massFiles.length || loading) return;
      loading = true;
      const res = await MlImageService.massAutoBind(massFiles, (cur, total, added) => {
        const countEl = document.getElementById('mlMassCount');
        if (countEl) countEl.textContent = `Обработано ${cur} из ${total}. Привязано: ${added}`;
      });
      loading = false;
      massFiles = [];
      GazpromToast.success(`Привязано фото: ${res.added}`);
      await paint();
    });
  }

  function bindCardsStep() {
    const goCard = async (delta, save) => {
      const entry = entries[cardIndex];
      if (save && entry && pendingTitle && pendingTitle !== entry.violationTitle) {
        await MlImageService.updateViolationTitle(entry.id, pendingTitle);
      }
      pendingTitle = null;
      cardIndex = Math.min(Math.max(0, cardIndex + delta), Math.max(0, entries.length - 1));
      await MlImageService.setCardIndex(cardIndex);
      await paint();
    };

    document.getElementById('mlCardOkBtn')?.addEventListener('click', () => goCard(1, true));
    document.getElementById('mlCardSkipBtn')?.addEventListener('click', () => goCard(1, false));
    document.getElementById('mlCardPrevBtn')?.addEventListener('click', () => goCard(-1, false));
    document.getElementById('mlCardStartBtn')?.addEventListener('click', async () => {
      cardIndex = 0;
      await MlImageService.setCardIndex(0);
      await paint();
    });
    document.getElementById('mlCardEndBtn')?.addEventListener('click', async () => {
      cardIndex = Math.max(0, entries.length - 1);
      await MlImageService.setCardIndex(cardIndex);
      await paint();
    });
    document.getElementById('mlCardManualBtn')?.addEventListener('click', () => {
      openManualPick((title) => {
        pendingTitle = title;
        const titleEl = document.querySelector('.ml-current-title');
        if (titleEl) titleEl.textContent = title;
        const predsHost = document.getElementById('mlCardPreds');
        if (predsHost) {
          predsHost.innerHTML = renderPredCards(currentPredictions, title);
          bindPredPick(predsHost, (t) => {
            pendingTitle = t;
            const titleEl = document.querySelector('.ml-current-title');
            if (titleEl) titleEl.textContent = t;
          });
        }
      });
    });

    const photoEl = document.getElementById('mlCardPhoto');
    let touchX = 0;
    let touchY = 0;
    let touchMoved = false;
    photoEl?.addEventListener('touchstart', (e) => {
      touchMoved = false;
      touchX = e.changedTouches[0]?.clientX || 0;
      touchY = e.changedTouches[0]?.clientY || 0;
    });
    photoEl?.addEventListener('touchmove', () => {
      touchMoved = true;
    });
    photoEl?.addEventListener('touchend', (e) => {
      const tx = e.changedTouches[0]?.clientX || 0;
      const ty = e.changedTouches[0]?.clientY || 0;
      const dx = tx - touchX;
      const dy = ty - touchY;
      if (!touchMoved && Math.abs(dx) < 15 && Math.abs(dy) < 15) {
        openPhotoLightboxFromEl(photoEl);
        return;
      }
      if (dx < -40) goCard(1, false);
      if (dx > 40) goCard(-1, false);
    });
  }

  function bindTestStep() {
    document.getElementById('mlDetailBack')?.addEventListener('click', () => {
      detailTitle = null;
      void paint();
    });

    const testInput = document.getElementById('mlTestInput');
    document.getElementById('mlTestPickBtn')?.addEventListener('click', () => {
      GazpromFileUtils?.triggerFilePicker?.(testInput);
    });
    if (testInput && !testInput.dataset.bound) {
      testInput.dataset.bound = '1';
      testInput.addEventListener('change', async () => {
        const files = [...(testInput.files || [])];
        for (const file of files.slice(0, 10)) {
          const url = await new Promise((res, rej) => {
            const r = new FileReader();
            r.onload = () => res(r.result);
            r.onerror = rej;
            r.readAsDataURL(file);
          });
          testPhotos.push(url);
        }
        testInput.value = '';
        await runTestPredict();
        await paint();
      });
    }

    document.getElementById('mlTestManualBtn')?.addEventListener('click', () => {
      openManualPick((title) => {
        selectedTestTitle = title;
        const preds = document.getElementById('mlTestPreds');
        if (preds) {
          preds.innerHTML = renderPredCards(testPredictions, title);
          bindPredPick(preds, (t) => {
            selectedTestTitle = t;
          });
        }
      });
    });

    document.getElementById('mlTestConfirmBtn')?.addEventListener('click', async () => {
      const title = selectedTestTitle || testPredictions[0]?.violationTitle;
      if (!title || !testPhotos.length) {
        GazpromToast.info('Добавьте фото и выберите нарушение');
        return;
      }
      let added = 0;
      for (const url of testPhotos) {
        const id = await MlImageService.addPhoto(title, url, 'manual');
        if (id) added += 1;
      }
      testPhotos = [];
      testPredictions = [];
      selectedTestTitle = null;
      GazpromToast.success(`Привязано фото: ${added}`);
      await paint();
    });

    document.getElementById('mlDatasetSearch')?.addEventListener('input', (e) => {
      datasetQuery = e.target.value;
      void hydrateDataset();
    });
    document.querySelectorAll('[data-ml-sort]').forEach((btn) => {
      btn.addEventListener('click', () => {
        datasetSort = btn.getAttribute('data-ml-sort');
        void paint();
      });
    });

    const preds = document.getElementById('mlTestPreds');
    if (preds && testPredictions.length) {
      bindPredPick(preds, (title) => {
        selectedTestTitle = title;
      });
    }
  }

  async function renderScreen() {
    currentStep = Math.min(currentStep, STEPS.length - 1);
    await paint();
    requestAnimationFrame(() => {
      GazpromMobileOverlay?.ensureScrollClearance?.('ml-training');
    });
  }

  function bindScreen() {
    if (bound) return;
    bound = true;
    const tile = document.querySelector('.settings-tile--ml');
    const open = () => {
      if (typeof goTo === 'function') goTo('ml-training');
    };
    tile?.addEventListener('click', open);
    tile?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        open();
      }
    });
  }

  function init() {
    bindScreen();
    const root = host();
    if (root && !root.dataset.mlDelegated) {
      root.dataset.mlDelegated = '1';
      root.addEventListener('click', (e) => {
        if (e.target.closest('#mlLoadActsBtn')) {
          e.preventDefault();
          void handleLoadActs();
          return;
        }
        if (e.target.closest('.ml-grid-del, .ml-thumb-del')) return;
        const photoEl = e.target.closest('.ml-photo-open');
        if (photoEl) {
          e.preventDefault();
          openPhotoLightboxFromEl(photoEl);
        }
      });
      root.addEventListener('keydown', (e) => {
        if (e.key !== 'Enter' && e.key !== ' ') return;
        const photoEl = e.target.closest('.ml-photo-open');
        if (!photoEl || e.target.closest('.ml-grid-del, .ml-thumb-del')) return;
        e.preventDefault();
        openPhotoLightboxFromEl(photoEl);
      });
    }
  }

  return { init, renderScreen };
})();
