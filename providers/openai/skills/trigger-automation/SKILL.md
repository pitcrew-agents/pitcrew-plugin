---
name: trigger-automation
description: >
  Set up a trigger that fires an existing PitCrew agent automatically — on a
  cron schedule, when an external event happens in Gmail / Drive / Slack /
  etc., or chained to another agent's bulk run. Activate when the user asks
  to schedule an agent, run it on an event, or wire two agents together.
---

## When to use this skill

Activate when the user says things like:

- "run this agent every Monday morning", "every 2 hours", "once a day"
- "when I get a new email from X, run my Y agent"
- "whenever a new file lands in this Drive folder, …"
- "after my bulk run of agent A finishes, start agent B"
- "start a bulk run of agent C whenever D runs"
- "turn off / pause this trigger", "delete this trigger", "show me what's scheduled"

Do NOT activate for:

- Running an agent **once right now** → use `start_agent_run` instead
- Building or editing an agent → use the Builder skills
- Changing an agent's per-run settings → use `configurations`, not triggers

## The four trigger types

Pick the right one based on how the user wants the agent to fire.

| Trigger type | Fires when | User-phrase examples | Tool |
|---|---|---|---|
| **Schedule** | A cron expression matches, in a specific timezone | "every weekday at 9am", "every hour" | `create_schedule_trigger` |
| **Event** | An external app (Gmail, Drive, Slack, …) emits a configured event via Composio | "when a Gmail arrives", "when a Drive file is uploaded" | `create_event_trigger` (then `enable_trigger`) |
| **Start bulk** | A parent agent runs — kicks off a bulk run of a child agent, one child per iterated item | "when I run A, bulk-run B for every row in A's output" | `create_start_bulk_trigger` |
| **After bulk** | A target agent's bulk run completes — fires this agent with aggregated results | "after bulk C finishes, run D with the aggregated reports" | `create_after_bulk_trigger` |

## Core workflow

1. **Identify the target agent.** If the user didn't name an exact agent, call `list_agents` and have the user pick.
2. **Pre-flight based on trigger type** (see the per-type sections below).
3. **Check existing triggers.** Call `list_agent_triggers` on the agent. If a similar trigger already exists, tell the user and ask whether to replace it or create another — the backend allows duplicates, so don't rely on it to deduplicate.
4. **Confirm before creating.** For each trigger type, confirm the key choices with the user (schedule + timezone, event source + mapping, target agent for bulk). Triggers can create recurring real-world activity — don't guess.
5. **Create.** Call the matching `create_*_trigger` tool.
6. **For Event triggers only**: the trigger is returned **inactive**. Call `enable_trigger` immediately after a successful create. Do NOT tell the user the trigger is active until `enable_trigger` succeeds.
7. **Summarise back.** Tell the user: trigger name, what fires it, when the next run will be (for Schedule / After bulk), and how to disable or delete it.

## Pre-flight: Schedule triggers

Before calling `create_schedule_trigger`:

1. **Call `list_schedule_presets`.** If a preset matches the user's intent ("every hour", "every weekday at 9am"), use the preset's `cron` value verbatim. Do not invent cron if a preset fits.
2. **Confirm the timezone.** Default sensibly to the user's locale if obvious from their message; otherwise ask. Timezone is required — the trigger will not create without it.
3. **payload_mapping** is optional. Only ask the user if the agent needs inputs that don't have sensible defaults in its spec.

## Pre-flight: Event triggers

Before calling `create_event_trigger`:

1. **Call `list_toolkits`** to confirm the app the user mentioned (Gmail, Drive, Slack, …) is actually connected.
2. **Call `list_available_external_triggers`** with the relevant toolkit slug. Each returned trigger has:
   - `slug` → use as `trigger_slug`
   - `toolkit_slug` → use as `toolkit_slug`
   - `config_schema` → tells you what to put in `trigger_config` (ask the user for each required field)
   - `payload_schema` → tells you what fields will be available for `payload_mapping`
3. **Build `trigger_config`** from the config_schema fields. Ask the user for each required field (e.g. Gmail: label, interval, query filter).
4. **Build `payload_mapping`** by matching the agent's input fields to the trigger's payload fields using JSONPath (e.g. `{"email_subject": "$.payload.subject"}`). Ask the user how they want each agent input filled.
5. **Call `create_event_trigger`.** The returned trigger has `enabled: false`.
6. **Immediately call `enable_trigger`.** Only now is the trigger live.

## Pre-flight: Start-bulk and After-bulk triggers

Before calling `create_start_bulk_trigger` or `create_after_bulk_trigger`:

1. **Call `list_agents`** and confirm the target agent exists. Use its id as `target_agent_id`.
2. For **start_bulk**: ask the user what field in the parent agent's output represents the "list of things to iterate over." Build an `iterate` map like `{"client_id": "$.state.items[*].id"}`. `iterate` must be non-empty — the backend rejects empty.
3. For **after_bulk**: ask the user what aggregated data the downstream agent needs. Options for `aggregate_mode`: `final_reports` (default — list of each child's final report), `all_outputs` (list of every task output per child), `s3_manifest` (pointer to full artifact set in S3). Build `payload_mapping` with JSONPath rooted at `$.bulk_run`.

## Important things to tell the user

- **No test-fire**: there is no API to fire a trigger immediately for testing. It will fire on its actual next real occurrence (next cron tick, next real email, next real bulk completion). Set expectations accordingly.
- **Admin role required** for creating, enabling, disabling, deleting. If the backend returns 403, surface it as "you need admin role in your organization to manage triggers."
- **Composio-backed event triggers** depend on the user having connected the relevant app (Gmail, Drive, etc.) in their PitCrew settings. If `enable_trigger` fails with an auth-shaped error, point them to the integrations page.
- **Duplicates are allowed** — the backend will happily create two identical triggers. Only `list_agent_triggers` + user confirmation prevents this.
- **Deleting is permanent.** `delete_trigger` cannot be undone. For a pause, use `disable_trigger` instead.

## Diagnosing a trigger that didn't fire

If the user says their trigger didn't fire:

1. Call `list_agent_triggers` to check `status` (should be `active`) and `enabled` (should be `true`).
2. Call `list_trigger_executions` to see whether the trigger received an event at all. If no executions, the issue is upstream (schedule hasn't ticked yet, Gmail hasn't matched, bulk run hasn't completed). If executions exist but failed, the payload_mapping or the agent itself likely has an issue.

## Tool reference

Discovery (read-only):
- `list_toolkits` — connected third-party apps for Event triggers
- `list_available_external_triggers(toolkits, limit)` — specific event slugs within an app
- `list_schedule_presets` — cron presets (hourly, weekday 9am, etc.)
- `list_agent_triggers(agent_id)` — existing triggers on an agent

Creation:
- `create_schedule_trigger(agent_id, name, schedule_expression, timezone, payload_mapping?)`
- `create_event_trigger(agent_id, name, trigger_slug, toolkit_slug, trigger_config, payload_mapping)` → **then** `enable_trigger`
- `create_start_bulk_trigger(agent_id, name, target_agent_id, iterate, shared?, config_id?)`
- `create_after_bulk_trigger(agent_id, name, target_agent_id, aggregate_mode?, min_success_rate?, payload_mapping?)`

Lifecycle:
- `enable_trigger(agent_id, trigger_id)`
- `disable_trigger(agent_id, trigger_id)`
- `delete_trigger(agent_id, trigger_id)` — permanent

Debugging:
- `list_trigger_executions(agent_id, trigger_id, limit?, offset?)`
