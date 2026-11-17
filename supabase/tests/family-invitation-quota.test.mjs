import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const migration = readFileSync(
  new URL("../migrations/202611170001_atomic_family_invite_limit.sql", import.meta.url),
  "utf8",
);
const handler = readFileSync(
  new URL("../functions/family-invitations/index.ts", import.meta.url),
  "utf8",
);
const schemaMigration = readFileSync(
  new URL("../migrations/202606120001_dashboard_mvp.sql", import.meta.url),
  "utf8",
);

test("family invitation quota serializes the count and insert per family", () => {
  const lockPosition = migration.indexOf("pg_advisory_xact_lock");
  const countPosition = migration.indexOf("select count(*)");
  const insertPosition = migration.indexOf("insert into public.family_invites");

  assert.ok(lockPosition >= 0);
  assert.ok(countPosition > lockPosition);
  assert.ok(insertPosition > countPosition);
  assert.match(migration, /if invite_count >= 5 then/i);
  assert.match(migration, /message = 'family_invite_rate_limit'/i);
  assert.match(migration, /role = 'owner'/i);
  assert.match(migration, /revoke all on function public\.create_family_invite/i);
  assert.match(migration, /to service_role;/i);
});

test("family invitation endpoint creates invites through the atomic RPC", () => {
  const sendStart = handler.indexOf("async function sendInvitation(");
  const acceptStart = handler.indexOf("async function acceptInvitation(", sendStart);
  const sendInvitation = handler.slice(sendStart, acceptStart);

  assert.match(sendInvitation, /rpc\(\s*'create_family_invite'/);
  assert.match(sendInvitation, /family_invite_rate_limit/);
  assert.match(sendInvitation, /jsonResponse\(429/);
  assert.doesNotMatch(sendInvitation, /\.insert\(/);
  assert.doesNotMatch(sendInvitation, /\.select\('id', \{ count: 'exact'/);
});

test("family invitation consumption locks rows and rejects expired or reused tokens", () => {
  const consumeStart = schemaMigration.indexOf(
    "create or replace function public.consume_family_invite(",
  );
  const consumeEnd = schemaMigration.indexOf(
    "alter table public.profiles enable row level security;",
    consumeStart,
  );
  const consumeFunction = schemaMigration.slice(consumeStart, consumeEnd);

  assert.ok(consumeStart >= 0);
  assert.ok(consumeEnd > consumeStart);
  assert.match(consumeFunction, /accepted_at is null/i);
  assert.match(consumeFunction, /expires_at > now\(\)/i);
  assert.match(consumeFunction, /for update/i);
  assert.match(consumeFunction, /update public\.family_invites[\s\S]*accepted_at = now\(\)/i);
  assert.match(handler, /rpc\(\s*'consume_family_invite'/);
});
