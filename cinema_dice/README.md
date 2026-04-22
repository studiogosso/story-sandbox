# 🎲 Cinema Dice

**映画企画ランダム生成ハーネス**。軸辞書から組み合わせを引いて、ありえない掛け算で企画を大量生成→評価する。

## 設計方針
- **生成** = Codex CLI (xhigh推論) ― 定額内・大量向け
- **評価** = Claude Sonnet ― 採点/厚レビュー
- **最終選定** = Claude Opus (必要時のみ手動)

Opus並列爆撃はコスト重いので、日常はCodex+Sonnetだけで回す。月1回くらいOpusで総括。

---

## ファイル

| ファイル | 役割 |
|---|---|
| `axes.json` | 軸辞書。15カテゴリ(era/profession/material/emotion/location/...)×約30項目 + 20レシピ(2軸10・3軸10) |
| `seen.json` | 既存企画&過去TOPの一覧。生成時に「被せるな」と渡す |
| `generate.sh` | Codex xhighで50本生成→`pool/*.jsonl`出力 |
| `evaluate.sh` | `pool/*.jsonl`をClaude Sonnetに渡し→`top/*.md`出力 |
| `pool/` | 日次の生成プール(JSONL) |
| `top/` | TOP3厚レビュー(Markdown) |
| `_archive/` | 月末に古いpoolを退避 |

---

## 使い方

### 1本だけ生成
```bash
cd ~/projects/workspace/2000_Creative/2900_Sandbox/cinema_dice
./generate.sh 2axis_era_material 50
# → pool/2026-04-22_0130_2axis_era_material.jsonl (50本)
```

### 評価
```bash
./evaluate.sh pool/2026-04-22_0130_2axis_era_material.jsonl
# → top/2026-04-22_0130_2axis_era_material_review.md (TOP3厚レビュー)
```

### レシピ一覧を確認
```bash
python3 -c "import json; [print(r['name'], '—', r['prompt_hint']) for r in json.load(open('axes.json'))['recipes']]"
```

### 全レシピを一晩で回す (20レシピ × 50本 = 1000本)
```bash
for recipe in $(python3 -c "import json; [print(r['name']) for r in json.load(open('axes.json'))['recipes']]"); do
  ./generate.sh "$recipe" 50
done
for f in pool/$(date +%Y-%m-%d)_*.jsonl; do
  ./evaluate.sh "$f"
done
```

---

## cron 自動化案

```cron
# 毎晩1時: 年通算日を20で割った剰余でレシピを選ぶ(20日サイクルで全レシピ消化)
0 1 * * * cd /home/studi/projects/workspace/2000_Creative/2900_Sandbox/cinema_dice && ./generate.sh $(python3 -c "import json,datetime; r=json.load(open('axes.json'))['recipes']; print(r[datetime.date.today().toordinal() % len(r)]['name'])") 50 >> .cinema_dice.log 2>&1

# 毎朝5:30: 前夜のpoolを評価
30 5 * * * cd /home/studi/projects/workspace/2000_Creative/2900_Sandbox/cinema_dice && for f in pool/$(date +%Y-%m-%d)_*.jsonl; do ./evaluate.sh "$f"; done >> .cinema_dice.log 2>&1

# 月末に pool を archive へ退避
0 4 1 * * cd /home/studi/projects/workspace/2000_Creative/2900_Sandbox/cinema_dice && mv pool/$(date -d "last month" +%Y-%m)*.jsonl _archive/ 2>/dev/null || true
```

日次1レシピ×50本=月1500本、年約1.8万本のプールに蓄積される。

---

## seen.json の更新

TOP評価で46点以上が出たら、その企画名を `seen.json.harness_top_cache` に追記する。次回生成時に「被せるな」と伝わる仕組み。

```bash
# TOP3で46点以上だった企画をseen.jsonに追記 (手動 or 週次バッチ)
python3 <<PY
import json
with open('seen.json') as f: data = json.load(f)
data['harness_top_cache'].append({"score": 46, "name": "XXX", "axis": "...", "date": "2026-04-22"})
with open('seen.json', 'w') as f: json.dump(data, f, ensure_ascii=False, indent=2)
PY
```

---

## 46点以上の共通条件 (TOP級に入る企画の3条件)

2026-04-21の1000本爆撃から抽出:
1. **物質が主題の比喩そのもの**(封筒・種子・クマムシ・霧・鶏脚の家…)
2. **時間スケールが通常映画を超える**(20年/10万年/76年/…)
3. **被害と加害の二重性を避けない**(戦争・歴史・家族の罪)

この3条件は `generate.sh` のプロンプトに既に仕込み済み。以降の生成にも自動で反映される。

---

## コスト感 (参考)

| 方式 | 1000本あたりの体感コスト |
|---|---|
| Opus 4.7 並列20本 | 数ドル〜十数ドル(従量) |
| Codex xhigh + Sonnet評価 | **Pro $100定額内で追加ゼロ** |
| Codex xhigh + Haiku評価 | さらに軽い |

## 今日のグランプリ(2026-04-21)
[top/2026-04-21_opus_bombard.md](top/2026-04-21_opus_bombard.md) 参照。
**『450通』(中朝国境の郵便局×20年分の空封筒×祖父に会ったことがない孫娘)** が50点満点でグランプリ。
