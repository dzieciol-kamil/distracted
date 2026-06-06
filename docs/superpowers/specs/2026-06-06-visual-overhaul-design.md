# Visual Overhaul — Design Spec
_2026-06-06_

## Cel

Zastąpić proceduralne `BoxMesh` w chunkach, postaci i hazardach modelami 3D z paczek Kenney (CC0, użycie komercyjne dozwolone bez atrybucji).

## Źródła assetów

Wszystkie paczki w `src/art/` — CC0, można używać komercyjnie.

| Paczka | Zastosowanie |
|---|---|
| `kenney_animated-characters-protagonists` | Postać gracza |
| `kenney_retro-urban-kit` | Droga village (dirt) + suburb (asphalt) + dekory (drzewa, trawa) |
| `kenney_city-kit-roads` | Droga town/city + latarnie |
| `kenney_city-kit-suburban_20` | Budynki w tle — suburb |
| `kenney_city-kit-industrial_1.0` | Budynki w tle — town |
| `kenney_city-kit-commercial_2.1` | Budynki w tle — city (+ skyscrapery) |
| `kenney_car-kit` | Samochody, ciężarówka, traktor, skrzynka, pachołek |
| `kenney_cube-pets_1.0` | Krowa, pies |
| `kenney_train-kit` | Pociąg (osobne zadanie — backlog) |

`src/art/` nie jest usuwany — zostaje jako archiwum do czasu zakończenia wyboru assetów.

## Struktura docelowa `src/assets/`

```
src/assets/
  characters/
    protagonist/
      characterMedium.fbx
      idle.fbx / run.fbx / jump.fbx
      skaterMaleA.png            ← domyślna skórka
  road/
    village/                     ← retro-urban-kit, dirt
      road-dirt-straight.glb
      road-dirt-center.glb
    suburb/                      ← retro-urban-kit, asphalt
      road-asphalt-straight.glb
      road-asphalt-center.glb
    town_city/                   ← city-kit-roads
      road-straight.glb
      road-end.glb
  environment/
    village/                     ← retro-urban-kit: drzewa, trawa
    suburb/                      ← suburban_20: budynki a-u
    town/                        ← industrial_1.0: budynki a-t
    city/                        ← commercial_2.1: budynki + skyscrapery
  hazards/
    sedan.glb / truck.glb / tractor.glb
    animal-cow.glb / animal-dog.glb
    box.glb / cone.glb
    light-curved.glb
```

## Podejście: Layered delivery (B)

Trzy osobne issues, każdy kończy się działającą grą:

1. **Issue 1 — Chunk system** (największy impact, główna zmiana architektury)
2. **Issue 2 — Player model** (podmiana sceny, brak zmian w logice)
3. **Issue 3 — Hazard models** (podmiana meshów, brak zmian w logice)
4. **Issue 4 — Pociąg** (nowa mechanika — backlog)

---

## Issue 1: Chunk system z GLB road tiles

### Co się zmienia

`chunk_manager.gd` przestaje tworzyć `BoxMesh`/`MeshInstance3D` w kodzie. Zamiast tego składa chunk z instancji GLB kafelków drogowych i losowych propsów z puli strefy.

### Wymiary kafelków

Do ustalenia przy imporcie do Godot — prawdopodobnie 2×2 lub 4×4 jednostki. Chunk builder oblicza `tile_count = CHUNK_LENGTH / tile_size` dynamicznie na podstawie rozmiaru zaimportowanego mesha.

### Nowe pola w `Zone` resource

```gdscript
@export var road_tile: PackedScene        # jeden kafelek drogi dla tej strefy
@export var prop_pool: Array[PackedScene] # pula budynków/drzew po bokach
@export var prop_density: float           # odstęp między propsami (jednostki Z)
```

### Logika chunk buildera

Dla każdego chunku:
1. Pobiera `Zone` dla danej pozycji Z (istniejąca logika `_zone_for_chunk_z`)
2. Instancjonuje `road_tile` N razy wzdłuż osi Z
3. Po obu bokach jezdni spawuje losowy props z `prop_pool` co `prop_density` jednostek, na `x = ±(path_width/2 + margines)`

### Mapowanie strefy → road tile

| Strefa | Kafelek | Pack |
|---|---|---|
| VILLAGE | `road-dirt-straight.glb` | retro-urban-kit |
| SUBURB | `road-asphalt-straight.glb` | retro-urban-kit |
| TOWN | `road-straight.glb` | city-kit-roads |
| CITY | `road-straight.glb` | city-kit-roads |

### Mapowanie strefy → propsy w tle

| Strefa | Propsy |
|---|---|
| VILLAGE | drzewa, trawa (retro-urban-kit) |
| SUBURB | domy podmiejskie a-u (suburban_20) + drzewa |
| TOWN | budynki przemysłowe a-t (industrial_1.0) |
| CITY | budynki komercyjne + skyscrapery (commercial_2.1) |

---

## Issue 2: Player model

### Co się zmienia

Tylko scena `player.tscn` — brak zmian w `player.gd`.

Do `Player` (CharacterBody3D) dodajemy:
- `MeshInstance3D` z `characterMedium.fbx` i teksturą `skaterMaleA.png`
- `AnimationPlayer` z biblioteką animacji z osobnych FBX

### Animacje

| Stan | Animacja |
|---|---|
| `walk_state == WALKING` | `run` |
| `walk_state == STOPPED` | `idle` |
| `phase == PHONE` | `idle` |

Przełączanie animacji przez sygnały `GameState.phase_changed` i obserwację `walk_state` w nowym skrypcie dołączonym do `AnimationPlayer`.

---

## Issue 3: Hazard models

### Co się zmienia

Podmiana geometrii w istniejących scenach hazardów — brak zmian w `hazard.gd` ani `lane_obstacle.gd`.

### Mapowanie

| Scena | Model | Pack |
|---|---|---|
| `samochod.tscn` | `sedan.glb` (warianty: police, taxi, hatchback) | car-kit |
| `ciezarowka.tscn` | `truck.glb` | car-kit |
| `traktor.tscn` | `tractor.glb` | car-kit |
| `krowa.tscn` | `animal-cow.glb` | cube-pets |
| `pies.tscn` | `animal-dog.glb` | cube-pets |
| `skrzynka.tscn` | `box.glb` + `cone.glb` | car-kit |
| `latarnia.tscn` | `light-curved.glb` | city-kit-roads |
| `kaluza.tscn` | flat quad + przezroczysta tekstura (procedural) | — |

Kolizje pozostają na istniejących `CollisionShape3D` — rozmiar dostosowany do nowego mesha.

---

## Issue 4: Pociąg (backlog)

Nowy hazard `pociag.tscn` oparty na modelach z `train-kit`. Pociąg przejeżdża przez przejazd kolejowy prostopadle do kierunku ruchu gracza. Spawn tylko w strefach TOWN i CITY. Mechanika (sygnalizacja, okno czasowe) do zaprojektowania osobno.

---

## Co NIE jest częścią tego scope'u

- Zmiany w logice gry (`player.gd`, `hazard.gd`, `game_state.gd`)
- HUD / UI / telefon
- Nowe typy powiadomień
- Usunięcie `src/art/` (osobne zadanie po zakończeniu wyboru)
- Skórki gracza inne niż domyślna
