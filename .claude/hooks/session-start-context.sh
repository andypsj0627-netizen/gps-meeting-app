#!/bin/sh
# SessionStart 훅: 원격 동기화 상태 확인(fetch) + 프로젝트 컨텍스트 주입
# 맥/윈도우 두 환경을 오가며 작업하므로, 세션 시작 시점에 원격과의 차이를
# 반드시 컨텍스트에 실어 보낸다. pull 실행 여부는 세션(에이전트)이 판단한다.
# SessionStart 훅은 stdout이 그대로 컨텍스트로 주입되므로 jq 불필요.
cd "$CLAUDE_PROJECT_DIR" || exit 0

echo "=== GPS Meeting App Context ==="
echo ""
echo "## Git 동기화 상태 (SessionStart 훅이 방금 fetch한 결과)"

if git fetch --quiet --prune 2>/dev/null; then
  UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  if [ -n "$UPSTREAM" ]; then
    BEHIND=$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)
    AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
    if [ "$BEHIND" -gt 0 ]; then
      echo "[경고] 로컬이 원격($UPSTREAM)보다 ${BEHIND}개 커밋 뒤처짐 — 다른 기기에서 작업한 내용일 가능성 높음."
      echo "새 커밋:"
      git log --oneline "HEAD..$UPSTREAM"
      echo "지시: 작업 트리가 깨끗하면 어떤 작업이든 시작하기 전에 'git pull --ff-only'로 먼저 동기화할 것. 커밋 안 된 변경이 있거나 fast-forward가 불가하면 사용자에게 알리고 처리 방법을 확인할 것."
    fi
    if [ "$AHEAD" -gt 0 ]; then
      echo "로컬이 원격보다 ${AHEAD}개 커밋 앞섬 — 푸시 안 된 작업 있음. 세션 종료 전 푸시 여부를 사용자와 확인할 것."
    fi
    if [ "$BEHIND" -eq 0 ] && [ "$AHEAD" -eq 0 ]; then
      echo "로컬과 원격($UPSTREAM)이 동기화된 상태."
    fi
  else
    echo "업스트림 브랜치가 설정되지 않음 — 원격 비교 불가."
  fi
else
  echo "[경고] git fetch 실패(오프라인 또는 인증 문제). 원격 상태 미확인 — 다른 기기의 커밋이 있을 수 있으니 네트워크 복구 후 fetch할 것. 미확인 상태로 푸시 금지."
fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "참고: 작업 트리에 커밋 안 된 변경이 있음."
fi

if [ -f CLAUDE.md ]; then
  echo ""
  cat CLAUDE.md
fi
if [ -f PROJECT_LOG.md ]; then
  echo ""
  echo "---"
  cat PROJECT_LOG.md
fi
