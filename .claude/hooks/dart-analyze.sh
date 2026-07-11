#!/bin/sh
# PostToolUse 훅: .dart 파일이 수정되면 프로젝트 전체 dart analyze 실행.
# stdin으로 도구 호출 JSON이 들어온다 (jq 없이 grep으로 .dart 여부만 판별).
# 분석 실패 시 exit 2로 에이전트에게 오류를 피드백한다(기계 게이트).
# ponytail: 전체 분석 — 코드베이스가 커져 느려지면 stdin JSON에서 파일 경로만 추출해 단일 파일 분석으로 전환
grep -q '\.dart"' || exit 0

. "$CLAUDE_PROJECT_DIR/.claude/hooks/find-flutter-tool.sh"
DART=$(find_tool dart) || { echo 'dart를 찾지 못해 분석을 건너뜀 — find-flutter-tool.sh에 경로를 추가하라' >&2; exit 2; }

cd "$CLAUDE_PROJECT_DIR" || exit 0
if ! OUT=$("$DART" analyze 2>&1); then
  echo "$OUT" | grep -v '^Analyzing' >&2
  exit 2
fi
exit 0
