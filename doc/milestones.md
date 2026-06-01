# Distracted — Milestony

## M1 — Vertical slice (moment prawdy)

**Cel:** Rdzeń się broni albo nie. Jedna grywalna scena, faza 1 (village), end-to-end.

**Zakres:**
- Auto-scroll walker
- Jeden typ hazardu (np. kałuża)
- Willpower bar
- Jeden interrupt z telefonem (jedna notyfikacja)
- Działający dual-view: overlay nad żywym światem, pasek 30 cm
- Metryki: dystans + % czasu w telefonie na ekranie końcowym
- Dummy-art: kolorowe prostokąty, zero sprite'ów

**Architektura już musi być porządna:**
- Stan `ROAD`/`PHONE_INTERRUPT` — nie hardkodować
- "Typ interakcji" jako pierwszorzędne pole w modelu notyfikacji
- Interrupt jako kolejka-o-długości-1 (rozszerzalna do prawdziwej kolejki)
- Willpower jako tuningowalne krzywe w resource'ach, nie hardkod

**Test:** Jeśli loop nie jest wciągający na placeholderach, żadne sprite'y go nie uratują.

---

## M2 — Fazy + skalowanie systemów

**Cel:** Village → Suburb jako data (nie nowy kod).

**Zakres:**
- System stref jako data (JSON/Resource)
- Willpower i frequency jako tuningowalne krzywe per faza
- 2-3 typy hazardów
- "Never safe" faktycznie się czuć

**Debug-narzędzie:** skok do dowolnej strefy (nie przez 3 min normalnej gry).

---

## M3 — Lista rozpraszaczy jako system

**Cel:** Notyfikacje jako deklaratywny zbiór, łatwy do rozszerzania.

**Zakres:**
- Notyfikacje jako Resource/JSON, losowane przy spawnie
- Model: pula treści × pula gestów
- 3-5 typów interakcji (tap, slide, swipe L/R, hold)
- Koszty uwagi (Glance / Action / Trap) widoczne w kodzie
- Treści: humor, charakter postaci

**Uwaga:** pisanie treści to inny tryb pracy niż mechanika — można robić "na luzie".

---

## M4 — Sprite'y i feel

**Cel:** Przejście z placeholderów na docelowy styl.

**Zakres:**
- Decyzja art style: flat 2.5D vs voxel/Crossy Road (osobne issue `decision`)
- Animacja telefonu wjeżdżającego
- Feedback przy kolizji z hazardem
- Juice (screen shake, dźwięki, particles)

**Dopiero teraz** — malowanie czegoś, co zmienia kształt, to marnotrawstwo.

---

## M5 — Testy (GUT)

**Cel:** Pokryć to, co psuje się cicho i drogo.

**Co testować:**
- Logika willpower (timing, granice, krzywe)
- Spawn/kolizje hazardów
- Parsowanie danych notyfikacji
- Maszyna stanów dual-view (ROAD ↔ PHONE_INTERRUPT ↔ GAME_OVER)

Nie TDD na całość — tylko logika, nie pixele. Może iść równolegle do M2 gdy krzywe willpower się stabilizują.

---

## M6 — Dokumentacja pod granty

**Cel:** Demo + dokumentacja w języku profilaktycznym.

**Zakres:**
- Gameplay trailer/gif (wymaga M4)
- Opis w języku profilaktycznym
- Moduł dla nauczyciela / scenariusz lekcji
- System kodów dla szkół (mechanizm dystrybucji)
- Statystyki końcowe (metryka czasu w telefonie)
- Rozdział kosztowy web vs mobile

**Zależy od M4** (sprite'y w trailerze). Przy presji deadline'u M4 i M6 idą równolegle.

---

## Kolejność i równoległość

```
M1 → M2 → M3 → M4 → M6
          ↘ M5 (równolegle od M2)
               M4 i M6 przy deadline'ach grantu
```
