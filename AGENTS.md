# Boorusama agent instructions

## Required reading

- Before repository changes, read [the development workflow](docs/development_workflow.md).
- Before repository ticket work, read [the task queue rules](docs/work/README.md)
  and check related tickets. For a specific request, stay within its scope.
- Before investigating a subsystem, read its relevant documentation under
  `docs/`. Before changing Dart or Flutter code or tests, read
  [the engineering guidelines](docs/engineering_guidelines.md).

## Ticket ownership and delivery

- The coordinating agent selects and claims eligible tickets, delegates each
  ticket's implementation to an implementer subagent, and reviews the result.
  The coordinator does not implement a ticket itself. The implementer may
  implement its assigned ticket directly; this rule does not require recursive
  delegation. If subagents are unavailable, report the blocker rather than
  implementing the ticket in the coordinator's place.
- Give every ticket its own worktree and branch based on the latest
  `origin/develop`. Never reuse a ticket's branch or worktree for another
  ticket. Claim the ticket before implementation, record the agent/session,
  worktree, and branch, and do not take over another claim without coordination.
- Verify the acceptance criteria and prepare the result for user review. Only
  after the user's explicit approval, manually squash-merge the ticket's pull
  request into `develop` as one commit. Do not directly commit a ticket to
  `develop` or enable auto-merge. After verifying the merge and remote branch
  deletion, remove that ticket's local worktree and branch.
- Follow the queue's status and evidence rules. A ticket does not authorize
  unrelated work, publication, or delivery.

## Repository and credentials

- Use `gh` for GitHub work. Never perform GitHub actions on a repository other
  than `timberpile/Boorusama`; target that repository explicitly in CLI calls.
  For other repositories, provide manual instructions instead.
- Always use `fvm` for Flutter and Dart. Use the Maestro MCP server to control
  the Android emulator when validating UI behavior.
- Emulator test accounts are already signed in. Read only needed entries from
  the ignored `.test_credentials` file. Never commit its contents or paste
  them into logs, screenshots, issues, responses, or test fixtures.
