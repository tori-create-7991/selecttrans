# Three-engine translation

## Context and scope

SelectTrans previously sent every translation to Gemini and could optionally
send history to Notion. It now offers three selected engines: Gemini, a Qwen
MLX model, and Apple's on-device Foundation Models system model. History is
stored as local Markdown.

## Design

```text
Settings -> TranslationEngineStore -> Translator -> selected TranslationEngine
                                               |-> Gemini (network)
                                               |-> Qwen MLX (local model folder)
                                               `-> Foundation Models (system model)
                                               `-> MarkdownHistoryStore
```

The selected engine is used for translation, proofreading, and
back-translation. Gemini retains the streaming path. Local engines return one
complete result through the same UI callback. Qwen can be downloaded only by
an explicit Settings action; that action resolves an immutable Hugging Face
revision, checks storage, keeps partial files for a subsequent range request,
and checks the SHA-256 advertised for the LFS model file. A compatible custom
MLX folder can alternatively be registered with a security-scoped bookmark.

Foundation Models checks `SystemLanguageModel.default.availability` before a
request and displays the system reason when unavailable. Qwen and Foundation
Models do not make translation network requests.

Markdown history is appended to
`~/Library/Application Support/NaniMini/history/YYYY-MM.md`. Entries include
time, engine, input, output, direction, mode, and source application. The
history is plaintext, stored in an owner-only directory and file.

## Boundaries

- macOS 26 or later is required.
- The Qwen setup download is the only network use of the Qwen path; it is not
  started automatically.
- Existing Notion history is neither migrated nor contacted.
- Real Qwen inference remains unverified until a model is downloaded on a
  target Mac.
