#!/bin/sh
# flutter/dart 실행 파일을 머신별 설치 경로에서 찾아 경로를 출력한다.
# 사용법: find_tool dart  →  발견 못 하면 빈 문자열
#
# 후보 순서: PATH → Windows(~/dev/flutter, .bat) → Mac(~/development/flutter)
# 새 머신에서 다른 경로에 설치했다면 아래 후보에 한 줄 추가하면 된다.
find_tool() {
  for c in \
    "$(command -v "$1" 2>/dev/null)" \
    "$HOME/dev/flutter/bin/$1.bat" \
    "$HOME/development/flutter/bin/$1"; do
    if [ -n "$c" ] && [ -x "$c" ]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

# 맥에서 Xcode.app이 손상돼 xcrun이 실패하면(objective_c 네이티브 에셋 빌드가
# 죽음) CommandLineTools를 DEVELOPER_DIR로 강제하는 xcrun shim을 PATH 앞에 끼운다.
# flutter 훅 러너는 환경변수를 필터링하지만 PATH는 전달하므로 shim만 유효하다.
# xcrun이 정상인 머신(윈도우 포함)에서는 아무것도 하지 않는다.
#
# source로 호출하는 것을 전제로, 만든 shim 디렉토리를 전역 변수 SHIM_DIR에 남기고
# PATH를 export한다. 호출자는 SHIM_DIR로 종료 시 정리(trap)할 수 있다.
setup_xcrun_shim() {
  if [ "$(uname)" = "Darwin" ] && ! xcrun --show-sdk-path >/dev/null 2>&1; then
    SHIM_DIR=$(mktemp -d)
    printf '#!/bin/sh\nDEVELOPER_DIR=/Library/Developer/CommandLineTools exec /usr/bin/xcrun "$@"\n' \
      > "$SHIM_DIR/xcrun"
    chmod +x "$SHIM_DIR/xcrun"
    PATH="$SHIM_DIR:$PATH"
    export PATH
  fi
}
