import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/encounter_event.dart';
import '../services/encounter_detector.dart';
import '../utils/position_latlng.dart';
import 'location_provider.dart';
import 'nearby_users_provider.dart';

/// 조우(만남) 이벤트를 한 번의 재계산 단위로 방출하는 스트림 provider.
///
/// 내 위치([positionStreamProvider])와 근처 사용자 목록([nearbyUsersProvider])을
/// 둘 다 구독하여, 어느 한쪽이 갱신될 때마다 최신 상태로 [EncounterDetector.update]를
/// 돌리고, 이번 재계산에서 새로 성립한 이벤트들을 하나의 배치([List])로 흘려보낸다.
/// detector는 나를 포함한 모든 참가자 쌍을 판정하므로, 배치에는 나↔상대와
/// 타인끼리의 조우가 섞여 담길 수 있다. 배치로 묶는 이유는, 여러 쌍이 같은
/// 방출에서 동시에 진입해도 UI가 마지막 1건만 덮어쓰지 않고 한 번에 알릴 수
/// 있게 하기 위함이다. 새 이벤트가 없으면 방출하지 않는다.
///
/// 내 위치나 사용자 목록이 아직 없으면(로딩/오류) detector를 돌리지 않는다.
/// 양쪽 모두 [AsyncValue.unwrapPrevious]로 이전 데이터를 벗겨, 오류 상태에서
/// 낡은 위치나 낡은 목록으로 유령 조우가 발생하지 않게 한다.
///
/// 위치/서비스 provider와 동일하게 Riverpod의 자동 재시도를 끈다.
final encounterEventsProvider =
    StreamProvider.autoDispose<List<EncounterEvent>>(
  (ref) {
    final detector = EncounterDetector();
    final controller = StreamController<List<EncounterEvent>>();

    // 위치 갱신과 사용자 목록 갱신 양쪽에서 호출하는 공통 재계산 함수.
    // 호출 시점의 최신 내 위치 + 최신 사용자 목록을 읽어 detector를 돌린다.
    void recompute() {
      // 위치도 오류 시 낡은 값을 쓰지 않도록 사용자 목록과 대칭으로 벗긴다.
      final position =
          ref.read(positionStreamProvider).unwrapPrevious().value;
      final users =
          ref.read(nearbyUsersProvider).unwrapPrevious().value;
      // 둘 중 하나라도 아직 없으면(로딩/오류) 판정하지 않는다.
      if (position == null || users == null) return;
      final events = detector.update(position.latLng, users);
      // 새로 성립한 조우가 없으면 빈 배치는 방출하지 않는다.
      if (events.isEmpty) return;
      controller.add(events);
    }

    // 위치 또는 사용자 목록이 갱신될 때마다 재계산한다.
    ref.listen(positionStreamProvider, (_, __) => recompute());
    ref.listen(nearbyUsersProvider, (_, __) => recompute());

    ref.onDispose(controller.close);
    return controller.stream;
  },
  retry: (retryCount, error) => null,
);
