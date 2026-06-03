# Телефонный режим веб-PWA «программа НЕТ»

Документ для продолжения работы **без контекста чата**.  
**Перед правками mobile — читать этот файл целиком**, особенно §7 (история) и §10 (чеклист).

Актуальная сборка: **web-69** (в UI: **Главная** → внизу «Сборка: web-XX»; номер подставляется из `GAZPROM_WEB_BUILD` в `app.js`).

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
| `css/app.css` | Mobile shell ~3595+, mobile overlays ~3788+, landscape ~3993+, мастер `wizard-panel--*` ~3766+ |
| `js/mobile-overlay.js` | MQ, `recoverViewportLayout`, свайп, `--vv-height`, lock `.main` |
| `index.html` | Shell-скрипт, `#appBuildId` на **Главной**, без `#globalSearch` в шапке на телефоне |
| `js/wizard.js` | Панели `wizard-panel--violations` / `--conclusions`, шаги мастера, lightbox |
| `js/ui-bindings.js` | `renderDataStatus` — полный и компактный текст баннера |
| `js/wizard-modals.js` | Модалки нарушений |
| `js/app.js` | `GAZPROM_WEB_BUILD`, `syncAppBuildLabel()` → `#appBuildId` |
| `sw.js` | `CACHE_NAME` = `gazprom-web-vXX` |

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
- **`.main`**: скролл контента; `padding-bottom` = `--gazprom-nav-block`.
- **Шапка (телефон):** только `#pageTitle`; **`.header-actions` скрыт** — нет глобального поиска (web-61). Поиск актов — на экране **История** (`#historySearch`).
- **Нижний бар:** `fixed`, `bottom: 0`, сдвиг вниз `--gazprom-nav-shift-down` (web-62).

### CSS-переменные (mobile)

```css
--gazprom-nav-lift: 0px;
--gazprom-nav-shift-down: 6px;   /* portrait; в landscape 4px */
--gazprom-nav-block: calc(50px + env(safe-area-inset-bottom) + 4px);
--mobile-modal-gutter: 20px;
--mobile-modal-width: 90%;
--vv-height: …px
```

### 3.1. Сборка приложения (web-63, web-64)

- `#appBuildId` на экране **Главная** (`#screen-home`), не в Настройках.
- Внизу главной по центру: `#screen-home.active` — flex-колонка, у `.app-build-id` — `margin-top: auto`.

### 3.2. Мастер — шаг 1: дата и номер (web-58)

- `.wizard-akt-meta-row` — 2 колонки 50/50.
- `#wDate`, `#wNumber` — класс `wizard-akt-meta-control`, высота 44px.

### 3.3. Мастер — шаг 4 «Нарушения» (web-65)

Класс панели: **`wizard-panel--violations`** (ставится в `wizard.js` → `render()`).

- Шапка шага: заголовок + кнопка «+ Добавить» **столбиком**, кнопка на всю ширину.
- Карточки `.viol-card` — **колонка** (номер, тело, действия снизу), текст с переносом.
- `#wPhotoGrid` — адаптивная сетка миниатюр.

### 3.4. Мастер — шаг 5 «Выводы комиссии» (web-65, web-67)

Класс панели: **`wizard-panel--conclusions`**.

- `#screen-wizard .wizard-layout` — **flex column**, `min-width: 0`, без overflow по X.
- Даты — **одна колонка** (`form-row` → flex column).
- Чипы представителей — **на всю ширину**, столбиком, длинный текст переносится.
- Шаблоны выводов / «Редактировать» — кнопки на всю ширину.
- Фильтры организаций — горизонтальный скролл в `.pred-filter-row`.

### 3.5. Кнопки «Назад» / «Далее» (web-66, web-68)

