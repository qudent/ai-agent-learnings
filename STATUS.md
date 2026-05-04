# AI Agent Learnings - Status

# Overall direction
Build a fast practical path for a Discord voice-channel bridge that talks to Codex: Discord voice input is gated by a wake word such as "codex", transcribed, written to a Unix-compatible stream/log, forwarded to an interruptible/follow-up-capable Codex session, and Codex replies are written to text surfaces plus spoken back into the voice channel via TTS. Prefer Codex app-server over one-shot `codex exec`; use the existing wrapper only for orchestration/fallback.
-------

## Current State
`main` contains the active-dispatcher orchestration update. New active task: research and prototype a voice-first Discord ↔ Unix pipes ↔ Codex bridge, with text observability and wake-word activation. Parallel research found that current Codex has an app-server JSON-RPC interface over stdio that supports live turn start, interrupt, steer, and streaming deltas; this is the preferred integration surface.

## Active Goals
- [ ] Spike `codex app-server --listen stdio://`: initialize, start thread, start turn, stream assistant deltas, `turn/steer`, and `turn/interrupt`.
- [ ] Build or dispatch a prototype with two Unix-compatible processes: `discord-voice-stdio` and `codex-appserver-adapter`.
- [ ] Implement Discord voice MVP: join/playback, receive/decode PCM, VAD/STT, wake word `codex`, stdin TTS playback, and optional transcript sinks.
- [ ] Keep `scripts/codex_wrap.sh` / `scripts/codex_wrap.py` as orchestration and fallback, not the preferred live voice control channel.

## TODO Plan
- [ ] Use `codex_dispatch` to turn `docs/plans/2026-05-04-discord-voice-codex-bridge.md` into an implementation/prototype plan or repo changes.
- [ ] Verify installed Codex version exposes `app-server`; if not, update Codex or fall back to wrapper restart/resume semantics.
- [ ] Decide target repo/package location for the bridge after the dispatcher inspects available Hermes/Codex source checkouts.
- [ ] Commit/push small logical changes after each slice.

## Blockers
- Need a live spike against installed Codex app-server before claiming the protocol works locally.
- Discord voice receive must be tested on the actual bot/server; library support is practical but less polished than playback.
- Wake word `codex` probably needs a custom wake model or STT phrase-spotting fallback.

## Recent Results
- Parallel Codex research found `codex app-server --listen stdio://` with JSON-RPC methods/events: `thread/start`, `thread/resume`, `turn/start`, `turn/interrupt`, `turn/steer`, and `item/agentMessage/delta` streaming.
- Local wrapper inspection found `codex_new_message` can interrupt by killing active `codex exec` and resuming the same session; useful fallback, but not a persistent bidirectional stdin channel.
- Discord voice research recommends Node Discord transport plus Python ML sidecars, local wake/VAD before STT, `selfDeaf: false`, one-speaker MVP, and explicit feedback-loop prevention.
- Detailed plan saved at `docs/plans/2026-05-04-discord-voice-codex-bridge.md`.

## Agent Notes
- Keep wake word local/cheap where possible; do not stream all audio to a cloud realtime API unless explicitly chosen later.
- Treat `codex exec` one-shot limitations honestly. If app-server is unavailable, wrapper semantics are stop/resume, not live steering.
- If this becomes Hermes gateway work, load the Hermes voice/gateway references and keep Discord thread/session naming constraints in mind.
