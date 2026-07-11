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
