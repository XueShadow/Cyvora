import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const migration = readFileSync(
  new URL("../migrations/202611230004_backend_hardening.sql", import.meta.url),
  "utf8",
);
const handler = readFileSync(
  new URL("../functions/scam-intelligence/index.ts", import.meta.url),
  "utf8",
);
const config = readFileSync(
  new URL("../config.toml", import.meta.url),
  "utf8",
);

test("Edge Functions require gateway JWT verification", () => {
  assert.match(config, /\[functions\.family-invitations\][\s\S]*verify_jwt = true/);
  assert.match(config, /\[functions\.scam-intelligence\][\s\S]*verify_jwt = true/);
});

test("scan retention supports only 30, 60, and 90 days", () => {
  assert.match(migration, /scan_history_retention_days in \(30, 60, 90\)/);
  assert.match(migration, /make_interval\(days => us\.scan_history_retention_days\)/);
});

test("cloud requests have an atomic 10-per-10-minute window", () => {
  assert.match(migration, /create table if not exists public\.edge_request_windows/);
  assert.match(migration, /consume_edge_request_window/);
  assert.match(handler, /target_request_limit: 10/);
  assert.match(handler, /target_window_seconds: 600/);
});

test("account deletion action uses explicit confirmation and admin deletion", () => {
  assert.match(handler, /DELETE MY ACCOUNT/);
  assert.match(handler, /admin\.auth\.admin\.deleteUser\(user\.id\)/);
  assert.match(handler, /profile-avatars/);
});
