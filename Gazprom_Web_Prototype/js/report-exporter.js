/**
 * Экспорт отчётов в Excel (SheetJS).
 */
const ReportExporter = (() => {
  const XLSX_LOCAL = './assets/vendor/xlsx.full.min.js';

  async function ensureXlsx() {
    if (typeof XLSX !== 'undefined') return;
    if (typeof ViolationRegistry !== 'undefined' && ViolationRegistry.loadXlsx) {
      await ViolationRegistry.loadXlsx();
      return;
    }
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = XLSX_LOCAL;
      const timer = setTimeout(() => {
        reject(new Error('Время ожидания загрузки SheetJS истекло.'));
      }, 15000);
      s.onload = () => {
        clearTimeout(timer);
        if (typeof XLSX === 'undefined') reject(new Error('Библиотека SheetJS не загружена'));
        else resolve();
      };
      s.onerror = () => {
        clearTimeout(timer);
        reject(new Error('Не удалось загрузить SheetJS из assets/vendor.'));
      };
      document.head.appendChild(s);
    });
  }

  function downloadWorkbook(wb, filename) {
    XLSX.writeFile(wb, filename);
    GazpromToast.success('Файл Excel скачан');
  }

  async function exportViolationsReport() {
    await ensureXlsx();
    const data = await GazpromStore.get();
    if (!GazpromStore.hasData(data)) throw new Error('Нет данных');

    const rows = [['Акт №', 'Дата', 'Организация', 'Объект', 'Нарушение', 'Вид', 'Место']];
    for (const akt of data.akts || []) {
      const org = akt.organization?.title || '';
      const date = AktUtils.formatDateShort(akt.date);
      for (const v of akt.violations || []) {
        rows.push([
          akt.number,
          date,
          org,
          v.mesto || '',
          v.title || '',
          v.vid || '',
          v.mesto || '',
        ]);
      }
    }
    if (rows.length === 1) rows.push(['—', '', '', '', 'Нет нарушений', '', '']);

    const ws = XLSX.utils.aoa_to_sheet(rows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Нарушения');
    downloadWorkbook(wb, `otchet_narusheniya_${new Date().toISOString().slice(0, 10)}.xlsx`);
  }

  async function exportSchedule() {
    await ensureXlsx();
    const data = await GazpromStore.get();
    const items = data?.scheduleItems || [];
    const rows = [['Год', 'Месяц', 'Организация', 'План', 'Факт']];
    for (const i of items) {
      rows.push([
        i.year,
        i.month,
        i.organizationTitle || i.organizationId || '',
        i.plannedDate ? AktUtils.formatDateShort(i.plannedDate) : '',
        i.actualDate ? AktUtils.formatDateShort(i.actualDate) : '',
      ]);
    }
    const ws = XLSX.utils.aoa_to_sheet(rows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'График');
    downloadWorkbook(wb, `grafik_${new Date().toISOString().slice(0, 10)}.xlsx`);
  }

  return { exportViolationsReport, exportSchedule };
})();
