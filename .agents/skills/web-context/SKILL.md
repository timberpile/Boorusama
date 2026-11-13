---
name: web-context
description: Web-agent-only GitHub-backed conversation context selection, restoration, and checkpointing across separate chats.
---

# Manage Boorusama web-agent conversation contexts

This skill is **only for remote ChatGPT/web agents** using the GitHub connector.
It is not a local coding-agent workflow and does not modify Flutter development,
testing, model settings, or the repository's GitHub Issue lifecycle.

## Storage and authority

- **Procedure:** this file on the latest `origin/develop`. Always load it from
  `develop`, never from an old context branch.
- **One context per branch:** `maintenance/web-context-<slug>`.
- **One context file per branch:** `docs/web-agent-context.md`.
- **No centralized context index or task queue.** Discover contexts from Git refs.
- `develop`, current issue bodies/comments, source code, approved specifications
  and actual branch heads are authoritative for their respective facts.
  Context files contain conversation continuity, not substitute issue statuses,
  live verification evidence or instructions for implementing code.
- Context branches are durable journals: **never merge them into `develop`**,
  use them as implementation bases, rebase them onto source branches, or
  automatically modify unrelated context branches.

## Initialize a chat

1. Fetch current `AGENTS.md` and this skill from `origin/develop`.
   Discover remote refs matching `maintenance/web-context-*` (paginate if
   needed). Do not infer their existence from older chats.
2. If the user has **not** named a context, show existing context names derived
   from branch slugs, plus the option to create a new one. Ask **one direct
   question**: which context to resume or what to name the new context?
   Do not silently choose or create one, even if the list is empty.
3. If the user already supplied a context name or exact branch, select it without
   re-asking. Resolve an unambiguous human name to its existing slug; ask only
   if multiple matches make the choice unsafe.
4. **Resume:** fetch that branch's `docs/web-agent-context.md`, plus its current
   branch head. Read linked authoritative documents as relevant, then reconcile
   changing facts with the *latest* `origin/develop`, GitHub Issues, branch
   heads, and targeted handoffs. Distinguish stale context, unverified notes,
   active tasks, and decisions. Summarize the recovered focus briefly.
5. **Create:** normalize the requested name to a lowercase ASCII kebab slug
   (2–48 characters; letters, digits, hyphens; trim repeated/edge hyphens).
   Refuse reserved/conflicting or ambiguous names instead of overwriting them.
   Create `maintenance/web-context-<slug>` from the current verified
   `origin/develop` HEAD using an authorized GitHub write, then create
   `docs/web-agent-context.md` from the template below. Do not initialize
   unrelated work or create a GitHub Issue merely to store context.
6. If GitHub read/write access is unavailable, explain the blocker and do not
   claim a context was loaded or saved. Continue the conversation without
   fabricating remote state.

## Context file template

Use this compact structure; keep sections relevant and remove empty filler.
The human-facing name is preserved here even if the branch slug differs.

```markdown
# Web context: <human-readable name>

Context slug: <slug>
Updated: <UTC date>
Last reconciled: develop <SHA> (<UTC date>)

## Scope and current focus
- Topic, user goal, and where the discussion should resume.

## Relevant sources
- Canonical GitHub Issues, approved design/spec links, and working branches.
- Distinguish historical source branches from current implementation branches.

## Decisions and rationale
- Decisions reached in conversation that are not already captured in a canonical
  repository document; link there when they have been recorded.

## Findings and open questions
- Confirmed results versus hypotheses; decisions still requiring the user.
- Unfinished investigations, evidence or limitations.

## Next starting point
- The next concrete discussion/research/design/review step, not a task queue.
```

**Do not** copy a full transcript or reproduce GitHub's open-issue backlog.
Keep the file concise (aim for well under 200 lines). If a detailed design,
finding, or accepted decision must outlive this conversation, record it in the
appropriate issue, specification, or subsystem documentation, then link to it.
A context can reference multiple issues/branches and remain independent from
other contexts discussing the same subsystem.

Never store secrets, tokens, credentials, private payloads, sensitive user
information, large logs, generated media, or device-local paths. Do not assume
a code change, merge, test pass, user acceptance, or issue closure unless the
linked source verifies it. A context's `Last reconciled` value records the
actual checked `develop` SHA and date, not a guessed current state.

## Maintain the selected context

- Update **only the selected context** after substantial new decisions,
  verified findings, changes of focus, new authoritative references, or
  a handoff. Save while the chat is active; do not rely on a final message
  or pretend to work asynchronously after the conversation ends.
- Avoid noisy commits for minor back-and-forth or unchanged information.
  Keep concise continuity plus links, not a running diary or alternate status
  tracker. Preserve user-approved decisions when pruning obsolete context.
- Before each write, refetch the context branch head and file blob SHA. Perform
  a compare-and-update using the current file SHA/branch head. If another agent
  updated that context, **re-read and semantically merge** both sets of changes.
  Never overwrite concurrent additions, reset, or force-push. Retry conflicts
  after refreshing remote state; report any unresolved conflict.
- Commit meaningful changes on that **same context branch** using short English
  commit messages such as `docs: update viewer web context`. Verify the
  remote file and commit after writing. Context writes do not authorize code
  commits, GitHub issue changes, PRs, merges, or edits to other branches.
- Periodically validate pointers relevant to the discussion, not every branch
  or issue in the repository. Historical statuses are not automatically current.
- When ending or handing off, save durable progress as above if it changed,
  then report the selected context branch and whether its write was verified.

## Web-to-local boundary

This context stores **web-chat continuity**, not operating instructions for
local coding agents. Local agents use their own `AGENTS.md`, skills, device
environment, verification rules, and model configuration.

**Never transfer** instructions addressed to this web agent about model choice,
thinking effort, subagent counts, parallelism, tool usage, or agent-specific
workflows to local-agent handoffs, Issues or delegation prompts unless the user
explicitly orders that transfer. Handoffs should contain technical results,
decisions, exact source refs, verification actually performed, and outstanding
work only. Review every handoff for accidental instruction transfer.

## Minimal chat starter

```text
Initialize Boorusama web-agent context management. Read
.agents/skills/web-context/SKILL.md from origin/develop. List existing
maintenance/web-context-* contexts and ask which to continue or what to name
a new one, unless I specified the context. Restore and maintain only the
selected context while following the repository's web-agent instructions.
```
