# Телефонный режим веб-PWA «программа НЕТ»

Документ для продолжения работы **без контекста чата**.  
**Перед правками mobile — читать этот файл целиком**, особенно §7 (история) и §10 (чеклист).

Актуальная сборка: **web-124** (в UI: **Главная** → внизу «Сборка: web-XX»; номер из `GAZPROM_ASSET_V` в `index.html`, дублируется в `app.js` → `GAZPROM_WEB_BUILD`). См. §3.3 — шаг «Нарушения»; **§3.11** — модалка редактирования нарушения; §3.6 — устранение; **§3.12** — график проверок; **§3.13** — одноколоночная сетка; §3.8 — история; §3.10 — нижняя навигация.

Деплой: GitHub Pages — https://rus89nur.github.io/program/  
Локально: `cd Gazprom_Web_Prototype && python3 dev-server.py` или `python3 -m http.server 8765`

---

## 1. Когда включается телефонный режим

| Условие | Поведение |
|---------|-----------|
| **Портрет:** ширина **≤ 900px** | Телефонный UI |
| **Альбом:** высота **≤ 520px**, ширина **≤ 1280px**, touch (`hover: none`) | Тот же телефонный UI (иначе на Plus/Max ширина >900 → десктоп и ломается вёрстка) |
| Иначе (широкий десктоп с мышью) | Десктоп: боковое меню, прежняя вёрстка **без изменений** |

**Media query (CSS и JS):**

```text
(max-width: 900px), (max-width: 1280px) and (max-height: 520px) and (hover: none)
```

Константа: `window.GAZPROM_PHONE_LAYOUT_MQ`. Класс на `<body>`: **`gazprom-mobile-shell`** (`index.html` ранний скрипт + `js/mobile-overlay.js`, `toggle` при `change` / `orientationchange`).

---

## 2. Ключевые файлы

| Файл | Назначение |
|------|------------|
| `css/app.css` | Mobile shell ~3595+, mobile overlays ~3788+, landscape ~3993+, мастер `wizard-panel--*` ~3766+, баннер `.data-status--peek` |
| `js/mobile-overlay.js` | MQ, `recoverViewportLayout`, `applyScrollClearance` / `bumpScrollClearanceAtRest`, `--vv-height`, lock `.main`, whitelist горизонтального скролла |
| `index.html` | Shell-скрипт, `#appBuildId` на **Главной**, без `#globalSearch` в шапке на телефоне |
| `js/wizard.js` | Панели `wizard-panel--violations` / `--conclusions`, шаги мастера, lightbox, сводка |
| `js/ui-bindings.js` | `renderHistory`, `renderDataStatus`, `peekDataStatusBar` / скрытие баннера |
| `js/wizard-modals.js` | Модалка нарушения `#wizardModalRoot`, делегирование `[data-close]` |
| `js/app.js` | `GAZPROM_WEB_BUILD`, `syncAppBuildLabel()` → `#appBuildId` |
| `js/elimination-editor.js` | Карточки актов на экране **Устранение** (`#eliminationCardList`) |
| `sw.js` | `CACHE_NAME` = `gazprom-web-vXX` |
| `nav-desktop-preview.html` | Макеты навигации (в т.ч. вариант 4 с FAB) — не прод |

**Отладка удалена** (web-50): нет `debug-agent.js`.

---

## 3. Архитектура mobile shell

```
┌ data-status ─────────────┐
├ .app ────────────────────┤
│  header (только заголовок)│
│  .main (скролл Y)        │
├ bottom-nav (fixed) ──────┤
└──────────────────────────┘
```

- **`html` / `body`**: `overflow: hidden`, `100dvh`, без горизонтального скролла страницы.
- **`.main`**: скролл контента; `--gazprom-nav-block` задаётся в JS (`syncNavScrollInset`, `applyScrollClearance`). Доп. `padding-bottom` на scroll-host: `#historyList`, `#eliminationCardList`, `.settings-grid`, `.wizard-layout`. Коррекция overlap после остановки скролла — `bumpScrollClearanceAtRest` (не во время жеста).
- **Шапка (телефон):** только `#pageTitle`; **`.header-actions` скрыт** — нет глобального поиска (web-61). Поиск актов — на экране **История** (`#historySearch`). В **landscape** на телефоне — то же: только заголовок, **без** поиска в шапке.
- **Нижний бар:** `fixed`, `bottom: 0`, outline SVG-иконки (§3.10), сдвиг вниз `--gazprom-nav-shift-down` (web-62).

### CSS-переменные (mobile)

```css
--gazprom-nav-lift: 0px;
--gazprom-nav-shift-down: 6px;   /* portrait; в landscape 4px */
--gazprom-nav-block: fallback в CSS; на телефоне задаётся JS (`innerHeight - nav.top + 12px`).
--mobile-modal-gutter: 20px;
--mobile-modal-width: 90%;
--vv-height: …px
```

