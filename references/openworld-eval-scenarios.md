# Openworld Evaluation Scenarios

The harness scenarios are intentionally small and auditable.

| Scenario | Candidate | Required evidence |
|---|---|---|
| `browser_form_fill_confirmed` | `browser-use` | confirm_required, replay_handle, rollback_plan |
| `browser_navigation_fallback` | `browser-use` | fallback provider, operator owner, evidence_refs |
| `desktop_operator_visible_edit` | `Agent-S` | replay_handle, checkpoint corpus, rollback_plan |
| `cross_plane_openworld_bundle` | both | unified task contract, confirm_required, no takeover |

All scenarios must remain candidate-only and replayable.
