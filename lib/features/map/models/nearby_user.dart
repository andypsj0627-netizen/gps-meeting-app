/// 주변 사용자(모임 후보)의 프로필.
///
/// Firestore `users` 컬렉션의 문서 하나에 대응한다. 위치는 여기 포함하지 않고
/// 시뮬레이션 계층에서 별도로 관리한다.
class NearbyUser {
  const NearbyUser({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
  });

  /// 사용자 고유 id (Firestore 문서 id).
  final String id;

  /// 표시 이름.
  final String name;

  /// 나이.
  final int age;

  /// 성별. 'm' 또는 'f'.
  final String gender;

  /// Firestore 문서 데이터로부터 모델을 만든다.
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

  /// Firestore 쓰기용 맵으로 변환한다(id는 문서 키이므로 제외).
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is NearbyUser &&
      other.id == id &&
      other.name == name &&
      other.age == age &&
      other.gender == gender;

  @override
  int get hashCode => Object.hash(id, name, age, gender);
}