### 3.1. Сборка приложения и деплой (web-63, web-69, web-112–114, web-119–120)

- `#appBuildId` **внутри** `#screen-home` (не последний ребёнок `.main` — иначе подпись видна на фоне других экранов, в т.ч. мастера).
- Внизу главной по центру: `#screen-home.active` — flex-колонка, у `.app-build-id` — `margin-top: auto`.
- **Единый номер:** `window.GAZPROM_ASSET_V` в `<head>` `index.html`; ранний скрипт на `DOMContentLoaded` пишет «Сборка: web-XX» в `#appBuildId`; `app.js`: `GAZPROM_WEB_BUILD = 'web-' + GAZPROM_ASSET_V`.
- **`syncAppBuildLabel()`** в `app.js` — дублирует подпись при старте.
- **web-119:** анимация `fadeIn` у `.screen.active` **без `transform`** — иначе `position: fixed` у `.app-build-id` «прыгает» внутри transformed-родителя при обновлении страницы.
- **web-120:** критический CSS в `<head>` (`#appShellCritical`) — sidebar скрыт, bottom-nav виден, **без** `fadeIn` до первой навигации (`html:not(.gazprom-navigated)`); boot в `mobile-overlay.js` без scroll-snap замера при старте; класс `gazprom-navigated` на `<html>` выставляет `goTo()` в `app.js`.
- **GitHub Pages:** изменения попадают в интернет только после **`git push origin main`** (workflow `deploy-gazprom-web.yml`). Локальные правки без push на https://rus89nur.github.io/program/ **не видны**.
- **SW (web-112):** `index.html` не в install-кэше; navigate/document и `sw.js` — `fetch(..., { cache: 'no-store' })`; `reg.update()` при `visibilitychange`. Bump `CACHE_NAME`, `?v=` в `sw.js` и `GAZPROM_ASSET_V` при каждом релизе.

### 3.2. Мастер — шаг 1: дата и номер (web-58)

- `.wizard-akt-meta-row` — 2 колонки 50/50.
- `#wDate`, `#wNumber` — класс `wizard-akt-meta-control`, высота 44px.

### 3.3. Мастер — шаг 4 «Нарушения» (web-65)

Класс панели: **`wizard-panel--violations`** (ставится в `wizard.js` → `render()`).

- Шапка шага: заголовок + кнопка «+ Добавить» **столбиком**, кнопка на всю ширину.
- Карточки `.viol-card` — **колонка** (номер, тело, действия снизу), текст с переносом.
- `#wPhotoGrid` — адаптивная сетка миниатюр.
- Тап по карточке → **`WizardModals.openViolationEditor`** (`#wizardModalRoot`) — см. **§3.11**.

### 3.11. Модалка «Редактирование / Новое нарушение» (web-108–114)

Корень: **`#wizardModalRoot`** (класс `modal-root`), разметка в `wizard-modals.js` → `ensureModalRoot()`.

**На телефоне (`body.gazprom-mobile-shell`):**

| Параметр | Значение |
|----------|----------|
| Размер | **На весь экран** — `width/height/max-height: 100%`, `border-radius: 0`, padding оверлея = safe-area (без `--mobile-modal-gutter` 90%) |
| Выделение текста в `textarea` | На корне модалки **`touch-action: auto`** (не `none` — иначе на iOS ручки выделения «замирают»); `overflow: hidden` (не `visible` — иначе не работают × / «Отмена») |
| Backdrop | `z-index: 0`, `touch-action: none`; диалог `z-index: 1` |
| Тело | `.modal-body` — `flex: 1`, прокрутка `overflow-y: auto` |
| Футер | **Один ряд**, порядок: **Удалить** (если редактирование) → **Сохранить** → **Отмена**; кнопки `flex: 1 1 0`, `min-height: 48px` (как `.wizard-footer`) |
| Закрытие | Делегирование `click` на `#wizardModalRoot` → `[data-close]` (крестик, «Отмена», тап по backdrop); `GazpromMobileOverlay.lock()` / `unlock()` |
| Клавиатура (web-124) | При **реальной** клавиатуре (`insetBottom > 80px`) — `wizard-modal--keyboard`: футер скрыт, **«Сохранить»** в шапке; модалка **всегда fullscreen** (без `visualViewport` resize); `.app` скрыт за модалкой (`visibility: hidden`); прокрутка к полю в `mobile-overlay.js` |

**`mobile-overlay.js`:** при открытой модалке (`hasOpenOverlay()`) глобальный `touchmove` **не** вызывает `preventDefault()` — не мешает ручкам выделения.

**Остальные модалки** (справочники, `vr-form-overlay`, confirm): по-прежнему **90%** ширины (`--mobile-modal-width`), центрирование flex, на корне `touch-action: none`.

