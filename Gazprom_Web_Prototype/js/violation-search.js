/**
 * ViolationSearch — умный поиск по реестру и нарушениям акта.
 *
 * Модель:
 * - нормализация (регистр, ё→е, пунктуация, тире, пробелы);
 * - кавычки "..." / «...» — точная фраза;
 * - несколько слов — логика И (каждый токен должен встретиться);
 * - короткие токены (1–2 символа) — только точное вхождение, без префиксов;
 * - ранжирование: формулировка > номер > вид > прочие поля.
 */
const ViolationSearch = (() => {
  const MIN_PREFIX_LEN = 3;
  const MAX_RESULTS = 200;

  function normalize(str) {
    return String(str ?? '')
      .toLowerCase()
      .replace(/\u0451/g, '\u0435')
      .replace(/[\u00a0\u202f\u2007\u2009\u200a\u200b\ufeff]/g, ' ')
      .replace(/[\u2010-\u2015\u2212]/g, '-')
      .replace(/[^0-9a-z\u0430-\u044f\-]+/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function expandText(normalized) {
    if (!normalized) return '';
    const dehyphen = normalized.replace(/-/g, ' ').replace(/\s+/g, ' ').trim();
    return dehyphen === normalized ? normalized : `${normalized} ${dehyphen}`;
  }

  function parseQuery(raw) {
    const query = String(raw ?? '').trim();
    if (!query) {
      return { raw: '', phrases: [], tokens: [], isEmpty: true };
    }

    const phrases = [];
    let rest = query;

    const pullQuoted = (pattern) => {
      rest = rest.replace(pattern, (_, inner) => {
        const p = normalize(inner);
        if (p) phrases.push(p);
        return ' ';
      });
    };

    pullQuoted(/"([^"]+)"/g);
    pullQuoted(/«([^»]+)»/g);
    pullQuoted(/'([^']+)'/g);

    const tokens = expandText(normalize(rest))
      .split(' ')
      .filter((t) => t.length > 0);

    return { raw: query, phrases, tokens, isEmpty: !phrases.length && !tokens.length };
  }

  function registryFields(item) {
    return {
      number: item?.number != null ? String(item.number) : '',
      title: item?.title || '',
      subTitle: item?.subTitle || '',
      description: item?.description || '',
      vid: item?.vid || '',
      formulaFromRules: item?.formulaFromRules || '',
    };
  }

  function actViolationFields(v) {
    return {
      number: '',
      title: v?.title || '',
      subTitle: v?.subTitle || '',
      description: v?.description || '',
      vid: v?.vid || '',
      formulaFromRules: v?.formulaFromRules || '',
      urlToPravilo: v?.urlToPravilo || '',
      mesto: v?.mesto || '',
    };
  }

  function fieldWeightsRegistry() {
    return {
      title: 40,
      number: 35,
      subTitle: 22,
      vid: 18,
      description: 15,
      formulaFromRules: 12,
    };
  }

  function fieldWeightsAct() {
    return {
      title: 40,
      subTitle: 22,
      urlToPravilo: 22,
      mesto: 20,
      vid: 18,
      description: 15,
      formulaFromRules: 12,
      number: 0,
    };
  }

  function buildFieldMaps(fields, weights) {
    const maps = {};
    for (const [key, weight] of Object.entries(weights)) {
      const raw = fields[key] || '';
      const norm = normalize(raw);
      maps[key] = {
        raw,
        norm,
        expanded: expandText(norm),
        weight,
      };
    }
    const combined = Object.values(maps)
      .map((f) => f.expanded)
      .filter(Boolean)
      .join(' ');
    return { maps, combined: expandText(combined) };
  }

  function tokenMatchesField(token, field) {
    if (!token || !field.expanded) return false;
    if (field.expanded.includes(token)) return true;
    if (token.length < MIN_PREFIX_LEN) return false;
    const words = field.expanded.split(' ').filter((w) => w.length >= MIN_PREFIX_LEN);
    return words.some((word) => word.startsWith(token) || token.startsWith(word));
  }

  function phraseMatchesField(phrase, field) {
    if (!phrase || !field.expanded) return false;
    return field.expanded.includes(phrase);
  }

  function scoreNeedle(needle, fieldMaps, combined, isPhrase) {
    let best = 0;
    for (const field of Object.values(fieldMaps)) {
      const hit = isPhrase
        ? phraseMatchesField(needle, field)
        : tokenMatchesField(needle, field);
      if (!hit) continue;
      const exactWord = field.expanded
        .split(' ')
        .some((w) => w === needle);
      best = Math.max(best, field.weight + (exactWord ? 8 : 0));
    }
    if (!best && combined.includes(needle)) best = 4;
    return best;
  }

  function scoreItem(fields, weights, parsed) {
    const { maps, combined } = buildFieldMaps(fields, weights);
    let score = 0;

    for (const phrase of parsed.phrases) {
      const part = scoreNeedle(phrase, maps, combined, true);
      if (!part) return -1;
      score += part * 2;
    }

    for (const token of parsed.tokens) {
      const part = scoreNeedle(token, maps, combined, false);
      if (!part) return -1;
      score += part;
    }

    if (parsed.tokens.length > 1) {
      const title = maps.title?.expanded || '';
      if (parsed.tokens.every((t) => title.includes(t))) score += 25;
    }

    return score;
  }

  function filterAndRank(items, query, mapFields, weights, { vidFilter, catalog } = {}) {
    let list = [...(items || [])];
    if (vidFilter) {
      list = list.filter((x) => {
        if (x.vid === vidFilter) return true;
        if (catalog && typeof ViolationTypes !== 'undefined') {
          return ViolationTypes.resolveVid(catalog, x.vid) === vidFilter;
        }
        return false;
      });
    }

    const parsed = parseQuery(query);
    if (parsed.isEmpty) return list;

    const scored = [];
    for (const item of list) {
      const fields = mapFields(item);
      const score = scoreItem(fields, weights, parsed);
      if (score >= 0) scored.push({ item, score });
    }

    scored.sort((a, b) => b.score - a.score || (a.item.number || 0) - (b.item.number || 0));
    return scored.slice(0, MAX_RESULTS).map((x) => x.item);
  }

  function filterRegistry(items, query, { vidFilter, catalog } = {}) {
    return filterAndRank(items, query, registryFields, fieldWeightsRegistry(), { vidFilter, catalog });
  }

  function filterActViolations(violations, query) {
    return filterAndRank(violations, query, actViolationFields, fieldWeightsAct());
  }

  return {
    normalize,
    parseQuery,
    filterRegistry,
    filterActViolations,
    MAX_RESULTS,
  };
})();
