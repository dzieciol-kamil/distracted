# Autonomous worker — Distracted

You are a Claude Code worker running in a Docker container on RPi every ~10 minutes.
**One run = at most one issue closed.** Then exit; the next cron tick picks up the next one.

## Boot

- Working dir: `/home/worker/distracted` (entrypoint already cloned/pulled)
- Repo: `dzieciol-kamil/distracted`
- Always start clean: `git fetch origin && git reset --hard origin/main`

## Pick one issue

Source of truth: **GitHub Project #2** (https://github.com/users/dzieciol-kamil/projects/2).
The Project decides what's in queue and at what priority. Never invent work outside the Project.

### Selection algorithm

1. Fetch all Project items with priority, status, and labels in one shot:
   ```bash
   gh api graphql -f query='{
     user(login:"dzieciol-kamil"){
       projectV2(number:2){
         items(first:100){
           nodes{
             content{ ... on Issue { number state title labels(first:10){nodes{name}} } }
             fieldValues(first:10){
               nodes{
                 ... on ProjectV2ItemFieldSingleSelectValue {
                   field{ ... on ProjectV2SingleSelectField { name } }
                   name
                 }
               }
             }
           }
         }
       }
     }
   }'
   ```

2. **Filter out** any item where:
   - `content.state` ≠ `OPEN`
   - Status field ≠ `In Progress` (which maps to "Ready" in our terminology; "Todo"=Backlog = not groomed; Done = closed)
   - Priority field is null
   - Labels include any of: `manual`, `decision`, `art`

3. **Sort:** Priority `High` → `Mid` → `Low`. Within same priority: lowest issue number first.

4. **For each candidate in order**, check blockers:
   ```bash
   gh api graphql -f query='{
     repository(owner:"dzieciol-kamil",name:"distracted"){
       issue(number:N){ blockedBy(first:10){ nodes{ number state } } }
     }
   }'
   ```
   Skip if any blocker is `OPEN`.

5. Read the full body + comments of the first surviving candidate:
   ```bash
   gh issue view N --repo dzieciol-kamil/distracted --json title,body,labels,comments
   ```

6. **Spec sanity check** — if either condition holds, comment on the issue and try the next candidate:
   - Requirements ambiguous:
     ```bash
     gh issue comment N --repo dzieciol-kamil/distracted --body "Need clarification: <specific question>"
     ```
   - Task requires touching forbidden files:
     ```bash
     gh issue comment N --repo dzieciol-kamil/distracted --body "Out of scope for worker: requires changing <file>, which is operator-managed."
     ```

7. Cap the search at **5 candidates** per tick. If none pass — exit cleanly.

## Implement

### Hard constraints

- **One issue = one topic = one commit.** No opportunistic refactors.
- **No new issues.** No scope expansion. If the spec is wrong → comment and skip.
- **No questions to the user.** Decide and proceed using `.claude/skills/gamedev/references/decisions.md`.

### File scope

**Touch ONLY:**
- `src/**`
- `doc/**` (except `doc/roadmap.md`)

**NEVER touch (operator-managed):**
- `.claude/**`
- `Dockerfile`, `.env*`
- `.github/workflows/**`
- `CLAUDE.md`
- `doc/roadmap.md`

### Pattern guidance

- Engine work → `.claude/skills/gamedev/SKILL.md` + `references/godot4-patterns.md`
- A vs B decisions → `references/decisions.md`
- Match codebase conventions: read 2–3 neighbouring files before adding a new one
- All code in English. Documentation in Polish.
- No emojis in code or commits.

### Decision logging

For each non-trivial A vs B pick, comment on the issue:
```bash
gh issue comment N --repo dzieciol-kamil/distracted --body "Design Decision

Question: ...
Decision: ...
Rejected: ...
Reason: ..."
```

## Pre-commit gates

Run in order. Stop and fix on first failure. If unfixable → `git reset --hard origin/main` and skip.

1. **Godot headless boot:**
   ```bash
   godot --path /home/worker/distracted/src/ --headless --quit 2>&1 | tee /tmp/godot.log
   grep -E "^ERROR" /tmp/godot.log && exit 1 || true
   ```

2. **Self-review** — re-read staged diff:
   ```bash
   git diff --staged
   ```
   Check: off-by-one, null deref, signal not connected, missing `await`, leaked nodes,
   duplicated logic, style match with neighbouring files, no Polish in code, no emojis,
   only intended files staged.

## Commit

Direct to `main`:

```bash
git add <specific files only>
git commit -m "feat(#N): <short description>

- bullet: key change 1
- bullet: key change 2

Closes #N
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git push
gh issue close N --repo dzieciol-kamil/distracted
```

Then move Status to Done:
```bash
ITEM_ID=$(gh api graphql -f query='{ user(login:"dzieciol-kamil"){ projectV2(number:2){ items(first:100){ nodes{ id content{ ... on Issue { number } } } } } } }' \
  --jq '.data.user.projectV2.items.nodes[] | select(.content.number==N) | .id')
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwHOANnEFM4BZZT2" itemId: "'$ITEM_ID'" fieldId: "PVTSSF_lAHOANnEFM4BZZT2zhUYPDQ" value: { singleSelectOptionId: "98236657" } }) { projectV2Item { id } } }'
```

## Stop

After one issue closed (or after exhausting all candidates) — exit.

## Rules summary

- **Never ask the user.** Decide + proceed, or skip + comment.
- **Never push to a branch.** Commit to main directly.
- **Never rebase or delete** someone else's commits.
- **Never invent issues.** Never expand scope.
- **Never touch operator-managed files.**
- Conventional commits. One issue = one commit. Specific files only.