**CSS:** `css/app.css` — блок «Mobile overlays» (~4674+), правила `body.gazprom-mobile-shell #wizardModalRoot*`.

### 3.4. Мастер — шаг 5 «Выводы комиссии» (web-65, web-67, web-72–73)

Класс панели: **`wizard-panel--conclusions`**.

- `#screen-wizard .wizard-layout` — **flex column**, `min-width: 0`, без overflow по X.
- Даты — **одна колонка** (`form-row` → flex column).
- Чипы представителей — **на всю ширину**, столбиком, длинный текст переносится.
- Шаблоны выводов / «Редактировать» — кнопки на всю ширину.
- Фильтры организаций — **горизонтальная** полоса в `.pred-filter-row`: `flex-wrap: nowrap`, `overflow-x: auto`, `overflow-y: hidden`, `-webkit-overflow-scrolling: touch`, `overscroll-behavior-x: contain`. В `mobile-overlay.js` — `.pred-filter-row` в whitelist горизонтального скролла (как `.toolbar-filters--pills`).
- **web-72:** временно вертикальный скролл в колонке (max-height 160px / 30vh). **web-73:** откат к горизонтальному ряду.

### 3.5. Сводка акта в мастере (web-70, web-74)

- Панель `.summary-panel` / `#wizardSummaryPanel` по умолчанию **свёрнута** (`summary-panel--collapsed`) на всех ширинах мастера.
- Заголовок — кнопка `#wizardSummaryToggle` с `aria-expanded` / `aria-controls="wizardSummaryBody"`.
- Раскрытие по tap/click (и Enter/Space); делегирование на `#wizardRoot` в `wizard.js` — переживает `render()` мастера.
- Содержимое строк — в `.summary-panel__body`; обновление в `updateSummary()`.
- **web-74:** строка «Организация» — краткое название (`organization.shortTitle`, иначе `title`); строка «Объект» убрана из сводки.

### 3.6. Устранение — карточки актов (web-76, web-115)

- Разметка: кольцо прогресса слева; блок **`elimination-act-card__content`** — шапка (номер акта, `shortTitle` организации, срок + бейдж «Устранено»/«Не устранено») и под ней **`elimination-act-card__foot`** (объект / статус).
- На телефоне (`body.gazprom-mobile-shell`): карточка — **CSS Grid** (`ring` | `header`, затем `foot` на **всю ширину**); `display: contents` у `__content`, чтобы объект не сжимался между кольцом и бейджем.
- Текст объекта: 14px, `line-height: 1.45`, `word-break: normal`, `overflow-wrap: break-word`, `hyphens: auto` — без рваных переносов внутри слов.
- Кольцо: 56×56px, `flex-shrink: 0`; бейдж статуса — колонка справа в шапке, не перекрывает текст.
- **web-115 — модалка «Продлить срок» / «История сроков»:** поле даты на телефоне — полная ширина, `min-height: 44px`, без обрезки; `deadlineHistory` хранит **только фактические продления** (не начальный срок); логика в `elimination-editor.js`, `akt-utils.js`.

### 3.7. Кнопки «Назад» / «Далее» (web-66, web-68, web-71)

- На телефоне: **одна строка**, `justify-content: space-between`, gap 12px.
- Кнопки **равной ширины**: `flex: 1 1 0`, `min-width: 0`, padding 12×10px, font 14px, `min-height: 48px`, текст с переносом (без `max-width: 46%`, без центрирования узких кнопок).
- Подпись последнего шага: **«💾 Сохранить черновик»** (полная, как на десктопе).
- web-67 временно уменьшал кнопки (12px) — **откат в web-68**; web-70 временно сужал кнопки (центр, 46%) — **откат в web-71** к виду web-66/web-68.

### 3.8. Экран «История» (web-75, web-77–82, web-85)

