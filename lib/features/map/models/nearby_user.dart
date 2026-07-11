import 'package:latlong2/latlong.dart';

/// 지도에 표시되는 "근처 사용자" 한 명 + 프로필.
///
/// 두 축의 정보를 한 모델에 담는다.
/// - 프로필: Firestore `users` 컬렉션 문서에 대응하는 [id]/[name]/[age]/[gender].
/// - 위치: 시뮬레이션 계층이 부여하는 현재 좌표 [position].
///
/// 프로필만 다루는 경로(로딩/시드)에서는 [position]을 생략하면 기본값(0,0)이
/// 쓰이고, 시뮬레이션이 실제 좌표를 채워 방출한다.
class NearbyUser {
  const NearbyUser({
    required this.id,
    required this.name,
    this.position = const LatLng(0, 0),
    this.age = 0,
    this.gender = '',
  });

  /// 사용자 식별자(Firestore 문서 id). 마커 key 및 동등성 비교의 기준이 된다.
  final String id;

  /// 표시 이름.
  final String name;

  /// 현재 위치. 프로필만 로드한 상태에서는 기본값(0,0)이며, 시뮬레이션이 채운다.
  final LatLng position;

  /// 나이.
  final int age;

  /// 성별. 'm' 또는 'f'.
  final String gender;

  /// Firestore 문서 데이터로부터 프로필을 만든다(위치는 시뮬레이션이 부여).
  ///
  /// 필드가 누락되면(null) 안전한 기본값으로 보정한다. 다만 필드 타입이 기대와
  /// 다르면(예: age가 문자열 "27") 캐스트가 [TypeError]를 던진다. 이 경우는
  /// 호출자([UserProfileRepository.loadProfiles])가 문서 단위로 걸러야 한다.
  factory NearbyUser.fromFirestore(String id, Map<String, dynamic> data) {
    return NearbyUser(
      id: id,
      name: (data['name'] as String?) ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      gender: (data['gender'] as String?) ?? '',
    );
  }

  /// Firestore 쓰기용 맵으로 변환한다(id는 문서 키이므로, position은 시뮬레이션
  /// 전용이므로 제외).
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
    };
  }

  /// 프로필은 유지한 채 위치만 바꾼 사본을 만든다. 시뮬레이션이 매 틱 사용한다.
  NearbyUser copyWith({LatLng? position}) {
    return NearbyUser(
      id: id,
      name: name,
      position: position ?? this.position,
      age: age,
      gender: gender,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NearbyUser &&
      other.id == id &&
      other.name == name &&
      other.position == position &&
      other.age == age &&
      other.gender == gender;

  @override
  int get hashCode => Object.hash(id, name, position, age, gender);

  @override
  String toString() => 'NearbyUser($id, $name, $position, $age, $gender)';
}
