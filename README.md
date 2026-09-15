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

メニューバーに「翻」が出れば起動成功。

> **旧名称 `NaniMini` からのアップグレード**: バンドルID(`com.ryo.nanimini`→`com.ryo.selecttrans`)が変わったため、TCCがアクセシビリティ権限を新規アプリとして扱います。`SelectTrans.app`で改めてアクセシビリティ権限を許可してください。`scripts/make-app.sh`が使う自己署名証明書名も`NaniMini Self-Signed`→`SelectTrans Self-Signed`に変わったため、未作成なら初回セットアップの手順で作成してください（既存の`NaniMini Self-Signed`証明書をそのまま使い続けたい場合は`SELECTTRANS_SIGN_IDENTITY="NaniMini Self-Signed"`を指定してビルドすれば新規作成は不要です）。翻訳履歴(`NaniMini/history`)・Qwenモデル(`NaniMini/Models`)は初回起動時に`SelectTrans/`配下へ自動移行されます。Gemini APIキー(Keychain)は`com.ryo.nanimini`保存分を初回読み取り時に自動移行します。

## 初回セットアップ

1. **アクセシビリティ権限**: System Settings → プライバシーとセキュリティ → アクセシビリティ で SelectTrans を許可（疑似 Cmd+C で選択テキスト取得に必要）
2. **Gemini API キー**: メニューバー「翻」→ 設定 → Gemini に貼り付け（https://aistudio.google.com/apikey ）
3. **Qwen（任意）**: 設定で保存先を選んでから「Qwenをダウンロード」を押すと、約869MBのMLXモデルを取得します。既定の保存先は `~/Library/Application Support/SelectTrans/Models/` です。取得時だけネットワークを使用し、翻訳時はローカル処理です。
4. **Apple Foundation Models（任意）**: macOS 26、対応Mac、Apple Intelligenceを有効にすると利用できます。

## 使い方

テキスト選択 → `Control + J` → ポップアップに訳。`翻訳`/`添削` 切替、`コピー`、`Esc` で閉じる。

## データとプライバシー

SelectTransは翻訳処理のため、次のデータを扱います。

- **選択テキスト**: アクセシビリティ権限を使って疑似`Cmd+C`を送信し、macOSのクリップボードから読み取ります。Gemini選択時のみ翻訳・添削内容をGemini APIへ送信します。
- **スクリーンショット**: 画像翻訳を実行した場合だけ、一時PNGを作成します。OCRはmacOS Visionでオンデバイス処理し、一時ファイルは処理後に削除します。
- **Gemini APIキー**: macOS Keychainに保存します。ソースコードや平文設定ファイルには保存しません。
- **既存のNotion／保留履歴**: この変更は既存のNotionページや端末内の旧保留キューを変更・削除しません。必要な移行は別途、明示操作として扱います。
- **Qwenモデル**: 明示的にダウンロード操作をした場合だけHugging Faceの `mlx-community/Qwen2.5-1.5B-Instruct-4bit` から、固定リビジョンを指定して取得します。選択した保存先（既定は `~/Library/Application Support/SelectTrans/Models/`）に保存し、翻訳テキストはHugging Faceへ送信しません。
- **翻訳履歴**: `~/Library/Application Support/SelectTrans/history/YYYY-MM.md`に平文で保存します。所有者のみが読める権限を設定しますが、機密文を扱う場合は注意してください。
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
