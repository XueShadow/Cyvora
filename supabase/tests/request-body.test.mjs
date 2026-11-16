import assert from "node:assert/strict";
import test from "node:test";
import {
  readJsonObjectBody,
  readLimitedBody,
} from "../functions/_shared/request-body.ts";

test("bounded JSON body parsing accepts object payloads", async () => {
  const request = new Request("https://example.test", {
    method: "POST",
    body: JSON.stringify({ action: "invite" }),
  });

  assert.deepEqual(await readJsonObjectBody(request, 1024), {
    ok: true,
    value: { action: "invite" },
  });
});

test("bounded JSON body parsing rejects invalid and non-object JSON", async () => {
  for (const body of ["{", "null", "[]", '"text"']) {
    const result = await readJsonObjectBody(
      new Request("https://example.test", { method: "POST", body }),
      1024,
    );
    assert.equal(result.ok, false, body);
    if (!result.ok) assert.equal(result.status, 400, body);
  }
});

test("bounded JSON body parsing rejects oversized declared and streamed bodies", async () => {
  const declaredOversize = await readLimitedBody(
    new Request("https://example.test", {
      method: "POST",
      headers: { "Content-Length": "20" },
      body: "{}",
    }),
    16,
  );
  assert.deepEqual(declaredOversize, { tooLarge: true });

  const streamedOversize = await readJsonObjectBody(
    new Request("https://example.test", {
      method: "POST",
      body: "x".repeat(17),
    }),
    16,
  );
  assert.deepEqual(streamedOversize, {
    ok: false,
    status: 413,
    error: "Request body is too large.",
  });
});
