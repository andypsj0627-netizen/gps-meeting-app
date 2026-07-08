# 프로젝트 작업 로그

세션별 작업 내용을 기록합니다. 최신 항목이 위에 위치합니다.

---

## 2026-07-08

### 완료 (3차: 웹 결함 수정 + 조우 펄스 링)
- 전 세션에서 발견한 웹 결함 수정: 첫 지도 렌더 전 위치 연속 방출 시 follow 리스너가 미마운트 컨트롤러의 camera를 읽던 예외
  - follow 리스너를 조우 리스너와 같은 data phase 조건부 등록으로 전환. 회귀 테스트는 수정 전 코드에서 실패 확인 후 추가(TDD)
  - 근거 확인: flutter_map 8.3.1은 외부 컨트롤러 camera를 FlutterMap.initState에서야 초기화하며, 최초 attach 후에는 다시 null이 되지 않음
- 조우 지점 펄스 링 애니메이션 (사용자 요청: 스낵바 외 시각 효과, 스타일 선택: 파문)
  - `EncounterEffectsLayer`: 조우 배치 수신 → 두 참가자 중간 지점에 1.5초 확산 파문 2회 → 재생 완료 시 자가 제거. 스낵바와 공존
- 코드 리뷰(8앵글 병렬 → 후보 27건 → 4검증자) 후 3건 수정: 테스트 펌프 헬퍼 공용 추출(`pumpMapScreenWithService`), AnimatedBuilder child로 프레임당 장식 재할당 제거, follow 가드 주석의 안전 근거 정확화
  - 주요 기각: 펄스 무한 누적(히스테리시스가 재발화를 10초+ 간격으로 제한, 상한 C(11,2)=55), 리플 랩 깜빡임(랩 순간 양쪽 비가시 — 의도된 파문 시작)
- `flutter test` 46건 통과

### 설계 부채 추가 (Phase 3 provider 재설계에 병합)
- "조우 체인은 data phase에서만 구독" 불변식이 세 가지 방식으로 흩어져 인코딩됨: 명시 가드 2곳(follow·스낵바 리스너) + `EncounterEffectsLayer`의 암묵적 마운트 위치(_MapView 안). 세 번째 조우 반응(소리/햅틱 등)을 추가할 때 가드를 재발견하지 못하면 기존 부채의 provider 고착이 재발 — 반응 팬아웃을 단일 가드 지점(디스패처)으로 모을 것
- 보류 판정(저심각): `_startFollowing`의 camera 접근이 FAB의 data phase 렌더 조건에만 암묵 의존, 재시도 복구 직후 follow 1건 지연(자가 치유)

### 완료 (2차: 쌍 단위 조우 확장)
- 조우 판정을 나↔사용자에서 **모든 참가자 쌍(pairwise)**으로 확장 (사용자 요청: 마커끼리도 조우)
  - `EncounterDetector`: 나를 `selfId='me'` 참가자로 포함, 무순서 쌍 키(`'a|b'` 정렬)로 히스테리시스 관리
  - `EncounterEvent`: `user` 단일 → `a`/`b` 쌍 (factory에서 순서 정규화: 나는 항상 a, 타인끼리는 id 정렬순), `involvesMe`/`partner` 게터
  - 스낵바 3분기: 나 포함 1건 "A님과 12m…", 타인끼리 1건 "A님과 B님이 만났어요!", 여러 건 "만남 K건: 나↔A, B↔C"
- 조우 반경 임시 확대: 진입 15→60m, 해제 40→100m (`simulationSpeedMultiplier`처럼 관찰 편의용, **출시 전 15/40 복원**)
  - detector 단위 테스트가 AppConstants 기본값에 의존하던 문제 발견 → 명시적 15/40 주입으로 수정 (상수 튜닝에 테스트 불변)
- 크롬 실행으로 동작 확인 (나↔마커, 마커↔마커 조우 스낵바), `flutter test` 42건 통과
- 참고: 쌍 조우 확장분은 코드 리뷰 생략하고 커밋 (사용자 결정, 동작 확인으로 갈음)

