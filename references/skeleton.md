# Section skeleton

Use this order. **Required** sections appear in every project. **Optional** sections appear only
when there is real content — skip them otherwise, never pad to complete the set.

The required set differs slightly from the sample statistics at the bottom of this file. Reasoning:

- **Testing / Code style** are common across all three samples, but they collapse into filler in
  projects with no test framework and no formatter. Demoted to optional.
- **Environment & commands** is what the agent needs every single time it does anything. Without it
  the agent guesses. Promoted to required.
- **Review checklist** is the agent's self-check anchor, and the only hook that prevents unfounded
  "I'm done" claims. Promoted to required.

## Required

### Repository layout

Directory → one-line responsibility. Code block or table. The agent should know where things live
without reading the README first.

Multi-module projects must show the hierarchy, especially the root-vs-subproject split. That
distinction is where path mistakes cluster.

### Environment & commands

The **exact** commands to install, run, test, and build. Use a code block.

Wrap the block in generation markers **only** when the commands really are script-generated, or
when the source config changes often. Otherwise those two comment lines are just noise:

```markdown
<!-- START generated-commands — re-verify after changing package.json -->
- **Dev server**: `npm run dev`
<!-- END generated-commands -->
```

Hard negative constraints belong here too, written as imperatives:

> **Never run pytest directly on the host.** Always go through `breeze`.

### Review checklist

Checkable pass conditions. Every item must be verifiable. Items that only a human can verify must
be labelled, so the AI cannot claim credit for them.

```markdown
- [ ] `cargo clippy -- -D warnings` is clean
- [ ] The changed path was actually executed — compiling is not verification

**A human verifies these. AI must not claim they are done**: real-device runs, visual regression.
```

## Optional

| Section | Include when |
|---|---|
| **Testing** | A test framework exists. Where tests live, how to run one, how to run all. |
| **Code style** | Conventions exist. Naming, formatter, language version baseline, comment granularity. |
| **Boundaries** | There are lines that must not be crossed. Architecture layering, off-limits directories, artifacts that must not be committed. |
| **Commits & PRs** | Conventions exist. Read `git log` first and follow what is already there. |
| **Domain constraints** | The project has non-negotiable domain definitions: terminology, protocol contracts, design tokens. |
| **Security model** | Credentials, untrusted external input, or privilege boundaries are involved. |
| **Output locations** | Generated files and scratch files need a defined home. |
| **References** | There are documents worth pointing at. **Always last.** One pointer per line, each with its trigger condition. |

Pointers need an explicit trigger:

```markdown
- **Release process**: `docs/release.md` — **required reading** when the user says "cut a release".
```

## Layering

| Layer | Location | Contents |
|---|---|---|
| Global | The agent's user-level config directory | Personal preferences and local environment: language, reasoning style, OS and shell, universal prohibitions |
| Project | `<repo>/AGENTS.md` | Project facts: stack, commands, conventions, boundaries |
| Subdirectory | `<repo>/<dir>/AGENTS.md` | Only what **differs** from the parent. Never repeat the parent. |

One-off requests, temporary plans, and single-iteration goals **do not belong in AGENTS.md**.
Put them in `docs/` or an issue.

When the root file grows, the first move is to **push down** — relocate module-specific rules into
that module's own AGENTS.md. Compressing the prose is the second move, not the first.

---

## Sources

The skeleton is derived from the section statistics of three real projects in the
[agents.md](https://agents.md) showcase:

- apache/airflow — https://github.com/apache/airflow/blob/main/AGENTS.md (522 lines)
- openai/codex — https://github.com/openai/codex/blob/main/AGENTS.md (322 lines)
- temporalio/sdk-java — https://github.com/temporalio/sdk-java/blob/master/AGENTS.md (59 lines)

All three: repository layout, testing, code style.
Most: environment & commands, commits & PRs, review checklist, boundaries, references.

Note that the sample sizes (522 / 322 lines) far exceed the official guidance. Treat them as
cautionary examples of module-local content accumulating in a root file, not as a target.

Instruction verifiability and rule consistency come from Anthropic's
[memory documentation](https://docs.claude.com/en/docs/claude-code/memory), which also recommends
keeping these files as short as possible.

The instruction budget — frontier reasoning models reliably follow roughly 150–200 instructions, and
adding more degrades compliance across **all** of them, not just the new ones — comes from
HumanLayer's [*Writing a Good CLAUDE.md*](https://www.humanlayer.dev/blog/writing-a-good-claude-md).

External material above was surveyed on 2026-08-28. The date is here because these are **snapshots
of external sources** and the linked files change; it is your basis for re-verification. This does
not contradict the "no hand-written dates" rule for AGENTS.md itself — that rule is about facts
concerning your own repo, where `git log` is the authority.
