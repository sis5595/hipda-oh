// Synthetic secrets only. Exercise the production Asset Store adapter.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const source = fs.readFileSync(path.resolve(__dirname,
  '../../main/ets/data/local/FourD4yAccountSessionStore.ets'), 'utf8');
const records = new Map();
let addError = 0, removeError = 0, updates = 0;
const asset = {
  Tag: { ALIAS: 1, SECRET: 2, ACCESSIBILITY: 3, RETURN_TYPE: 4 },
  Accessibility: { DEVICE_UNLOCKED: 1 }, ReturnType: { ALL: 1 },
  add: async attributes => {
    if (addError) throw { code: addError };
    const key = Buffer.from(attributes.get(1)).toString();
    if (records.has(key)) throw { code: 24000003 };
    records.set(key, attributes.get(2));
  },
  update: async (query, replacement) => {
    updates++;
    records.set(Buffer.from(query.get(1)).toString(), replacement.get(2));
  },
  query: async query => {
    const value = records.get(Buffer.from(query.get(1)).toString());
    return value ? [new Map([[2, value]])] : [];
  },
  remove: async query => {
    if (removeError) throw { code: removeError };
    if (!records.delete(Buffer.from(query.get(1)).toString())) throw { code: 24000002 };
  }
};
const util = {
  TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value); } },
  TextDecoder: { create: encoding => ({ decodeToString: value => new TextDecoder(encoding).decode(value) }) }
};
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, { exports: exportsObject, require: name => {
  if (name === '@kit.AssetStoreKit') return { asset };
  if (name === '@kit.ArkTS') return { util };
  throw new Error(`Unexpected import ${name}`);
}, Uint8Array });
const store = exportsObject.FourD4yAccountSessionStore;
(async () => {
  const id = 'account_test_1';
  for (const length of [1, 900, 901, 1024]) {
    const value = 'x'.repeat(length);
    assert.equal(await store.save(id, value), true);
    assert.equal(await store.load(id), value);
  }
  assert.equal(await store.save(id, 'x'.repeat(1025)), false);
  assert.equal(await store.save(id, '中'.repeat(342)), false);
  assert.equal(await store.save(id, ''), false);
  assert.equal(await store.save('../invalid', 'x'), false);
  const before = updates;
  for (const code of [24000001, 24000005, 24000008]) {
    addError = code;
    assert.equal(await store.save(id, 'replacement'), false);
    removeError = code;
    assert.equal(await store.remove(id), false);
  }
  assert.equal(updates, before, 'service failures must not cause blind update');
  removeError = 0;
  assert.equal(await store.remove(id), true);
  assert.equal(await store.remove(id), true, 'not found is idempotent success');
  assert.equal(await store.load(id), null);
  console.log('Account session storage regression passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
