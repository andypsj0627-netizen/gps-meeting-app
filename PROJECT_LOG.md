# 프로젝트 작업 로그

세션별 작업 내용을 기록합니다. 최신 항목이 위에 위치합니다.

---

## 2026-07-14

### 완료
- CLAUDE.md에 "구현 최소주의 사다리" 추가 — ponytail 플러그인(DietrichGebert/ponytail) 검토 후 플러그인 설치 대신 원칙만 Worker 브리프 기준에 이식 (상시 주입·전역 적용이 기존 워크플로우와 충돌한다고 판단)
- 지도 확대/축소 버튼: 우하단 소형 FAB 2개 + 기존 내 위치 버튼 유지, MapOptions minZoom 3/maxZoom 19(OSM 한계), 줌 버튼은 follow 모드를 해제하지 않음
- 가상 사용자 5→10명 확장 (`defaultNearbyUsers` user6~10 + `_simUserCount` 10)
- **마커 산 관통 문제 해결** (사용자 보고 → 원인 2겹):
  - 폴백 직선 보행 제거: 경로 계산 실패 시 직선을 걷지 않고 10~20s 백오프 후 새 목적지 재시도 (Worker/Opus 위임), 폴백 debugPrint 가시화
  - **진짜 주범은 라우팅 서버**: router.project-osrm.org 데모는 car 전용이라 `foot`이 무시되어 마커가 자동차용 터널로 산을 통과 (응답 duration 15.3m/s로 확인) → FOSSGIS `routing.openstreetmap.de/routed-foot`(진짜 보행자 프로필, CORS 확인)로 교체
- 코드 리뷰(8앵글 병렬 + 5건 검증 에이전트) → 확정 10건 전부 수정 (Worker/Opus 위임, Advisor 검증):
  - 시드 갭: 컬렉션 비었을 때만 시드 → 누락 id 항상 upsert (기존 환경에서 user6~10이 영원히 안 생기던 문제)
  - 경로 접합: `[현 위치, ...경로]`로 스폰 직후 첫 경로의 직선 지형 관통 뿌리 해결
  - 조우 스폰 기준선: 최초 판정은 이벤트 없이 활성 집합만 시드 (지도 진입 즉시 스낵바 86% 확률 문제, 몬테카를로 검증. 해금 색상은 유지되고 알림만 억제)
  - 시작 지터: `initialRequestJitter`(기본 3s)로 구독 직후 동시 HTTP 10건 버스트 분산
  - 마커 팔레트 10색 + 안정 해시(codeUnits 합 — 웹/VM 색 일관), 줌 버튼 위젯 테스트 3건, waiting 상태 문서/상수 정리, 플래너 계약 doc 정정, 동어반복 단언 삭제, ponytail 주석
  - 주요 기각: 새 서버 CORS 우려(curl+실행 로그로 정상 확인), 오프라인 시 마커 동결(의도된 트레이드오프)
- README에 **위치 데이터 모델 확정** 섹션 추가 (Phase 3 설계 기준): presence 분리, geohash/퍼징/정밀 3층위, geohash 접두사 쿼리, 쓰기 주기, 이력 TTL 30일 + Phase 4에 서버 판정 전환·위치정보법 신고 항목
- `flutter test` 83건 전체 통과, dart analyze 클린

### 다음 세션에서 할 일
- 프로필 생성/수정 화면 (이름/나이/성별 — 문서 부재를 정상 케이스로 취급, set() 자연 복구)
- 익명 인증 검토: 로그인 우회 모드에서 Firestore 실데이터 읽기용 (콘솔에서 익명 로그인 활성화 필요)
- 시뮬레이션 속도 배율(5.0) 하향 검토 — 공개 라우팅 서버 요청량 절감
- Android 실기기 테스트 준비

---

## 2026-07-13

### 완료 (2차: 지도 기능 테스트 + 조우 재잠금 + 로그인 우회)
- 크롬 실동작 확인 완료: 로그인 → 지도 전환, 시뮬레이션 마커, 조우 해금(색+프로필 탭) 동작 확인 (사용자 확인)
- 조우 재잠금 (사용자 요청): 해금을 sticky 누적 → **현재 조우 활성 상태 파생**으로 전환
  - 조우 반경(60m) 진입 시 해금, 해제 반경(100m) 이탈 또는 목록 소실 시 재잠금(회색+탭 무반응). 여러 쌍에 걸친 사용자는 마지막 쌍 해제 시 잠김
  - `EncounterDetector.activeUserIds` 게터 + `encounterUpdatesProvider`(이벤트+활성 집합을 단일 소스로 방출, 재잠금은 이벤트 없이 집합 변화로 전파) 신설, `encounterEventsProvider`는 파생으로 재구현(스낵바·펄스 소비처 무변경)
  - 부수 효과: 조우 반응이 단일 팬아웃 지점으로 모여 7/8 "조우 체인 가드 분산" 설계 부채 부분 해소
- 로그인 우회 플래그 (사용자 요청: 로그인 화면은 나중에 디자인 후 재활성화):
  - `AppConstants.requireLogin = false` — 앱 시작 시 로그인 화면 없이 바로 지도. **로그인 화면 작업 재개 시 true 복원**
  - 우회 시 인증 배선 자체를 생략(라우터 조기 반환), 로그아웃 버튼 숨김, Auth 코드는 전부 보존
  - 우회 모드에서 Firestore 프로필은 인증 룰에 막혀 기본 5인 fallback으로 동작(화면상 동일)
