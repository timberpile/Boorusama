import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'abandoned unknown-origin admission immediately restores its occupied slot',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
        final permits = <ApiRequestPermit>[];
        for (var i = 0; i < 4; i++) {
          c.acquire(key).then(permits.add);
        }
        time.flushMicrotasks();
        permits.first.abandon();
        var started = false;
        c.acquire(key).then((p) {
          started = true;
          p.release();
        });
        time.flushMicrotasks();
        expect(started, true);
        c.dispose();
      });
    },
  );

  test(
    'running active work permits bounded passive progress without preemption',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
        ApiRequestPermit? passive;
        ApiRequestPermit? active;
        c
            .acquire(
              key,
              context: const ApiRequestContext(
                requestClass: ApiRequestClass.preload,
              ),
            )
            .then((p) => passive = p);
        c.acquire(key).then((p) => active = p);
        var next = false;
        c
            .acquire(
              key,
              context: const ApiRequestContext(
                requestClass: ApiRequestClass.automatic,
              ),
            )
            .then((p) {
              next = true;
              p.release();
            });
        time.flushMicrotasks();
        expect(passive, isNotNull);
        expect(active, isNotNull);
        expect(next, true);
        active!.release();
        time.flushMicrotasks();
        expect(next, true);
        expect(c.snapshot(key).inFlight, 1);
        passive!.release();
        c.dispose();
      });
    },
  );

  test('priority classes keep FIFO even when the transport is saturated', () {
    fakeAsync((time) {
      final c = ApiRequestCoordinator(
        elapsed: () => time.elapsed,
        policy: (_) => ApiQuotaPolicy.buffered(
          sourceWindows: const [
            ApiStartWindow(capacity: 100, duration: Duration(minutes: 1)),
          ],
        ),
      );
      final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
      final permits = <ApiRequestPermit>[];
      for (var i = 0; i < 4; i++) {
        c.acquire(key).then(permits.add);
      }
      final order = <String>[];
      void queue(String name, ApiRequestClass priority) {
        c.acquire(key, context: ApiRequestContext(requestClass: priority)).then(
          (p) {
            order.add(name);
            p.release();
          },
        );
      }

      queue('auto', ApiRequestClass.automatic);
      queue('bulk', ApiRequestClass.bulkTransfer);
      queue('user1', ApiRequestClass.userInitiated);
      queue('interactive', ApiRequestClass.interactive);
      queue('user2', ApiRequestClass.userInitiated);
      time.flushMicrotasks();
      permits.first.release();
      time.flushMicrotasks();
      expect(order, ['interactive', 'user1', 'user2', 'bulk', 'auto']);
      for (final p in permits.skip(1)) {
        p.release();
      }
      time.flushMicrotasks();
      expect(order.last, 'auto');
      c.dispose();
    });
  });

  test('known Derpibooru windows constrain documented search bursts', () {
    fakeAsync((time) {
      final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://derpibooru.org'));
      var starts = 0;
      for (var i = 0; i < 21; i++) {
        c
            .acquire(
              key,
              descriptor: const ApiRequestDescriptor(
                path: '/api/v1/json/search/images',
              ),
            )
            .then((p) {
              starts++;
              p.release();
            });
      }
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 9));
      time.flushMicrotasks();
      expect(starts, 20);
      time.elapse(const Duration(seconds: 1));
      time.flushMicrotasks();
      expect(starts, 21);
      c.dispose();
    });
  });

  test(
    'tiny evidenced limits keep a conservative longer window instead of zero capacity',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(
          elapsed: () => time.elapsed,
          policy: (_) => ApiQuotaPolicy.buffered(
            sourceWindows: const [
              ApiStartWindow(capacity: 1, duration: Duration(seconds: 1)),
            ],
          ),
        );
        final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
        var starts = 0;
        for (var i = 0; i < 2; i++) {
          c.acquire(key).then((p) {
            starts++;
            p.release();
          });
        }
        time.flushMicrotasks();
        expect(starts, 1);
        time.elapse(const Duration(milliseconds: 1249));
        expect(starts, 1);
        time.elapse(const Duration(milliseconds: 1));
        time.flushMicrotasks();
        expect(starts, 2);
        c.dispose();
      });
    },
  );

  test(
    'simultaneous rate failures keep the same fallback episode deadline',
    () {
      fakeAsync((time) {
        final wall = DateTime.utc(2026);
        final c = ApiRequestCoordinator(
          elapsed: () => time.elapsed,
          now: () => wall.add(time.elapsed),
          jitter: () => 0,
        );
        final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
        expect(c.recordRateLimit(key), wall.add(const Duration(seconds: 30)));
        time.elapse(const Duration(seconds: 1));
        expect(c.recordRateLimit(key), wall.add(const Duration(seconds: 30)));
        time.elapse(const Duration(seconds: 29));
        expect(c.recordRateLimit(key), wall.add(const Duration(seconds: 150)));
        c.dispose();
      });
    },
  );

  test(
    'server dates and fallback steps retain scope and gradually clear penalties',
    () {
      fakeAsync((time) {
        final wall = DateTime.utc(2026);
        final c = ApiRequestCoordinator(
          elapsed: () => time.elapsed,
          now: () => wall.add(time.elapsed),
          jitter: () => 0,
        );
        final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
        for (final seconds in [30, 120, 600, 1800]) {
          expect(
            c.recordRateLimit(key).difference(wall.add(time.elapsed)),
            Duration(seconds: seconds),
          );
          time.elapse(Duration(seconds: seconds));
        }
        c.recordSuccess(key);
        expect(
          c.recordRateLimit(key).difference(wall.add(time.elapsed)),
          const Duration(minutes: 10),
        );
        c.dispose();
        final dates = ApiRequestCoordinator(
          elapsed: () => time.elapsed,
          now: () => wall,
          jitter: () => 0,
        );
        expect(
          dates.recordRateLimit(
            key,
            retryAfter: 'Thu, 01 Jan 2026 00:02:00 GMT',
          ),
          wall.add(const Duration(minutes: 2)),
        );
        // Concurrent failures in the same episode cannot shorten the deadline.
        expect(
          dates.recordRateLimit(key, retryAfter: '1'),
          wall.add(const Duration(minutes: 2)),
        );
        dates.dispose();
      });
    },
  );

  test(
    'shares four permits across callers on one origin without a guessed rate',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test/path'));
        final permits = <ApiRequestPermit>[];
        for (var i = 0; i < 5; i++) {
          c.acquire(key).then(permits.add);
        }
        time.flushMicrotasks();
        expect(permits.length, 4);
        permits.first.release();
        time.flushMicrotasks();
        expect(permits.length, 5);
        c.dispose();
      });
    },
  );

  test(
    'caps passive work and starts active work before queued passive FIFO',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
        final order = <String>[];
        for (var i = 0; i < 13; i++) {
          c
              .acquire(
                key,
                context: const ApiRequestContext(
                  requestClass: ApiRequestClass.automatic,
                ),
              )
              .then((p) {
                order.add('passive$i');
                p.release();
              });
        }
        time.flushMicrotasks();
        c.acquire(key).then((p) {
          order.add('active');
          p.release();
        });
        time.elapse(const Duration(seconds: 4));
        time.flushMicrotasks();
        expect(order.where((s) => s.startsWith('passive')).length, 12);
        expect(order.last, 'active');
        time.elapse(const Duration(seconds: 56));
        time.flushMicrotasks();
        expect(order.last, 'passive12');
        expect(order.indexOf('active'), lessThan(order.indexOf('passive12')));
        c.dispose();
      });
    },
  );

  test(
    'cancelled queued requests consume no capacity and other origins continue',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
        for (var i = 0; i < 4; i++) {
          c.acquire(key);
        }
        final token = CancelToken();
        Object? error;
        c
            .acquire(key, context: ApiRequestContext(cancelToken: token))
            .then(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );
        token.cancel();
        var otherStarted = false;
        c
            .acquire(ApiQuotaKey.fromUri(Uri.parse('https://other.test')))
            .then((_) => otherStarted = true);
        time.flushMicrotasks();
        expect(error, isA<DioException>());
        expect(otherStarted, true);
        expect(c.snapshot(key).queued, 0);
        c.dispose();
      });
    },
  );

  test('cooldown rejects queued manual work and never replays it later', () {
    fakeAsync((time) {
      final wall = DateTime.utc(2026);
      final c = ApiRequestCoordinator(
        elapsed: () => time.elapsed,
        now: () => wall.add(time.elapsed),
        jitter: () => 0,
      );
      final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
      for (var i = 0; i < 4; i++) {
        c.acquire(key);
      }
      ApiCooldownException? error;
      c
          .acquire(key)
          .then(
            (_) {},
            onError: (Object e) {
              error = e as ApiCooldownException;
            },
          );
      c.recordRateLimit(key, retryAfter: '120');
      time.flushMicrotasks();
      expect(error?.retryAt, wall.add(const Duration(minutes: 2)));
      time.elapse(const Duration(minutes: 3));
      expect(c.snapshot(key).queued, 0);
      c.dispose();
    });
  });

  test(
    'actual origins include effective ports and known sites use stricter policies',
    () {
      fakeAsync((time) {
        expect(
          ApiQuotaKey.fromUri(Uri.parse('HTTPS://SITE.test:443/a')),
          ApiQuotaKey.fromUri(Uri.parse('https://site.test/b')),
        );
        expect(
          ApiQuotaKey.fromUri(Uri.parse('https://site.test:444')),
          isNot(ApiQuotaKey.fromUri(Uri.parse('https://site.test'))),
        );
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        var starts = 0;
        final key = ApiQuotaKey.fromUri(Uri.parse('https://e621.net'));
        for (var i = 0; i < 2; i++) {
          c.acquire(key).then((p) {
            starts++;
            p.release();
          });
        }
        time.flushMicrotasks();
        expect(starts, 1);
        time.elapse(const Duration(seconds: 1));
        time.flushMicrotasks();
        expect(starts, 2);
        c.dispose();
      });
    },
  );
}
