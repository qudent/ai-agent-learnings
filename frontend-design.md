# Frontend Design Instructions

Project-agnostic frontend guidance distilled from user instructions in this
repo's full reachable git history. Source-specific names such as
`chatgit`/`codex-web-interface` are kept only where they explain provenance;
the rules below should be applied to future frontend work generally.

## Scope And Sources

Reviewed with `git log --all` on 2026-04-30, focusing on human-authored
`[codex_start_user]`, `[codex_resume_user]`, `@codex`, and user-edited
`STATUS.md` commits. The main source cluster is the 2026-04-29
`codex-web-interface` pass.

Primary source commits:

- `b7a52ce` - user-edited `STATUS.md` with the original UI wishlist.
- `8ad96cf` - test-driven frontend behavior expectations.
- `9fdef7c` - broken web branching and parent-branch tree convention.
- `39e7422` - auto-update, transcript access, branch rename, naming, hints.
- `20ee50d` - active-branch visual indication and chatbox uploads.
- `3e67529` / `e0f93ad` - parent/child branch metadata and naming consistency.
- `2416ed9` - message queuing and recursive branch testing.
- `d748e60` / `9ccb5e5` - paste/drop attachments and removable arbitrary files.
- `0e98811` / `76efbf6` - left bar information architecture and run grouping.
- `a530edb` / `2eeb3dc` - auto-refresh and overflow fixes.
- `b083847` - load roundtrips, confusing UI, sizing/proportioning.
- `7f54469` - supplied timeline redesign proposal.
- `23479f0` / `1e1468e` - selection, copy-message controls, queue semantics.
- `f2de1a3` / `d536430` - row-click affordance and button spacing.
- `ac60b99` - negative critique: button factory, huge path header, weak
  hierarchy, dense wall text, overlong placeholder, dull palette.
- `bd2d3bc` - clearer detail copy, run controls, pause naming, explicit queue.
- `8525b4b` / `37acbd4` - visible active state must match behavior; branch
  from message should work in parallel.
- `5de0df1` - manually exercise the UI and find issues after merging.

## Core Product Model

- Design for user intent, not backend storage. If the backend is Git history
  but the user is reading a conversation, the UI should read as a conversation
  timeline rather than an audit log.
- Make the data model visible in the simplest useful way: branches are
  conversations, branch ancestry is a subtle tree, and runs belong under the
  branch that owns them.
- Do not infer important hierarchy from paths. Store and display explicit
  parent metadata such as `parent-branch` and `parent-commit`.
- Active, queued, finished, aborted, and archived runs should be grouped under
  their owning branch. Finished runs must remain accessible instead of
  disappearing behind dead "Show" controls.
- A useful branch/run unit contains branch metadata, an active run if present,
  queued messages, finished runs, transcripts, marker commits, prompts, and
  attachments.

## Layout

- Prefer a dense three-pane work surface for Git-backed chat interfaces:
  conversation/branch list on the left, selected conversation in the middle,
  selected detail/patch/transcript on the right.
- The left pane should reflect branch ancestry subtly. Avoid a flat list that
  makes child branches look like independent root conversations.
- Conversation rows should prioritize the message or prompt first. Hashes,
  statuses, paths, and other system metadata belong in a smaller, quieter
  metadata line.
- Keep long paths and rare actions out of the main header. Put secondary
  actions such as rename/delete/checkout behind an ellipsis or compact menu.
- Fix overflow with stable grid sizing, scroll containers, truncation, and
  ellipsis where appropriate. Long status rows must not paint across panes.
- Pay attention to proportioning and sizing, especially in branch rows and
  repeated controls. Crowded gutters, flush timeline markers, and uneven button
  spacing are defects.
- Test narrow/mobile layouts yourself. A page that puts hundreds of rows before
  the composer or detail pane is not usable, even if desktop looks acceptable.

## Timeline And Visual Hierarchy

- For conversation history, use a timeline metaphor: a continuous vertical line
  and status nodes communicate sequence better than isolated card piles.
- Use node shape/color for status where possible, instead of repeating large
  "finished" or "active" labels on every item.
- Active/running state should be visually attached to the branch or run row,
  for example by row coloring or an explicit status marker. A separate "active
  branch" label below the list is not enough.
- Green/active styling must mean a real live process is running. Once the
  process exits, the branch should stop looking active.
