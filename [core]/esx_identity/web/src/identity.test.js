import test from "node:test";
import assert from "node:assert/strict";
import { dateLabel, defaults, validateIdentity, toPayload } from "./identity.js";

const settings = { ...defaults, currentYear: 2026 };
const valid = { firstname: "Santiago", lastname: "Rivera", dob: "2000-02-29", gender: "m", height: 175 };
test("accepts a real leap date and builds the ESX wire format", () => {
    assert.deepEqual(validateIdentity(valid, settings), {});
    assert.equal(dateLabel(valid.dob, "DD/MM/YYYY"), "29/02/2000");
    assert.equal(dateLabel(valid.dob, "MM/DD/YYYY"), "02/29/2000");
    assert.equal(dateLabel(valid.dob, "YYYY/MM/DD"), "2000/02/29");
    assert.deepEqual(toPayload({ ...valid, firstname: " Santiago ", height: "180" }), {
        firstname: "Santiago",
        lastname: "Rivera",
        dateofbirth: "29/02/2000",
        sex: "m",
        height: 180,
    });
});
test("rejects impossible dates, future dates and years outside ESX bounds", () => {
    for (const dob of ["", "2001-02-29", "2000-04-31", "2027-01-01", "2009-01-01", "1925-12-31"]) {
        assert.ok(validateIdentity({ ...valid, dob }, settings).dob, dob);
    }
    for (const dob of ["1926-01-01", "2008-12-31"]) assert.equal(validateIdentity({ ...valid, dob }, settings).dob, undefined);
});
test("uses configured height bounds and rejects non-numeric values", () => {
    for (const height of ["", "abc", 119, 221, Infinity]) assert.ok(validateIdentity({ ...valid, height }, settings).height);
    for (const height of [120, 220]) assert.equal(validateIdentity({ ...valid, height }, settings).height, undefined);
    assert.ok(validateIdentity(valid, { ...settings, minHeight: 180 }).height);
});
test("checks names using the server byte-length limit and requires sex", () => {
    for (const firstname of [" ", "123", "<script>", "a".repeat(20), "á".repeat(10)]) assert.ok(validateIdentity({ ...valid, firstname }, settings).firstname);
    assert.equal(validateIdentity({ ...valid, firstname: "José", lastname: "De la Cruz" }, settings).firstname, undefined);
    assert.ok(validateIdentity({ ...valid, gender: "" }, settings).gender);
    assert.equal(validateIdentity({ ...valid, gender: "f" }, settings).gender, undefined);
});
