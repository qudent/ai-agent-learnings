# Discord Voice ↔ Codex Bridge Plan

## Goal

Build a voice-first Discord channel for talking to Codex while keeping a Unix-compatible boundary:

```text
Discord voice input --wake word "codex"--> STT transcript JSONL --> Codex adapter --> Codex app-server/wrapper
Discord voice output <-- TTS from assistant text JSONL <-- Codex adapter <-- Codex streaming output
```

The bridge should also expose text-observable logs/transcripts through stdout/stdin JSONL, files, and optionally a Discord text channel or DM.

## Main research result

Use **`codex app-server --listen stdio://`** as the preferred Codex integration surface.

`codex exec` is one-shot. It can emit JSONL (`codex exec --json`) and can resume sessions across invocations, but stdin is only initial prompt/context, not a live control channel. It is therefore the wrong primitive for a live voice loop if follow-up/interrupt/steering is required.

Codex app-server is a JSON-RPC 2.0 server over stdio/websocket/unix socket. The stdio transport is newline-delimited JSON over stdin/stdout, which matches the requested Unix-stream-compatible boundary after a small adapter.

Relevant commands:

```bash
codex app-server --listen stdio://
# stdio is also the default:
codex app-server
```

Relevant protocol methods/events found in Codex source/docs:

- `thread/start`
- `thread/resume`
- `turn/start`
- `turn/interrupt`
- `turn/steer`
- streaming notifications such as `item/agentMessage/delta`, `item/started`, `item/completed`, `turn/completed`

Important references:

- `codex-rs/app-server/README.md`
- `codex-rs/app-server-transport/src/transport/stdio.rs`
- `codex-rs/app-server-protocol/src/protocol/v2.rs`
- GitHub: <https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md>
- GitHub: <https://github.com/openai/codex/blob/main/codex-rs/app-server-transport/src/transport/stdio.rs>
- GitHub: <https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/v2.rs>

Related issues/PRs to track:

- <https://github.com/openai/codex/issues/10233> — non-interactive/headless status gap
- <https://github.com/openai/codex/issues/11750> — headless/non-interactive fork request
- <https://github.com/openai/codex/issues/17095> — TUI follow-up/interrupt UX
- <https://github.com/openai/codex/issues/20919> — `codex exec` stdin pipe hang
- <https://github.com/openai/codex/issues/19689> — `codex exec --json` automation stream issue
- <https://github.com/openai/codex/pull/18945> — app-server stdio flush
- <https://github.com/openai/codex/pull/20663>, <https://github.com/openai/codex/pull/20664> — related stdio exec-server work
- <https://github.com/openai/codex/pull/19040> — process exec API work

## Codex-side adapter

### Preferred: app-server adapter

Run Codex app-server as a child process and translate between a simple bridge JSONL protocol and app-server JSON-RPC.

Bridge input to adapter:

```jsonl
{"type":"user_turn","text":"inspect the failing tests","utterance_id":"utt_001"}
{"type":"steer","text":"actually focus on the logs first"}
{"type":"interrupt","reason":"new wake utterance"}
{"type":"status"}
```

