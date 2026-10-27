import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { countries, countryOptions } from '../../[core]/esx_identity/web/src/countries.js';
import { validateIdentity, toPayload } from '../../[core]/esx_identity/web/src/identity.js';
import { createTranslator, supportedLocales } from '../../[core]/esx_identity/web/src/i18n.js';
const form = { firstname: ' Test ', lastname: 'Name', dob: '1990-01-01', gender: 'm', height: 180, nationality: 'Spain' };
test('UI payload carries the canonical country without changing existing fields', () => {
  assert.deepEqual(validateIdentity(form), {});
  assert.deepEqual(toPayload(form), { firstname: 'Test', lastname: 'Name', dateofbirth: '01/01/1990', sex: 'm', height: 180, nationality: 'Spain' });
});
test('missing or tampered nationality blocks submission', () => {
  for (const nationality of [undefined, '', {}, 'Atlantis', 'spain']) assert(validateIdentity({ ...form, nationality }).nationality);
});
test('every country is selectable and identifiers remain unique', () => {
  assert.equal(new Set(countries.map(({ value }) => value)).size, countries.length);
  assert(countries.length >= 190);
  for (const country of countries) assert.equal(validateIdentity({ ...form, nationality: country.value }).nationality, undefined);
});
test('all UI languages have nationality labels, errors and six-field progress', () => {
  for (const { code } of supportedLocales) {
    const t = createTranslator(code);
    for (const key of ['nationality', 'nationalityPlaceholder', 'nationalityRequired']) assert.notEqual(t(key), key);
    assert(t('completed', { completed: 6, total: 6 }).includes('6'));
    const options = countryOptions(code);
    assert.equal(options.length, countries.length);
    assert.deepEqual(new Set(options.map(({ value }) => value)), new Set(countries.map(({ value }) => value)));
  }
  assert.equal(countryOptions('es').find(({ value }) => value === 'Spain').label, 'España');
});
test('SQL catalog prepares nationality during core startup', () => {
  const catalog = JSON.parse(fs.readFileSync(new URL('../../[core]/esx_lib/imports/catalog/data.json', import.meta.url)));
  assert(catalog.resources.es_extended.columns.some(({ table, name }) => table === 'users' && name === 'nationality'));
  assert(catalog.schemas.users.fields.includes('nationality'));
});
