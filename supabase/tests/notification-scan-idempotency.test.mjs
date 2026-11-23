import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const migration = readFileSync(
  new URL("../migrations/202611170005_notification_scan_idempotency.sql", import.meta.url),
  "utf8",
);
const initialLeaseFix = readFileSync(
  new URL("../migrations/202611170007_notification_scan_reservation_initial_lease.sql", import.meta.url),
  "utf8",
);
const handler = readFileSync(
  new URL("../functions/scam-intelligence/index.ts", import.meta.url),
  "utf8",
);
const listener = readFileSync(
  new URL("../../flutter/android/app/src/main/kotlin/com/example/cyvora_mobile/MessageNotificationListenerService.kt", import.meta.url),
  "utf8",
);
const storage = readFileSync(
  new URL("../../flutter/android/app/src/main/kotlin/com/example/cyvora_mobile/NotificationQueueStorage.kt", import.meta.url),
  "utf8",
);
const queue = readFileSync(
  new URL("../../flutter/lib/core/permissions/message_notification_service.dart", import.meta.url),
  "utf8",
);
const repository = readFileSync(
  new URL("../../flutter/lib/dashboard/dashboard_repository.dart", import.meta.url),
  "utf8",
);
const dashboard = readFileSync(
  new URL("../../flutter/lib/dashboard/dashboard_screen.dart", import.meta.url),
  "utf8",
);

test("notification reservations bind a user-scoped request key to a content fingerprint", () => {
  assert.match(migration, /primary key \(user_id, request_id\)/i);
  assert.match(migration, /request_fingerprint text not null/i);
  assert.match(migration, /for update/i);
  assert.match(migration, /lease_expires_at > now\(\)/i);
  assert.match(migration, /request_fingerprint <> target_request_fingerprint/i);
  assert.match(migration, /pg_cron is required to enforce notification scan idempotency retention/i);
  assert.match(migration, /cron\.schedule\([\s\S]*delete-expired-notification-scan-idempotency/i);
});

test("the forward migration returns the newly inserted reservation lease", () => {
  const start = initialLeaseFix.indexOf(
    "create or replace function public.reserve_notification_scan(",
  );
  const end = initialLeaseFix.indexOf(
    "revoke all on function public.reserve_notification_scan",
    start,
  );
  const reservation = initialLeaseFix.slice(start, end);

  assert.ok(start >= 0);
  assert.ok(end > start);
  assert.match(
    reservation,
    /on conflict \(user_id, request_id\) do nothing\s+returning \* into existing;/i,
  );
  assert.match(
    reservation,
    /if found then[\s\S]*'status', 'reserved'[\s\S]*'lease_token', existing\.lease_token/i,
  );
});

test("recording a reserved notification scan saves the result atomically", () => {
  const start = migration.indexOf(
    "create or replace function public.record_notification_threat_scan(",
  );
  const end = migration.indexOf(
    "create or replace function public.delete_expired_notification_scan_idempotency()",
    start,
  );
  const completion = migration.slice(start, end);

  assert.ok(start >= 0);
  assert.ok(end > start);
  assert.match(completion, /for update/i);
  assert.match(completion, /public\.record_threat_scan\(/i);
  assert.match(completion, /status = 'completed'[\s\S]*response = response_body/i);
  assert.match(completion, /if reservation\.status = 'completed'[\s\S]*return reservation\.scan_record_id/i);
  assert.match(migration, /before delete on public\.scan_records/i);
  assert.match(migration, /status = 'deleted'[\s\S]*response = null/i);
});

test("the Edge Function reserves before quota and replays completed results", () => {
  const reservation = handler.indexOf('admin.rpc("reserve_notification_scan"');
  const scanQuota = handler.indexOf('"consume_scam_intelligence_quota"', reservation);
  assert.ok(reservation >= 0);
  assert.ok(scanQuota > reservation);
  assert.match(handler, /body\.notification_idempotency_key/);
  assert.match(handler, /if \(data\.status === "completed"\)[\s\S]*return jsonResponse\(200, data\.response\)/);
  assert.match(handler, /data\.status === "deleted"[\s\S]*jsonResponse\(410/);
  assert.match(handler, /admin\.rpc\("record_notification_threat_scan"/);
  assert.match(handler, /finally \{[\s\S]*releaseNotificationScan/);
  assert.match(repository, /'notification_idempotency_key': notificationIdempotencyKey/);
  assert.match(dashboard, /notificationIdempotencyKey != null && error\.status == 410/);
});

test("notification updates receive a new key while duplicate callbacks remain stable", () => {
  assert.match(listener, /statusBarNotification\.key[\s\S]*statusBarNotification\.postTime/);
  assert.match(storage, /existingGroupId != notificationGroupId[\s\S]*item\.optString\("id"\) != notificationGroupId/);
  assert.match(queue, /analyze\(content, notification\.id\)/);
});
