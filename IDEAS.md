# Ideas & Proposals

This file tracks ideas and proposals for the finix codebase. When you have an idea for a feature, improvement, or change, submit a PR adding an entry using the template below.

**Note:** PRs to this file should only come from contributors of any repository under the `finix-community` GitHub organization. PRs from non-contributors may be declined.

## Template

Copy the template below and fill in each section:

```markdown
### [Title]

- **Status:** `proposed` `in-progress` `completed` `declined` (pick one).
- **Author:** @your-handle
- **Date:** YYYY-MM-DD
- **Description:** A clear and concise description of the idea.
- **Motivation:** Why is this needed? What problem does it solve?
- **Proposed Approach:** High-level outline of how it could be implemented (optional).
- **Related:** Links to issues, PRs, or discussions (optional).
```

### [Do not evaluate modules by default]

- **Status:** `proposed`
- **Author:** @willowispll
- **Date:** 2026-06-22
- **Description:** Make finix do not evaluate any modules by default.
- **Motivation:** This will make the system even more lightweight and unopinionated; furthermore, users should primarily use profiles anyway.
- **Proposed Approach:** Edit modules/default.nix?
- **Related:** Multiple conversations in discord
