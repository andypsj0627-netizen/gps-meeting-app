/// 조우 등급.
///
/// 시공간 겹침이 쌓일수록 상승하는 사다리:
/// 스침 → 인연 → 운명 → 연결. 상위 등급일수록 상대 정보가 더 열린다.
enum EncounterTier {
  /// 스침 — 이니셜·나이대만 흐리게.
  brush,

  /// 인연 — 이름·나이·한줄소개 + 맥락.
  bond,

  /// 운명 — '지금 근처' 뱃지가 붙는다.
  fate,

  /// 연결 — 대화가 열린 상태.
  connect,
}

/// 등급의 한국어 라벨.
extension EncounterTierLabel on EncounterTier {
  /// 화면에 표시할 한국어 등급 이름.
  String get label {
    switch (this) {
      case EncounterTier.brush:
        return '스침';
      case EncounterTier.bond:
        return '인연';
      case EncounterTier.fate:
        return '운명';
      case EncounterTier.connect:
        return '연결';
    }
  }
}
