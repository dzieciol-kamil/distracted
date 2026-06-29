# Horyzont — Design (issue #15)

## Cel

Dodanie tła środowiskowego: niebieskie niebo z animowanymi chmurami nad horyzontem, zielona ziemia pod nim. Ziemia zmienia kolor przy zmianie strefy.

## Decyzje

- **Niebo + chmury:** `WorldEnvironment` z `ProceduralSkyMaterial` — built-in Godot, animowane chmury (drift), gradient niebieski. Stałe we wszystkich strefach.
- **Ziemia:** duży `MeshInstance3D` (płaski box ~500×500 j.) z `StandardMaterial3D` flat color. Kolor zmienia się Tweenem przy przejściu strefy.
- **Renderer:** gl_compatibility — brak custom shaderów, tylko built-in materiały.

## Kolory ziemi per strefa

| Strefa  | Kolor              | Hex       |
|---------|--------------------|-----------|
| VILLAGE | zielona trawa      | `#4caf50` |
| SUBURB  | ciemniejsza zieleń | `#388e3c` |
| TOWN    | szaro-zielony      | `#78909c` |
| CITY    | beton szary        | `#546e7a` |

Kolory do doprecyzowania podczas tuningu — zmiana wyłącznie w jednym miejscu (resource lub stała).

## Zmiany w scenie

- `game.tscn`: dodać `WorldEnvironment` (sky) + `MeshInstance3D` jako ground plane
- `game.gd` lub dedykowany `environment_controller.gd`: nasłuchuje sygnału zmiany strefy z `GameState`, Tween na kolor `StandardMaterial3D` ground plane

## Co NIE wchodzi w zakres

- Zmiana nieba per strefa (decyzja: niebo stałe)
- Custom shadery
- Cząstki chmur 3D