### 발견된 기존 결함 (미수정)
- 웹에서 첫 프레임 전에 위치 스트림이 연속 방출되면 follow 리스너가 미렌더 `_mapController.camera`를 읽어 예외 (map_screen.dart:113, Riverpod이 잡아 동작엔 지장 없음). "flutter_map 8.x 동기 초기화라 방어 불필요" 주석의 가정이 웹에서 깨짐 — 다음 세션에서 수정 검토

### 완료
- 조우(만남) 감지 + 스낵바 알림 (7/7 설계 승인 대기 건): 근처 사용자가 15m 이내 진입 시 알림, 40m 이탈 후 재진입해야 재발생(히스테리시스)
  - `EncounterDetector` 순수 로직(반경/시계 주입 가능) + `EncounterEvent` 모델 + `encounterEventsProvider`(재계산 1회당 이벤트를 배치 `List`로 방출)
  - 스낵바 UI(사용자 선택): 1명이면 거리 포함, 동시 여러 명이면 이름을 합쳐 1개로 표시
- 코드 리뷰(8앵글 병렬 → 후보 10건 검증 → 7건 확정) 후 6건 수정:
  - 유령 조우 방지(내 위치도 `unwrapPrevious`로 대칭 보호), 동시 조우 스낵바 소실 해소(배치 방출), 죽은 간접층(`encounterDetectorProvider`) 제거, `EncounterEvent`의 미사용 `==`/`hashCode` 제거(double 정밀도 함정), 테스트 헬퍼 통합(`testDistance`/`userAt`), 테스트 공백 3건 보강(동시 조우 UI, 재시도 후 조우 재개, 배치 방출)
- `flutter analyze` 이슈 0 / `flutter test` 38건 통과

### 설계 부채 (Phase 3에서 해결)
- 조우 체인의 생존/재시도 안전성이 MapScreen의 data-phase 가드에만 의존 (리뷰 확정, 수정 보류)
  - `nearbyUsersProvider`가 `positionStreamProvider`를 read(watch 아님)+`retry: null`로 쓰므로, 미래에 다른 구독자(푸시 알림 등)가 조우 스트림을 무조건 listen하면 위치 오류 후 재시도해도 nearby가 AsyncError에 고착됨
  - Firestore 지오쿼리로 교체할 때 provider 그래프 차원에서 재설계할 것 (예: 재시도 신호 provider를 watch)

### 다음 세션에서 할 일
- Android 실기기 연결 테스트 (USB 디버깅 켜고 연결만 하면 됨)
- Phase 2: Firebase 프로젝트 연동 논의

---

## 2026-07-07

### 완료
- 가상 근처 사용자 시뮬레이션 (A/B/C): `NearbyUsersService` 추상화(Phase 3에서 Firestore로 교체 예정) + `FakeNearbyUsersService`
  - v1 랜덤 워크 → 사용자 피드백 반영해 v2로 개선: OSRM 도보 경로를 따라 걷는 상태머신(목적지 선정 → 경로 요청 → 보행 1.1~1.5m/s, 300ms 틱 보간 → 도착 후 대기)
  - `RoutePlanner` 추상화 + `OsrmRoutePlanner` (실패 시 직선 폴백 + 10~20초 백오프)
- 코드 리뷰(8앵글 병렬 + 검증)로 findings 10건 확정 → 전부 수정: autoDispose 수명주기, 유령 마커(unwrapPrevious), 마커 id 키잉/팔레트 순환, 목적지 최소 거리, 유휴 방출 억제, 죽은 코드 제거 등
- 맥 Android 테스트 환경 구축: SDK 36 + 라이선스 수락 완료 (기기 연결만 하면 됨)
- 테스트 편의 조정: 시뮬레이션 속도 배율 도입(`AppConstants.simulationSpeedMultiplier = 5.0`, 출시 전 1.0 예정), 가상 사용자 A~J 10명으로 확장
- `flutter analyze` 이슈 0 / `flutter test` 23건 통과

### 다음 기능 (설계 승인 대기)
- 마커 만남(조우) 감지 + 알림: 15m 접근 시 이벤트, 40m 히스테리시스로 스팸 방지, 알림 UI(스낵바 vs 다이얼로그) 결정 대기

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
