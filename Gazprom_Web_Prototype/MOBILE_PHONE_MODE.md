# Телефонный режим веб-PWA «программа НЕТ»

Документ для продолжения работы **без контекста чата**. Актуальная сборка на момент последнего обновления файла: **web-65** (проверьте в UI: Настройки → «Сборка: web-XX»).

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

Константа в JS: `window.GAZPROM_PHONE_LAYOUT_MQ`. Класс на `<body>`: **`gazprom-mobile-shell`** (`index.html` ранний скрипт + `js/mobile-overlay.js`, `toggle` при `change` / `orientationchange`).

---

## 2. Ключевые файлы

| Файл | Назначение |
|------|------------|
| `css/app.css` | Блоки **`Mobile shell`** (~3580+) и **`Mobile overlays`** (~3750+), медиа `@media (max-width: 900px)` |
| `js/mobile-overlay.js` | MQ телефона, `recoverViewportLayout` после поворота, блокировка свайпа, `--vv-height`, lock `.main` |
| `index.html` | `viewport-fit=cover`, `interactive-widget=resizes-content`, ранний скрипт `gazprom-mobile-shell`, подключение `mobile-overlay.js` |
| `js/wizard.js` | Lightbox фото (`photoSrcAsync`), галерея «Все фото акта», класс `wizard-akt-meta-row` (дата + номер) |
| `js/wizard-modals.js` | Модалки нарушений, `GazpromMobileOverlay.lock/unlock` |
| `js/app.js` | `closeBackupModal`, `GAZPROM_WEB_BUILD` |
| `js/toast.js`, `js/catalog-editor.js`, `js/schedule-editor.js`, `js/violation-registry.js`, `js/elimination-editor.js`, `js/short-akt-form.js` | Вызовы `GazpromMobileOverlay` при открытии/закрытии оверлеев |
| `sw.js` | `CACHE_NAME` = `gazprom-web-vXX` — bump при каждом релизе |

**Отладочная инструментация удалена** (web-50): нет `debug-agent.js`, нет кнопки «Скопировать журнал отладки».

---

## 3. Архитектура mobile shell

```
┌ data-status ─────────────┐
├ .app ────────────────────┤
│  header (2 ряда)         │
│  .main (скролл Y)        │
├ bottom-nav (fixed bottom)┤  ← поверх контента, bottom: 0 + safe-area
└──────────────────────────┘
```

- **`html` / `body`**: `overflow: hidden`, высота `100dvh`, без горизонтального скролла страницы.
- **`.main`**: единственная вертикальная прокрутка контента; `padding-bottom` = высота нижнего бара (`--gazprom-nav-block`).
- **Нижний бар**: `position: fixed; bottom: 0; left: 0; right: 0` — сразу над панелью браузера Safari (без лишнего подъёма с web-57).
- **Шапка**: заголовок на всю ширину, поиск **на всю ширину** (`min-width: 0`, убран `min-width: 200px` у `.search-box` на mobile).

### CSS-переменные (mobile)

```css
--gazprom-nav-lift: 0px;
--gazprom-nav-block: calc(52px + env(safe-area-inset-bottom, 0px) + 6px);
--mobile-modal-gutter: 20px;
--mobile-modal-width: 90%;
--vv-height: …px  /* из visualViewport, JS */
```

---

## 3.1. Экран «Редактирование акта» — дата и номер (web-58)

Шаг 1 мастера (`js/wizard.js`):

- Обёртка: `.form-row.wizard-akt-meta-row` — две колонки 50/50 на телефоне.
- Поля: `#wDate` и `#wNumber` с классом **`wizard-akt-meta-control`** (одинаковая высота **44px**, `width: 100%`, `box-sizing: border-box`).
- Для `input[type=date]` на iOS: `-webkit-appearance: none` (см. `#wDate.wizard-akt-meta-control` в `app.css`).

