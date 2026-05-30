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
  vm.runInContext(readFileSync(join(root, 'js/akt-utils.js'), 'utf8'), ctx);
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
});
