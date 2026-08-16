#!/usr/bin/env python3
"""対訳表から、文字列カタログと L10n.swift を作り直します。

    python3 Scripts/generate_l10n.py

文言の追加・修正は Scripts/localization_strings.py だけを編集し、
このスクリプトを実行してください。生成物を直接編集すると、
次の実行で上書きされます。

--check を付けると、生成物が対訳表と一致しているかだけを調べます。
一致しなければ終了コード1を返すので、CIでの検査に使えます。
"""

import argparse
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(ROOT, "BusTimeApp", "Localization")
CATALOG_PATH = os.path.join(OUTPUT_DIR, "Localizable.xcstrings")
SWIFT_PATH = os.path.join(OUTPUT_DIR, "L10n.swift")

# 対訳表に載せる言語です。日本語が原本で、英語と簡体字中国語を訳として持ちます。
LANGUAGES = ("en", "ja", "zh-Hans")
SOURCE_LANGUAGE = "ja"

SWIFT_HEADER = """import Foundation

/// 画面に出る文言をまとめた入り口です。
///
/// 実際の文字は Localization/Localizable.xcstrings に置き、ここには意味の名前だけを残します。
/// 表示される言語は端末の設定に従います。日本語・英語・簡体字中国語を用意しています。
/// 停留所名などの固有名詞は現地の案内と一致させるため、日本語のままにしています。
///
/// このファイルはウィジェット拡張とも共有します。
/// String(localized:) は各バンドルのカタログを見るため、両方の成果物にカタログを含めています。
///
/// このファイルは Scripts/generate_l10n.py が作ります。直接編集しないでください。
public enum L10n {"""


def load_entries():
    sys.path.insert(0, os.path.join(ROOT, "Scripts"))
    from localization_strings import ENTRIES

    keys = [entry[0] for entry in ENTRIES]
    duplicated = sorted({key for key in keys if keys.count(key) > 1})
    if duplicated:
        raise SystemExit("キーが重複しています: %s" % ", ".join(duplicated))
    return ENTRIES


def build_catalog(entries):
    catalog = {"sourceLanguage": SOURCE_LANGUAGE, "version": "1.0", "strings": {}}
    for key, ja, en, zh, _ in entries:
        values = {"en": en, "ja": ja, "zh-Hans": zh}
        catalog["strings"][key] = {
            "extractionState": "manual",
            "localizations": {
                language: {"stringUnit": {"state": "translated", "value": values[language]}}
                for language in LANGUAGES
            },
        }
    return json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def swift_member_name(tail):
    """キーの後半部分から、Swiftの要素名を作ります。"""
    return re.sub(r"[^0-9a-zA-Z]", "", tail[0].lower() + tail[1:])


def swift_enum_name(head):
    """キーの前半部分から、Swiftの列挙型名を作ります。"""
    return head[0].upper() + head[1:]


def build_swift(entries):
    groups = {}
    for key, ja, en, zh, args in entries:
        head, tail = key.split(".", 1)
        groups.setdefault(head, []).append((key, tail, ja, args))

    lines = [SWIFT_HEADER]
    for head, members in groups.items():
        lines.append("  public enum %s {" % swift_enum_name(head))
        for key, tail, ja, args in members:
            lines.append("    /// %s" % ja.replace("\n", "\\n"))
            name = swift_member_name(tail)
            if args:
                params = ", ".join("_ arg%d: %s" % (i, kind) for i, kind in enumerate(args))
                call = ", ".join("arg%d" % i for i in range(len(args)))
                lines.append("    public static func %s(%s) -> String {" % (name, params))
                lines.append('      String(format: String(localized: "%s"), %s)' % (key, call))
                lines.append("    }")
            else:
                lines.append(
                    '    public static var %s: String { String(localized: "%s") }' % (name, key)
                )
        lines.append("  }")
        lines.append("")
    lines.append("}")
    return "\n".join(lines)


def write_if_needed(path, content, check_only):
    current = io.open(path, encoding="utf-8").read() if os.path.exists(path) else None
    if current == content:
        return False
    if check_only:
        return True
    io.open(path, "w", encoding="utf-8").write(content)
    return True


def main():
    parser = argparse.ArgumentParser(description="対訳表から文字列カタログとL10nを作ります。")
    parser.add_argument(
        "--check",
        action="store_true",
        help="書き換えずに、生成物が対訳表と一致しているかだけ調べます。",
    )
    options = parser.parse_args()

    entries = load_entries()
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    stale = [
        path
        for path, content in (
            (CATALOG_PATH, build_catalog(entries)),
            (SWIFT_PATH, build_swift(entries)),
        )
        if write_if_needed(path, content, options.check)
    ]

    if options.check:
        if stale:
            print("対訳表と一致していません:")
            for path in stale:
                print("  %s" % os.path.relpath(path, ROOT))
            print("Scripts/generate_l10n.py を実行してください。")
            return 1
        print("生成物は対訳表と一致しています。（%d件）" % len(entries))
        return 0

    if stale:
        for path in stale:
            print("更新しました: %s" % os.path.relpath(path, ROOT))
    else:
        print("変更はありませんでした。")
    print("文言は%d件です。" % len(entries))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