- На телефоне: **одна строка**, `justify-content: space-between`, обе кнопки `flex: 1` (одинаковая ширина).
- Размер: padding 12×10px, font 14px, `min-height: 48px`, текст с переносом.
- Подпись последнего шага: **«💾 Сохранить черновик»** (полная, как на десктопе).
- web-67 временно уменьшал кнопки (12px) — **откат в web-68**.

---

## 4. Модальные окна и lightbox

- Оверлеи: `z-index: 10000`, центрирование flex.
- Диалоги: 90% ширины, `--vv-height` для max-height.
- Lightbox: `photoSrcAsync`, галерея по акту.
- `.summary-panel` на mobile: не sticky; на шагах мастера layout — колонка (сводка может быть выше контента, `order: -1` в phone MQ).

---

## 5. Горизонтальный свайп

`mobile-overlay.js`: блокировка доминирующего горизонтального жеста; сброс `scrollX` / `main.scrollLeft`.

---

## 5.1. Поворот экрана — web-59

- Единый phone MQ в CSS и JS.
- `recoverViewportLayout()` на `orientationchange` (80–700 ms).
- `.wizard-akt-meta-row` — всегда 2 колонки в phone MQ.

### 5.2. Читаемый landscape — web-60, web-61

- Баннер: `.data-status__line--compact` (одна строка).
- Шапка: только заголовок (поиск скрыт на всех вкладках).
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
| web-69 | `syncAppBuildLabel()` — сборка из JS (не из кэша HTML); bump SW v69 |

**При каждом релизе mobile обязательно:**

1. Bump `GAZPROM_WEB_BUILD`, `index.html` (сборка + `?v=` css/js), `sw.js` `CACHE_NAME`.
2. **Обновить этот файл** — строка сборки в шапке документа, таблица §7, §10 при необходимости.

---

## 8. Чеклист проверки на телефоне

1. **Главная** → внизу по центру «Сборка: web-69» (после обновления страницы).
2. Нет глобального поиска в шапке; на **Истории** — своё поле поиска.
3. **Мастер шаг 1** — дата и номер 50/50, одна высота.
4. **Мастер шаг 4** — карточки нарушений без обрезки справа; кнопка добавления на всю ширину.
5. **Мастер шаг 5** — даты столбиком, чипы представителей на всю ширину, без горизонтального сдвига.
6. **Назад / Далее** — в одну строку, одинаковая ширина, текст читаем.
7. Модалка нарушения — по центру, ~90% ширины.
8. Поворот landscape ↔ portrait — вёрстка не «ломается»; в landscape баннер — одна строка.
9. Нижний бар — удобная высота, не перекрывает контент.

---

## 9. Симулятор vs реальный iPhone

- Simulator: нет панели Safari — отступы бара могут отличаться.
- После CSS/JS mobile — проверка на **реальном iPhone** обязательна.

---

## 10. Что делать дальше

- [x] Дата/номер — web-58
- [x] Поворот — web-59
- [x] Landscape chrome — web-60, web-61
- [x] Нижний бар, сборка на главной — web-62–64
- [x] Мастер шаги 4–5 — web-65, web-67
- [x] Кнопки мастера в строку — web-66 / web-68
- [ ] Мастер шаги 2–3 (организация, объект)
- [ ] История, устранение — отступы карточек
- [ ] Модалки — тонкая подстройка полей
- [ ] PWA vs Safari in-browser

**Не трогать** desktop (`> 900px` + мышь) без явного запроса.

---

## 11. Связанные документы

- `QA_WEB.md` — общая приёмка PWA
- `README.md` — запуск, деплой, ссылка на этот файл

---

_Обновлено под web-69. При следующем релизе — синхронизировать номер сборки и §7._

### Кэш PWA: на телефоне старая «Сборка»

Если в UI web-67, а в репозитории новее — закэшированы `index.html` / SW. После деплоя: закрыть вкладку, открыть снова (или «Обновить» в Safari). При активации нового SW страница перезагрузится. С **web-69** подпись берётся из `app.js`, даже если HTML старый.
