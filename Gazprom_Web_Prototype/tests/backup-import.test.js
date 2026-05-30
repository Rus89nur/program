import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';
import { describe, it, expect, beforeAll } from 'vitest';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function loadBackup() {
  const ctx = {
    console,
    Date,
    Math,
    JSON,
    parseInt,
    String,
    Array,
    Error,
    Promise,
    AktUtils: null,
    GazpromStore: {
      get: async () => null,
      set: async () => {},
      hasData: () => false,
    },
  };
  vm.createContext(ctx);
  vm.runInContext(readFileSync(join(root, 'js/akt-utils.js'), 'utf8'), ctx);
  vm.runInContext(readFileSync(join(root, 'js/backup-import.js'), 'utf8'), ctx);
  return ctx;
}

describe('GazpromBackup', () => {
  let GazpromBackup;
  beforeAll(() => {
    GazpromBackup = loadBackup().GazpromBackup;
  });

  it('normalizeBackup requires akts array', () => {
    expect(() => GazpromBackup.normalizeBackup({})).toThrow(/актов/);
  });

  it('normalizeBackup preserves structure', () => {
    const raw = {
      version: '1.2',
      akts: [{ id: '1', number: '1', violations: [{ photo: ['abc123'] }] }],
      organizations: [],
      trash: [],
    };
    const out = GazpromBackup.normalizeBackup(raw);
    expect(out.akts).toHaveLength(1);
    expect(out.akts[0].violations[0].photo[0]).toBe('abc123');
    expect(out.version).toBe('1.2');
  });

  it('getStats counts photos', () => {
    const backup = {
      version: '1.0',
      timestamp: new Date().toISOString(),
      akts: [{ violations: [{ photo: ['a', 'b'] }] }],
      trash: [],
      comissionPeople: [],
      organizations: [],
      objects: [],
      predstavitely: [],
      scheduleItems: [],
      violationEliminations: [],
    };
    expect(GazpromBackup.getStats(backup).photos).toBe(2);
  });

  it('round-trip demo file parses', () => {
    const demo = JSON.parse(
      readFileSync(join(root, 'assets/sample-demo.gazprombackup'), 'utf8')
    );
    const normalized = GazpromBackup.normalizeBackup(demo);
    expect(normalized.akts.length).toBeGreaterThan(0);
    const stats = GazpromBackup.getStats(normalized);
    expect(stats.organizations).toBeGreaterThan(0);
  });
});
