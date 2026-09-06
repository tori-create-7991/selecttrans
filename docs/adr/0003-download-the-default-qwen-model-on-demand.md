# 0003. Download the default Qwen MLX model on demand

Status: Accepted

## Decision

Settings provides an explicit action to download
`mlx-community/Qwen2.5-1.5B-Instruct-4bit` from an immutable Hugging Face
revision into Application Support. It checks free storage, retains partial
files, verifies the LFS model-file SHA-256, and registers the resulting folder.
Manual folder registration remains available for compatible custom models.

## Consequences

The setup action intentionally uses the network, but subsequent Qwen
translation remains local. The app discloses the approximate size and must not
silently download updates or send translation text to Hugging Face.
