import 'encounter_tier.dart';

/// 스침 피드 카드 한 건의 뷰모델.
///
/// 표시용으로 이미 가공된 최종 문자열만 담는다 — 마스킹/등급계산/시간 포맷팅은
/// 이 모델의 관심사가 아니다(각각 별도 엔진이 만들어 채운다).
class EncounterCard {
  const EncounterCard({
    required this.id,
    required this.tier,
    required this.displayName,
    required this.ageLabel,
    this.bio,
    required this.contextLine,
    required this.placeLabel,
    required this.timeLabel,
    this.likedByMe = false,
    this.isNearbyNow = false,
  });

  /// 카드 식별자.
  final String id;

  /// 조우 등급.
  final EncounterTier tier;

  /// 표시 이름. 스침이면 이니셜('ㅎ'), 그 외 실명.
  final String displayName;

  /// 나이 라벨. 스침이면 나이대('20대'), 그 외 실제 나이('27').
  final String ageLabel;

  /// 한줄소개. 인연 이상만 채워지고, 스침은 null.
  final String? bio;

  /// 조우 맥락 문구(예 '이번 주 3번째 스침 · 매번 화요일 저녁').
  final String contextLine;

  /// 장소 라벨(예 '망원동 부근').
  final String placeLabel;

  /// 시간 라벨. 미리 구운 표시용 문자열(예 '어제 저녁').
  final String timeLabel;

  /// 내가 호감을 눌렀는지 여부.
  final bool likedByMe;

  /// 지금 근처에 있는지 여부(운명 등급의 '지금 근처' 뱃지 조건).
  final bool isNearbyNow;

  /// 호감 상태만 바꾼 사본을 만든다.
  // ponytail: likedByMe 외 필드 copyWith는 미구현 — 다른 필드 수정이 필요해지면 확장.
  EncounterCard copyWith({bool? likedByMe}) {
    return EncounterCard(
      id: id,
      tier: tier,
      displayName: displayName,
      ageLabel: ageLabel,
      bio: bio,
      contextLine: contextLine,
      placeLabel: placeLabel,
      timeLabel: timeLabel,
      likedByMe: likedByMe ?? this.likedByMe,
      isNearbyNow: isNearbyNow,
    );
  }
}
