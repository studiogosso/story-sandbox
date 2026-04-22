#!/bin/bash
# Cinema Dice — 評価スクリプト
# pool/*.jsonl を Claude Sonnet に渡し、TOP3 を厚くレビュー
# 出力: top/YYYY-MM-DD_{recipe}.md

set -euo pipefail
cd "$(dirname "$0")"

INPUT="${1:-}"
if [[ -z "${INPUT}" || ! -f "${INPUT}" ]]; then
  echo "usage: evaluate.sh pool/YYYY-MM-DD_xxx.jsonl"
  echo ""
  echo "利用可能なpool:"
  ls -1t pool/*.jsonl 2>/dev/null | head -10
  exit 1
fi

TODAY=$(date +%Y-%m-%d)
BASE=$(basename "${INPUT}" .jsonl)
OUTPUT="top/${BASE}_review.md"
LINES=$(wc -l < "${INPUT}")

mkdir -p top

echo "📖 Cinema Dice — 評価開始"
echo "  入力:  ${INPUT} (${LINES}行)"
echo "  出力:  ${OUTPUT}"
echo ""

# JSONL → Claude に渡す
PROMPT=$(cat <<EOF
以下は映画企画のJSONLデータ(${LINES}本)。各本は {id, recipe, axes, concept, score} の構造。
scoreのtotalが高い順にTOP5を選び、上位3本を厚くレビューせよ。

## 入力
\`\`\`jsonl
$(cat "${INPUT}")
\`\`\`

## 出力フォーマット (厳守)
# ${BASE} — Cinema Dice 評価レポート

**生成本数**: ${LINES}本 / **生成日時**: $(date '+%Y-%m-%d %H:%M')

## スコア分布
- 46点以上: N本
- 40-45点: N本
- 30-39点: N本
- 29点以下: N本

## TOP5 一覧
| 順位 | 点 | コンセプト |
|---|---|---|
| 1 | XX | ... |
...

## TOP3 厚レビュー

### 1位: [コンセプト] (XX点)
- **ログライン**: 1行
- **世界観・人物**: 3-4行
- **売れる理由**: 2行
- **最大地雷**: 1行
- **画の核 (2D+3DCG)**: 2行

### 2位 / 3位 も同形式

## MVP 1本の明示 + 2行コメント

日本語、密度重視、全体1500-2500字。
EOF
)

# Claude Sonnet で評価 (cron安全のため --no-session-persistence)
claude -p --no-session-persistence --model sonnet "${PROMPT}" > "${OUTPUT}"

echo ""
echo "✅ 評価完了"
echo "  ${OUTPUT}"
echo ""
echo "📊 TOP5プレビュー:"
grep -E "^\| [1-5] " "${OUTPUT}" 2>/dev/null | head -5 || head -20 "${OUTPUT}"
