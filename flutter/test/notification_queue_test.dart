import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyvora_mobile/core/permissions/message_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final notification = PendingMessageNotification(
    id: 'notification-1',
    title: 'Bank notice',
    text: 'Verify your account now',
    packageName: 'example.bank',
    receivedAt: DateTime.fromMillisecondsSinceEpoch(1),
  );

  test('removes a notification only after analysis succeeds', () async {
    final events = <String>[];
    final removed = <String>[];
    var analysisSucceeded = false;
    final queue = PendingMessageNotificationQueue(
      remove: (id) async {
        expect(analysisSucceeded, isTrue);
        events.add('remove');
        removed.add(id);
      },
      markCompleted: (id) async {
        expect(analysisSucceeded, isTrue);
        events.add('complete');
      },
    );

    final outcome = await queue.scan(notification, (
      content,
      idempotencyKey,
    ) async {
      expect(content, notification.text);
      expect(idempotencyKey, notification.id);
      analysisSucceeded = true;
      return true;
    });

    expect(outcome, NotificationScanOutcome.completed);
    expect(removed, [notification.id]);
    expect(events, ['complete', 'remove']);
  });

  test('keeps failed notifications and allows retry', () async {
    final removed = <String>[];
    final completed = <String>[];
    var attempts = 0;
    final queue = PendingMessageNotificationQueue(
      remove: (id) async => removed.add(id),
      markCompleted: (id) async => completed.add(id),
    );

    final failed = await queue.scan(notification, (_, _) async {
      attempts++;
      return false;
    });
    expect(failed, NotificationScanOutcome.failed);
    expect(removed, isEmpty);
    expect(completed, isEmpty);

    final retried = await queue.scan(notification, (_, _) async {
      attempts++;
      return true;
    });
    expect(retried, NotificationScanOutcome.completed);
    expect(attempts, 2);
    expect(removed, [notification.id]);
    expect(completed, [notification.id]);
  });

  test(
    'prevents concurrent duplicate analysis for the same notification',
    () async {
      final removed = <String>[];
      final analysisResult = Completer<bool>();
      var attempts = 0;
      final queue = PendingMessageNotificationQueue(
        remove: (id) async => removed.add(id),
        markCompleted: (_) async {},
      );

      final first = queue.scan(notification, (_, _) {
        attempts++;
        return analysisResult.future;
      });
      final duplicate = await queue.scan(notification, (_, _) async {
        attempts++;
        return true;
      });

      expect(duplicate, NotificationScanOutcome.alreadyProcessing);
      expect(attempts, 1);
      expect(removed, isEmpty);

      analysisResult.complete(true);
      expect(await first, NotificationScanOutcome.completed);
      expect(removed, [notification.id]);
    },
  );

  test(
    'retries queue cleanup without re-running successful analysis',
    () async {
      var removalAttempts = 0;
      var completionMarks = 0;
      var analysisAttempts = 0;
      final queue = PendingMessageNotificationQueue(
        remove: (id) async {
          removalAttempts++;
          if (removalAttempts == 1) {
            throw StateError('temporary channel failure');
          }
        },
        markCompleted: (_) async {
          completionMarks++;
        },
      );

      await expectLater(
        queue.scan(notification, (_, _) async {
          analysisAttempts++;
          return true;
        }),
        throwsStateError,
      );

      final cleanup = await queue.scan(notification, (_, _) async {
        analysisAttempts++;
        return true;
      });

      expect(cleanup, NotificationScanOutcome.completed);
      expect(analysisAttempts, 1);
      expect(completionMarks, 2);
      expect(removalAttempts, 2);
    },
  );

  test('an updated notification uses its distinct idempotency key', () async {
    final update = PendingMessageNotification(
      id: 'notification-1-update',
      title: notification.title,
      text: 'Your account was updated',
      packageName: notification.packageName,
      receivedAt: notification.receivedAt.add(const Duration(seconds: 1)),
    );
    final keys = <String>[];
    final queue = PendingMessageNotificationQueue(
      remove: (_) async {},
      markCompleted: (_) async {},
    );

    await queue.scan(notification, (_, key) async {
      keys.add(key);
      return true;
    });
    await queue.scan(update, (_, key) async {
      keys.add(key);
      return true;
    });

    expect(keys, [notification.id, update.id]);
  });

  test(
    'a restarted queue reuses server idempotency after marker failure',
    () async {
      final persistedResults = <String, bool>{};
      var requests = 0;
      var providerAttempts = 0;
      var persistedScans = 0;
      final firstQueue = PendingMessageNotificationQueue(
        remove: (_) async {},
        markCompleted: (_) async {
          throw StateError(
            'Simulate interruption before local completion mark.',
          );
        },
      );

      await expectLater(
        firstQueue.scan(notification, (content, key) async {
          requests++;
          if (persistedResults.containsKey(key)) return true;
          providerAttempts++;
          persistedResults[key] = true;
          persistedScans++;
          return true;
        }),
        throwsStateError,
      );

      final restartedQueue = PendingMessageNotificationQueue(
        remove: (_) async {},
        markCompleted: (_) async {},
      );
      final outcome = await restartedQueue.scan(notification, (
        content,
        key,
      ) async {
        requests++;
        if (persistedResults.containsKey(key)) return true;
        providerAttempts++;
        persistedResults[key] = true;
        persistedScans++;
        return true;
      });

      expect(outcome, NotificationScanOutcome.completed);
      expect(requests, 2);
      expect(providerAttempts, 1);
      expect(persistedScans, 1);
    },
  );

  test(
    'notification consent, retention, and deletion use native storage APIs',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('cyvora/notification_scanning');
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'getNotificationRetentionDays' => 7,
          'getMessageMonitoringConsent' => false,
          'markPendingMessageNotificationCompleted' => null,
          _ => null,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const service = MessageNotificationService();

      expect(await service.retentionDays(), 7);
      expect(await service.hasMonitoringConsent(), isFalse);
      await service.setRetentionDays(30);
      await service.setMonitoringConsent(true);
      await service.setMonitoringConsent(false);
      await service.markCompleted(notification.id);
      await service.remove(notification.id);
      await service.clearPending();

      expect(calls.map((call) => call.method), [
        'getNotificationRetentionDays',
        'getMessageMonitoringConsent',
        'setNotificationRetentionDays',
        'setMessageMonitoringConsent',
        'setMessageMonitoringConsent',
        'markPendingMessageNotificationCompleted',
        'removePendingMessageNotification',
        'clearPendingMessageNotifications',
      ]);
      expect(calls[2].arguments, {'days': 30});
      expect(calls[3].arguments, {'granted': true});
      expect(calls[4].arguments, {'granted': false});
      expect(calls[5].arguments, {'id': notification.id});
      expect(calls[6].arguments, {'id': notification.id});
    },
  );
}
