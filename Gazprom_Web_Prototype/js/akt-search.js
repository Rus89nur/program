/** Поиск и фильтрация актов (история, глобальный поиск). */
const AktSearch = (() => {
  function isDraft(akt) {
    return AktUtils.isDraft(akt);
  }

  function getOrgTitle(akt) {
    return akt.organization?.shortTitle || akt.organization?.title || '';
  }

  function filterAkts(akts, { query = '', year = null, violationsOnly = false, draftsOnly = false, completedOnly = false } = {}) {
    let list = [...(akts || [])];

    if (year != null) {
      list = list.filter((a) => {
        const d = new Date(a.date);
        return !Number.isNaN(d.getTime()) && d.getFullYear() === year;
      });
    }

    if (violationsOnly) {
      list = list.filter((a) => (a.violations || []).length > 0);
    }

    if (draftsOnly) {
      list = list.filter(isDraft);
    }

    if (completedOnly) {
      list = list.filter((a) => !isDraft(a));
    }

    const q = String(query).trim().toLowerCase();
    if (q) {
      list = list.filter((a) => {
        const haystack = [
          String(a.number),
          getOrgTitle(a),
          a.description,
          ...(a.objectsCheck || []).map((o) => `${o.title} ${o.subTitle}`),
          ...(a.violations || []).map((v) => `${v.title} ${v.mesto}`),
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return haystack.includes(q);
      });
    }

    return list.sort((a, b) => new Date(b.date) - new Date(a.date));
  }

  function parseFilterPill(label) {
    const t = String(label).trim();
    if (t === 'Все') return { year: null, violationsOnly: false };
    if (t === 'С нарушениями') return { year: null, violationsOnly: true };
    if (t === 'Черновики') return { year: null, draftsOnly: true };
    const y = parseInt(t, 10);
    if (!Number.isNaN(y) && y > 2000) return { year: y, violationsOnly: false };
    return {};
  }

  return { filterAkts, parseFilterPill, isDraft, getOrgTitle };
})();
