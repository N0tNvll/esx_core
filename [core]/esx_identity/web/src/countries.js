// SPDX-License-Identifier: GPL-3.0-only
import countries from "../../../esx_lib/imports/nationality/countries.json" with { type: "json" };

export { countries };

export function countryOptions(locale, list = countries) {
    let names;
    try { names = new Intl.DisplayNames([locale], { type: "region" }); } catch { /* Keep canonical labels. */ }
    return list.map(({ value, code }) => {
        let label = value;
        try { label = names?.of(code) || value; } catch { /* Unknown region identifiers keep their label. */ }
        return { value, label };
    }).sort((a, b) => a.label.localeCompare(b.label, locale));
}
