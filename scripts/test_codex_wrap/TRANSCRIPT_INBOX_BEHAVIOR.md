# Transcript Inbox Behavior

- Starting a wrapper run creates:
  - `agents/<slug>/profile.md`
  - `agents/<slug>/inbox.md`
  - `transcripts/archive/<date>-<slug>.md`
  - `transcripts/active/<slug>.md`
- Commit bodies are concise pointers, not full transcript bodies.
- Git author identifies the speaker or agent that caused the commit.
- User follow-up messages append to the target inbox and transcript with a
  `user:` block.
- Assistant output appends to the transcript with a `codex:<slug>:` block.
- Stopping or aborting removes only `transcripts/active/<slug>.md`; archive
  transcript and inbox remain.
