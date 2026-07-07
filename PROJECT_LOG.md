# 프로젝트 작업 로그

세션별 작업 내용을 기록합니다. 최신 항목이 위에 위치합니다.

---

## 2026-07-07

### 완료
- 가상 근처 사용자 시뮬레이션 (A/B/C): `NearbyUsersService` 추상화(Phase 3에서 Firestore로 교체 예정) + `FakeNearbyUsersService`
  - v1 랜덤 워크 → 사용자 피드백 반영해 v2로 개선: OSRM 도보 경로를 따라 걷는 상태머신(목적지 선정 → 경로 요청 → 보행 1.1~1.5m/s, 300ms 틱 보간 → 도착 후 대기)
  - `RoutePlanner` 추상화 + `OsrmRoutePlanner` (실패 시 직선 폴백 + 10~20초 백오프)
- 코드 리뷰(8앵글 병렬 + 검증)로 findings 10건 확정 → 전부 수정: autoDispose 수명주기, 유령 마커(unwrapPrevious), 마커 id 키잉/팔레트 순환, 목적지 최소 거리, 유휴 방출 억제, 죽은 코드 제거 등
- 맥 Android 테스트 환경 구축: SDK 36 + 라이선스 수락 완료 (기기 연결만 하면 됨)
- `flutter analyze` 이슈 0 / `flutter test` 23건 통과

### 다음 세션에서 할 일
- Android 실기기 연결 테스트 (USB 디버깅 켜고 연결만 하면 됨)
- 아이폰 테스트는 App Store에서 Xcode 업데이트 후 가능 (이 맥의 Xcode 14.3.1이 손상 상태)
- Phase 2: Firebase 프로젝트 연동 논의

---

## 2026-07-06

### 완료
- 폴더 구조 보완: `lib/features/{auth,chat,profile}`, `lib/shared` 등 빈 모듈 폴더 생성 (`.gitkeep`)
- Firebase 패키지 추가 (Phase 2 대비): firebase_core 4.11.0, firebase_auth 6.5.4, cloud_firestore 6.6.0, firebase_storage 13.4.3
- 맥 로컬 Flutter SDK 업그레이드: 3.13.1 → 3.44.4 (Dart 3.12.2)
  - 로컬 stable 브랜치가 원격과 갈라져 있어 `flutter upgrade` 실패 → `git reset --hard origin/stable`로 해결
- flutter_lints 6.0.0으로 업그레이드
- 7/5 세션(윈도우 환경)의 지도 기능 작업과 병합, `flutter analyze` / `flutter test` 통과 확인

### 다음 세션에서 할 일
- Phase 2: Firebase 프로젝트 연동 논의 (콘솔에서 프로젝트 생성 → flutterfire configure)

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
