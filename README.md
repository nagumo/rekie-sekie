# rekie-sekie（歴積）

macOS のメニューバーに常駐するクリップボード履歴マネージャーです。
コピーした内容を自動で積み上げ（歴積）、ショートカット一発で呼び出して貼り付けられます。

ネットワーク通信は一切行わず、履歴はすべてローカルにのみ保存されます。

## 機能

- **クリップボード履歴** — テキスト・画像（サムネイル表示）を自動記録。同じ内容を再コピーしたら新規追加せず先頭へ移動
- **どこでも呼び出し** — `⌘⇧V` でマウスカーソル位置に履歴ポップオーバーを表示。数字キー（1–9）・矢印キー + Enter・クリックで選択すると、直前のアプリに自動で貼り付け
- **インクリメンタルサーチ** — 履歴をその場で絞り込み
- **スニペット（定型文）** — `⌃⇧⌘V` で呼び出し。フォルダ分け管理、`{date}` `{time}` `{datetime}` の動的変数を貼り付け時に展開
- **プライバシー配慮** — 1Password 等のパスワードマネージャーがコピーに付与する `org.nspasteboard.ConcealedType` マーカーを検知し、履歴に記録しない（設定でON/OFF、既定ON）。特定アプリからのコピーを除外する設定も可能
- **カスタマイズ** — ショートカット変更、履歴最大件数、メニューバーアイコン、表示言語（日本語/英語）、ログイン時自動起動
- **自動アップデート** — Sparkle による更新通知・自動更新

## インストール

1. [Releases](https://github.com/nagumo/rekie-sekie/releases) から最新の `RekieSekie-vX.Y.Z.zip` をダウンロード
2. 展開した `RekieSekie.app` を `/Applications` に移動して起動
3. 初回起動時にアクセシビリティ権限を求められたら許可する（選択した履歴を `⌘V` で自動貼り付けするために必要）

配布バイナリは Developer ID 署名・Apple notarization 済みです。

### 動作環境

- macOS 13 (Ventura) 以降
- Apple Silicon

## 使い方

| 操作 | ショートカット |
|---|---|
| クリップボード履歴を開く | `⌘⇧V` |
| スニペット一覧を開く | `⌃⇧⌘V` |
| 項目を選択 | 数字キー `1`–`9` / `↑↓` + `Enter` / クリック |
| 閉じる | `Esc` |

設定・スニペット管理は、メニューバーアイコンの右クリックメニューから開けます。

## セキュリティ

- ネットワーク通信なし（同期機能なし、完全ローカル）。唯一の外部通信は Sparkle によるアップデート確認のみ
- パスワードマネージャーからのコピーは既定で履歴に記録しない（`ConcealedType` 検知）
- 自動アップデートは EdDSA 署名で検証される

## 開発

Swift Package Manager のみで完結します。

```bash
swift build            # ビルド
swift test             # テスト
swift run RekieSekie   # 実行
scripts/build-app.sh   # .app バンドルの組み立て
```

技術スタック: Swift / SwiftUI + AppKit / [GRDB](https://github.com/groue/GRDB.swift)（SQLite）/ [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) / [Sparkle](https://sparkle-project.org/)

機能の設計経緯は [docs/spec_clipy_gap.md](docs/spec_clipy_gap.md) を参照してください。[Clipy](https://github.com/Clipy/Clipy) を機能の基本形としています。

## ライセンス

[MIT License](LICENSE)
