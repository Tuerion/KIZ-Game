# FOKUS (Arbeitstitel) – Arcade-Prototyp

Endlos-Arcade: Man rollt einen Ball (die eigene Aufmerksamkeit) einen Berg hinauf.
Benachrichtigungen, Werbung und Doomscrolling kosten Aufmerksamkeit.

## Steuerung
- **Tablet:** irgendwo antippen und halten = schieben, ziehen = lenken
- **Test am PC:** Maus wie Touch, oder WASD/Pfeiltasten, oder Controller (linker Stick)

## Ablauf
- **Attract-Mode:** Charakter steht am Fuß des Berges und scrollt am Handy. Berühren startet sofort.
- **Run:** Endloser Berg, Schwierigkeit steigt mit der Strecke. Alle 200 m ein grünes Ruhe-Plateau.
- **Game Over:** Aufmerksamkeit 0, 8 s keine Eingabe (Spieler weggegangen) oder 6 min Limit.
- **Ergebnis:** Höhe, Punkte, Ablenkungsbilanz, Tagesrangliste. Danach automatisch zurück in den Attract-Mode.

## Mechaniken
| Mechanik | Wirkung |
| --- | --- |
| Benachrichtigungen | Treffer kosten Aufmerksamkeit, bleiben am Ball kleben und machen ihn schwerer |
| Benachrichtigungs-Wände | tauchen erst kurz vorher auf – der Wegweiser davor verrät die Lücke |
| Werbe-Popups | kleines X springt manchmal weg; Antippen der Werbung kostet Aufmerksamkeit |
| Doomscroll | bei < 30 % Aufmerksamkeit; nur raus, wenn man 2,5 s nichts berührt |
| Kurz aufs Handy schauen | bei < 55 % bleibt der Charakter kurz stehen, Ball rollt zurück |
| Fokus-Streak | ohne Ablenkung steigt der Punkte-Multiplikator (bis x5) |
| Wenig Aufmerksamkeit | Ball kleiner/grauer, Steuerung träge und wackelig, Reizüberflutung im HUD |

Alle Zahlen zum Feintuning stehen oben in `main/main.gd`.
Highscores liegen in `user://scores.cfg` (pro Tag).
