#!/bin/bash
# Cinema Dice — 生成スクリプト
# 軸辞書からレシピを引いて Codex xhigh に投げ、JSONL で映画企画を大量生成
# 出力: pool/YYYY-MM-DD_HHMMSS_{recipe}.jsonl

set -euo pipefail
cd "$(dirname "$0")"

RECIPE="${1:-2axis_era_material}"
COUNT="${2:-50}"
WORKSPACE="${WORKSPACE_DIR:-$HOME/projects/workspace}"

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
OUTPUT="pool/${TIMESTAMP}_${RECIPE}.jsonl"

mkdir -p pool

# レシピ存在チェック (python)
RECIPE_JSON=$(python3 -c "
import json, sys
data = json.load(open('axes.json'))
match = [r for r in data['recipes'] if r['name'] == sys.argv[1]]
if not match:
    print('NOTFOUND')
else:
    print(json.dumps(match[0], ensure_ascii=False))
" "${RECIPE}")

if [[ "${RECIPE_JSON}" == "NOTFOUND" ]]; then
  echo "❌ レシピ '${RECIPE}' が axes.json に存在しない"
  echo "利用可能レシピ:"
  python3 -c "import json; [print('  ' + r['name']) for r in json.load(open('axes.json'))['recipes']]"
  exit 1
fi

echo "🎲 Cinema Dice — 生成開始"
echo "  レシピ: ${RECIPE}"
echo "  本数:   ${COUNT}"
echo "  出力:   ${OUTPUT}"
echo ""

# Codex 用プロンプト
PROMPT=$(cat <<EOF
あなたはアニメ映画監督(MAPPA所属・仏在住・2D+3DCG長編志向)の企画ブレスト役。
「ありえない組み合わせ」から映画企画の種を大量に生成する。

## 軸辞書 (axes.json)
\`\`\`json
$(cat axes.json)
\`\`\`

## 既存企画・過去TOP (seen.json) — これらと被らせない
\`\`\`json
$(cat seen.json)
\`\`\`

## 今回のレシピ
\`\`\`json
${RECIPE_JSON}
\`\`\`

## タスク
上記レシピの axes 配列から各カテゴリの項目をランダム抽選し、${COUNT}本の映画企画を生成。
各本について5項目×10点で採点。合計 total を付ける。

### 採点基準 (5項目×10点=50点)
1. originality  — 独自性。他で見たことがないか
2. visual       — 2D+3DCG で撮る必然性・画力
3. emotion      — 感情のコア。泣ける/震える核
4. market       — 国際市場性(日・仏・米・アジア)
5. blood        — 監督の血(MAPPA重厚×仏作家性)

### 生成ルール
- 既存企画・過去TOP(seen.json)の要素と被せない
- 既存ヒット作の焼き直し/既出作品名の羅列はNG
- 日/欧/その他の文化圏をバランスよく
- 46点以上(TOP級)の共通条件を意識:
  (a) 物質が主題の比喩そのもの
  (b) 時間スケールが通常映画を超える
  (c) 被害と加害の二重性を避けない

## 出力形式(厳守)
**JSONLのみ。1行1本、前後に説明文なし。** 各行の構造:

{"id":1,"recipe":"${RECIPE}","axes":{"era":"...","material":"..."},"concept":"1〜2行の粗アイデア(ログライン1行+画の核1行)","score":{"originality":9,"visual":8,"emotion":9,"market":7,"blood":8,"total":41}}

全${COUNT}行。前後に \`\`\` や説明は絶対に付けない。
EOF
)

# Codex実行 (xhigh推論、full-auto)
codex exec --full-auto \
  -c model_reasoning_effort="xhigh" \
  "${PROMPT}" > "${OUTPUT}.raw" 2> >(tee "${OUTPUT}.stderr" >&2)

# Codex出力から JSONL だけ抽出 (前後の説明や ``` を削除)
grep -E '^\{.*"total"' "${OUTPUT}.raw" > "${OUTPUT}" || {
  echo "⚠️  JSONL抽出失敗。raw出力を確認: ${OUTPUT}.raw"
  exit 2
}

LINES=$(wc -l < "${OUTPUT}")
echo ""
echo "✅ 生成完了"
echo "  ${OUTPUT} (${LINES}行)"

# 簡易統計 (python)
echo ""
echo "📊 スコア分布 (TOP10点):"
python3 -c "
import json
scores = [json.loads(l)['score']['total'] for l in open('${OUTPUT}')]
for s in sorted(scores, reverse=True)[:10]:
    print(f'  {s}点')
"

echo ""
echo "🥇 TOP候補(40点以上):"
python3 -c "
import json
items = [json.loads(l) for l in open('${OUTPUT}')]
items.sort(key=lambda x: -x['score']['total'])
for it in [x for x in items if x['score']['total'] >= 40][:5]:
    print(f\"  [{it['score']['total']}] {it['concept'][:80]}\")
"
