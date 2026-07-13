import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/encounter_event.dart';
import '../services/encounter_detector.dart';
import '../utils/position_latlng.dart';
import 'location_provider.dart';
import 'nearby_users_provider.dart';

/// 이 파일은 조우 반응(스낵바/펄스 알림과 마커 해금)의 단일 팬아웃 지점이다.
///
/// detector를 소유하고 재계산을 돌리는 곳은 [encounterUpdatesProvider] 하나뿐이며,
/// 매 재계산 결과([EncounterUpdate])에서 새 이벤트 목록과 조우 활성 사용자 집합을
/// 함께 방출한다. 스낵바/펄스용 [encounterEventsProvider]와 해금용
/// [unlockedUsersProvider]는 모두 이 하나의 소스에서 파생되므로, 위치/목록을
/// 이중으로 구독하거나 detector를 중복 소유하지 않는다.

/// 한 번의 재계산 결과. 새로 성립한 조우 이벤트 목록과, 그 시점의 조우 활성
/// 사용자 id 집합(나 제외)을 함께 담는다. 스낵바/펄스는 [events]를, 해금 여부는
/// [activeUserIds]를 각각 소비한다.
typedef EncounterUpdate = ({List<EncounterEvent> events, Set<String> activeUserIds});

/// 조우 재계산 결과([EncounterUpdate])를 방출하는 단일 소스 스트림 provider.
///
/// 내 위치([positionStreamProvider])와 근처 사용자 목록([nearbyUsersProvider])을
/// 둘 다 구독하여, 어느 한쪽이 갱신될 때마다 최신 상태로 [EncounterDetector.update]를
/// 돌린다. 결과로 이번 재계산에서 새로 성립한 이벤트 목록과, 그 시점의 조우 활성
/// 사용자 집합([EncounterDetector.activeUserIds])을 하나의 레코드로 방출한다.
/// detector는 나를 포함한 모든 참가자 쌍을 판정하므로, 이벤트에는 나↔상대와
/// 타인끼리의 조우가 섞여 담길 수 있다.
///
/// 방출 조건: 새 이벤트가 있거나, 활성 사용자 집합이 직전 방출과 달라졌을 때만
/// 방출한다. 둘 다 변화가 없으면 방출하지 않는다. 이벤트가 없어도 활성 집합이
/// 줄어든(멀어져 재잠금) 순간을 흘려보내야 [unlockedUsersProvider]가 재잠금을
/// 반영할 수 있기 때문이다.
///
/// 내 위치나 사용자 목록이 아직 없으면(로딩/오류) detector를 돌리지 않는다.
/// 양쪽 모두 [AsyncValue.unwrapPrevious]로 이전 데이터를 벗겨, 오류 상태에서
/// 낡은 위치나 낡은 목록으로 유령 조우가 발생하지 않게 한다.
///
/// 위치/서비스 provider와 동일하게 Riverpod의 자동 재시도를 끈다.
final encounterUpdatesProvider = StreamProvider.autoDispose<EncounterUpdate>(
  (ref) {
    final detector = EncounterDetector();
    final controller = StreamController<EncounterUpdate>();

    // 직전에 방출한 조우 활성 사용자 집합(불변 복사본). 이벤트가 없어도 이 집합이
    // 바뀌면 방출해야 하므로, 변화 판정을 위해 추적한다.
    var lastActive = <String>{};

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
      final active = {...detector.activeUserIds};
      // 새 이벤트도 없고 활성 집합도 그대로면 방출하지 않는다.
      if (events.isEmpty && setEquals(active, lastActive)) return;
      lastActive = active;
      controller.add((events: events, activeUserIds: active));
    }

    // 위치 또는 사용자 목록이 갱신될 때마다 재계산한다.
    ref.listen(positionStreamProvider, (_, __) => recompute());
    ref.listen(nearbyUsersProvider, (_, __) => recompute());

    ref.onDispose(controller.close);
    return controller.stream;
  },
  retry: (retryCount, error) => null,
);

/// 조우(만남) 이벤트를 한 번의 재계산 단위로 방출하는 스트림 provider.
///
/// [encounterUpdatesProvider]에서 파생한다. 매 재계산 결과 중 **새로 성립한
/// 이벤트가 있는 배치만** 그대로 흘려보낸다(활성 집합만 바뀐 재잠금 방출은 여기서
/// 걸러진다). 배치로 묶는 이유는, 여러 쌍이 같은 재계산에서 동시에 진입해도 UI가
/// 마지막 1건만 덮어쓰지 않고 한 번에 알릴 수 있게 하기 위함이다.
///
/// 공개 타입([List])과 방출 시맨틱(비어있지 않은 배치만)은 스낵바/펄스 소비자와
/// 동일하게 유지된다. [ref.listen]으로 상류를 구독해, autoDispose 연쇄에서
/// [encounterUpdatesProvider]가 이 provider보다 먼저 죽지 않게 한다.
///
/// 위치/서비스 provider와 동일하게 Riverpod의 자동 재시도를 끈다.
final encounterEventsProvider =
    StreamProvider.autoDispose<List<EncounterEvent>>(
  (ref) {
    final controller = StreamController<List<EncounterEvent>>();

    ref.listen(encounterUpdatesProvider, (_, next) {
      // 상류 첫 상태(로딩)에는 value가 null일 수 있다.
      final events = next.value?.events;
      // 새로 성립한 조우가 없으면 빈 배치는 방출하지 않는다.
      if (events == null || events.isEmpty) return;
      controller.add(events);
    });

    ref.onDispose(controller.close);
    return controller.stream;
  },
  retry: (retryCount, error) => null,
);

/// 조우로 "해금"된 사용자 id를 파생하는 provider.
///
/// [encounterUpdatesProvider]가 방출하는 조우 활성 사용자 집합을 그대로 상태로
/// 반영한다. 즉 조우 활성 상태 동안만 해금되며, 마커가 [EncounterDetector.exitRadius]
/// 밖으로 멀어지거나 목록에서 사라져 활성 집합에서 빠지면 다시 잠긴다(재잠금).
/// 마커 탭으로 프로필 바텀시트를 열 수 있는지를 이 집합으로 게이팅한다.
final unlockedUsersProvider =
    NotifierProvider.autoDispose<UnlockedUsersNotifier, Set<String>>(
  UnlockedUsersNotifier.new,
);

/// [unlockedUsersProvider]의 상태를 관리하는 notifier.
class UnlockedUsersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.listen(encounterUpdatesProvider, (_, next) {
      // 상류 첫 상태(로딩)에는 value가 null일 수 있다.
      final active = next.value?.activeUserIds;
      if (active == null) return;
      // 활성 집합이 그대로면 상태 교체를 생략한다(불필요한 리빌드 방지).
      if (setEquals(state, active)) return;
      state = Set<String>.unmodifiable(active);
    });
    return const {};
  }
}
