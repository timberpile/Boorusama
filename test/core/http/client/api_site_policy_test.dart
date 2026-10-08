import 'package:boorusama/core/http/client/coordination.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'abandoned Danbooru read reservation immediately restores rolling and token capacity while dispatched reads remain charged',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final key = ApiQuotaKey.fromUri(
          Uri.parse('https://danbooru.donmai.us'),
        );
        var admissions = 0;
        for (var i = 0; i < 9; i++) {
          c.acquire(key).then((p) {
            admissions++;
            p.release();
          });
        }
        time.flushMicrotasks();
        expect(admissions, 9);
        ApiRequestPermit? unstarted;
        c.acquire(key).then((p) {
          admissions++;
          unstarted = p;
        });
        time.flushMicrotasks();
        expect(admissions, 10);
        c.acquire(key).then((p) {
          admissions++;
          p.release();
        });
        time.flushMicrotasks();
        expect(admissions, 10);
        unstarted!.abandon();
        time.flushMicrotasks();
        expect(
          admissions,
          11,
          reason:
              'both the full rolling window and empty token bucket must refund an undispatched reservation',
        );
        c.acquire(key).then((p) {
          admissions++;
          p.release();
        });
        time.flushMicrotasks();
        expect(
          admissions,
          11,
          reason:
              'completion of dispatched reads must not refund their rate debit',
        );
        time.elapse(const Duration(milliseconds: 999));
        expect(admissions, 11);
        time.elapse(const Duration(milliseconds: 1));
        time.flushMicrotasks();
        expect(admissions, 12);
        c.dispose();
      });
    },
  );

  test(
    'elapsed refill plus abandonment cannot create extra Danbooru burst tokens',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final key = ApiQuotaKey.fromUri(
          Uri.parse('https://danbooru.donmai.us'),
        );
        ApiRequestPermit? unstarted;
        c.acquire(key).then((p) => unstarted = p);
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 10));
        unstarted!.abandon();
        var admissions = 0;
        for (var i = 0; i < 12; i++) {
          c.acquire(key).then((p) {
            admissions++;
            p.release();
          });
        }
        time.flushMicrotasks();
        expect(admissions, 10);
        time.elapse(const Duration(seconds: 1));
        time.flushMicrotasks();
        expect(
          admissions,
          11,
          reason:
              'idle refill and the abandoned token must be capped at ten, not permit two new reads after one second',
        );
        time.elapse(const Duration(seconds: 1));
        time.flushMicrotasks();
        expect(admissions, 12);
        c.dispose();
      });
    },
  );

  for (final host in ['danbooru.donmai.us', 'safebooru.donmai.us']) {
    test(
      '$host allows ten read burst starts then refills at one per second',
      () {
        fakeAsync((time) {
          final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
          final key = ApiQuotaKey.fromUri(Uri.parse('https://$host'));
          var starts = 0;
          for (var i = 0; i < 20; i++) {
            c.acquire(key).then((p) {
              starts++;
              p.release();
            });
          }
          time.flushMicrotasks();
          expect(starts, 10);
          time.elapse(const Duration(seconds: 9));
          time.flushMicrotasks();
          expect(starts, 19);
          time.elapse(const Duration(milliseconds: 999));
          expect(starts, 19);
          time.elapse(const Duration(milliseconds: 1));
          time.flushMicrotasks();
          expect(starts, 20);
          c.dispose();
        });
      },
    );
  }

  test(
    'Danbooru mutation GET has conservative write pacing separate from safe POST reads',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final key = ApiQuotaKey.fromUri(
          Uri.parse('https://danbooru.donmai.us'),
        );
        var writes = 0;
        var reads = 0;
        for (var i = 0; i < 2; i++) {
          c
              .acquire(
                key,
                descriptor: const ApiRequestDescriptor(
                  replaySafety: ApiReplaySafety.mutation,
                ),
              )
              .then((p) {
                writes++;
                p.release();
              });
        }
        c
            .acquire(
              key,
              descriptor: const ApiRequestDescriptor(
                method: 'POST',
              ),
            )
            .then((p) {
              reads++;
              p.release();
            });
        time.flushMicrotasks();
        expect(writes, 1);
        expect(reads, 1);
        time.elapse(const Duration(seconds: 1));
        time.flushMicrotasks();
        expect(writes, 2);
        c.dispose();
      });
    },
  );

  test('Derpi general traffic does not inherit exhausted search allowance', () {
    fakeAsync((time) {
      final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://derpibooru.org'));
      var searches = 0;
      var general = 0;
      for (var i = 0; i < 21; i++) {
        c
            .acquire(
              key,
              descriptor: const ApiRequestDescriptor(
                path: '/api/v1/json/search/images',
              ),
            )
            .then((p) {
              searches++;
              p.release();
            });
      }
      time.flushMicrotasks();
      expect(searches, 20);
      for (var i = 0; i < 11; i++) {
        c
            .acquire(
              key,
              descriptor: const ApiRequestDescriptor(
                path: '/api/v1/json/images/1',
              ),
            )
            .then((p) {
              general++;
              p.release();
            });
      }
      time.flushMicrotasks();
      expect(general, 10);
      time.elapse(const Duration(seconds: 5));
      time.flushMicrotasks();
      expect(general, 11);
      expect(searches, 20);
      time.elapse(const Duration(seconds: 5));
      time.flushMicrotasks();
      expect(searches, 21);
      c.dispose();
    });
  });

  for (final host in ['e621.net', 'e926.net']) {
    test('$host retains one per second without a synthetic minute cap', () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final key = ApiQuotaKey.fromUri(Uri.parse('https://$host'));
        var starts = 0;
        for (var i = 0; i < 30; i++) {
          c.acquire(key).then((p) {
            starts++;
            p.release();
          });
        }
        time.flushMicrotasks();
        expect(starts, 1);
        time.elapse(const Duration(seconds: 29));
        time.flushMicrotasks();
        expect(starts, 30);
        c.dispose();
      });
    });
  }

  test(
    'Zerochan enforces a rolling sixty per minute at the actual www origin',
    () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        final key = ApiQuotaKey.fromUri(Uri.parse('https://www.zerochan.net'));
        var starts = 0;
        for (var i = 0; i < 61; i++) {
          c.acquire(key).then((p) {
            starts++;
            p.release();
          });
        }
        time.flushMicrotasks();
        expect(starts, 60);
        time.elapse(const Duration(seconds: 59));
        expect(starts, 60);
        time.elapse(const Duration(seconds: 1));
        time.flushMicrotasks();
        expect(starts, 61);
        c.dispose();
      });
    },
  );

  for (final origin in [
    'https://aibooru.online',
    'https://ponybooru.org',
    'https://kpop.asiachan.com',
    'https://danbooru.donmai.us:444',
  ]) {
    test('$origin does not inherit another deployment policy', () {
      fakeAsync((time) {
        final c = ApiRequestCoordinator(elapsed: () => time.elapsed);
        var starts = 0;
        final key = ApiQuotaKey.fromUri(Uri.parse(origin));
        for (var i = 0; i < 65; i++) {
          c.acquire(key).then((p) {
            starts++;
            p.release();
          });
        }
        time.flushMicrotasks();
        expect(starts, 65);
        c.dispose();
      });
    });
  }
}
