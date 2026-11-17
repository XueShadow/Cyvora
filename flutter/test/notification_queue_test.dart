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
    final removed = <String>[];
    var analysisSucceeded = false;
    final queue = PendingMessageNotificationQueue(
      remove: (id) async {
        expect(analysisSucceeded, isTrue);
        removed.add(id);
      },
    );

    final outcome = await queue.scan(notification, (content) async {
      expect(content, notification.text);
      analysisSucceeded = true;
      return true;
    });

    expect(outcome, NotificationScanOutcome.completed);
    expect(removed, [notification.id]);
  });

  test('keeps failed notifications and allows retry', () async {
    final removed = <String>[];
    var attempts = 0;
    final queue = PendingMessageNotificationQueue(
      remove: (id) async => removed.add(id),
    );

    final failed = await queue.scan(notification, (_) async {
      attempts++;
      return false;
    });
    expect(failed, NotificationScanOutcome.failed);
    expect(removed, isEmpty);

    final retried = await queue.scan(notification, (_) async {
      attempts++;
      return true;
    });
    expect(retried, NotificationScanOutcome.completed);
    expect(attempts, 2);
    expect(removed, [notification.id]);
  });

  test(
    'prevents concurrent duplicate analysis for the same notification',
    () async {
      final removed = <String>[];
      final analysisResult = Completer<bool>();
      var attempts = 0;
      final queue = PendingMessageNotificationQueue(
        remove: (id) async => removed.add(id),
      );

      final first = queue.scan(notification, (_) {
        attempts++;
        return analysisResult.future;
      });
      final duplicate = await queue.scan(notification, (_) async {
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
      var analysisAttempts = 0;
      final queue = PendingMessageNotificationQueue(
        remove: (id) async {
          removalAttempts++;
          if (removalAttempts == 1) {
            throw StateError('temporary channel failure');
          }
        },
      );

      await expectLater(
        queue.scan(notification, (_) async {
          analysisAttempts++;
          return true;
        }),
        throwsStateError,
      );

      final cleanup = await queue.scan(notification, (_) async {
        analysisAttempts++;
        return true;
      });

      expect(cleanup, NotificationScanOutcome.completed);
      expect(analysisAttempts, 1);
      expect(removalAttempts, 2);
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
          _ => null,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const service = MessageNotificationService();

      expect(await service.retentionDays(), 7);
      expect(await service.hasMonitoringConsent(), isFalse);
      await service.setRetentionDays(30);
      await service.setMonitoringConsent(true);
      await service.clearPending();

      expect(calls.map((call) => call.method), [
        'getNotificationRetentionDays',
        'getMessageMonitoringConsent',
        'setNotificationRetentionDays',
        'setMessageMonitoringConsent',
        'clearPendingMessageNotifications',
      ]);
      expect(calls[2].arguments, {'days': 30});
      expect(calls[3].arguments, {'granted': true});
    },
  );
}
