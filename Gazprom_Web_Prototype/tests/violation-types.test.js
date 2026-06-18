import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';
import { describe, it, expect, beforeAll } from 'vitest';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function loadModules() {
  const ctx = {
    console,
    AktUtils: {
      uuid: (() => {
        let n = 0;
        return () => `id-${++n}`;
      })(),
    },
    ViolationTemplates: {
      VIOLATION_TYPES: ['Пожарная безопасность', 'Пожароопасные работы', 'Электробезопасность'],
      MAPPING_SEED_TYPES: ['Новый вид Smart Forms', 'Ещё один новый вид'],
    },
  };
  vm.createContext(ctx);
  const expose = '\nthis.ViolationTypes = ViolationTypes;\n';
  vm.runInContext(readFileSync(join(root, 'js/violation-types.js'), 'utf8') + expose, ctx);
  return ctx.ViolationTypes;
}

describe('ViolationTypes', () => {
  let VT;

  beforeAll(() => {
    VT = loadModules();
  });

  it('ensureCatalog начинает с пустого классификатора', () => {
    const catalog = { akts: [] };
    VT.ensureCatalog(catalog);
    expect(catalog.violationTypes.length).toBe(0);
    expect(VT.getActiveTypes(catalog).length).toBe(0);
    expect(catalog.violationTypesPurgedV2).toBe(true);
  });

  it('purgeBuiltinDefaults удаляет зашитые виды один раз', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: '1', title: 'Пожарная безопасность', status: 'active' },
        { id: '2', title: 'Мой вид', status: 'active' },
      ],
      typeMappings: {},
    };
    VT.purgeBuiltinDefaults(catalog);
    expect(catalog.violationTypes).toHaveLength(1);
    expect(catalog.violationTypes[0].title).toBe('Мой вид');
  });

  it('purgeBuiltinRegistryVids очищает устаревшие виды в реестре', () => {
    const catalog = {
      akts: [],
      violationTypes: [],
      violationRegistry: [
        { id: 'r1', title: 'Тест', vid: 'Пожарная безопасность' },
        { id: 'r2', title: 'Тест 2', vid: 'Мой новый вид' },
      ],
      typeMappings: {},
    };
    expect(VT.purgeBuiltinRegistryVids(catalog)).toBe(true);
    expect(catalog.violationRegistry[0].vid).toBe('');
    expect(catalog.violationRegistry[1].vid).toBe('Мой новый вид');
  });

  it('purgeBuiltinRegistryVids не удаляет новые Smart Forms виды из реестра', () => {
    const seed = 'Нарушение требований пожарной безопасности';
    const catalog = {
      akts: [],
      violationTypes: [{ id: 'n1', title: seed, status: 'active' }],
      violationRegistry: [{ id: 'r1', title: 'Тест', vid: seed }],
      typeMappings: {},
    };
    expect(VT.purgeBuiltinRegistryVids(catalog)).toBe(false);
    expect(catalog.violationRegistry[0].vid).toBe(seed);
  });

  it('ensureCatalog возвращает seed-виды на вкладку «Сопоставить» после перепurge', () => {
    const seeds = ['Новый вид Smart Forms', 'Ещё один новый вид'];
    const catalog = {
      akts: [],
      violationTypes: [],
      violationRegistry: [],
      typeMappings: {},
      violationTypesPurgedV2: true,
      dismissedMappingSeeds: [...seeds],
    };
    VT.ensureCatalog(catalog);
    expect(VT.getPendingTypes(catalog).some((t) => seeds.includes(t.title))).toBe(true);
  });

  it('ensureCatalog не переполняет стек при реестре со встроенными видами (импорт бэкапа)', () => {
    const catalog = {
      akts: [{ violations: [{ vid: 'Старый вид' }] }],
      violationRegistry: [{ id: 'r1', title: 'Тест', vid: 'Пожарная безопасность' }],
      violationTypes: [],
      typeMappings: {},
    };
    expect(() => VT.ensureCatalog(catalog)).not.toThrow();
    expect(catalog.violationRegistry[0].vid).toBe('');
    expect(catalog.registryBuiltinVidsPurgedV2).toBe(true);
  });

  it('getVidSelectTitles не подтягивает все виды из реестра', () => {
    const catalog = {
      akts: [],
      violationTypes: [{ id: '1', title: 'Новый вид', status: 'active' }],
      violationRegistry: [{ id: 'r1', title: 'Тест', vid: 'Пожарная безопасность' }],
      typeMappings: {},
      violationTypesPurgedV2: true,
    };
    const titles = VT.getVidSelectTitles(catalog, '');
    expect(titles).toEqual(['Новый вид']);
  });

  it('getVidSelectTitles включает ожидающие привязки (pending)', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: '1', title: 'Активный вид', status: 'active' },
        { id: '2', title: 'Новый Smart Forms', status: 'pending' },
      ],
      typeMappings: {},
      violationTypesPurgedV2: true,
    };
    const titles = VT.getVidSelectTitles(catalog, '');
    expect(titles).toEqual(['Активный вид', 'Новый Smart Forms']);
  });

  it('getVidSelectTitles включает сохранённый seed-вид при редактировании', () => {
    const seed = 'Нарушение требований пожарной безопасности';
    const catalog = {
      akts: [],
      violationTypes: [{ id: 'p1', title: seed, status: 'pending' }],
      typeMappings: {},
      violationTypesPurgedV2: true,
      mappingSeedsRestoredV3: true,
    };
    const titles = VT.getVidSelectTitles(catalog, seed);
    expect(titles).toContain(seed);
  });

  it('getVidSelectTitles включает resolved vid вне активного списка', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'a1', title: 'Пожароопасные работы', status: 'archived' },
        { id: 'a2', title: 'Нарушение требований пожарной безопасности', status: 'active' },
      ],
      typeMappings: {},
    };
    const titles = VT.getVidSelectTitles(catalog, 'Пожароопасные работы');
    expect(titles[0]).toBe('Пожароопасные работы');
    expect(titles).toContain('Нарушение требований пожарной безопасности');
  });

  it('resolveVid следует цепочке replacedBy', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'a1', title: 'Пожароопасные работы', status: 'archived', replacedBy: 'a2' },
        { id: 'a2', title: 'Пожарная безопасность', status: 'active' },
      ],
      typeMappings: { a1: 'a2' },
    };
    expect(VT.resolveVid(catalog, 'Пожароопасные работы')).toBe('Пожарная безопасность');
  });

  it('syncOrphanVids добавляет неизвестные виды из актов в архив', () => {
    const catalog = {
      akts: [{ violations: [{ vid: 'Старый вид из акта' }] }],
      violationTypes: [{ id: 'x', title: 'Пожарная безопасность', status: 'active' }],
      typeMappings: {},
    };
    VT.ensureCatalog(catalog);
    const archived = VT.getArchivedTypes(catalog);
    expect(archived.some((t) => t.title === 'Старый вид из акта')).toBe(true);
  });

  it('migrateStoredVids переписывает vid в актах', () => {
    const catalog = {
      akts: [{ violations: [{ vid: 'Пожароопасные работы' }] }],
      violationRegistry: [{ vid: 'Пожароопасные работы' }],
      violationTypes: [
        { id: 'a1', title: 'Пожароопасные работы', status: 'archived', replacedBy: 'a2' },
        { id: 'a2', title: 'Пожарная безопасность', status: 'active' },
      ],
      typeMappings: { a1: 'a2' },
    };
    const n = VT.migrateStoredVids(catalog);
    expect(n).toBe(2);
    expect(catalog.akts[0].violations[0].vid).toBe('Пожарная безопасность');
  });

  it('buildKindStats группирует по resolved vid', () => {
    const catalog = {
      akts: [
        { violations: [{ vid: 'Пожароопасные работы' }, { vid: 'Пожарная безопасность' }] },
      ],
      violationTypes: [
        { id: 'a1', title: 'Пожароопасные работы', status: 'archived', replacedBy: 'a2' },
        { id: 'a2', title: 'Пожарная безопасность', status: 'active' },
      ],
      typeMappings: { a1: 'a2' },
    };
    const stats = VT.buildKindStats(catalog, { resolve: true });
    expect(stats.get('Пожарная безопасность')).toBe(2);
  });

  it('pending-вид активируется при setMapping', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'a1', title: 'Старый', status: 'archived' },
        { id: 'p1', title: 'Новый', status: 'pending' },
      ],
      typeMappings: {},
    };
    VT.setMapping(catalog, 'a1', 'p1');
    expect(VT.findById(catalog, 'p1').status).toBe('active');
    expect(VT.getActiveTypes(catalog).some((t) => t.title === 'Новый')).toBe(true);
  });

  it('deleteType удаляет неиспользуемый вид', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'a1', title: 'Лишний уникальный вид', status: 'pending' },
      ],
      typeMappings: {},
    };
    VT.ensureCatalog(catalog);
    const before = catalog.violationTypes.length;
    const r = VT.deleteType(catalog, 'a1');
    expect(r.ok).toBe(true);
    expect(catalog.violationTypes).toHaveLength(before - 1);
  });

  it('deleteType не восстанавливает удалённый seed-вид', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'seed1', title: 'Новый вид Smart Forms', status: 'pending' },
      ],
      typeMappings: {},
      dismissedMappingSeeds: [],
    };
    VT.ensureCatalog(catalog);
    const r = VT.deleteType(catalog, 'seed1');
    expect(r.ok).toBe(true);
    VT.ensureCatalog(catalog);
    expect(VT.getPendingTypes(catalog).some((t) => t.title === 'Новый вид Smart Forms')).toBe(false);
    expect(catalog.dismissedMappingSeeds).toContain('Новый вид Smart Forms');
  });

  it('несколько архивных видов могут указывать на один новый', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'old1', title: 'Старый 1', status: 'archived' },
        { id: 'old2', title: 'Старый 2', status: 'archived' },
        { id: 'new1', title: 'Новый', status: 'pending' },
      ],
      typeMappings: {},
    };
    VT.setMapping(catalog, 'old1', 'new1');
    VT.setMapping(catalog, 'old2', 'new1');
    expect(VT.countMappedFrom(catalog, 'new1')).toBe(2);
    expect(VT.findById(catalog, 'new1').status).toBe('active');
  });

  it('activateStandaloneType активирует уникальный вид без предшественника', () => {
    const catalog = {
      akts: [],
      violationTypes: [{ id: 'p1', title: 'Уникальный', status: 'pending' }],
      typeMappings: {},
    };
    expect(VT.activateStandaloneType(catalog, 'p1')).toBe(true);
    expect(VT.findById(catalog, 'p1').status).toBe('active');
    expect(VT.findById(catalog, 'p1').standalone).toBe(true);
  });

  it('restoreType возвращает вид из архива в активные', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'a1', title: 'Старый', status: 'archived', replacedBy: 'a2' },
        { id: 'a2', title: 'Новый', status: 'active' },
      ],
      typeMappings: { a1: 'a2' },
    };
    const r = VT.restoreType(catalog, 'a1');
    expect(r.ok).toBe(true);
    expect(VT.findById(catalog, 'a1').status).toBe('active');
    expect(VT.getMappings(catalog).a1).toBeUndefined();
  });
});
