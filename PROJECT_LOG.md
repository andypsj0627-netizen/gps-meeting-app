# 프로젝트 작업 로그

세션별 작업 내용을 기록합니다. 최신 항목이 위에 위치합니다.

---

## 2026-07-11

### 완료
- Phase 2 착수 — Firebase 백엔드 구축:
  - Firebase CLI(15.23.0) 설치, `flutterfire configure`로 web/android/ios 앱 등록 (`lib/firebase_options.dart`)
  - Firestore 데이터베이스 생성 (서울 asia-northeast3), 개발용 보안 룰 배포 (`users` 컬렉션만 2026-09-01까지 open — Auth 도입 시 교체)
  - `firebase_core` + `cloud_firestore` 연동. Firebase 초기화는 `firebaseInitProvider`로 지연 실행(첫 프레임 비차단), 실패 시 기본 프로필로 fallback
  - 테스트 사용자 5명(이름/id/나이/성별)을 첫 실행 시 `users` 컬렉션에 자동 시드 (디버그 빌드, WriteBatch)
- 시뮬레이션 사용자 마커 5개 (Worker/Opus 위임 → Advisor 검증):
  - 내 위치 주변 200m 내 스폰, 1초 주기 랜덤 워크(5~15m), 300m 이탈 시 복귀
  - 조우 판정: 내 위치 또는 다른 마커와 30m 이내 접근 시 조우(sticky), 하이라이트 + 탭 시 프로필 바텀시트(이름/id/나이/성별)
- 코드 리뷰(8앵글 병렬 + 검증 에이전트)로 확정 결함 13건 발견 → 전부 수정:
  - 프로필 로드 완료 시 마커 재배치/조우 초기화 버그, Firestore 타입 불일치 시 전체 프로필 폐기, 스폰 직후 조우 미판정, 타이머 영구 실행(autoDispose 전환), 시드 배치화, 죽은 유연성 제거, 테스트 pump 헬퍼 공용화 등
- 훅 크로스플랫폼화: `.claude/settings.json`의 Mac 하드코딩 경로(이 PC에서 매번 실패)를 `.claude/hooks/*.sh` 스크립트로 분리 — flutter/dart 경로 자동 탐색(Windows `~/dev/flutter` + Mac `~/development/flutter`), Stop 훅은 flutter test 하드 게이트만 수행(자동 커밋/push 제거), analyze 실패 시 exit 2 피드백
- 테스트 28건 전체 통과, dart analyze 클린

### 다음 세션에서 할 일
- Phase 2 계속: Firebase Auth (이메일/소셜 로그인) 설계 및 구현
- 프로필 생성/수정 화면
- 조우 sticky 상태 이중 저장(Set + bool) 단순화 검토 (리뷰 지적, 유지보수성)
- Android 실기기 테스트 준비 (커맨드라인 SDK + USB 디버깅)

---

## 2026-07-05 (2차 세션)

### 완료
- Phase 1 구현 (Worker/Opus 위임 → Advisor 검증): 지도(flutter_map+OSM), 실시간 위치 스트림(geolocator+Riverpod), 내 위치 마커, go_router, Material 3 테마
- 로드맵 재편: Phase 1을 "지도 & GPS 코어"로 변경, 인증/Firebase는 Phase 2로, 보안·프라이버시 검토는 Phase 4(출시 전 필수)로 이동
- 코드 리뷰(8앵글 병렬 + 패키지 소스 검증)로 확정 결함 10건 발견 → 전부 수정:
  - 오류 분류 체계(LocationFailureKind) 도입, 영구 거부 시 "설정 열기" 버튼, 일시 오류에도 지도 유지, 재시도 로딩 피드백
  - follow 모드(사용자 제스처 시 해제 + 내 위치 FAB), 카메라 줌 리셋 버그 해소, MapController dispose, iOS 권한 키 추가
  - 테스트 보강: 공용 헬퍼 추출, 앱 루트 스모크/재시도 상호작용/설정 버튼/지도 유지 테스트 (총 10건 통과)
- Chrome에서 실행 확인: 지도+내 위치 마커 정상 동작 (데스크톱 Chrome은 Wi-Fi/IP 기반 위치라 부정확할 수 있음 — 실기기 GPS와 무관)

### 다음 세션에서 할 일
- Phase 2: Firebase 연동 (Auth, Firestore, Storage) 논의 및 착수
- Android 실기기 테스트 준비 (커맨드라인 SDK 도구 + USB 디버깅, Android Studio 불필요)

---

## 2026-07-05

### 완료
- 로컬 개발 환경 연결: 레포 clone (`C:\Users\andyp\projects\gps-meeting-app`), git 전역 계정 설정, push 권한 검증
- 문서 분리: README.md(목적/컨셉/로드맵/결정 로그) ↔ CLAUDE.md(개발 룰)
- CLAUDE.md에 Advisor/Worker 모델 역할 분담 규칙 추가 (Advisor=판단·검증, Worker=Opus 서브에이전트로 구현 위임)
- 역할 분담 ↔ 워크플로우 섹션 중복·충돌 정리 (미설치 feature-dev 에이전트 참조 제거)
- Flutter SDK 3.44.4 (stable) 설치: `%USERPROFILE%\dev\flutter`, 사용자 PATH 등록
- `flutter doctor` 점검: Flutter/Chrome/네트워크 정상. Android toolchain 미설치, Visual Studio 미설치(모바일 타깃이라 불필요)

### 다음 세션에서 할 일
- Phase 1: 폴더 구조 설계 (`lib/core`, `lib/features`, `lib/shared`)
- pubspec.yaml에 초기 패키지 추가 (firebase_core, geolocator, go_router 등)
- Firebase 프로젝트 연동 논의
- 당분간 Chrome(`flutter run -d chrome`)으로 개발, Android 테스트는 Phase 2쯤 커맨드라인 도구 + 실기기 연결 예정

---

## 2026-07-01

### 완료
- Flutter 프로젝트 초기 생성 (`gps_meeting_app`)
- CLAUDE.md 작성 (프로젝트 방향, 단계별 계획)
- GitHub 레포지토리 생성 및 초기 커밋

### 다음 세션에서 할 일
- Phase 1: 폴더 구조 설계 (`lib/core`, `lib/features`, `lib/shared`)
- pubspec.yaml에 초기 패키지 추가 (firebase_core, geolocator, go_router 등)
- Firebase 프로젝트 연동 논의