- `flutter test` 75건 통과 (재잠금 6건 + 우회 1건 신규), dart analyze 클린

### 완료 (1차: Firebase Auth)
- Firebase Auth (이메일/비밀번호) — 설계 승인 후 Worker/Opus 구현, Advisor 검증:
  - `AuthUser` 경계 모델(firebase_auth의 User 미노출), `AuthRepository`(signIn/signUp/signOut), `AuthFailure` 예외(코드→한국어 메시지, models로 승격)
  - 라우터 provider 전환: /splash·/login·/ + redirect (GoRouter 1회 생성, ValueNotifier+refreshListenable로 재평가 — 재생성 시 네비게이션 스택 초기화 함정 회피)
  - 로그인/회원가입 토글 폼, 가입 시 users/{uid} 최소 문서({email, createdAt}) 자동 생성, 지도 AppBar에 로그아웃(임시 배치)
  - 시뮬레이션 마커와 실제 회원 문서 분리: 시드에 `sim: true`, 로드는 where(sim==true)
- 코드 리뷰(8앵글 → 후보 34건 → 15건 검증 → 확정 11건) 후 전부 수정:
  - 보안: Firestore 룰 sim 시드 절의 타인 문서 덮어쓰기 구멍(resource 가드 추가), 컬렉션 열거로 전 회원 이메일 유출(get/list 분리, list는 sim==true 한정)
  - 복구 경로: Firebase init 실패 시 로그인 화면 영구 고립 → 스플래시 에러 UI + 재시도(invalidate), init 무한 대기 → 10초 타임아웃
  - 프라이버시: 로그아웃 후 GPS 스트림 지속(Riverpod3 pause는 geolocator 네이티브에 안 닿음) → positionStreamProvider autoDispose 전환
  - 기타: GoRouter dispose 누락(FIFO 순서로 등록), signOut 에러 스낵바, 테스트 pump/override 헬퍼 통합(pumpApp/pumpUntilFound), re-export shim 제거, 낡은 lazy init 주석 정정, /splash NoTransitionPage, xcrun shim을 find-flutter-tool.sh 공용 함수로 이동
  - 주요 기각: 릴리즈 sim 마이그레이션 공백(의도된 kDebugMode 가드), signUp 스키마 충돌(sim 필터+null-safe 파싱이 방어)
- 세션 시작 Git 동기화 자동화: SessionStart 훅이 fetch 후 behind/ahead 상태를 컨텍스트로 주입 (프로젝트 레벨로 이동, 윈도우에도 자동 적용)
- 테스트 68건 통과 (행 이슈 2건 수정: 단일 구독 StreamController의 리스너 없는 close() 무한 대기 → broadcast, pumpAndSettle vs 무한 스피너 → 유한 pumpUntilFound), dart analyze 클린

### 설계 부채 추가
- 미로그인 redirect가 원래 목적지(state.uri)를 버림 — 보호 라우트가 2개 이상 되거나 딥링크 도입 시 from 파라미터 보존 구현 (현재는 보호 대상이 '/' 하나라 피해 0)
- Firebase init을 main()에서 선시작(warm-up)하면 스플래시 체류 단축 가능 — 실측 후 판단
- signUp의 프로필 문서 생성 실패는 debugPrint로만 삼킴 — 프로필 화면(다음 작업)이 문서 부재를 정상 케이스로 취급하고 set()으로 자연 복구해야 함 (브리프에 전제 명시할 것)

### 배포·운영 (커밋 후 진행)
- **firestore.rules 배포 완료** (이 맥에서 `npx firebase-tools@latest`로 — 전역 firebase-tools는 Node 25와 비호환이라 npx 사용, CLI 재인증(`login --reauth`) 필요했음)
- 옛 시드 문서 user1~user5 삭제 (7/11 시드분은 `sim` 필드가 없어 새 룰의 resource 가드에 걸려 덮어쓰기 불가 — 삭제 후 다음 디버그 실행 시 sim:true로 재시드됨)
- 크롬 실동작 확인 (부분): 앱 기동·스플래시→로그인 라우팅 정상, 10분 로그 감시에서 Firebase 에러(permission-denied 등) 0건. 회원가입→지도→마커 5개→로그아웃 전체 흐름 확인은 다음 세션에서 마저
- 참고: 텍스트 필드에 한글 입력 시 Flutter 웹 엔진 IME 조합 어서션 발생 — 프레임워크 이슈(디버그 모드 한정), 우리 코드 무관

### 다음 세션에서 할 일
- 크롬 전체 흐름 확인 마무리: 회원가입 → 지도 진입 → 시뮬레이션 마커 5개(새 룰에서 시드/조회 통과 신호) → 로그아웃 → 재로그인
- 프로필 생성/수정 화면 (이름/나이/성별 입력 — 가입 문서의 name 공백을 채우는 작업. 문서 부재를 정상 케이스로 취급하고 set()으로 자연 복구할 것 — 설계 부채 참고)
- 조우 sticky 상태 이중 저장(Set + bool) 단순화 검토 (7/11 리뷰 지적)
- Android 실기기 테스트 준비

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