- Разметка карточки как на **Устранении**: иконка слева; **`history-list-item__content`** — шапка (блок **`history-list-item__head`**: номер акта, `shortTitle` организации, **«Проверка: дата»** в той же позиции, что «Срок:» на Устранении; справа кнопка **×**) и **`history-list-item__foot`** (объект, тип акта).
- Ширина и отступы карточек — как **Устранение**: `gap: 12px` в списке, padding карточки `16×20` (десктоп) / `12×14` (телефон); у `.history-card.card--flush` на телефоне `padding: 0`, без лишних боковых отступов списка.
- На телефоне (`body.gazprom-mobile-shell`): карточка — **CSS Grid** (`icon` | `header`, затем `foot` на **всю ширину**); `display: contents` у `__content`; разделитель подвала — только на телефоне.
- Подвал: **`history-list-item__object`** — название объекта из `(akt.objectsCheck || [])[0].title` (fallback `subTitle`); затем тип акта. Дата проверки — в шапке (`__head`), не в подвале.
- Подзаголовок шапки — **только тип акта** в подвале («Полный акт» / «Сокращённый акт»), **без** числа нарушений.
- Бейдж «Завершён» / «Черновик» убран; вместо статуса справа в шапке — **кнопка удаления** (красная **×**, `var(--danger)`, tap 44×44); для черновиков — компактная метка «Черновик» в подвале.
- Организация — **`AktSearch.getOrgTitle`** (`shortTitle`, иначе `title`), отдельная строка `.history-list-item__org` с переносом слов.
- Панель фильтров — **колонка** (поиск сверху, затем **одна** горизонтальная полоса pills `.toolbar-filters--pills`: `flex-wrap: nowrap`, `overflow-x: auto`, `touch-action: pan-x pinch-zoom` на полосе и на `.filter-pill`, `padding-right` для прокрутки до «Полные» / «Черновики»).
- Блок **«Сортировка»** (`.history-list-toolbar`) — **одна строка**, горизонтальный скролл при нехватке места; кнопка организации подписана **«Орг.»** (`aria-label="Организация"`). Кнопки `.history-sort-btn` — как filter-pill: **13px**, padding **10×12px**, `min-height` **40px** (десктоп) / **44px** (телефон); web-81 временно ужимал до 11px — откат в **web-85**.
- Кнопка **«Экспорт списка»** удалена (web-75); `exportHistory` убран из `report-exporter.js`.

**Корневая причина залипания горизонтального свайпа (web-81 → web-82):** на телефоне у `body` / `.main` задано `touch-action: pan-y`, а глобальный `touchmove` в `mobile-overlay.js` при доминирующем горизонтальном жесте вызывает `preventDefault()`. Селекторов web-81 (`.toolbar-filters--pills`, `.history-list-toolbar`) было недостаточно: свайп часто начинается на **`<button class="filter-pill">`** — Safari не прокручивает родителя с `overflow-x: auto`, пока жест идёт по кнопке; плюс обработчик на `document` перехватывал жест раньше полосы. **web-82:** расширенный `HORIZONTAL_SCROLL_SELECTOR` (`#screen-history .toolbar--history`, `.toolbar-history__body`, …), `touch-action: pan-x pinch-zoom` на pills/сортировке, `overflow-x: visible` у оболочки toolbar и карточки, capture-`stopPropagation` в whitelist-зоне (без `preventDefault` на document). **web-85:** убран ручной `scrollLeft` на `touchmove` (web-82) — он заменял нативную инерцию `-webkit-overflow-scrolling: touch` пошаговым сдвигом; остаются CSS `pan-x` + shield + `preventDefault` вне whitelist.

### 3.9. Баннер статуса данных (web-86 — web-94)

- `#dataStatusBar` — при загруженных данных (`renderDataStatus` в `ui-bindings.js`): компактная строка **«✓ актов: N · орг: M · фото: K»** (`.data-status__line--compact`); полная строка — на десктопе / в портрете без peek.
- После обновления статистики — **`peekDataStatusBar`**: классы `data-status--peek` / `data-status--hidden`, показ ~**3,5 с** (`DATA_STATUS_PEEK_MS`), затем скрытие с анимацией ~**0,75 с** (`DATA_STATUS_ANIM_MS`, CSS `cubic-bezier`).
- **ПК и телефон:** `position: fixed` оверлей (`z-index: 1200`), **полупрозрачный** фон + `backdrop-filter` — контент под баннером просвечивает, layout **не сдвигается**; `pointer-events: none`.
- На телефоне (`body.gazprom-mobile-shell`): **web-94** — зелёный фон ещё прозрачнее (`rgba` ~0,58–0,62, blur 14px), safe-area padding; peek — уезжает вверх `transform`.
- Для пустой / «свежей» базы — **`hideDataStatusBar`**, баннер не показывается (импорт — в **Настройках**).
- `role="status"`, `aria-live="polite"` на загруженном состоянии.

### 3.10. Нижняя навигация — outline + подчёркивание (web-88–90)

**Разметка** (`index.html`, класс `.bottom-nav`):

| Пункт | `data-screen` | Подпись (desktop / скрыта на телефоне) |
|-------|---------------|----------------------------------------|
| Главная | `home` | Главная |
| Редактируемый акт | `wizard` | Редакт. |
| История | `history` | История |
| Отчёты | `reports` | Отчёты |
| Устранение | `elimination` | Устран. |
| Настройки | `settings` | Ещё |

**Иконки:** inline SVG outline (сетка, карандаш, история, столбчатая диаграмма, щит, ползунки) — единый набор с боковым меню на десктопе.

**Размер (не меняется при выборе):**

| Зона | SVG |
|------|-----|
| Sidebar (десктоп) | **26×26 px** |
| Bottom bar (телефон) | **28×28 px** |