Adapter to Codex app-server:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
{"jsonrpc":"2.0","id":2,"method":"thread/start","params":{"cwd":"/target/repo","approvalPolicy":"never"}}
{"jsonrpc":"2.0","id":3,"method":"turn/start","params":{"threadId":"...","input":[{"type":"text","text":"inspect the failing tests"}]}}
{"jsonrpc":"2.0","id":4,"method":"turn/steer","params":{"threadId":"...","expectedTurnId":"...","input":[{"type":"text","text":"actually focus on the logs first"}]}}
{"jsonrpc":"2.0","id":5,"method":"turn/interrupt","params":{"threadId":"...","turnId":"..."}}
```

Adapter output to bridge:

```jsonl
{"type":"status","state":"thread_started","thread_id":"..."}
{"type":"assistant_text","text":"I am checking the failing tests.","final":false}
{"type":"assistant_text","text":"The issue is fixed and tests pass.","final":true}
{"type":"turn_completed","status":"completed"}
{"type":"error","message":"..."}
```

The voice side should TTS `assistant_text` events and append all events to transcript sinks.

### Fallback: existing `ai-agent-learnings` wrapper

If the app-server path is unavailable on the installed Codex version, use the wrapper scripts:

- `scripts/codex_wrap.sh`
- `scripts/codex_wrap.py`
- `scripts/branch_commands.sh`

Useful functions:

- `codex_dispatch <prompt>` — broad active dispatcher orchestration
- `codex_commit <prompt>` — narrow one-shot implementation agent
- `codex_new_message <prompt>` — append follow-up, stop active run, resume Codex session
- `codex_abort [run]` — abort active run
- `codex_active` / `codex_agents` — status

This fallback is not a live stdin control channel. It implements interruption as: append user follow-up to inbox/transcript, kill active `codex exec`, then resume the same Codex session with a new prompt. That is acceptable for a first bridge if app-server is not available, but app-server is the cleaner solution.

## Discord voice side

Recommended MVP stack: **Node.js Discord adapter + Python ML sidecars**.

- Discord transport: `discord.js`, `@discordjs/voice`, `prism-media`, `@discordjs/opus`
- VAD: Node Silero packages or Python `webrtcvad-wheels`/Silero
- Wake word: `codex` by default, using a custom Porcupine/openWakeWord model if available; fallback to local STT phrase spotting
- STT: local `faster-whisper` after wake/VAD gate; cloud STT only after wake if desired
- TTS: Piper/local TTS or configured cloud TTS; return WAV/PCM/Opus to Node for playback

Pipeline:

1. Bot is invited with voice permissions and joins a configured voice channel.
2. Connect with `selfDeaf: false`; otherwise receive audio will not work.
3. Subscribe to per-user Opus streams via the voice receiver.
4. Decode to PCM, resample from Discord 48 kHz audio to 16 kHz mono for wake/VAD/STT.
5. Idle mode listens locally for wake word `codex`.
6. After wake, VAD captures a single utterance until silence.
7. STT emits a transcript event to stdout JSONL.
8. A supervisor/pipe connects transcript events to the Codex adapter.
9. Assistant text events are converted to TTS and played into the voice channel.
10. Transcript/assistant events are optionally appended to a file, text channel, or DM.

Discord bridge stdout examples:

```jsonl
{"type":"ready","guild_id":"...","channel_id":"..."}
{"type":"wake","user_id":"...","wake":"codex","ts":"..."}
{"type":"transcript","id":"utt_001","user_id":"...","text":"inspect the failing tests","confidence":0.91}
{"type":"error","code":"stt_failed","message":"..."}
```

Discord bridge stdin examples:

```jsonl
{"type":"say","text":"I found three modified files."}
{"type":"play","path":"/tmp/reply.wav"}
{"type":"mute","state":true}
{"type":"shutdown"}
```

## Permissions and pitfalls

- Bot needs View Channel, Connect, Speak, and Use Voice Activity; Send Messages if posting transcripts.
- Gateway intents: Guilds and GuildVoiceStates. Message Content only if using text-prefix commands; slash commands avoid it.
- Discord voice receive is less polished than playback. Test early on the actual server.
- Discord speaking events are not reliable VAD. Run local VAD on decoded PCM.
- `codex` may not be a bundled wake word. Plan for a custom model or STT-based phrase spotting fallback.
- Avoid feedback loops: pause wake/STT while TTS plays or ignore the bot's own audio/SSRC.
- Start MVP with one active speaker/utterance at a time.
- DM transcript append can fail due user privacy settings. File/text-channel append is more reliable.
- Make consent obvious: post/play a short notice that the bot is transcribing voice.

## Implementation order

1. Create a small prototype repo or package with two independent processes:
   - `discord-voice-stdio`: Discord voice adapter with JSONL stdin/stdout.
   - `codex-appserver-adapter`: JSONL bridge to `codex app-server --listen stdio://`.
2. Spike Codex app-server stdio:
   - initialize
   - start thread in a target repo
   - start a turn
   - stream assistant deltas
   - send `turn/steer`
   - send `turn/interrupt`
3. Spike Discord playback only: join channel and play a local/generated WAV.
4. Spike receive only: decode one user's Opus and print PCM levels/duration.
5. Add VAD segmentation and fake transcript JSONL.
6. Add STT and wake gate for `codex`.
7. Pipe Discord transcripts into the Codex adapter and pipe assistant events back to TTS playback.
8. Add file/text-channel/DM transcript sinks.
9. Add reconnect, rate limiting, privacy notice, and configuration.

## Recommended next action

Use `codex_dispatch` from this repo to create the prototype or implementation plan, but instruct it to prefer Codex app-server over the existing `codex exec` wrapper for the live voice bridge. The wrapper remains useful for orchestration around the build itself and as a fallback on older Codex versions.
