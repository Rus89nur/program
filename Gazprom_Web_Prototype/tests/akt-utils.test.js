import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';
import { describe, it, expect, beforeAll } from 'vitest';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function loadScripts() {
  const ctx = { console, Date, Math, JSON, parseInt, String, Number, isNaN: Number.isNaN };
  vm.createContext(ctx);
  const expose = '\nif (typeof AktUtils !== "undefined") this.AktUtils = AktUtils;\n';
  vm.runInContext(readFileSync(join(root, 'js/akt-utils.js'), 'utf8') + expose, ctx);
  return ctx;
}

describe('AktUtils', () => {
  let AktUtils;
  beforeAll(() => {
    AktUtils = loadScripts().AktUtils;
  });

  it('isDraft returns true for empty url', () => {
    expect(AktUtils.isDraft({ urlToFllACT: null })).toBe(true);
    expect(AktUtils.isDraft({ urlToFllACT: '' })).toBe(true);
  });

  it('isDraft returns false for web completed', () => {
    expect(AktUtils.isDraft({ urlToFllACT: 'web:completed/abc' })).toBe(false);
  });

  it('nextAktNumber increments max', () => {
    expect(AktUtils.nextAktNumber([{ number: '5' }, { number: '12' }])).toBe('13');
  });

  it('occupiedNumbers excludes current id', () => {
    const set = AktUtils.occupiedNumbers(
      [{ id: 'a', number: '1' }, { id: 'b', number: '2' }],
      'a'
    );
    expect(set.has('1')).toBe(false);
    expect(set.has('2')).toBe(true);
  });

  it('occupiedNumbers filters by calendar year', () => {
    const akts = [
      { id: 'a', number: '5', date: '2025-06-01T00:00:00.000Z' },
      { id: 'b', number: '6', date: '2026-03-01T00:00:00.000Z' },
      { id: 'c', number: '7', date: '2026-08-01T00:00:00.000Z' },
    ];
    const set2026 = AktUtils.occupiedNumbers(akts, null, 2026);
    expect(set2026.has('5')).toBe(false);
    expect(set2026.has('6')).toBe(true);
    expect(set2026.has('7')).toBe(true);
    expect(set2026.size).toBe(2);
  });

  it('nextAktNumber is global max across years', () => {
    const akts = [
      { number: '3', date: '2024-01-01T00:00:00.000Z' },
      { number: '12', date: '2026-01-01T00:00:00.000Z' },
    ];
    expect(AktUtils.nextAktNumber(akts)).toBe('13');
  });

  it('nextAktNumberForYear uses max in same calendar year only', () => {
    const akts = [
      { id: 'a', number: '28', date: '2026-05-01T00:00:00.000Z' },
      { id: 'b', number: '5', date: '2025-06-01T00:00:00.000Z' },
      { id: 'c', number: '40', date: '2024-01-01T00:00:00.000Z' },
    ];
    expect(AktUtils.nextAktNumberForYear(akts, 2026)).toBe('29');
    expect(AktUtils.nextAktNumberForYear(akts, 2025)).toBe('6');
    expect(AktUtils.nextAktNumberForYear(akts, 2023)).toBe('1');
  });

  it('applyCurrentEditable ignores short acts', () => {
    const catalog = { akts: [], editableAkt: null, editableAktReference: null };
    const short = {
      id: 's1',
      number: '9',
      violations: [{ title: 'Сокращенный: X', vid: 'X' }],
    };
    AktUtils.applyCurrentEditable(catalog, short);
    expect(catalog.editableAkt).toBe(null);
    const full = { id: 'f1', number: '10', violations: [{ title: 'Нарушение', vid: '' }] };
    AktUtils.applyCurrentEditable(catalog, full);
    expect(catalog.editableAkt?.akt?.id).toBe('f1');
  });

  it('getFullEditableAkt returns only full editable', () => {
    const short = {
      editableAkt: {
        akt: { id: 's', violations: [{ title: 'Сокращенный: X' }] },
      },
    };
    expect(AktUtils.getFullEditableAkt(short)).toBe(null);
    const full = {
      editableAkt: {
        akt: { id: 'f', violations: [{ title: 'Полное' }] },
      },
    };
    expect(AktUtils.getFullEditableAkt(full)?.id).toBe('f');
  });

  it('isShortFormat detects prefixed violations', () => {
    const short = {
      violations: [{ title: 'Сокращенный: Работы на высоте', vid: 'Работы на высоте' }],
    };
    const full = { violations: [{ title: 'Нет ограждения', vid: '' }] };
    expect(AktUtils.isShortFormat(short)).toBe(true);
    expect(AktUtils.isShortFormat(full)).toBe(false);
  });

  it('isFullFormat respects short exclusion and url', () => {
    expect(
      AktUtils.isFullFormat({
        number: '5',
        violations: [],
        urlToFllACT: 'web:completed/x',
      })
    ).toBe(true);
    expect(
      AktUtils.isFullFormat({
        number: '5',
        violations: [{ title: 'Сокращенный: X' }],
        urlToFllACT: 'web:completed/x',
      })
    ).toBe(false);
    expect(AktUtils.isFullFormat({ number: '19', violations: [] })).toBe(true);
  });

  it('getEliminationDeadline uses report date for short acts', () => {
    const akt = {
      violations: [{ title: 'Сокращенный: Прочие работы' }],
      actPredostavlenDate: '2026-07-01T00:00:00.000Z',
      actustranenDate: '2026-08-01T00:00:00.000Z',
      date: '2026-06-01T00:00:00.000Z',
    };
    expect(AktUtils.getEliminationDeadline(akt)).toBe('2026-07-01T00:00:00.000Z');
  });

  it('buildShortViolations creates prefixed rows', () => {
    const list = AktUtils.buildShortViolations({ 'Работы на высоте': 2 });
    expect(list).toHaveLength(2);
    expect(list[0].title).toBe('Сокращенный: Работы на высоте');
    expect(list[0].vid).toBe('Работы на высоте');
  });

  it('capitalizeFirstLetter uppercases first letter in Russian text', () => {
    expect(AktUtils.capitalizeFirstLetter('не проведён инструктаж')).toBe('Не проведён инструктаж');
    expect(AktUtils.capitalizeFirstLetter('  иванов')).toBe('  Иванов');
    expect(AktUtils.capitalizeFirstLetter('Уже с заглавной')).toBe('Уже с заглавной');
    expect(AktUtils.capitalizeFirstLetter('123abc')).toBe('123abc');
    expect(AktUtils.capitalizeFirstLetter('')).toBe('');
  });

  it('lowercaseFirstLetter lowercases first letter in Russian text', () => {
    expect(AktUtils.lowercaseFirstLetter('Начальник участка')).toBe('начальник участка');
    expect(AktUtils.lowercaseFirstLetter('  Главный инженер')).toBe('  главный инженер');
    expect(AktUtils.lowercaseFirstLetter('уже с маленькой')).toBe('уже с маленькой');
    expect(AktUtils.lowercaseFirstLetter('123abc')).toBe('123abc');
    expect(AktUtils.lowercaseFirstLetter('')).toBe('');
  });

  it('computeConclusionDatesFromInspection matches iOS (+1 month, +7 days)', () => {
    const inspection = '2026-03-09T12:00:00.000Z';
    const dates = AktUtils.computeConclusionDatesFromInspection(inspection);
    expect(AktUtils.toDateInputValue(dates.actustranenDate)).toBe('2026-04-09');
    expect(AktUtils.toDateInputValue(dates.actPredostavlenDate)).toBe('2026-04-09');
    expect(AktUtils.toDateInputValue(dates.actUtverzdenDate)).toBe('2026-03-16');
  });

  it('computeConclusionDatesFromInspection shifts weekend dates to previous workday', () => {
    const inspection = '2026-02-07T12:00:00.000Z';
    const dates = AktUtils.computeConclusionDatesFromInspection(inspection);
    expect(AktUtils.toDateInputValue(dates.actustranenDate)).toBe('2026-03-06');
    expect(AktUtils.toDateInputValue(dates.actPredostavlenDate)).toBe('2026-03-06');
    expect(AktUtils.toDateInputValue(dates.actUtverzdenDate)).toBe('2026-02-13');
  });

  it('applyInspectionDateChange recalculates all dates when inspection day changes', () => {
    const akt = {
      date: '2026-01-10T12:00:00.000Z',
      actustranenDate: '2026-05-01T12:00:00.000Z',
      actPredostavlenDate: '2026-05-01T12:00:00.000Z',
      actUtverzdenDate: '2026-01-20T12:00:00.000Z',
      conclusionDatesManual: { elim: true, pred: true, utver: true },
      conclusionDatesInspectionBasis: '2026-01-10T12:00:00.000Z',
    };
    AktUtils.applyInspectionDateChange(akt, '2026-02-01T12:00:00.000Z');
    expect(AktUtils.toDateInputValue(akt.actustranenDate)).toBe('2026-02-27');
    expect(AktUtils.toDateInputValue(akt.actPredostavlenDate)).toBe('2026-02-27');
    expect(AktUtils.toDateInputValue(akt.actUtverzdenDate)).toBe('2026-02-06');
    expect(akt.conclusionDatesManual).toEqual({ elim: false, pred: false, utver: false });
  });

  it('applyInspectionDateChange preserves manual dates when inspection day unchanged', () => {
    const akt = {
      date: '2026-01-10T12:00:00.000Z',
      actustranenDate: '2026-05-01T12:00:00.000Z',
      actPredostavlenDate: '2026-05-01T12:00:00.000Z',
      actUtverzdenDate: '2026-01-20T12:00:00.000Z',
      conclusionDatesManual: { elim: true, pred: true, utver: true },
      conclusionDatesInspectionBasis: '2026-01-10T12:00:00.000Z',
    };
    AktUtils.applyInspectionDateChange(akt, '2026-01-10T15:00:00.000Z');
    expect(AktUtils.toDateInputValue(akt.actustranenDate)).toBe('2026-05-01');
    expect(AktUtils.toDateInputValue(akt.actPredostavlenDate)).toBe('2026-05-01');
    expect(AktUtils.toDateInputValue(akt.actUtverzdenDate)).toBe('2026-01-20');
    expect(akt.conclusionDatesManual).toEqual({ elim: true, pred: true, utver: true });
  });

  it('ensureConclusionDateTracking preserves legacy acts without manual flags', () => {
    const akt = {
      date: '2026-06-01T12:00:00.000Z',
      actustranenDate: '2026-08-01T12:00:00.000Z',
      actPredostavlenDate: '2026-08-01T12:00:00.000Z',
      actUtverzdenDate: '2026-06-10T12:00:00.000Z',
    };
    AktUtils.ensureConclusionDateTracking(akt);
    expect(akt.conclusionDatesInspectionBasis).toBe('2026-06-01T12:00:00.000Z');
    expect(akt.conclusionDatesManual).toEqual({ elim: true, pred: true, utver: true });
    AktUtils.applyInspectionDateChange(akt, '2026-06-01T12:00:00.000Z');
    expect(AktUtils.toDateInputValue(akt.actustranenDate)).toBe('2026-08-01');
  });

  it('stripSurroundingQuotes removes paired and lone edge quotes', () => {
    expect(AktUtils.stripSurroundingQuotes('«Котельная №2»')).toBe('Котельная №2');
    expect(AktUtils.stripSurroundingQuotes('"Котельная №2"')).toBe('Котельная №2');
    expect(AktUtils.stripSurroundingQuotes('«Котельная №2')).toBe('Котельная №2');
    expect(AktUtils.stripSurroundingQuotes('Котельная №2»')).toBe('Котельная №2');
  });

  it('createEmptyDraft sets iOS-style conclusion dates', () => {
    const draft = AktUtils.createEmptyDraft({ akts: [], organizations: [] });
    expect(draft.conclusionDatesManual).toEqual({ elim: false, pred: false, utver: false });
    expect(draft.conclusionDatesInspectionBasis).toBe(draft.date);
    const expected = AktUtils.computeConclusionDatesFromInspection(draft.date);
    expect(AktUtils.toDateInputValue(draft.actustranenDate)).toBe(
      AktUtils.toDateInputValue(expected.actustranenDate)
    );
    expect(AktUtils.toDateInputValue(draft.actPredostavlenDate)).toBe(
      AktUtils.toDateInputValue(expected.actPredostavlenDate)
    );
    expect(AktUtils.toDateInputValue(draft.actUtverzdenDate)).toBe(
      AktUtils.toDateInputValue(expected.actUtverzdenDate)
    );
  });
});