**Активный пункт на телефоне (`body.gazprom-mobile-shell`):**

- **Только подчёркивание** под иконкой: полоска **26×3 px**, цвет `#26c6da`, `border-radius: 999px` (`::after` у `.bottom-nav-item.active`).
- **Без** pill-фона, padding, ring/box-shadow на иконке (web-88 временно добавлял — **откат в web-89**).
- **Без** изменения размера SVG и контейнера `.nav-icon` при `.active`.
- Цвет подписи/иконки активного пункта — `var(--primary)`; opacity иконок одинаковая у active/inactive (**0.72**).

**Десктоп (sidebar):** активный пункт — cyan-полоска **слева** (4 px) + подсветка фона; размер иконок тот же.

**CSS:** `css/app.css` — блок `.bottom-nav` и `body.gazprom-mobile-shell .bottom-nav-item*` (~2040+, ~4870+).

**Не использовать:** вариант 4 (FAB «Новый акт») — только макет `nav-desktop-preview.html`.

### 3.12. График проверок на главной (web-116, web-118, web-119)

Блок `#schedulePanel` / `schedule-editor.js` на телефоне:

| Параметр | Поведение |
|----------|-----------|
| Шапка | Заголовок и переключатель года **не накладываются** друг на друга |
| Портрет | Год — **отдельная строка** под заголовком (flex-wrap) |
| Альбом | Шапка в **одну строку**; сетка месяцев **6×2**, ячейки с прокруткой текста |
| Переключатель года | Только в блоке ‹ **год** › (`web-118`); без дублирования года в заголовке |
| web-119 | Убрана альбомная сетка в одну строку; финальная вёрстка шапки без overlap |

**CSS:** `css/app.css` — блок `#schedulePanel` / `.schedule-*` в phone MQ.

### 3.13. Ширина экрана — flex-shell (web-121, web-122)

**Проблема (web-121):** при скрытом `.sidebar` сетка `.app` оставалась `grid-template-columns: 64px 1fr`, а `.header` и `.main` — `grid-column: 2` (десктоп). Контент смещался относительно ширины экрана.

**Доработка (web-122):**

- На телефоне `.app` — **`display: flex; flex-direction: column`** (не grid): сайдбар не участвует в раскладке, шапка и `.main` на **100%** ширины.
- `.sidebar { display: none !important }` в phone MQ и критическом CSS.
- **Safe-area:** у `.header` и `.main` исправлены перепутанные `padding` (right ← `inset-right`, left ← `inset-left`) — в landscape без лишней полосы справа.
- Критический CSS в `<head>` (`#appShellCritical`) — flex-правила до загрузки `app.css`.

**Файлы:** `css/app.css` (блоки ~1380, ~3033, ~4023), `index.html` (`#appShellCritical`).

## 4. Модальные окна и lightbox

- Оверлеи: `z-index: 10000`, центрирование flex (кроме fullscreen `#wizardModalRoot` — §3.11).
- **Обычные** диалоги: 90% ширины (`--mobile-modal-width`), `--vv-height` для max-height, нижний padding оверлея `+18px` над баром Safari.
- **Нарушение:** fullscreen на телефоне — §3.11.
- Lightbox: `photoSrcAsync`, галерея по акту.
- `.summary-panel` на mobile: не sticky; на шагах мастера layout — колонка (сводка может быть выше контента, `order: -1` in phone MQ); по умолчанию свёрнута (web-70).

---

## 5. Горизонтальный свайп

`mobile-overlay.js`: блокировка доминирующего горизонтального жеста; сброс `scrollX` / `main.scrollLeft`; whitelist для pills/фильтров (§3.8).

---

## 5.1. Поворот экрана — web-59

- Единый phone MQ в CSS и JS.
- `recoverViewportLayout()` на `orientationchange` (80–700 ms).
- `.wizard-akt-meta-row` — всегда 2 колонки в phone MQ.

### 5.2. Читаемый landscape — web-60, web-61

- Баннер: `.data-status__line--compact` (одна строка).
- **Шапка: только `#pageTitle`** — `.header-actions` скрыт, **глобального поиска нет** (ни в portrait, ни в landscape на телефоне).
- Bottom-nav: только иконки, меньше `--gazprom-nav-block`.
- Плитки **Настроек** — обычный вид (без ужатия web-60).

---

## 6. Импорт бэкапа и фото (кратко)

- Десктоп: base64 в каталоге (`skipPhotoIngest`).
- iPhone + большой файл: `PhotoStore.ingestCatalogInPlace`.
- См. `js/backup-import.js`, `js/photo-store.js`.

---

## 7. История изменений (mobile UX)

