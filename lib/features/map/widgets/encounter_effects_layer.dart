import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/encounter_event.dart';
import '../providers/encounter_provider.dart';

/// 활성 펄스 효과 하나. 조우 지점과 목록 안에서의 고유 식별자를 가진다.
///
/// [seq]는 0부터 증가하는 카운터로, 위젯 키(`encounter_pulse_<seq>`)를 만든다.
/// 시퀀스를 쓰는 이유는 (1) 같은 지점에서 조우가 반복돼도 키가 겹치지 않게 하고
/// (2) 테스트에서 키를 예측 가능하게 하기 위함이다.
class _PulseEffect {
  const _PulseEffect(this.seq, this.point);

  final int seq;
  final LatLng point;
}

/// 조우가 성립한 지점 위에 파문(펄스 링) 애니메이션을 그리는 FlutterMap 레이어.
///
/// [encounterEventsProvider]가 방출하는 조우 배치를 [ref.listen]으로 받아,
/// 이벤트마다 활성 효과 1개를 추가한다. 각 효과는 [_PulseRing]이 재생을 마치면
/// 스스로 목록에서 빠지므로, 화면에는 진행 중인 파문만 남는다. 스낵바 알림과는
/// 독립적으로 동작하여, 알림은 문구로 파문은 지도 위 위치로 조우를 표현한다.
///
/// FlutterMap children 안에서 사용해야 한다([MarkerLayer]를 반환하므로).
class EncounterEffectsLayer extends ConsumerStatefulWidget {
  const EncounterEffectsLayer({super.key});

  @override
  ConsumerState<EncounterEffectsLayer> createState() =>
      _EncounterEffectsLayerState();
}

class _EncounterEffectsLayerState
    extends ConsumerState<EncounterEffectsLayer> {
  /// 현재 재생 중인 펄스 효과들.
  final List<_PulseEffect> _effects = [];

  /// 다음 효과에 부여할 시퀀스 번호. 효과가 소멸해도 되감지 않아 키가 항상 유일하다.
  int _nextSeq = 0;

  /// 조우 지점을 두 참가자 좌표의 산술 평균으로 잡는다.
  ///
  /// 조우 반경이 수십 m 수준이라 지구 곡률에 따른 대권 중점과의 오차는 무시할
  /// 만하다. 이 규모에서는 위경도 산술 평균이 사실상 정확한 중점이라, 굳이
  /// 구면 보간을 쓰지 않는다.
  LatLng _midpoint(EncounterEvent event) => LatLng(
        (event.a.position.latitude + event.b.position.latitude) / 2,
        (event.a.position.longitude + event.b.position.longitude) / 2,
      );

  /// 완료된 효과를 목록에서 제거한다. [_PulseRing]이 재생을 마치면 호출한다.
  void _removeEffect(int seq) {
    if (!mounted) return;
    setState(() => _effects.removeWhere((e) => e.seq == seq));
  }

  @override
  Widget build(BuildContext context) {
    // 조우 배치가 올 때마다 이벤트당 효과 1개를 추가한다. 배치는 방출당 최소
    // 1건이 보장되므로(provider가 빈 배치를 방출하지 않음) 목록이 커지기만 하다가
    // 각 링의 재생 완료 콜백으로 다시 줄어든다.
    ref.listen<AsyncValue<List<EncounterEvent>>>(encounterEventsProvider,
        (previous, next) {
      final events = next.value;
      if (events == null || events.isEmpty || !mounted) return;
      setState(() {
        for (final event in events) {
          _effects.add(_PulseEffect(_nextSeq++, _midpoint(event)));
        }
      });
    });

    return MarkerLayer(
      markers: [
        for (final effect in _effects)
          Marker(
            key: ValueKey('encounter_pulse_${effect.seq}'),
            point: effect.point,
            width: 80,
            height: 80,
            child: _PulseRing(
              onCompleted: () => _removeEffect(effect.seq),
            ),
          ),
      ],
    );
  }
}

/// 중심에서 바깥으로 두 번 퍼지며 사라지는 원형 파문 애니메이션.
///
/// 총 1500ms 동안 forward 1회를 재생하되, 진행도 t에 `(t * 2) % 1`을 적용해
/// 링이 2회 퍼지는 리플로 보이게 한다. 각 리플은 스케일 0→1로 확장하면서
/// 불투명 1→0으로 서서히 투명해진다. 재생을 마치면 [onCompleted]를 호출해
/// 부모가 자신을 목록에서 제거하도록 한다.
class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.onCompleted});

  /// 애니메이션이 끝났을 때(status completed) 한 번 호출된다.
  final VoidCallback onCompleted;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          widget.onCompleted();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      // 프레임 불변인 원형 장식은 한 번만 만들어 child로 넘기고, builder는 이를
      // 감싸기만 한다. 매 프레임 DecoratedBox/BoxDecoration/Border를 재할당하지 않는다.
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
        ),
      ),
      builder: (context, child) {
        // 전체 진행도를 2배로 감아 리플을 2회 반복시킨다.
        final ripple = (_controller.value * 2) % 1;
        return Opacity(
          // 리플 진행에 따라 불투명 → 투명.
          opacity: (1 - ripple).clamp(0.0, 1.0),
          child: Transform.scale(
            // 중심에서 바깥으로 확장.
            scale: ripple,
            child: child,
          ),
        );
      },
    );
  }
}
