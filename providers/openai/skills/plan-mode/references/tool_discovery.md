# Tool Discovery Guide

This guide explains how to find relevant tools from the virtual filesystem
at `/tools/`. Use this during the plan_worker's tool discovery step.

---

## Filesystem Layout

```
/tools/
  shared/
    builtin/          ← built-in platform tools (always available)
      pdf_tools.md
      csv_analysis_tools.md
      code_gen_tools.md
      report_tools.md
      ...one .md file per category
    composio/         ← external integrations (Gmail, Slack, HubSpot, Salesforce, etc.)
      gmail_tools.md
      slack_tools.md
      salesforce_tools.md
      ...one .md file per toolkit
    dynamic/          ← platform-level dynamic integrations
      ...
  org/
    {org_id}/
      custom/         ← org-specific custom scripts
        ...
      dynamic/        ← org-specific integrations
        ...
```

Each `.md` file contains multiple tools, each as an `## ToolName` heading
followed by a JSON schema block with `name`, `description`, `input_schema`,
and `output_schema`.

---

## Step-by-Step Discovery Process

### Step 1 — List available categories

Start with a broad `ls` to see what tool categories exist:

```
ls /tools/shared/builtin/
ls /tools/shared/composio/
```

This shows you the file names (e.g. `pdf_tools.md`, `gmail_tools.md`).
Each file name tells you what category of tools it contains.

### Step 2 — Search by keyword

Use `grep` to quickly find tools matching your intent keywords.
Search the entire `/tools/` tree in one call:

```
grep -r "pdf" /tools/
grep -r "email" /tools/
grep -r "compliance" /tools/
grep -r "salesforce" /tools/
```

The results show you which files contain relevant tools and which heading names match.

**Good keywords to try based on intent:**
- File processing: `pdf`, `csv`, `excel`, `extract`, `parse`, `read`
- Integrations: the service name — `gmail`, `slack`, `hubspot`, `salesforce`, `box`
- Data operations: `validate`, `analyse`, `analyse`, `compare`, `score`
- Output: `report`, `email`, `send`, `notify`, `generate`
- Web: `scrape`, `http`, `url`, `crawl`

### Step 3 — Read matching tool files

Once you know which file(s) contain relevant tools, read them:

```
read_file /tools/shared/builtin/pdf_tools.md limit=100
read_file /tools/shared/composio/gmail_tools.md limit=100
```

The `limit=100` keeps context small — enough to see all tool names and descriptions.
Read the full schema block only for tools you plan to include in the plan.

### Step 4 — Check all_integrations index

For external integrations, there is a summary index file:

```
read_file /tools/shared/composio/all_integrations.md
```

This gives you a one-line description per toolkit so you can quickly decide
which integrations are relevant without reading each file.

### Step 5 — Write candidates to workspace

After identifying candidate tools, write them to the workspace so the orchestrator
and edit_worker can reference them:

```
write_file /workspace/tool_candidates.md
```

Format:
```markdown
# Tool Candidates

## Selected Tools

- **read_pdf** (builtin) — Extracts text from PDF files
- **validate_content** (builtin) — Validates content against policy rules
- **generate_report** (builtin) — Generates structured visual report
- **GMAIL_SEND_EMAIL** (composio:gmail) — Sends email via Gmail

## Considered but Excluded

- analyze_csv — user's input is PDF, not CSV
```

---

## Tool Name Conventions

| Source | Name format | Example |
|---|---|---|
| Built-in | `snake_case` | `read_pdf`, `analyze_csv`, `generate_report` |
| Composio | `ALLCAPS_WITH_UNDERSCORES` | `GMAIL_SEND_EMAIL`, `SLACK_POST_MESSAGE` |

Always use the exact tool name as it appears in the tool file — these are
what the edit_worker will wire into tool_config.tool_name.

---

## Always-Available Tools

These tools are always available regardless of the tool index.
You do not need to discover them — include them in any plan that needs them:

| Tool | When to use |
|---|---|
| `download_file` | Download a file from a URL to make it available for other tools |
| `read_pdf` | Extract text from a PDF |
| `analyze_csv` | Parse and analyse a CSV file |
| `excel_reader` | Read Excel files (.xlsx, .xls) |
| `read_pdf_tables` | Extract tables specifically from PDFs |
| `write_file` | Write content to a file |
| `read_file` | Read a file's content |
| `http_get` | Make an HTTP GET request |
| `http_post` | Make an HTTP POST request |
| `scrape_url` | Scrape content from a web page |
| `code_gen` | Generate and execute Python code in a sandbox (no network access) |
| `generate_report` | Generate a rich structured report (ALWAYS use as final task) |

---

## Choosing Between Tools

### File processing
- PDF → `read_pdf` (text) or `read_pdf_tables` (tables)
- CSV → `analyze_csv`
- Excel → `excel_reader`
- Word/HTML → use `download_file` first, then `read_file`

### External services
- Gmail → `GMAIL_SEND_EMAIL`, `GMAIL_FETCH_EMAILS`
- Slack → `SLACK_POST_MESSAGE`, `SLACK_FETCH_MESSAGES`
- HubSpot → search `grep -r "hubspot" /tools/`
- Salesforce → `grep -r "salesforce" /tools/`
- Other → check `all_integrations.md` then grep for the service name

### Data validation/compliance
- Policy checks → `validate_content` (if it appears in grep results)
- Custom validation logic → `code_gen` (Python sandbox, no network)
- LLM-based assessment → use an `llm_call` task in the agent

### Final output (always include)
- `generate_report` — for any agent producing structured findings, summaries, or reports
- Do NOT use plain `llm_call` as the last task unless the output is conversational text only

---

## Inclusion in the Plan

In `submit_plan()`, the `tools` parameter should list the exact tool names
the edit_worker will use in tool_config.tool_name:

```json
["read_pdf", "validate_content", "GMAIL_SEND_EMAIL", "generate_report"]
```

Do NOT include:
- Tools you discovered but won't use
- Vague categories or filenames
- Tools that require integrations the user hasn't mentioned needing

The edit_worker will read the tool schemas from `/tools/` using these names
to get the exact input_schema parameters before building the agent.
