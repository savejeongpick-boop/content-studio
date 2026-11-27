#!/bin/sh
# GitHub Pages 배포 스크립트 — 5채널 콘텐츠 스튜디오
# 사용법:  sh projects/github-pages-deploy/deploy.sh
# 저장소(savejeongpick-boop/content-studio)가 없으면 만들고, 파일을 올리고, Pages를 켜고, 실제 HTTP 200을 확인한다.
set -u

OWNER="savejeongpick-boop"
REPO="content-studio"
BRANCH="main"
BASE="https://${OWNER}.github.io/${REPO}"
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== 1) 저장소 확인: ${OWNER}/${REPO}"
if gh repo view "${OWNER}/${REPO}" >/dev/null 2>&1; then
  echo "   이미 존재함"
else
  echo "   없음 → 생성 시도"
  OUT="$(gh repo create "${OWNER}/${REPO}" --public --description "5채널 콘텐츠 스튜디오" 2>&1)"
  RC=$?
  echo "   결과: ${OUT}"
  if [ $RC -ne 0 ] || ! gh repo view "${OWNER}/${REPO}" >/dev/null 2>&1; then
    echo "!! 저장소를 만들 수 없습니다 (권한). 이 경우 웹에서 빈 저장소를 만든 뒤 다시 실행하세요."
    echo "   https://github.com/new  →  Repository name: ${REPO}  /  Public  /  README 없이 생성"
    exit 10
  fi
fi

echo "== 2) git 초기화 및 커밋"
if [ ! -d "${DIR}/.git" ]; then
  git -C "${DIR}" init -b "${BRANCH}" >/dev/null 2>&1 || git -C "${DIR}" init >/dev/null 2>&1
fi
git -C "${DIR}" checkout -B "${BRANCH}" >/dev/null 2>&1
git -C "${DIR}" add -A
git -C "${DIR}" -c user.name="savejeongpick-boop" -c user.email="savejeongpick-boop@users.noreply.github.com" \
  commit -m "5채널 콘텐츠 스튜디오 HTML 배포 ($(date +%Y-%m-%d))" >/dev/null 2>&1 || echo "   (변경 없음 또는 이미 커밋됨)"
git -C "${DIR}" remote remove origin >/dev/null 2>&1
git -C "${DIR}" remote add origin "https://github.com/${OWNER}/${REPO}.git"

echo "== 3) 푸시"
if ! git -C "${DIR}" push -u origin "${BRANCH}" 2>&1; then
  echo "!! 푸시 실패. 위 git 오류 메시지를 그대로 보고하세요."
  exit 11
fi

echo "== 4) GitHub Pages 켜기"
PG="$(gh api "repos/${OWNER}/${REPO}/pages" 2>&1)"
case "${PG}" in
  *'"html_url"'*) echo "   이미 켜져 있음";;
  *)
    gh api -X POST "repos/${OWNER}/${REPO}/pages" \
      -H "Accept: application/vnd.github+json" \
      -f 'source[branch]='"${BRANCH}" -f 'source[path]=/' 2>&1 | head -5 || true
    ;;
esac

echo "== 5) 실제 접속 확인 (최대 10분)"
i=0
while [ $i -lt 40 ]; do
  C1="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/")"
  C2="$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/ai-prompts-hub.html")"
  echo "   [${i}] ${BASE}/ → ${C1}   ai-prompts-hub.html → ${C2}"
  if [ "${C1}" = "200" ] && [ "${C2}" = "200" ]; then
    echo "OK  ${BASE}/"
    echo "OK  ${BASE}/ai-prompts-hub.html"
    exit 0
  fi
  i=$((i + 1))
  sleep 15
done

echo "?? 10분 안에 200이 확인되지 않았습니다. Pages 상태:" 
gh api "repos/${OWNER}/${REPO}/pages" 2>&1 | head -10
echo "임시 대체 링크(렌더링):"
echo "   https://raw.githack.com/${OWNER}/${REPO}/${BRANCH}/index.html"
echo "   https://raw.githack.com/${OWNER}/${REPO}/${BRANCH}/ai-prompts-hub.html"
exit 12
