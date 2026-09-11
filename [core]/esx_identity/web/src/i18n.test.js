import test from "node:test";
import assert from "node:assert/strict";
import { createTranslator, normalizeLocale, supportedLocales } from "./i18n.js";

test("normalizes configured ESX locales and falls back to English", () => {
    assert.equal(normalizeLocale("es_ES"), "es");
    assert.equal(normalizeLocale("pt-BR"), "pt");
    assert.equal(normalizeLocale("unknown"), "en");
});

test("translates core identity labels with interpolation", () => {
    const es = createTranslator("es");
    const fr = createTranslator("fr");
    assert.equal(es("submit"), "Comenzar mi historia");
    assert.equal(fr("ageHint", { maxAge: 100 }), "PERSONNAGE DE 18 A 100 ANS");
    assert.equal(createTranslator("zz")("submit"), "Start my story");
});

test("keeps every selectable locale renderable", () => {
    for (const locale of supportedLocales) {
        const translate = createTranslator(locale.code);
        assert.notEqual(translate("formTitle"), "formTitle", locale.code);
        assert.notEqual(translate(locale.labelKey), locale.labelKey, locale.code);
    }
});
