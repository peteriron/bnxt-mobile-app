# Working with Claude Code

The repo is set up so an AI pair can work in it with little re-explaining. These conventions also help any new human contributor.

## `CLAUDE.md` at the repo root

Short, specific, and about *this* repo. It points to `REQUIREMENTS.md` (what and why) and the setup guide (how to build and test), then states the rules that aren't obvious from the code:

- The exact command that runs both test suites, and why each flag is there.
- The testing policy: tests with every feature, test-first for every bug, update rather than delete tests.
- Regenerate the project after adding files.
- The dependency-injection pattern to follow, and the shared mocks to reuse.
- UI-test pitfalls discovered the hard way.
- Patterns to watch for (a nested `ObservableObject` that doesn't propagate changes).

Keep it current: when a pitfall costs time, add a sentence. When a rule changes, rewrite it. See [CLAUDE.template.md](CLAUDE.template.md).

## Scratch directory inside the repo

A gitignored `.tmp/` (with a committed `.gitkeep`) for logs, captures, downloaded reference material and probe scripts. It stays reachable without extra permissions, never ends up in a commit, and is cleaned up once its contents have served their purpose. That matters most for anything containing personal data or credentials.

## A release runbook as a command

`.claude/commands/release.md` is a numbered runbook (see 04). It encodes the order, the stop conditions ("don't continue past a failing test") and the judgment parts (writing What's New), and ends by handing Submit for Review back to a human. `/release 2.1.0` runs it.

## How to ask for work

What worked well here:

- **"Grill me first"** before a large feature: one topic at a time, concrete options with a recommendation, answers written into `REQUIREMENTS.md` straight away.
- **Hand over real artifacts**, like a HAR capture from the official website, instead of describing an endpoint. Delete them afterwards if they contain your login.
- **Ask for a prototype before code**, and review it with real data.
- **State constraints as decisions** ("no services that need a person's login") so they're recorded and apply to later work.
- **Report bugs plainly.** The test-first rule means a bug report automatically gets a reproducing test.

## Memory

Claude keeps per-project memory notes outside the repo for things the code can't tell it: the user's preferences, the live App Store state, lessons like "check App Store Connect before staging". Facts the repo already records (code structure, decisions, history) belong in the repo, not in memory.

## Safety rails worth keeping

- Commits and pushes only when asked; feature work on a branch, merged when asked.
- No destructive or outward-facing action (deleting branches, withdrawing a submission, publishing) without confirmation, and after looking at the target first.
- Secrets stay out of the repo and out of chat output: redact auth headers when inspecting captures.
- Submit for Review is always the human's click.