Стили: общие правила ~строка 477 в `app.css`, mobile — блок `gazprom-mobile-shell` ~3735.

---

## 4. Модальные окна и lightbox

- Оверлеи: `z-index: 10000`, `display: flex; align-items: center; justify-content: center`.
- Диалоги: **90%** ширины, боковые отступы **20px**, `max-height` с учётом `--vv-height` и safe-area.
- **Lightbox** (`wizard.js` → `openLightbox`): `photoSrcAsync`, галерея по всему акту в `#wPhotoGrid`, стрелки в стиле «чипов» под фото.
- При открытии модалки: `GazpromMobileOverlay.lock()` — скролл `.main` блокируется.
- **Сводка акта** (`.summary-panel`): на mobile `position: relative`, не sticky; под модалками не перекрывает (`z-index` оверлеев выше).

---

## 5. Горизонтальный свайп (реальный iPhone)

`mobile-overlay.js`:

- Блокирует жест влево/вправо, если `|dx| ≥ |dy| * 0.45` (кроме `.list-table`, `.wizard-stepper`, `.toolbar-filters--pills`).
- Сбрасывает `window.scrollX` и `main.scrollLeft` на touchstart/touchend/scroll.
- `touch-action: pan-y` на `body`, `.app`, `.main`.

**Причина прошлых багов:** шапка в одну строку (заголовок + поиск `min-width: 200px`) раздувала страницу шире экрана; `grid-column: 2` у header/main при одной колонке сетки.

---

## 5.1. Поворот экрана (portrait ↔ landscape) — web-59

**Симптом:** в альбомной — «десктоп»/сжатая вёрстка; после возврата в портрет — поля мастера в одну колонку, сдвиг, залипший scroll-lock.

**Причины:**

1. В landscape на iPhone Plus/Max **ширина > 900px** → снимался `gazprom-mobile-shell`, включался десктоп-grid с сайдбаром.
2. Ранний скрипт в `index.html` **только добавлял** класс, не снимал при `resize`.
3. `.form-row { 1fr }` перебивал дату/номер, если класс shell пропадал.
4. После поворота оставались `gazprom-scroll-lock` / `--vv-height` от landscape.

**Исправления (web-59):**

- Единый MQ (см. §1) во всех `@media` в `app.css` и в `mobile-overlay.js`.
- `recoverViewportLayout()` на `orientationchange` / `resize` / `mq.change` (с задержками 80–700 ms для iOS).
- `.form-row.wizard-akt-meta-row` всегда **2 колонки** в phone MQ (без зависимости от shell).
- Сброс залипшего scroll-lock, если модалка не открыта.
- Компактные стили мастера в landscape (секция `@media … landscape` в `app.css`).

### 5.2. Читаемый landscape (web-60)

**Проблема:** мало высоты — зелёный баннер на 3+ строки, шапка в 2 ряда, нижний бар с подписями — контент (настройки) не виден.

**Решение:**

- `ui-bindings.js` → `renderDataStatus`: две версии текста — `.data-status__line--full` (портрет) и `--compact` (альбомная, одна строка с ellipsis).
- `app.css` landscape: шапка только заголовок (без поиска); `--gazprom-nav-block` ~36px; bottom-nav без подписей. Плитки настроек — как в портрете (без ужатия web-60).
- **web-61:** `body.gazprom-mobile-shell .header-actions { display: none }` — глобальный поиск убран на всех вкладках; на «Истории» свой `#historySearch`.

---

## 6. Импорт бэкапа и фото (кратко)

- **Десктоп:** фото остаются base64 в каталоге (`skipPhotoIngest`), быстрый просмотр.
- **iPhone + файл > 50 МБ:** `PhotoStore.ingestCatalogInPlace` — фото в IndexedDB как `photo:id`.
- Опция «Импорт без фото» в модалке бэкапа.
- Подробности импорта — в коде `js/backup-import.js`, `js/photo-store.js`, `js/data-store.js`.

