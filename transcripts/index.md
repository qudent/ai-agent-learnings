# Transcript Index

Agent-specific state is stored in `agents/<slug>/profile.md`, `agents/<slug>/inbox.md`, `transcripts/active/<slug>.md`, and `transcripts/archive/<date>-<slug>.md`.

List active agents with:

```bash
find transcripts/active agents -maxdepth 3 -type f 2>/dev/null | sort
```