- Avoid equal-volume interfaces where every label, hash, button, and body line
  competes for attention. The message is primary; metadata and actions are
  secondary.
- Avoid dull one-note palettes and unstyled terminal dumps. Raw log/detail text
  can be useful, but the surrounding hierarchy should make it scannable.

## Controls And Affordances

- Rows should be clickable when that is the natural affordance. Clicking a
  commit row should open its patch/detail; clicking a run row should open its
  transcript.
- Row clicks must not interfere with text selection or explicit button clicks.
- Prefer compact icon or menu actions over repeated text-button factories.
  Repeated `Transcript`, `Patch`, and `Copy` buttons under every row create
  clutter.
- Make copy behavior explicit. If a control copies the message, call it
  `Copy message`; if it copies a hash, make that clear and add a discoverable
  hint.
- Include obvious hints for hidden affordances, such as hash-click-to-copy.
- Button text must describe the actual action. Ambiguous labels such as
  `Send/queue`, `Abort active`, or generic `Copy hash` in a message detail
  context cause confusion.
- Put run controls where users act on runs. A pause/abort control belongs near
  Continue/Fresh/Branch/Queue, not isolated in a header.
- Name destructive or interruptive controls by user effect. Prefer `Pause run`
  over `Abort active` when the user-facing meaning is pausing/stopping a run.
- Queuing should be an explicit option. `Continue` should not silently mean
  "queue this behind the active run" unless the UI says so plainly.

## Composer And Attachments

- Prefer paste and drag/drop for screenshots and files over a prominent
  `Attach screenshot` button.
- Attachment handling should support arbitrary files, not only screenshots.
- Attachments shown in the composer need an `x` or equivalent remove control
  before sending.
- The UI should explain enough about attachment storage to avoid ambiguity:
  whether files are committed, temporary, or stored under the repo metadata
  area.

## Refresh, State, And Performance

- Auto-refresh repo/conversation state when relevant inputs change; do not
  require a manual refresh after entering a new path.
- Empty marker commits or state updates should appear without a full browser
  refresh.
- Passive refresh must not destroy text selection.
- Measure roundtrips and payload size when the UI feels slow over SSH tunnels.
  Reduce initial and polling requests where possible.
- If there are stale "open" transcripts or runs, make their state explicit and
  repair the visible history so users are not left guessing.

## Branching And Parallel Work

- Branching from a selected message should work even while the current branch
  has an active run, because the new branch can run in a separate worktree.
- Same-worktree actions may need active-run guards, but branch creation should
  not be blocked by an unrelated active process when it targets a child
  worktree.
- Multiple browser tabs should be able to send commands to different
  branches/worktrees in parallel without branch/log collisions.
- Recursive branch creation should be tested: child branches should be able to
  create grandchild branches while preserving metadata and UI hierarchy.

## Detail And Patch Views

- The detail pane should say exactly what it shows: selected commit patch,
  selected run transcript, or selected message text.
- A commit detail view should support full commit message plus patch output,
  such as `git show --format=fuller --patch`, when that is the useful detail.
- Showing only the first line in summary lists is usually right; expand into
  fuller detail only after selection.
- If a commit has sibling descendants, expose them with a dropdown or similarly
  compact selector.
- Full-file expansion from a patch can be useful, but it is lower priority than
  clear summary/detail navigation.

## Naming And Copy

- Use product names that distinguish the UI from the backend tool. For example,
  `codex-web-interface` is clearer than `codex-web` when the latter sounds like
  a web version of Codex itself.
- Review command/API/UI names after features drift. A name that was accurate
  before queueing, branching, or run controls may become misleading.
- Keep metadata key names generic when they describe general behavior:
  `parent-branch`, not app-specific variants such as `chatgit-parent`.

## Implementation Style And Verification

- Keep frontend implementation simple when the surface is still small. A
  single-page plain JavaScript app is acceptable if it remains understandable;
  do not add framework bloat by default.
- Use test-driven development for frontend behavior too. If browser test
  infrastructure is too heavy, write markdown behavior contracts first, then
  encode them in executable tests when feasible.
- Write tests for UI state contracts such as active marker clearing,
  selection-preserving refresh, row-click behavior, queue semantics, uploads,
  and recursive branch creation.
- After merging UI work, restart the running interface and manually exercise it
  in a browser. Static checks are not enough.
- Use screenshots and narrow viewport checks to find layout problems that
  automated assertions may miss.
