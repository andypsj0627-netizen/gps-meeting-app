# 개발 환경 설정

어느 기기에서든 동일한 환경으로 개발을 시작하기 위한 가이드.
새 기기에서는 이 문서 순서대로 진행하면 된다.

## 요구 사항

| 항목 | 버전/기준 | 비고 |
|------|-----------|------|
| Flutter SDK | **stable 채널** (검증된 버전: 3.44.4) | 아래 설치 방법 참고 |
| Git | 최신 | Flutter 설치에도 필요 |
| Chrome | 최신 | 웹 테스트 실행용 (`flutter run -d chrome`) |
| Android SDK | 커맨드라인 도구 (선택) | 실기기 테스트 시에만. Android Studio 불필요 |

주요 패키지 버전은 `pubspec.yaml`/`pubspec.lock`에 고정되어 있으므로
`flutter pub get`만 실행하면 동일하게 재현된다.
(flutter_riverpod 3.x, flutter_map 8.x, geolocator 14.x, go_router 17.x)

## 1. Flutter 설치 (Windows 기준)

winget에 Flutter SDK 패키지가 없으므로 git clone 방식을 사용한다.

```powershell
# stable 채널 clone (약 2~3분)
git clone -b stable https://github.com/flutter/flutter.git "$env:USERPROFILE\dev\flutter"

# 사용자 PATH에 등록 (새 터미널부터 적용)
$flutterBin = "$env:USERPROFILE\dev\flutter\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterBin", "User")

# 첫 실행 시 Dart SDK 자동 다운로드 + 환경 점검
flutter doctor
```

macOS/Linux는 [공식 문서](https://docs.flutter.dev/get-started/install) 참고
(동일하게 stable 채널 사용).

`flutter doctor` 결과에서 이 프로젝트에 필요한 것:
- ✅ Flutter, Chrome — 필수
- ⬜ Android toolchain — 실기기 테스트 시에만 (아래 3번)
- ❌ Visual Studio — 불필요 (모바일 타깃, Windows 데스크톱 빌드 안 함)

## 2. 프로젝트 시작

```powershell
git clone https://github.com/andypsj0627-netizen/gps-meeting-app.git
cd gps-meeting-app
flutter pub get      # pubspec.lock 기준으로 패키지 설치
dart analyze         # 이슈 0건이어야 정상
flutter test         # 전체 통과해야 정상
flutter run -d chrome  # 웹으로 실행
```

> 데스크톱 Chrome의 위치는 Wi-Fi/IP 기반 추정이라 부정확할 수 있다
> (VPN·유선랜 환경에서 다른 지역으로 표시되기도 함). 실제 GPS 트래킹
> 검증은 반드시 실기기에서 한다.

## 3. Android 실기기 테스트 (선택)

Android Studio 없이 커맨드라인 도구만으로 가능하다.

1. JDK 17 + Android SDK cmdline-tools 설치 후 `flutter config --android-sdk <경로>`
2. `flutter doctor --android-licenses`로 라이선스 동의
3. 폰: 설정 → 휴대전화 정보 → 빌드번호 7번 연타(개발자 모드) → USB 디버깅 켜기
4. USB 연결 후 `flutter devices`로 인식 확인 → `flutter run -d <기기ID>`
5. 케이블 없이 돌아다니며 테스트하려면: `flutter build apk --debug` 후
   `build/app/outputs/flutter-apk/app-debug.apk`를 폰에 설치

## 검증된 환경

| 날짜 | OS | Flutter | 상태 |
|------|----|---------|------|
| 2026-07-05 | Windows 11 Pro (25H2) | 3.44.4 stable | Chrome 실행 확인 |
