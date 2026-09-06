# 0002. Select Gemini, Qwen MLX, and Apple Foundation Models

Status: Accepted

## Decision

SelectTrans exposes exactly three translation engines: Gemini, Qwen 1.5B
Instruct 4-bit MLX, and Apple Foundation Models. It targets macOS 26, uses a
single engine abstraction, and stores history locally as Markdown rather than
in Notion.

## Consequences

Gemini is the only translation path with network traffic and keeps its
Keychain API key. Qwen requires a compatible downloaded or manually chosen
model. Foundation Models requires a supported device, enabled Apple
Intelligence, and a ready system model. macOS 13--25 support is dropped.
