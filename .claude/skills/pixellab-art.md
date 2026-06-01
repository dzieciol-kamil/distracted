# PixelLab — generowanie assetów

## MCP vs REST API

**MCP tool `create_object` z `reference_image_base64` jest zepsuty** — PixelLab bug:
- MCP owrappuje stringa w `{base64: value}` i wymaga `width`/`height`
- API v2 jednocześnie odrzuca `width`/`height` jako "extra inputs not permitted"

**Rozwiązanie:** użyj REST API bezpośrednio.

## Klucz API

Przechowywany w `.env` (gitignored): `PIXEL_LAB_APIKEY=...`

## Generowanie assetów dla Distracted

### Styl

Low-poly / voxel, widok z perspektywy za postacią (Subway Surfers / Crossy Road).
Tło: jezdnia z pasami, chodniki, budynki po bokach.
Kolory: czyste, nasycone, brak realizmu — cel: czytelność na telefonie.

### Postać gracza (pieszy)

```python
import base64, json, urllib.request

with open('/Users/kamil/Projects/distracted/.env') as f:
    for line in f:
        if line.startswith('PIXEL_LAB_APIKEY='):
            key = line.strip().split('=', 1)[1]

payload = {
    "description": "low-poly voxel pedestrian walking, looking at smartphone, casual clothes, viewed from behind at slight angle, game character, simple blocky style, bright colors",
    "view": "isometric",
    "size": 64,
    "n_directions": 1,
    "outline": "lineless",
    "shading": "medium shading",
    "no_background": True,
    "seed": 42
}

req = urllib.request.Request(
    'https://api.pixellab.ai/v1/generate-image-pixflux',
    data=json.dumps(payload).encode(),
    headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
    method='POST'
)
```

### Polling statusu (background jobs)

```python
import time

while True:
    req = urllib.request.Request(
        f'https://api.pixellab.ai/v2/background-jobs/{job_id}',
        headers={'Authorization': f'Bearer {key}'}
    )
    with urllib.request.urlopen(req) as r:
        resp = json.load(r)
    if resp['status'] == 'completed':
        break
    elif resp['status'] == 'failed':
        raise Exception(resp)
    time.sleep(15)
```

## MCP — co DZIAŁA (bez reference image)

```
create_character(
    description="...",
    view="isometric",
    size=64,
    n_directions=4,
    outline="lineless",
    shading="medium shading"
)
# Potem: get_character(character_id=...) po ~3 min
```

## Działające endpointy (v2)

- `POST /v2/generate-8-rotations-v3` — 8 rotacji z referencji
- `POST /v2/map-objects` — obiekty na mapę
- `GET /v2/background-jobs/{job_id}` — polling statusu

## Gdzie zapisywać assety

- Postacie: `src/assets/textures/characters/`
- Jezdnia/tiles: `src/assets/textures/environment/`
- Hazardy: `src/assets/textures/hazards/`
- UI: `src/assets/textures/ui/`
