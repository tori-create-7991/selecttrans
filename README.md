# SelectTrans

選択したテキストをショートカットで翻訳できる、macOS向けのオープンソース・メニューバーアプリです。英語と日本語の相互翻訳に対応し、ネイティブSwiftUIで動作します。

SelectTransは独立したオープンソースプロジェクトであり、特定の商用翻訳サービスとは提携していません。

## 機能

- **ランチャーモード**: メニューバー常駐・Dock 非表示・Cmd+Tab 非表示（`.accessory`）
- **グローバルショートカット**: 既定 `Control + J`（設定でリバインド可）
- **どのアプリでも翻訳**: テキスト選択 → ショートカット → カーソル付近にポップアップ
- **方向自動判定**: 日本語を含めば JA→EN、それ以外は EN→JA（ローカル判定・APIコスト0）
- **翻訳 / 添削タブ**: ポップアップ上でモード切替
- **LLM**: Google Gemini（利用者自身のAPIキーをKeychainに保管）
- **履歴を Notion へ**: 翻訳のたびに Notion DB に1ページ追加（非同期・失敗はローカル退避→再送）
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
3. **Notion 履歴（任意）**: internal integration token と Database ID を設定に貼り付け。DB 必要プロパティ: `原文`(Title)/`訳文`(Text)/`方向`(Select)/`モード`(Select)/`取得元アプリ`(Text)/`日時`(Date)

## 使い方

テキスト選択 → `Control + J` → ポップアップに訳。`翻訳`/`添削` 切替、`コピー`、`Esc` で閉じる。

## データとプライバシー

SelectTransは翻訳処理のため、次のデータを扱います。

- **選択テキスト**: アクセシビリティ権限を使って疑似`Cmd+C`を送信し、macOSのクリップボードから読み取ります。翻訳・添削する内容はGemini APIへ送信されます。
- **スクリーンショット**: 画像翻訳を実行した場合だけ、一時PNGを作成します。OCRはmacOS Visionでオンデバイス処理し、一時ファイルは処理後に削除します。認識したテキストを翻訳する場合はGemini APIへ送信されます。
- **Gemini APIキー**: macOS Keychainに保存します。ソースコードや平文設定ファイルには保存しません。
- **Notion履歴**: integration tokenとDatabase IDの両方を設定した場合だけ有効になります。原文、訳文、翻訳方向、モード、取得元アプリ、日時をNotion APIへ送信します。資格情報はmacOS Keychainに保存します。
- **Notion再送キュー**: Notion設定後の送信に失敗した場合、再送対象を`~/Library/Application Support/NaniMini/pending.json`へ保存します。保存先は所有者だけがアクセスできる権限に設定しますが、原文と訳文は平文で含まれるため、機密情報を扱う場合は注意してください。未送信データを失わないat-least-once方式のため、送信完了とローカル確認の間に終了するとNotionページが重複する場合があります。Notion未設定時には新規保存しません。
- **解析・テレメトリー**: SelectTrans独自のアクセス解析や利用状況送信は実装していません。

GeminiおよびNotionへ送信したデータの取扱いは、それぞれのサービスの規約とプライバシーポリシーに従います。

## 設計メモ

| レイヤー | ファイル |
|---|---|
| 起動・常駐 | `main.swift` / `AppDelegate.swift` |
| ショートカット | `Shortcuts.swift` |
| テキスト取得 | `Core/TextGrabber.swift` |
| 方向判定 | `Core/LangDetector.swift` |
| LLM | `Translation/GeminiClient.swift` / `Prompts.swift` / `Translator.swift` |
| UI | `UI/PopupPanel.swift` / `PopupView.swift` / `SettingsView.swift` |
| 保存 | `Storage/KeychainStore.swift` / `NotionHistoryClient.swift` / `PendingQueue.swift` |

## ライセンス

[MIT License](LICENSE)
