import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// 위치 획득 실패의 종류.
///
/// 화면 계층에서 종류별로 서로 다른 안내/조치(설정 열기 등)를 제공하기 위해
/// 사용한다.
enum LocationFailureKind {
  /// 기기의 위치 서비스(GPS)가 꺼져 있음.
  serviceDisabled,

  /// 앱 위치 권한이 이번에 거부됨(다시 요청 가능).
  denied,

  /// 앱 위치 권한이 영구 거부됨(설정에서만 변경 가능).
  deniedForever,

  /// 권한 상태를 판별할 수 없거나 기타 알 수 없는 실패.
  unknown,
}

/// 위치 권한/서비스 관련 실패를 나타내는 예외.
///
/// [kind]로 실패 종류를 구분하여 화면 계층이 적절한 조치를 안내한다.
class LocationException implements Exception {
  const LocationException(this.kind, this.message);

  /// 실패 종류.
  final LocationFailureKind kind;

  /// 사용자에게 보여줄 안내 메시지.
  final String message;

  @override
  String toString() => 'LocationException($kind): $message';
}

/// 위치 스트림을 제공하는 서비스 추상화.
///
/// Geolocator 직접 호출을 이 인터페이스 뒤로 숨겨, 테스트에서 fake 구현으로
/// 손쉽게 override할 수 있도록 한다.
abstract class LocationService {
  /// 권한을 확인/요청한 뒤 위치 변경 스트림을 반환한다.
  ///
  /// 권한이 없거나 위치 서비스가 꺼져 있으면 스트림은
  /// [LocationException] 오류를 방출한다.
  Stream<Position> getPositionStream();

  /// 앱 설정 화면을 연다(권한 영구 거부 시 사용).
  Future<bool> openAppSettings();

  /// 기기의 위치 설정 화면을 연다(위치 서비스 꺼짐 시 사용).
  Future<bool> openLocationSettings();
}

/// Geolocator를 실제로 호출하는 [LocationService] 구현체.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Stream<Position> getPositionStream() async* {
    // 1. 기기의 위치 서비스(GPS)가 켜져 있는지 확인한다.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        LocationFailureKind.serviceDisabled,
        '위치 서비스가 꺼져 있습니다. 기기 설정에서 위치를 켜주세요.',
      );
    }

    // 2. 앱의 위치 권한을 확인하고, 필요하면 요청한다.
    //    denied 뿐 아니라 unableToDetermine(웹 등에서 판별 불가)도 요청을 시도한다.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        throw const LocationException(
          LocationFailureKind.denied,
          '위치 권한이 거부되었습니다. 권한을 허용해야 내 위치를 표시할 수 있습니다.',
        );
      case LocationPermission.deniedForever:
        throw const LocationException(
          LocationFailureKind.deniedForever,
          '위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 권한을 허용해주세요.',
        );
      case LocationPermission.unableToDetermine:
        throw const LocationException(
          LocationFailureKind.unknown,
          '위치 권한 상태를 확인할 수 없습니다. 잠시 후 다시 시도해주세요.',
        );
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        // 권한 확보됨 — 아래에서 스트림을 방출한다.
        break;
    }

    // 3. 권한이 확보되면 실제 위치 스트림을 방출한다.
    //    스트림 도중 발생하는 geolocator 내장 예외를 커스텀 [LocationException]으로
    //    변환하여, 화면 계층이 권한/서비스 오류를 일관되게 구분할 수 있도록 한다.
    final inner = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
    try {
      await for (final position in inner) {
        yield position;
      }
    } on PermissionDeniedException {
      throw const LocationException(
        LocationFailureKind.denied,
        '위치 권한이 거부되었습니다. 권한을 허용해야 내 위치를 표시할 수 있습니다.',
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        LocationFailureKind.serviceDisabled,
        '위치 서비스가 꺼져 있습니다. 기기 설정에서 위치를 켜주세요.',
      );
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// 위치 서비스 provider.
///
/// 기본값은 Geolocator 구현체이며, 테스트에서는 이 provider를 override하여
/// fake 스트림/권한 거부 상태를 주입한다.
final locationServiceProvider = Provider<LocationService>((ref) {
  return const GeolocatorLocationService();
});

/// 현재 위치를 실시간으로 방출하는 스트림 provider.
///
/// [locationServiceProvider]에 위임하므로, 서비스만 override하면
/// 이 provider의 동작 전체를 테스트에서 제어할 수 있다.
///
/// Riverpod 3 는 기본적으로 오류 발생 시 자동 재시도(백오프 Timer)를 수행하는데,
/// 여기서는 권한 거부 시 사용자가 직접 "재시도" 버튼을 누르도록 설계했으므로
/// [retry] 를 null 로 반환해 자동 재시도를 비활성화한다.
final positionStreamProvider = StreamProvider<Position>(
  (ref) {
    final service = ref.watch(locationServiceProvider);
    return service.getPositionStream();
  },
  retry: (retryCount, error) => null,
);
