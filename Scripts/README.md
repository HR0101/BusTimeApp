# 文言（多言語対応）の追加・修正手順

アプリの文言は日本語・英語・簡体字中国語の3言語を用意しています.
表示される言語は端末の「設定 › 一般 › 言語と地域」に従います.

## 原本はどこか

`Scripts/localization_strings.py` が唯一の原本です.
次の2つのファイルは**このスクリプトが作る生成物**なので,直接編集しないでください.

- `BusTimeApp/Localization/Localizable.xcstrings` — 実際の文字（String Catalog）
- `BusTimeApp/Localization/L10n.swift` — コードから呼ぶ名前

## 手順

1. `Scripts/localization_strings.py` に1行足します.

   ```python
   ("result.nextBus", "つぎのバス", "Next bus", "下一班车", []),
   ```

   形式は `(キー, 日本語, 英語, 簡体字中国語, 引数の型)` です.
   キーは `区分.名前` で,区分が Swift の列挙型,名前がその要素になります.

2. 生成し直します.

   ```sh
   python3 Scripts/generate_l10n.py
   ```

3. コードから呼びます.

   ```swift
   Text(L10n.Result.nextBus)
   ```

## 文言に値を差し込む場合

書式指定子を含め,引数の型を並べます.2つ以上あるときは `%1$@` のように順番を明示してください.

```python
("countdown.minutes", "あと%d分", "%d min left", "还有%d分钟", ["Int"]),
("search.resultCount", "%1$lld便見つかりました。%2$@", "Found %1$lld services. %2$@",
 "找到%1$lld个班次。%2$@", ["Int", "String"]),
```

生成後は関数として呼べます.

```swift
L10n.Countdown.minutes(12)
L10n.Search.resultCount(3, explanation)
```

## 生成物が古くなっていないか調べる

```sh
python3 Scripts/generate_l10n.py --check
```

対訳表と生成物がずれていれば,ずれているファイルを表示して終了コード1を返します.
CI に入れておくと,生成を忘れたまま取り込むことを防げます.

## 翻訳しないもの

次のものは意図的に日本語のまま残しています.

- 停留所名（コロンブスシティ・海浜幕張駅・ヨーカドー前）— 現地の案内と一致させるため
- `enum` の `rawValue` — 保存や比較に使う識別子のため.表示用には別に `displayName` などを用意します
- `print` や `#Preview` の文言 — 開発者向けで画面に出ないため

## 対応言語を増やすとき

1. `Scripts/generate_l10n.py` の `LANGUAGES` に言語コードを足します
2. `Scripts/localization_strings.py` の各行に訳を足します（タプルの要素が増えます）
3. `BusTimeApp.xcodeproj/project.pbxproj` の `knownRegions` に同じ言語コードを足します
