#!/bin/sh
# Stop 훅: 변경사항이 있으면 flutter test를 실행하는 하드 게이트.
# 실패 시 exit 2로 세션 종료를 차단하고 수정을 요구한다. 커밋은 하지 않는다.
INPUT=$(cat)
if echo "$INPUT" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0  # 게이트 재진입 무한 루프 방지
fi

cd "$CLAUDE_PROJECT_DIR" || exit 0

# 작업 트리가 깨끗하면 테스트 불필요
git diff --quiet && git diff --cached --quiet \
  && [ -z "$(git ls-files --others --exclude-standard)" ] && exit 0

. "$CLAUDE_PROJECT_DIR/.claude/hooks/find-flutter-tool.sh"
# 게이트는 조용히 무력화되면 안 된다 — flutter가 없으면 실패로 처리한다.
FLUTTER=$(find_tool flutter) || {
  echo 'flutter를 찾지 못해 테스트 게이트를 실행할 수 없음 — .claude/hooks/find-flutter-tool.sh에 설치 경로를 추가하라' >&2
  exit 2
}

# 맥 Xcode 손상 시 xcrun shim을 PATH에 끼운다(정상 머신에선 no-op).
# SHIM_DIR을 만들면 종료 시 정리한다(비어 있으면 rm 생략).
trap 'test -n "$SHIM_DIR" && rm -rf "$SHIM_DIR"' EXIT
setup_xcrun_shim

"$FLUTTER" test 1>&2 || { echo 'flutter test 실패 — 세션 종료 전 수정 필요' >&2; exit 2; }
