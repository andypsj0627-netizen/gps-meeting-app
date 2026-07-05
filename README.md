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

### Phase 1 — 기반 구조 (현재)
- [ ] 프로젝트 폴더 구조 설계
- [ ] Firebase 연동 (Auth, Firestore, Storage)
- [ ] 기본 인증 (이메일/소셜 로그인)
- [ ] 프로필 생성/수정 화면

### Phase 2 — GPS 핵심 기능
- [ ] 위치 권한 요청 및 실시간 위치 수집
- [ ] 근처 사용자 목록 표시 (지도 or 리스트)
- [ ] 거리 기반 필터링

### Phase 3 — 매칭 & 소통
- [ ] 좋아요 / 관심 표시 기능
- [ ] 상호 관심 시 채팅 활성화
- [ ] 실시간 채팅 (Firebase Realtime DB or Firestore)

### Phase 4 — 완성도
- [ ] 푸시 알림
- [ ] 신고/차단 기능
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

---

개발 진행 규칙(코딩/검증 절차)은 [`CLAUDE.md`](./CLAUDE.md), 세션별 작업 이력은 [`PROJECT_LOG.md`](./PROJECT_LOG.md) 참고.
