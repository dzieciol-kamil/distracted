# Distracted — Game Concept

## Elevator pitch

Endless walker inspired by Subway Surfers. You play as a pedestrian glued to their phone, navigating an increasingly dangerous road. Notifications pull your attention away from traffic — and the more you train your willpower, the more your phone fights back.

## Core loop

1. Walk forward (auto-scroll, Subway Surfers POV)
2. Notification arrives → willpower bar starts counting down
3. When bar hits zero → phone flies in from the top, blocking most of the screen
4. Player handles the notification (tap, swipe, dismiss) while only seeing ~30cm of road at the bottom
5. Phone slides back up → full road view restored
6. Repeat, escalating in density and speed

## Dual view

**Road mode** (default)
- Third-person view from behind, Subway Surfers style
- Full road visible, hazards readable in advance

**Phone mode** (triggered by willpower bar expiry)
- Phone drops from top of screen, covers ~80% of view
- Only a ~30cm strip of road visible at the bottom edge
- Player reads/handles notification on the phone screen
- Exits when notification is resolved or dismissed

The strip at the bottom creates peripheral tension — player instinctively watches it even while reading the notification, exactly like in real life.

## Willpower mechanic

- **Willpower bar**: time between notification arrival and forced phone check
- Starts short (low willpower), grows as the game progresses
- But: notification frequency also increases with progression
- Net effect: player is never safe — just better at choosing *when* they get distracted

## Progression: Rural → City

| Zone | Traffic density | Notification frequency | Hazards |
|------|----------------|----------------------|---------|
| Village | Very low | 1–2 per minute | Puddles, animals (rabbit, dog), slow tractor |
| Suburb | Low | 3–4 per minute | Cyclists, parked cars pulling out, traffic lights |
| Town | Medium | 5–6 per minute | Scooters, crossings, construction zones |
| City center | High | Constant | Cars from multiple lanes, buses, trams, cyclists |

## Notifications (examples)

Notifications are a source of humor and character — they tell a story about who this person is:
- SMS from mom ("I sent you 47 photos, did you see them?")
- Instagram: someone liked your photo from 2019
- Spam call: "Your car warranty has expired"
- App notification: your food delivery is 3 stops away
- WhatsApp group: 128 unread messages
- System update reminder (for the 6th time today)

## Hazards

- Traffic lights (red = stop, player must stop or dodge)
- Cars crossing
- Cyclists from behind or head-on
- E-scooters
- Animals (village: rabbits, dogs; city: pigeons)
- Construction barriers
- Other pedestrians (also on phones — meta)
- Puddles / ice

## Monetization (ideas, TBD)

- Lives / continues
- Cosmetic phone skins, character skins
- "Notification packs" (themed joke notifications)
- F2P with optional "Digital Detox" premium — ironic name, removes ads

## Technical notes

- Platform: mobile (iOS + Android primary)
- Engine: TBD (Godot 4 candidate — existing tooling)
- Art style: TBD — could work as flat 2.5D or voxel (Crossy Road-adjacent)
- MVP scope: one zone (village → suburb), 3 notification types, core dual-view mechanic
