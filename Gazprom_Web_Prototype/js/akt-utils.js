/** Утилиты для актов (совместимость с iOS AKT). */
const AktUtils = (() => {
  function uuid() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }

  function toDateInputValue(iso) {
    if (!iso) return '';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return '';
    return d.toISOString().slice(0, 10);
  }

  function formatDateShort(iso) {
    if (!iso) return '—';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return '—';
    return d.toLocaleDateString('ru-RU');
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function isDraft(akt) {
    const url = akt?.urlToFllACT;
    if (url == null || url === '') return true;
    if (typeof url === 'string') {
      if (url.startsWith('web:')) return false;
      return url.length === 0 || url === '/' || url.endsWith('/');
    }
    return false;
  }

  function countPhotos(akt) {
    return (akt?.violations || []).reduce((n, v) => n + (v.photo?.length || 0), 0);
  }

  function photoSrc(photoData) {
    if (!photoData) return '';
    if (typeof photoData === 'string') {
      if (photoData.startsWith('photo:')) return '';
      if (photoData.startsWith('data:')) return photoData;
      return `data:image/jpeg;base64,${photoData}`;
    }
    return '';
  }

  async function photoSrcAsync(photoData) {
    if (!photoData) return '';
    if (typeof PhotoStore !== 'undefined' && PhotoStore.isPhotoId(photoData)) {
      return PhotoStore.resolveDataUrl(photoData);
    }
    return photoSrc(photoData);
  }

  function nextAktNumber(akts) {
    const nums = (akts || [])
      .map((a) => parseInt(a.number, 10))
      .filter((n) => !Number.isNaN(n));
    const max = nums.length ? Math.max(...nums) : 0;
    return String(max + 1);
  }

  function occupiedNumbers(akts, excludeId, year) {
    return new Set(
      (akts || [])
        .filter((a) => {
          if (a.id === excludeId) return false;
          if (year == null) return true;
          const aktYear = a.date ? new Date(a.date).getFullYear() : null;
          return aktYear === year;
        })
        .map((a) => String(a.number))
    );
  }

  function defaultOrg(catalog) {
    const orgs = catalog?.organizations || [];
    if (orgs.length) return { ...orgs[0] };
    return { id: uuid(), title: 'Организация не указана', shortTitle: '—' };
  }

  function createEmptyDraft(catalog) {
    const now = new Date();
    const iso = now.toISOString();
    const in30 = new Date(now);
    in30.setDate(in30.getDate() + 30);

    const number = nextAktNumber(catalog?.akts);
    const comission = (catalog?.comissionPeople || []).slice(0, 1).map((p) => ({ ...p }));

    return {
      id: uuid(),
      number,
      date: iso,
      comission,
      organization: defaultOrg(catalog),
      objectsCheck: [],
      predstavitelyComission: [],
      violations: [],
      description: '',
      actustranenDate: in30.toISOString(),
      actPredostavlenDate: iso,
      actUtverzdenDate: iso,
      urlToFllACT: null,
      realDateCreate: iso,
      uniqueID: `${toDateInputValue(iso)}-${number}`,
    };
  }

  function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
  }

  return {
    uuid,
    toDateInputValue,
    formatDateShort,
    escapeHtml,
    isDraft,
    countPhotos,
    photoSrc,
    photoSrcAsync,
    nextAktNumber,
    occupiedNumbers,
    createEmptyDraft,
    clone,
    defaultOrg,
  };
})();