| Сборка | Что сделано |
|--------|-------------|
| web-46 | Lightbox: `photoSrcAsync` |
| web-47–49 | Галерея акта, стиль стрелок lightbox |
| web-50 | Удалена debug-инструментация |
| web-51–56 | Mobile shell, модалки, overflow |
| web-57 | Нижний бар `bottom: 0` |
| web-58 | Дата/номер акта; файл `MOBILE_PHONE_MODE.md` в репо |
| web-59 | Поворот: phone MQ + `recoverViewportLayout` |
| web-60 | Landscape: компактный статус, бар без подписей |
| web-61 | Скрыт `#globalSearch`; настройки — обычные плитки |
| web-62 | Нижний бар чуть ниже (`--gazprom-nav-shift-down`) |
| web-63 | Сборка перенесена на **Главную** |
| web-64 | Надпись сборки по центру внизу главной |
| web-65 | Мастер шаги 4–5: классы панелей + mobile CSS |
| web-66 | Кнопки Назад/Далее в одну строку, равная ширина |
| web-67 | Выводы: без overflow; кнопки временно уменьшены |
| web-68 | Кнопки мастера возвращены к виду web-66 |
| web-69 | **`syncAppBuildLabel()`** — сборка из `app.js` (не из кэша HTML); bump SW v69 |
| web-70 | Сводка акта в мастере: свёрнута по умолчанию, раскрытие по заголовку; кнопки Назад/Далее уже (центр, max-width 46%) |
| web-71 | Кнопки Назад/Далее возвращены к web-66/web-68 (space-between, равная ширина); сворачиваемая сводка — без изменений |
| web-72 | Выводы: фильтры организаций — вертикальный скролл в `.pred-filter-row` (колонка, max-height 160px/30vh); чипы на всю ширину |
| web-73 | Выводы: откат web-72 — фильтры снова **горизонтальный** скролл; `.pred-filter-row` в whitelist |
| web-74 | Сводка акта: организация — `shortTitle` (fallback `title`); строка «Объект» удалена |
| web-75 | История: краткая организация, mobile-столбик; toolbar без наложения; удалён «Экспорт списка» |
| web-76 | **Устранение:** сетка карточек на телефоне, объект на всю ширину, читаемые переносы; `shortTitle` в шапке |
| web-77 | **История:** карточки как Устранение — сетка, `shortTitle`, дата и тип в подвале; **×** вместо бейджа «Завершён»; без числа нарушений |
| web-78 | Навигация вариант 4 (десктоп): FAB «Новый акт», SVG-иконки, «Текущий черновик»; макет в `nav-desktop-preview.html` |
| web-79 | **История:** в подвале — объект и «Проверка: дата»; удаление — красная **×** |
| web-80 | **История:** карточки по ширине/отступам как Устранение; «Проверка: дата» в шапке (`__head`); восстановление v4 sidebar (коммит fix) затем **откат sidebar** в web-81 — в проде классическая боковая панель + SVG в bottom-nav |
| web-81 | **История:** pills и «Сортировка» в одну строку, «Орг.»; первый whitelist горизонтального скролла (на iPhone ещё залипало — web-82) |
| web-82 | **История:** рабочий горизонтальный свайп pills/сортировки — `pan-x` на кнопках, расширенные селекторы, capture-shield |
| web-83–84 | Промежуточные bump `GAZPROM_WEB_BUILD` / `?v=` / SW — без отдельных mobile UX в git |
| web-85 | **История:** кнопки сортировки крупнее (13px, 44px min-height); **плавный** горизонтальный скролл — убран ручной `scrollLeft` |
| web-86 | **Баннер данных:** peek при обновлении статистики, компактная строка «✓ актов · орг · фото», анимация скрытия |
| web-87 | **Баннер данных:** доработка peek (таймеры 3,5 с / 0,75 с, `aria-live`, fixed-оверлей на телефоне) |
| web-88 | **Навигация v1:** outline SVG в sidebar и bottom bar; иконки 26/28 px; на телефоне активный пункт — pill + полоска снизу (временно) |
| web-89 | **Bottom bar:** активный пункт — **только подчёркивание** под иконкой; размер SVG не меняется при выборе; убраны pill/padding/shadow web-88 |
| web-88–89 | Нижний бар: outline SVG, активный пункт — только подчёркивание (без pill на иконке) |
| web-90 | **Нижний бар:** восстановлена вкладка **Отчёты** (`data-screen="reports"`) — как в боковом меню десктопа; порядок: Главная → Редакт. → История → Отчёты → Устран. → Ещё |
| web-91 | **Устранение:** диалог «Продлить срок» / «История сроков» поверх карточки нарушений — `catalog-form-overlay--elevated` (z-index 9300 / 10010 на телефоне) |
| web-92 | **Баннер данных:** fixed-оверлей поверх экрана (ПК и телефон), полупрозрачный blur — контент **не сдвигается** при peek |
| web-93 | Bump релиза: `GAZPROM_ASSET_V` / SW `gazprom-web-v93` |
| web-94 | **Баннер данных (телефон):** более прозрачный зелёный оверлей (`rgba` ~0,58–0,62 + blur 14px) — контент просвечивает сильнее |
| web-95 | **Баннер данных:** убрана жёлтая/статичная панель при загрузке — только краткий зелёный peek при синхронизации; `#dataStatusBar` скрыт до первого peek |
| web-96 | **Сборка:** `#appBuildId` перенесён в `#screen-home` — не просвечивает на шаге «Выводы» (срок устранения); **фильтры организаций** в `.pred-filter-row` снова **горизонтальный** ряд с `overflow-x` (откат web-72 в mobile CSS) |
| web-97 | **Мастер:** «Назад»/«Далее» — уточнён статический `--gazprom-nav-block` (частично) |
| web-98 | **Все экраны:** `syncNavScrollInset()` — динамический `--gazprom-nav-block` по `getBoundingClientRect(.bottom-nav)` + панель Safari; вызов при resize/orientation/смене вкладки |
| web-104–107 | **Прокрутка под bottom-nav:** `padding-bottom` на scroll-host списков/настроек/мастера; кэш `navBlockByScreen`; cap ~240px; сброс PWA-кэша (105) |
| web-108 | **Плавный скролл:** коррекция overlap только после остановки (`bumpScrollClearanceAtRest`, debounce 450ms / `scrollend`) |
| web-109 | Удалена отладочная панель DEBUG / `agentLog` |
| web-110 | Подсказка восстановления данных; убран агрессивный purge |
| web-111 | (промежуточный bump) |
| web-112 | **Модалка нарушения (iOS):** `touch-action: auto` на `#wizardModalRoot`; не блокировать `touchmove` при `hasOpenOverlay()`; закрытие через делегирование `[data-close]`; **деплой/версия:** `GAZPROM_ASSET_V`, SW без кэша `index.html`, `cache: no-store` для HTML/SW |
| web-113 | **Модалка нарушения:** на **весь экран** на телефоне (как шаг «Нарушения»), не 90% |
| web-114 | **Футер модалки:** кнопки в **одну строку** — Удалить → Сохранить → Отмена; равная ширина, safe-area снизу |
| web-115 | **Устранение:** поле даты в модалке продления срока на телефоне; `deadlineHistory` — только записи продлений |
| web-116 | **График проверок:** шапка без overlap; в landscape сетка **6×2**, прокрутка в ячейках |
| web-117 | Откат промежуточного графика; bump SW `gazprom-web-v117` |
| web-118 | **График:** переключатель года в блоке ‹ ›; портрет — год на отдельной строке, альбом — одна строка шапки |
| web-119 | **График:** заголовок и год без наложения; **Главная:** `fadeIn` без `transform` — метка сборки не прыгает |
| web-120 | **Загрузка:** критический CSS в head; анимация экрана только после `gazprom-navigated`; boot без scroll-snap замера |
| web-121 | **Все экраны:** одноколоночная сетка `1fr` — контент по центру ширины экрана (убран пустой отступ 64px слева) |
| web-122 | **Модалка нарушения + клавиатура:** привязка к `visualViewport`; при клавиатуре скрыт футер, «Сохранить» в шапке; читаемая высота `textarea`; автоскролл к полю |
| web-123 | (откатано в web-124) vv-якорь и раздувание полей по фокусу |
| web-124 | **Модалка нарушения:** без смены размеров окна; реестр/экраны не просвечивают; поля не раздуваются при фокусе |
| web-122 | **Все экраны:** mobile shell на **flex** (не grid); исправлены safe-area padding у шапки и `.main` |