---

## 7. История изменений (mobile UX)

| Сборка | Что сделано |
|--------|-------------|
| web-46 | Lightbox: `photoSrcAsync` |
| web-47 | Галерея «Все фото акта», lightbox по центру |
| web-48–49 | Стиль стрелок lightbox (чипы) |
| web-50 | Удалена debug-инструментация |
| web-51 | Mobile overlay lock, первый mobile shell |
| web-52 | Shell: скролл в `.main`, бар без сдвига |
| web-53 | Бар и модалки: стиль чипов; центрирование |
| web-54 | `visualViewport` (потом упрощён) |
| web-55 | Шапка 2 ряда, фикс overflow, сводка под модалками |
| web-56 | Модалки 90%, жёсткий запрет горизонтального свайпа |
| web-57 | Нижний бар `bottom: 0` (вплотную к Safari) |
| web-58 | Детальная настройка: дата проверки = размер поля «Номер акта» (`wizard-akt-meta-row`), этот файл в репозитории |
| web-59 | Поворот экрана: phone MQ в landscape, `recoverViewportLayout`, фикс дата/номер после rotate |
| web-60 | Читаемый landscape: компактный статус, шапка в 1 ряд, нижний бар без подписей, плотная сетка настроек |
| web-61 | Настройки — прежний вид плиток; на телефоне скрыт верхний `#globalSearch` (поиск остаётся на экране «История») |

При правках **всегда bump**: `js/app.js` → `GAZPROM_WEB_BUILD`, `index.html` (текст сборки + `?v=` у css/js), `sw.js` → `CACHE_NAME`.

---

## 8. Чеклист проверки на телефоне

1. **Главная** → внизу «Сборка: web-XX» совпадает с ожидаемой.
2. **Главная / История / Устранение / Настройки** — нет сдвига влево-вправо, поиск на всю ширину.
3. **Редактируемый акт** — дата и номер одной высоты, в одной строке (50/50).
4. Модалка нарушения — по центру, 90% ширины, поля не вылезают.
5. Фото: миниатюра → lightbox; «Все фото акта» листает все фото акта.
6. Нижний бар — сразу над панелью браузера, не перекрывает иконки.
7. Поворот landscape → portrait: поля мастера (дата/номер) в 2 колонки, без сдвига; в landscape — телефонный UI, не сайдбар.
8. Landscape: зелёная полоса — одна строка (краткий текст), шапка «заголовок + поиск» в ряд, настройки — плитки в несколько колонок, нижний бар — только иконки.

---

## 9. Симулятор vs реальный iPhone

- **Simulator (Xcode):** нет нижней панели Safari → бар и отступы могут выглядеть иначе.
- **Реальный Safari:** проверять обязательно после изменений mobile CSS/JS.
- Локально: `python3 -m http.server 8765` + `xcrun simctl openurl booted http://127.0.0.1:8765/`

---

## 10. Что делать дальше (детальная настройка)

Запросы пользователя вести **точечно по экранам**:

- [x] Мастер: дата/номер — **web-58** (`wizard-akt-meta-row`, класс `wizard-akt-meta-control` на `#wDate` и `#wNumber`)
- [ ] Остальные шаги мастера (организация, объект, нарушения…)
- [ ] История, устранение, настройки — отступы карточек
- [ ] Модалки — ширина 85–92%, поля форм
- [ ] PWA «На экран Домой» vs Safari in-browser
- [x] Поворот portrait ↔ landscape — **web-59**
- [x] Читаемый landscape (компактный chrome) — **web-60**

**Не трогать** стили desktop (`> 900px`) без явного запроса.

---

## 11. Связанные документы

- `QA_WEB.md` — общая приёмка PWA (не только mobile)
- `README.md` — запуск, деплой

---

_Файл создан для передачи контекста ассистенту/разработчику. Обновляйте секцию 7 и номер сборки при каждом релизе mobile._
