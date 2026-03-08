# Release Evidence Bundle Contract

Bundle v3 must expose the following required fields.

| Field | Why it is required |
|---|---|
| `bundle_version` | proves the contract schema that the bundle follows |
| `version` | ties the bundle to version governance |
| `updated` | captures the release cut review date |
| `git_head` | links evidence to a concrete repository state |
| `evidence_refs` | points back to board, dashboard, release docs, and verify artifacts |
| `ledger_tail` | makes ledger continuity visible to operators |

Bundle v3 is valid only if these fields are present and non-empty.
