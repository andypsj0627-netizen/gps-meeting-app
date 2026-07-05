import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_meeting_app/features/map/providers/location_provider.dart';

import 'helpers/location_test_helpers.dart';

void main() {
  group('positionStreamProvider', () {
    test('서비스가 방출한 위치가 provider를 통해 전달된다', () async {
      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(
            FakeLocationService(Stream.value(fakePosition(37.5665, 126.9780))),
          ),
        ],
      );
      addTearDown(container.dispose);
      // provider 를 구독 상태로 유지한다.
      // onError 를 주지 않으면 오류 상태가 zone 으로 재던져져 테스트가 깨진다.
      final sub = container.listen(
        positionStreamProvider,
        (_, __) {},
        onError: (_, __) {},
      );
      addTearDown(sub.close);

      final position = await container.read(positionStreamProvider.future);

      expect(position.latitude, 37.5665);
      expect(position.longitude, 126.9780);
    });

    test('여러 위치가 순차적으로 방출되면 마지막 값으로 갱신된다', () async {
      final controller = StreamController<Position>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(
            FakeLocationService(controller.stream),
          ),
        ],
      );
      addTearDown(container.dispose);
      // onError 를 주지 않으면 오류 상태가 zone 으로 재던져져 테스트가 깨진다.
      final sub = container.listen(
        positionStreamProvider,
        (_, __) {},
        onError: (_, __) {},
      );
      addTearDown(sub.close);

      controller.add(fakePosition(1, 1));
      await container.read(positionStreamProvider.future);
      expect(container.read(positionStreamProvider).value?.latitude, 1);

      controller.add(fakePosition(2, 2));
      // 다음 이벤트 루프까지 대기하여 스트림 이벤트를 전달한다.
      await Future<void>.delayed(Duration.zero);
      expect(container.read(positionStreamProvider).value?.latitude, 2);
    });

    test('권한 거부 시 LocationException(denied) 이 전달된다', () async {
      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(
            FakeLocationService(
              Stream<Position>.error(
                const LocationException(
                  LocationFailureKind.denied,
                  '권한 거부됨',
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      // onError 를 주지 않으면 오류 상태가 zone 으로 재던져져 테스트가 깨진다.
      final sub = container.listen(
        positionStreamProvider,
        (_, __) {},
        onError: (_, __) {},
      );
      addTearDown(sub.close);

      await expectLater(
        container.read(positionStreamProvider.future),
        throwsA(
          isA<LocationException>().having(
            (e) => e.kind,
            'kind',
            LocationFailureKind.denied,
          ),
        ),
      );
    });
  });
}
