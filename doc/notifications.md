# Distracted — Model powiadomień

## Dwie rozdzielone warstwy

Notyfikacja = **treść** × **typ interakcji**

Rozdzielenie jest celowe: ta sama treść może raz wymagać dismiss, raz slide-to-view. Model: pula treści × pula gestów, łączone przy spawnie z sensownymi ograniczeniami ("następna piosenka" nie pasuje do SMS-a).

## Koszty uwagi

| Typ | Gest | Czas oczu w tel. | Przykłady |
|-----|------|-----------------|-----------|
| **Glance** | Jeden tap | ~0.5s | Dismiss, następna piosenka |
| **Action** | Gest wymagający celności | ~1-2s | Slide-to-unlock, swipe zdjęć, decline call |
| **Trap** | Wciąga | ~3-5s+ | Odpisz mamie, scrolluj zdjęcia, "idź pobiegać" |

Typ interakcji = koszt uwagi = ryzyko na drodze. To naturalna krzywa trudności bez dotykania prędkości.

## Paleta gestów (docelowo 4-5)

- **tap** — szybkie tapnięcie (dismiss, ok, następna piosenka)
- **slide** — przesunięcie poziome (slide-to-unlock, odblokowanie, cofnij/następna)
- **swipe_up** — odrzuć połączenie (szybkie, ale specyficzne)
- **hold** — przytrzymaj (dłuższe, np. "czytasz wiadomość")
- **scroll** — przewijanie (trap, np. "128 wiadomości w grupie")

**Trzymaj paletę małą, pulę treści dużą.**

## Format JSON

```json
{
  "id": "mom_photos",
  "app": "SMS",
  "sender": "Mama",
  "text": "Wysłałam ci 47 zdjęć, widziałeś?",
  "cost": "trap",
  "gesture": "scroll",
  "compatible_gestures": ["dismiss", "scroll"]
}
```

## Kolejka powiadomień (M5+ / City zone)

W M1: interrupt to kolejka-o-długości-1. Rozszerzenie do prawdziwej kolejki = dodanie listy i logiki wyboru, nie przepisanie.

**Nie hardkodować "jest dokładnie jeden telefon na ekranie" w dziesięciu miejscach.**

Kolejka pojawia się jako mechanika **miasta** — po wsi (jeden bodziec naraz) gracz ma gesty w palcach i jest gotowy na kakofonię. Eskalacja fabularna, nie arbitralna trudność.

## Skalowanie contentu

- Nowy gest → działa ze wszystkimi pasującymi treściami
- Nowa treść → działa ze wszystkimi pasującymi gestami
- Dodanie żartu/gestu = zmiana danych w JSON, nie commit w logice spawnera
