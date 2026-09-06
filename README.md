# SelectTrans

選択したテキストをショートカットで翻訳できる、macOS向けのオープンソース・メニューバーアプリです。英語と日本語の相互翻訳に対応し、ネイティブSwiftUIで動作します。

SelectTransは独立したオープンソースプロジェクトであり、特定の商用翻訳サービスとは提携していません。

## 機能

- **ランチャーモード**: メニューバー常駐・Dock 非表示・Cmd+Tab 非表示（`.accessory`）
- **グローバルショートカット**: 既定 `Control + J`（設定でリバインド可）
- **どのアプリでも翻訳**: テキスト選択 → ショートカット → カーソル付近にポップアップ
- **方向自動判定**: 日本語を含めば JA→EN、それ以外は EN→JA（ローカル判定・APIコスト0）
- **翻訳 / 添削タブ**: ポップアップ上でモード切替
- **翻訳エンジン**: Gemini、ローカルQwen 1.5B MLX、Apple Foundation Modelsを設定から選択
- **ローカル履歴**: 翻訳を端末内の月別Markdownへ保存
- **画像翻訳**: 選択範囲をスクリーンショットして、macOS VisionによるオンデバイスOCRを実行
- **読み上げ**: macOSの音声合成で翻訳結果を再生

## ビルド & 起動

```bash
swift run                 # 開発中（ターミナルにログ）
bash scripts/make-app.sh  # .app バンドル化（推奨：権限が安定）
open SelectTrans.app
```

旧名称の `NaniMini.app` は、ビルド時に `SelectTrans.app` への互換シンボリックリンクとして作成されます。

メニューバーに「翻」が出れば起動成功。

Swiftパッケージの内部ターゲット名と実行ファイル名は、既存環境との互換性のため`NaniMini`のまま維持しています。

## 初回セットアップ

1. **アクセシビリティ権限**: System Settings → プライバシーとセキュリティ → アクセシビリティ で SelectTrans を許可（疑似 Cmd+C で選択テキスト取得に必要）
2. **Gemini API キー**: メニューバー「翻」→ 設定 → Gemini に貼り付け（https://aistudio.google.com/apikey ）
3. **Qwen（任意）**: 設定で「Qwenをダウンロード」を押すと、約869MBのMLXモデルを取得します。取得時だけネットワークを使用し、翻訳時はローカル処理です。
4. **Apple Foundation Models（任意）**: macOS 26、対応Mac、Apple Intelligenceを有効にすると利用できます。

## 使い方

テキスト選択 → `Control + J` → ポップアップに訳。`翻訳`/`添削` 切替、`コピー`、`Esc` で閉じる。

## データとプライバシー

SelectTransは翻訳処理のため、次のデータを扱います。

- **選択テキスト**: アクセシビリティ権限を使って疑似`Cmd+C`を送信し、macOSのクリップボードから読み取ります。Gemini選択時のみ翻訳・添削内容をGemini APIへ送信します。
- **スクリーンショット**: 画像翻訳を実行した場合だけ、一時PNGを作成します。OCRはmacOS Visionでオンデバイス処理し、一時ファイルは処理後に削除します。
- **Gemini APIキー**: macOS Keychainに保存します。ソースコードや平文設定ファイルには保存しません。
- **既存のNotion／保留履歴**: この変更は既存のNotionページや端末内の旧保留キューを変更・削除しません。必要な移行は別途、明示操作として扱います。
- **Qwenモデル**: 明示的にダウンロード操作をした場合だけHugging Faceから取得し、`~/Library/Application Support/NaniMini/Models/`に保存します。翻訳テキストはHugging Faceへ送信しません。
- **翻訳履歴**: `~/Library/Application Support/NaniMini/history/YYYY-MM.md`に平文で保存します。所有者のみが読める権限を設定しますが、機密文を扱う場合は注意してください。
- **解析・テレメトリー**: SelectTrans独自のアクセス解析や利用状況送信は実装していません。

GeminiまたはQwenダウンロード時に送信するデータの取扱いは、それぞれのサービスの規約とプライバシーポリシーに従います。

## 設計メモ

| レイヤー | ファイル |
|---|---|
| 起動・常駐 | `main.swift` / `AppDelegate.swift` |
| ショートカット | `Shortcuts.swift` |
| テキスト取得 | `Core/TextGrabber.swift` |
| 方向判定 | `Core/LangDetector.swift` |
| LLM | `Translation/GeminiClient.swift` / `LocalTranslationEngines.swift` / `Translator.swift` |
| UI | `UI/PopupPanel.swift` / `PopupView.swift` / `SettingsView.swift` |
| 保存 | `Storage/KeychainStore.swift` / `MarkdownHistoryStore.swift` / `QwenModelDownloader.swift` |

## ライセンス

[MIT License](LICENSE)
