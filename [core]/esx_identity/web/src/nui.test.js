import test from "node:test";
import assert from "node:assert/strict";

test("NUI supports renamed resources and the current context protocol", async () => {
    globalThis.window = { GetParentResourceName: () => "identity_custom", location: { protocol: "https:", search: "?preview=1" } };
    const { postNui, isPreview } = await import("./nui.js?game");
    assert.equal(isPreview, false);
    const realFetch = globalThis.fetch;
    try {
        globalThis.fetch = async (url, options) => {
            assert.equal(url, "https://identity_custom/register");
            assert.equal(options.method, "POST");
            assert.deepEqual(JSON.parse(options.body), { firstname: "Santiago" });
            return { ok: true, json: async () => ({ ok: false, error: "Rejected" }) };
        };
        assert.deepEqual(await postNui("register", { firstname: "Santiago" }), { ok: false, error: "Rejected" });
        window.location.protocol = "http:";
        globalThis.fetch = async (url) => {
            assert.equal(url, "http://identity_custom/ready");
            return { ok: true, json: async () => 1 };
        };
        assert.equal(await postNui("ready"), 1);
        globalThis.fetch = async () => ({ ok: false });
        await assert.rejects(postNui("register"), /No se pudo conectar/);
    } finally {
        globalThis.fetch = realFetch;
    }
});

test("browser preview never sends a registration request", async () => {
    globalThis.window = { location: { protocol: "http:", search: "?preview=1" } };
    const { postNui, isPreview } = await import("./nui.js?preview");
    assert.equal(isPreview, true);
    const realFetch = globalThis.fetch;
    try {
        globalThis.fetch = () => {
            throw new Error("Preview must not fetch");
        };
        assert.deepEqual(await postNui("register"), { ok: true });
    } finally {
        globalThis.fetch = realFetch;
    }
});
