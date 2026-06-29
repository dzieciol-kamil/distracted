# Distracted — Architektura techniczna

## Silnik i renderer

- **Godot 4.4**, GDScript (typed)
- **Renderer:** gl_compatibility (OpenGL ES — max. kompatybilność mobile)
- **Viewport:** 390×844 (iPhone 14 portrait)
- **Stretch:** canvas_items / expand

## Autoloady (singletony)

| Autoload | Plik | Odpowiedzialność |
|---|---|---|
| GameState | scripts/autoloads/game_state.gd | Faza gry, strefa, dystans, prędkość, score |
| SceneManager | scripts/autoloads/scene_manager.gd | Przejścia między scenami |
| AudioManager | scripts/autoloads/audio_manager.gd | Muzyka i SFX |
| NotificationManager | scripts/autoloads/notification_manager.gd | Kolejka powiadomień, willpower timer |
| HazardSpawner | scripts/autoloads/hazard_spawner.gd | Spawn/despawn przeszkód |

## Sceny

```
scenes/
  ui/
    main_menu.tscn    — ekran tytułowy
    game_over.tscn    — wynik i retry
  game/
    game.tscn         — główna scena rozgrywki (root)
    player.tscn       — CharacterBody3D gracza
    chunk_manager.tscn — pula chunków jezdni
    hud.tscn          — CanvasLayer: score, strefa, willpower bar
    phone_overlay.tscn — CanvasLayer z=10: overlay telefonu
  hazards/            — sceny przeszkód (do dodania)
```

## Hierarchia sceny Game

```
Game (Node3D)
  ├── WorldContainer (Node3D)
  │   ├── ChunkManager (Node3D)
  │   └── HazardContainer (Node3D)
  ├── Player (CharacterBody3D, group: "player")
  ├── GameCamera (Camera3D)
  ├── DirectionalLight3D
  ├── HUD (CanvasLayer)
  └── PhoneOverlay (CanvasLayer, layer=10)
```

## System pasów (lanes)

```
Lane 0 (left):   x = -1.2
Lane 1 (center): x =  0.0
Lane 2 (right):  x = +1.2
```

Gracz startuje na pasie 1 (centrum). Zmiana pasa = Tween 0.25s ease-in-out cubic.

## Chunki jezdni

- Długość chunku: 20 jednostek (oś z)
- Aktywnych jednocześnie: 6 (120 jednostek)
- Pula: 10 obiektów (6 aktywnych + 4 bufor)
- Recykling: chunk.z > player.z + 15 → wróć do puli, respawn z przodu

## Fazy gry

```gdscript
enum GamePhase { ROAD, PHONE, GAME_OVER, PAUSED }
```

- ROAD → domyślna, gracz biegnie, widoczne zagrożenia
- PHONE → overlay telefonu zasłania 80% ekranu; widać dolny pasek jezdni
- GAME_OVER → kolizja z przeszkodą → za 1.5s przejście na game_over.tscn
- PAUSED → gra wstrzymana (aplikacja w tle)

## Progresja stref

| Strefa | Dystans | Prędkość | Interwał powiadomień |
|--------|---------|----------|----------------------|
| VILLAGE | 0–500m | 6 u/s | 30s |
| SUBURB | 500–1500m | 9 u/s | 20s |
| TOWN | 1500–3000m | 13 u/s | 12s |
| CITY | 3000m+ | 18 u/s | 6s |

## Willpower mechanic

1. NotificationManager co `interval` sekund emituje `notification_arrived`
2. WillpowerBar zaczyna odliczać od `current_willpower_time` → 0
3. Gdy bar = 0 → `GameState.set_phase(PHONE)`
4. Gracz może zdismissować powiadomienie → `GameState.set_phase(ROAD)`
5. `current_willpower_time` i `interval` to **tuningowalne krzywe**, nie hardkodowane wartości

## Maszyna stanów

```
ROAD ─── notification_timeout ──→ PHONE_INTERRUPT
         (willpower bar = 0)         │
                                    ├─ dismissed → ROAD
                                    └─ hazard_hit → GAME_OVER
ROAD ─── hazard_hit ──────────→ GAME_OVER
```

Interrupt = kolejka-o-długości-1. **Nie hardkodować "jest dokładnie jeden telefon".**

## Metryki sesji

Dwie metryki trzymane w GameState przez całą sesję:
- `distance: float` — dystans w metrach
- `time_on_phone: float` — łączny czas w sekundach gdy phase == PHONE_INTERRUPT

Na ekranie Game Over: dystans + procent czasu w telefonie.

## Kolizje (warstwy)

```
Layer 1: World (krawędzie jezdni, bariery)
Layer 2: Player
Layer 3: Hazards (samochody, rowerzyści)
Layer 4: Triggers (strefy stopu, sygnalizacja)
```

## Input

| Akcja | Klawiatura (dev) | Dotyk (mobile) |
|-------|-----------------|-----------------|
| lane_left | A / Left | Swipe lewo (>40px) |
| lane_right | D / Right | Swipe prawo (>40px) |
| dismiss_notification | Escape | Tap na DismissButton |

## Dane

- `src/data/notifications/notifications.json` — lista powiadomień z tekstami
- Konfiguracja stref: stałe w `GameState` (GDScript constants, nie JSON)