**При каждом релизе mobile обязательно:**

1. Bump `GAZPROM_ASSET_V` в `index.html`, подпись в `#appBuildId`, `?v=` у `app.js` / `wizard-modals.js` / `mobile-overlay.js`, `sw.js` `CACHE_NAME` и пути в `STATIC_ASSETS`.
2. **`git push origin main`** — иначе на GitHub Pages останется старая сборка.
3. **Обновить этот файл** — строка сборки в шапке документа, §3.11, таблица §7, §8.

---

## 8. Чеклист проверки на телефоне

1. **Главная** → внизу по центру актуальная «Сборка: web-124» (или новее); метка **не прыгает** при обновлении страницы; на **мастере** подписи сборки **нет**.
2. Нет глобального поиска в шапке (portrait и landscape); на **Истории** — своё поле `#historySearch`.
3. **Мастер шаг 1** — дата и номер 50/50, одна высота.
4. **Мастер шаг 4** — карточки нарушений без обрезки справа; кнопка добавления на всю ширину.
5. **Мастер шаг 5** — даты столбиком, чипы представителей на всю ширину, без горизонтального сдвига страницы; фильтры организаций — **горизонтальный** свайп по ряду чипов.
6. **Сводка акта** — свёрнута по умолчанию; по нажатию раскрываются строки; «Организация» — краткое имя, без строки «Объект».
7. **Назад / Далее** — в одну строку, равная ширина по краям (`space-between`); на последнем шаге «💾 Сохранить черновик».
8. **Модалка нарушения** — на **весь экран**; выделение текста в полях (ручки двигаются); закрытие: ×, «Отмена», тап по затемнению; футер: **Удалить | Сохранить | Отмена** в одну строку, равная ширина; **при клавиатуре** — футер скрыт, «Сохранить» в шапке, поле ввода читаемо (web-122).
9. Поворот landscape ↔ portrait — вёрстка не «ломается»; в landscape шапка **без поиска**, баннер — одна строка (или peek, см. п. 13).
10. Нижний бар — **6 пунктов** (в т.ч. **Отчёты**); иконки **28 px**, не меняют размер при tap; активный пункт — **только голубое подчёркивание** снизу (§3.10); бар не перекрывает контент.
11. **История** — карточки на всю ширину как Устранение; в шапке номер, организация, «Проверка: дата»; в подвале объект и тип; **×** справа; pills — **плавный** свайп до «Черновики»; «Сортировка», **Орг.**, кнопки ~13px; нет «Экспорт списка».
12. **Устранение** — кольцо слева, бейдж в шапке; объект на всю ширину; `shortTitle` организации.
13. **Баннер данных** — после синхронизации/импорта кратко «✓ актов · орг · фото», затем плавно исчезает; **fixed-оверлей** сверху, на телефоне **полупрозрачный** (blur); экран не прыгает; `pointer-events: none`.
14. **График проверок** — заголовок и год не накладываются; в портрете год на отдельной строке; в альбоме — сетка 6×2.
15. **Центрирование** — контент всех экранов без сдвига вправо (нет пустой полосы 64px слева); шапка и `.main` на всю ширину.

