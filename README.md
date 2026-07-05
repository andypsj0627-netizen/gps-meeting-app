# GPS Meeting App

모바일 GPS를 활용한 셀프 소개팅 앱. 근처에 있는 사람들과 자연스럽게 연결해주는 위치 기반 매칭 서비스.

- **앱 이름**: GPS Meeting App
- **기술 스택**: Flutter (크로스플랫폼 — iOS / Android)
- **패키지명**: `gps_meeting_app`
- **GitHub 레포**: `gps-meeting-app`

---

## 핵심 컨셉
- 사용자가 자신의 위치를 공개하면 근처의 다른 사용자를 볼 수 있음
- 상호 관심이 있을 때만 연락처 또는 채팅이 연결됨
- "셀프 소개팅" — 앱이 강제 매칭하는 게 아니라 사용자가 주도적으로 탐색

---

## 개발 방향 (단계별)

큰 그림 우선: 앱의 핵심 동작(지도 + GPS)이 눈에 보이게 먼저 만들고, 사용자 기반과 서비스 준비는 이후 단계에서 붙인다.

### Phase 1 — 지도 & GPS 코어 (현재)
- [x] 프로젝트 폴더 구조 설계 (core / features / shared)
- [x] 지도 표시 (flutter_map, OpenStreetMap)
- [x] 위치 권한 요청 및 실시간 위치 수집 (geolocator)
- [x] 지도 위 내 위치 마커 표시, 이동 시 마커·카메라 추적 (follow 모드 + 내 위치 버튼)

### Phase 2 — 사용자 기반
- [ ] Firebase 연동 (Auth, Firestore, Storage)
- [ ] 기본 인증 (이메일/소셜 로그인)
- [ ] 프로필 생성/수정 화면

### Phase 3 — 매칭 & 소통
- [ ] 근처 사용자 지도/리스트 표시, 거리 기반 필터링
- [ ] 좋아요 / 관심 표시 기능
- [ ] 상호 관심 시 채팅 활성화
- [ ] 실시간 채팅 (Firebase Realtime DB or Firestore)

### Phase 4 — 서비스 준비 (출시 전 필수)
- [ ] 푸시 알림
- [ ] 신고/차단 기능
- [ ] 위치 프라이버시·보안 검토 (좌표 노출 정책, Firestore 보안 룰)
- [ ] 프리미엄 기능 (유료화 고려)

---

## 폴더 구조 (목표)
```
lib/
  core/          # 공통 유틸, 상수, 테마
  features/      # 기능별 모듈 (auth, map, chat, profile)
  shared/        # 공용 위젯
  main.dart
```

---

## 주요 결정사항 로그
| 날짜 | 결정 | 이유 |
|------|------|------|
| 2026-07-01 | Flutter 선택 | iOS/Android 크로스플랫폼 |
| 2026-07-01 | GPS 기반 근거리 매칭 | 자연스러운 만남 유도 |
| 2026-07-05 | 상태 관리: Riverpod | 컴파일 타임 안전성, 테스트 용이, Firebase 스트림과 궁합 |
| 2026-07-05 | 지도: flutter_map (OSM) | API 키 불필요, Chrome에서 즉시 테스트 가능. 필요 시 추후 교체 |
| 2026-07-05 | 지도/GPS를 Phase 1로 승격 | 핵심 동작 검증 우선, 인증/Firebase는 Phase 2로 |

---

개발 환경 설정은 [`SETUP.md`](./SETUP.md), 개발 진행 규칙(코딩/검증 절차)은 [`CLAUDE.md`](./CLAUDE.md), 세션별 작업 이력은 [`PROJECT_LOG.md`](./PROJECT_LOG.md) 참고.
