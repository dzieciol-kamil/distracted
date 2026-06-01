# Distracted — Game Concept

## Elevator pitch

Endless walker inspirowany Subway Surfers / dino z Chrome'a. Grasz pieszym wpatrzonym w telefon, idącym przez coraz bardziej niebezpieczną drogę. Powiadomienia odciągają uwagę od ruchu drogowego — im bardziej trenujesz silną wolę, tym bardziej telefon walczy o Twoją uwagę. Gra jest jednocześnie arcade'em i komentarzem o uzależnieniu od telefonu.

## Model rozgrywki — dino-style (kluczowa decyzja)

Zawsze zaczynasz od zera. Jedna sesja, natychmiastowy restart, brak zapisów stanu, brak meta-progresji.

**Dlaczego:** Core fantasy brzmi "nigdy nie jesteś bezpieczny, tylko lepiej wybierasz, kiedy się rozproszysz". Trwała progresja z odblokowaniami podkopałaby ten przekaz. Wieczny restart utrwala tezę: za każdym razem zaczynasz tak samo bezbronny — tak samo jak telefon w prawdziwym życiu.

**Świeżość** bez progresji = dwie osie:
1. Treść powiadomień (humor, charakter postaci)
2. Typ interakcji wymagany przez powiadomienie

## Metryki końcowe (ekran Game Over)

- **Dystans** — jak daleko doszedłeś
- **Czas w telefonie** — jaki % czasu patrzyłeś w ekran

Ekran końcowy: _"Przeszedłeś 1,2 km. Patrzyłeś na drogę przez 14% czasu."_

To edukacyjny payoff — lusterko, nie wykład. Zamienia wynik w refleksję.

Zapis: tylko te dwie metryki, w localStorage (web) — brak infrastruktury serwerowej.

## Dual-view — serce mechaniki

**Road mode (domyślny)**
- Widok zza pleców (Subway Surfers POV)
- Pełna droga widoczna, hazardy czytelne z wyprzedzeniem

**Phone mode (wyzwalany wyczerpaniem paska silnej woli)**
- Telefon wjeżdża z góry (CanvasLayer), zasłania ~80% ekranu
- Widoczny tylko ~30 cm paska drogi na dole — peryferyjne napięcie
- Gracz czyta/obsługuje powiadomienie, pasek drogi tworzy instynktowne napięcie
- Telefon zjeżdża po obsłużeniu lub odrzuceniu powiadomienia

**Kluczowa decyzja architektoniczna:** dual-view to **stan** (`ROAD` / `PHONE_INTERRUPT`), nie osobna scena. Telefon to overlay/CanvasLayer nad ciągle żyjącą rozgrywką. Świat ticka dalej pod spodem — notyfikacja **zasłania, ale nie pauzuje**. To jest cały myk.

## Mechanika silnej woli (willpower)

Pasek silnej woli = czas między nadejściem powiadomienia a wymuszonym sprawdzeniem telefonu.

- Zaczyna krótki (niska wola), rośnie w miarę postępu
- Częstotliwość powiadomień też rośnie z postępem
- Efekt netto: gracz nigdy nie jest bezpieczny — staje się tylko lepszy w **wybieraniu, kiedy się rozproszy**

**Implementacja:** willpower i częstotliwość jako **tuningowalne krzywe/resource'y**, nie hardkodowane wartości — będą tunigowane setki razy.

## Notyfikacje — model danych

Notyfikacja = dwie rozdzielone warstwy:

1. **Treść** (kto, o czym — humor, charakter)
2. **Typ interakcji** (jaki gest, jaki koszt uwagi)

Rozdzielenie jest celowe: ta sama treść może raz wymagać dismiss, raz slide-to-view. Model: **pula treści × pula gestów**, łączone przy spawnie z sensownymi ograniczeniami.

### Przykłady treści

- SMS od mamy: "Wysłałam ci 47 zdjęć, widziałeś?"
- Instagram: ktoś polubił twoje zdjęcie z 2019
- Spam: "Gwarancja na twój samochód wygasła"
- Dostawa jedzenia 3 przystanki dalej
- Grupa WhatsApp: 128 nieprzeczytanych
- Przypomnienie o aktualizacji systemu (6. raz dziś)

### Koszty uwagi (typy interakcji)

| Typ | Opis | Czas oczu w telefonie |
|-----|------|----------------------|
| **Glance** | Jeden tap (dismiss, następna piosenka) | ~0.5s |
| **Action** | Gest wymagający celności (slide-to-unlock, swipe zdjęć) | ~1-2s |
| **Trap** | Wciąga (odpisz mamie, scrolluj zdjęcia) | ~3-5s+ |

Typ interakcji = koszt uwagi = ryzyko na drodze. To skalowanie trudności bez dotykania prędkości.

### Skalowanie contentu

- Nowy gest → działa ze wszystkimi pasującymi treściami
- Nowy żart → działa ze wszystkimi pasującymi gestami
- Nowa treść/gest = zmiana danych, nie kodu

**Uwaga scope:** trzymaj paletę gestów małą (4-5: tap, slide, swipe L/R, hold), pulę treści dużą.

## Kolejka powiadomień (NIE w MVP)

Kilka powiadomień naraz — wybierasz, co teraz obsługujesz, na każdym odłożonym leci timer. Przejście z "reaguj na bodziec" do "zarządzaj uwagą jako zasobem".

**Dlaczego nie teraz:** dodaje drugą oś trudności na wierzch pierwszej. Może być genialne albo kakofonia.

**Architektonicznie:** w M1 zrób interrupt jako stan z **kolejką-o-długości-1**. Rozszerzenie do prawdziwej kolejki = dodanie listy, nie przepisanie. **Nie hardkoduj "jest dokładnie jeden telefon na ekranie" w dziesięciu miejscach.**

## Progresja stref

| Strefa | Gęstość ruchu | Powiadomień/min | Hazardy |
|--------|--------------|-----------------|---------|
| Village | Bardzo niska | 1-2 | Kałuże, zwierzęta (królik, pies), traktor |
| Suburb | Niska | 3-4 | Rowerzyści, wyjeżdżające auta, światła |
| Town | Średnia | 5-6 | Hulajnogi, przejścia, budowy |
| City center | Wysoka | Ciągłe | Auta z wielu pasów, autobusy, tramwaje |

Hazardy ogólnie: światła (czerwone = stop), przejeżdżające auta, rowerzyści, hulajnogi, zwierzęta, bariery, inni piesi (też w telefonach — meta), kałuże/lód.

**Przejście między strefami = zmiana danych, nie nowy kod.**

## Platforma i tech

- **Primary:** web (Godot 4 → HTML5/WebGL) — gra w przeglądarce, tablice interaktywne
- **Późniejszy:** mobile (iOS + Android)
- **Silnik:** Godot 4 / GDScript
- **Styl:** TBD — flat 2.5D albo voxel (Crossy Road-adjacent)

## Monetyzacja (TBD)

- Lives / continues
- Skiny telefonu i postaci
- "Notification packs" (tematyczne żarty)
- F2P + opcjonalny premium "Digital Detox" — ironicznie usuwa reklamy
