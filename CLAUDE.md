# Distracted — Claude Working Rules

## Zawsze zacznij sesję od:
1. Przeczytaj `./doc/` — pełna dokumentacja projektu, koncepcja, mechanika, decyzje
2. Sprawdź projekt na GitHub: https://github.com/users/dzieciol-kamil/projects/2

## Zawsze kończ sesję:
1. Zaktualizuj odpowiednie pliki w `./doc/` jeśli coś ustalono
2. Zrób commit i push na aktywnym branchu
3. Zamknij issue na GH jeśli zadanie ukończone: `gh issue close <number> --repo dzieciol-kamil/distracted`

## Struktura projektu
- `./doc/` — dokumentacja: koncepcja, mechanika, decyzje
- `./src/` — kod gry (Godot 4, GDScript, 3D)

## Workflow z zadaniami
- Backlog = GitHub Project: https://github.com/users/dzieciol-kamil/projects/2
- Issues trackowane na: https://github.com/dzieciol-kamil/distracted/issues
- Dostępne labele: `bug`, `feature`, `art`, `content`, `decision`, `manual`
- Pola w projekcie: **Status** (Backlog / Ready / Done), **Priority** (High / Mid / Low)
- Status "Backlog" = Todo w GitHub UI, "Ready" = In Progress w GitHub UI
- Każde nowe issue po stworzeniu: dodaj do projektu i ustaw Priority — domyślnie Mid
- Każde zadanie developerskie = osobny branch: `feature/<issue-number>-krotki-opis`
- Branch tworzymy od `main`, mergujemy do `main` po ukończeniu
- Branch twórz przez GitHub: `gh issue develop <number> -n feature/<number>-opis --repo dzieciol-kamil/distracted`
- Każde zakończenie zadania:
  1. Commit + push na branchu
  2. Uruchom Code Review (`/review`) na tym branchu
  3. Popraw znaleziska z CR
  4. Zamknij issue na GH: `gh issue close <number> --repo dzieciol-kamil/distracted`
  5. Ustaw Status → Done w projekcie
  6. Merge do `main`

### Jak dodać nowe issue do projektu i ustawić Priority
```bash
# 1. Stwórz issue
gh issue create --repo dzieciol-kamil/distracted --title "..." --body "..." --label feature

# 2. Pobierz node ID issue
ISSUE_ID=$(gh api graphql -f query='{ repository(owner:"dzieciol-kamil",name:"distracted"){ issue(number:NR){ id } } }' --jq '.data.repository.issue.id')

# 3. Dodaj do projektu
ITEM_ID=$(gh api graphql -f query='mutation { addProjectV2ItemById(input: { projectId: "PVT_kwHOANnEFM4BZZT2" contentId: "'$ISSUE_ID'" }) { item { id } } }' --jq '.data.addProjectV2ItemById.item.id')

# 4. Ustaw Priority Mid (domyślne)
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwHOANnEFM4BZZT2" itemId: "'$ITEM_ID'" fieldId: "PVTSSF_lAHOANnEFM4BZZT2zhUYPN8" value: { singleSelectOptionId: "ec97aadb" } }) { projectV2Item { id } } }'

# 5. Ustaw Status Backlog
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwHOANnEFM4BZZT2" itemId: "'$ITEM_ID'" fieldId: "PVTSSF_lAHOANnEFM4BZZT2zhUYPDQ" value: { singleSelectOptionId: "f75ad846" } }) { projectV2Item { id } } }'
```

IDs do zapamiętania:
- Project ID: `PVT_kwHOANnEFM4BZZT2`
- Priority field ID: `PVTSSF_lAHOANnEFM4BZZT2zhUYPN8` | High: `203d4713` | Mid: `ec97aadb` | Low: `1fcc62af`
- Status field ID: `PVTSSF_lAHOANnEFM4BZZT2zhUYPDQ` | Backlog (Todo): `f75ad846` | Ready (In Progress): `47fc9ee4` | Done: `98236657`

## Relacje i blokady między issues
```bash
# Pobierz node ID issues
ID_BLOCKED=$(gh api graphql -f query='{ repository(owner:"dzieciol-kamil",name:"distracted"){ issue(number:BLOCKED_NR){ id } } }' --jq '.data.repository.issue.id')
ID_BLOCKER=$(gh api graphql -f query='{ repository(owner:"dzieciol-kamil",name:"distracted"){ issue(number:BLOCKER_NR){ id } } }' --jq '.data.repository.issue.id')

# Ustaw relację
gh api graphql -f query='mutation { addBlockedBy(input:{ issueId:"'$ID_BLOCKED'", blockingIssueId:"'$ID_BLOCKER'" }){ issue { number } } }'

# Sprawdź blokady
gh api graphql -f query='{ repository(owner:"dzieciol-kamil",name:"distracted"){ issue(number:NR){ blockedBy(first:10){ nodes{ number title } } } } }'
```

## Walidacja Godot
```bash
godot --path /Users/kamil/Projects/distracted/src/ --headless --quit 2>&1
```
Zero ERRORów = ok. Warningi są akceptowalne jeśli celowe.

## AI Visual QA

Dla prac związanych z visual QA traktuj issue #22 jako źródło prawdy.

Polecenia:

    godot --path /Users/kamil/Projects/distracted/src/ --headless --quit 2>&1
    godot --path /Users/kamil/Projects/distracted/src/ --scene res://scenes/qa/visual_qa.tscn --quit-after 180 -- --qa-capture
    godot --path /Users/kamil/Projects/distracted/src/ --quit-after 300 -- --qa-gameplay-smoke

Wygenerowane screenshoty i logi trafiają do `qa-artifacts/` i nie są commitowane.

PR-y opisuj najpierw językiem produktowym:
- co widział gracz,
- dlaczego to było problemem czytelności, feelingu albo fair play,
- jaki efekt dla gracza ma mieć zmiana,
- co AI przetestowało,
- co nadal wymaga decyzji właściciela.

Jeśli AI nie wie, czy coś jest błędem czy stylem, nie zmieniaj tego w kodzie. Załóż osobne issue ze screenshotem, kontekstem i proponowanym efektem dla gracza, a potem poczekaj na akceptację.

Po decyzjach właściciela, które zmieniają zakres auto-poprawek, aktualizuj `docs/ai-visual-qa-guidelines.md`.

## Spec i plan — TYLKO w GitHub Issues (nie w plikach lokalnych)

GH Issue jest jedynym źródłem prawdy. **Nigdy** nie twórz lokalnych plików spec/plan.

**Spec** (po brainstormingu) → body issue:
```bash
gh issue edit <nr> --repo dzieciol-kamil/distracted --body "$(cat <<'EOF'
## Spec
...
EOF
)"
```

**Plan** (po writing-plans) → komentarz do issue:
```bash
gh issue comment <nr> --repo dzieciol-kamil/distracted --body "$(cat <<'EOF'
...treść planu...
EOF
)"
```

Przed writing-plans zawsze pobierz spec z issue:
```bash
gh issue view <nr> --repo dzieciol-kamil/distracted
```

Pełny flow: `brainstorming → spec w body issue → /clear → writing-plans → plan jako komentarz → /clear → executing-plans`

## Zasady pracy
- Dokumentacja po polsku (rozmowy z właścicielem), kod i komentarze po angielsku
- Przed kodowaniem — zawsze doprecyzuj wymagania w `./doc/`
- Pilnuj wszystkich dobrych praktyk SOLID, KISS, DRY
- Kod ma być przede wszystkim czytelny
