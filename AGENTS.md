# AI Coding Assistant Guide

This document provides **binding guidance** for any AI coding
assistant (e.g., Claude, Gemini, Copilot, etc.) working on this
project. Its purpose is to make AI-assisted development **reliable,
transparent, secure, and repeatable**. This file is about *how we
work*, not what we're building.

See [README.md](./README.md) project-specific context; additionally
the AI assistant MUST follow:

- The project documentation index found in [docs/README.md](./docs/README.md). This index MUST be consulted to locate specific documents and MUST be updated whenever new ADRs or TDDs are added.
- The **architecture decisions** contained within [docs/adr/](./docs/adr/)
- The **technical designs** contained within [docs/tdd/](./docs/tdd/)
- The **core principals**, conventions, and security rules described here.

---
## Core Principals

- We prefer simple, clean, maintainable solutions over clever or
  complex ones, even if the latter are more concise or
  performant. Readability and maintainability are primary concerns.
- Doing it right is better than doing it fast. You are not in a
  rush. NEVER skip steps or take shortcuts.
- Stay focused. Fix only what relates to your current task. Notice something else that needs work? Bring it up in chat or document it separately rather than fixing it now.
- **Small steps, incremental progress** Prefer many small validated moves over
  large leaps. Each phase or task should have a clear, observable checkpoint. If the code request is broad, request the interlocutor to break it down or offer to do so with checkpoints.
- **Surface before solving.** If a command produces unexpected output, a result
  looks ambiguous, or something is being skipped or deferred -- pause and name
  it before moving on. "Good enough to proceed" is a valid call, but make it
  explicitly. Log it if it affects project state.
- Preserve comments. They're documentation, not clutter.
- Write evergreen code. Describe what code does, not when it was
  written. (i.e. avoid "newFunction")

## Conventions

### Interaction norms

We're colleagues working together. Neither of us is afraid to admit we don't know something or are in over our head. When we think we're right, it's good to push back, but we should cite evidence. We trust each other, but verify claims about code functionality rather than taking them at face value if we think they're incorrect.

### Getting help

If you're confused or having trouble with something, you are strongly encouraged to stop and ask for help. Especially if it's something your human might be better at.

### Decision-Making Framework
#### 🟢 Proceed Immediately
- Fix tests, linting errors, type errors
- Implement single functions with clear specs
- Correct typos, formatting, documentation
- Refactor within a single file to improve clarity
- Add missing imports or dependencies
- Remove unnecessary imports or dependencies

#### 🟡 Propose First
- Changes spanning multiple files
- New features or significant functionality
- API or interface changes

#### 🔴 Always Explicitly Ask a Human First!
- Rewriting working code from scratch
- Changing core business logic or removing functionality
- Architectural changes. Architectural decisions are recorded as ADRs
  in [docs/adr/](./docs/adr/). Consult existing ADRs before proposing
  changes that affect architecture.
- Security modifications

###  Testing and Reliability
We follow a test-driven development (TDD) approach: write tests first
to fail, then write the implementation to make them pass.

The assistant MUST:

- Generate tests alongside non-trivial code changes.
- Prefer **small, focused tests** over large, brittle integration tests in early phases.

All newly generated or refactored logic SHOULD have at least **basic test coverage** before being considered complete.

### Defaults

These apply unless overridden for a specific app:

- **Target environments**: confirm before assuming (OS, arch, runtime version)
- **Destructive operations** (delete, overwrite, reboot, migrate): always confirm explicitly, even if it seems like the obvious next step
- **Dependencies**: check what's already installed/present before adding
- **Secrets**: never write credentials, tokens, or keys into any tracked file; flag if a config pattern would require it
- **GitHub**: never commit without explicit request; never push a branch; never propose a commit message without explicit request; new branches should default to branching from `main`
- **Documentation**: ADRs and TDDs are documents that are written and consumed by humans first. If you are asked to generate one, suggest the author create a draft you can format. Other types of documentation can be AI-driven, but do not include extraneous information and highlight assumptions made.

---
## Security, PII, and Logging

The assistant MUST:

- Consider the OWASP Top Ten web application security risks
- Assume that **all record content and case data are sensitive**.
- Ensure:
  - No raw PII is logged to console or application logs by default.
  - Any debug logging is either:
    - Redacted, or
    - Explicitly controlled via environment flags and never enabled in production.

The assistant MUST NOT:

- Introduce new external dependencies that send data to third-party
  services (e.g., error trackers, SaaS analytics) without explicit
  human approval.
- Commit secrets, credentials, API keys, PII or CJI
- Add “phone home” telemetry or non-essential network calls.
- Render unsanitized HTML -- in React, avoid 'dangerouslySetInnerHtml'.