---

## 9. Симулятор vs реальный iPhone

- Simulator: нет панели Safari — отступы бара могут отличаться.
- После CSS/JS mobile — проверка на **реальном iPhone** обязательна.

---

## 10. Что делать дальше

- [x] Дата/номер — web-58
- [x] Поворот — web-59
- [x] Landscape chrome — web-60, web-61 (шапка без поиска)
- [x] Нижний бар, сборка на главной — web-62–64
- [x] `syncAppBuildLabel` — web-69
- [x] Мастер шаги 4–5 — web-65, web-67, web-72–73
- [x] Кнопки мастера в строку — web-66 / web-68 / web-71
- [x] Сводка акта сворачиваемая + краткая орг. — web-70, web-74
- [x] История: карточки, объект, дата, ×, ширина — web-77–80
- [x] История: горизонтальный скролл фильтров/сортировки — web-81–82, web-85
- [x] История: крупные кнопки сортировки — web-85
- [x] Устранение — карточки на телефоне — web-76
- [x] Баннер статуса данных (peek) — web-86–87
- [x] Нижняя навигация outline + подчёркивание active — web-88–89
- [x] Устранение: диалог продления срока поверх списка нарушений — web-91
- [ ] Мастер шаги 2–3 (организация, объект)
- [ ] Навигация v4 (FAB) — только макет `nav-desktop-preview.html`, в прод не включать
- [x] Модалка нарушения: fullscreen, iOS-выделение, закрытие, футер в строку — web-112–114
- [x] Устранение: дата в модалке, история только продлений — web-115
- [x] График проверок на телефоне — web-116, web-118, web-119
- [x] Метка сборки и загрузка без прыжка — web-119, web-120
- [x] Одноколоночная сетка, центрирование экранов — web-121, web-122 (flex-shell)
- [ ] Прочие модалки (справочники) — тонкая подстройка при необходимости
- [ ] PWA vs Safari in-browser

**Не трогать** desktop (`> 900px` + мышь) без явного запроса.

---

## 11. Связанные документы

- `QA_WEB.md` — общая приёмка PWA
- `README.md` — запуск, деплой, ссылка на этот файл

---

_Обновлено под **web-124**. При следующем релизе — синхронизировать `GAZPROM_ASSET_V`, §3.11, §3.12–3.13, §7, §8._

### Кэш PWA и GitHub Pages: старая «Сборка»

1. **Не запушено в git** — на https://rus89nur.github.io/program/ останется старая версия (нужен `git push origin main`, workflow ~1–2 мин).
2. **Закэширован SW** — закрыть вкладку полностью, открыть снова; при необходимости Safari → удалить данные сайта `github.io` или переустановить PWA с домашнего экрана.
3. **web-112+:** подпись из `GAZPROM_ASSET_V` + ранний скрипт в `index.html`; SW тянет свежий HTML с сети (`no-store` для navigation).
