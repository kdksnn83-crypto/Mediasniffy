# One Mission: Nasser Stahl – Prototyp 0.3

Eigenständiger Einzelspieler-Prototyp. Alle Geometrie, Materialien und Geräusche
werden im Projekt erzeugt. Keine kopierten Arma-Assets, externen Bibliotheken,
Plugins oder kostenpflichtigen Ressourcen.

## Implementiert

- First-Person-Bewegung, Sprint/Ausdauer, Ducken mit angepasster Kollision,
  Zielen, fünf Schuss, Reserve und zeitgesteuertes Nachladen.
- Wald, Fluss, Stahlbrücke, Wachhütte, Deckung, Forsthütte, Regen und Nebel.
- Vierköpfiger Trupp. Drei Kameraden folgen oder halten; sie sichern gegen
  sichtbare Gegner. Physische Brückenüberquerung mit getrennten Laufspuren.
- Vier Wachen: einfache Patrouille, Sichtkegel, Sichtprüfung gegen Geometrie,
  begrenzte Sichtweite (52 m), Suche am letzten bekannten Ort.
  Gehörte Schüsse verraten den Schussort zeitweise, nicht alle Trupppositionen.
- Zuganfahrt, Entladung und Abfahrt. Alarm verkürzt die Standzeit.
- Zwei erforderliche Brückenladungen, optionale Zugladung, gesperrte Zündung
  bis alle Überlebenden auf dem Nordufer sind.
- Geskriptete Sprengung, Brückenwrack und deaktivierte Brückenkollision.
  Der Zug wird nur mit gesetzter Zugladung während der Entladung zerstört.
- Zwei Verstärkungen kommen nach der Sprengung vom nördlichen Zufahrtsweg.
- Rückzug, Kennwort und Abschlusswertung. Tod des Spielers führt zum Scheitern.
- Feldkarte mit eigener Position, Trupp, bekannten Sabotagepunkten und Fluchtweg.

## Ballistik – Erweiterung 0.2

Der vom Nutzer gelieferte C#-Ansatz wurde für Godot/GDScript angepasst.
Es sind keine Unity-Abhängigkeiten enthalten. Die dünn besetzte Mach/Cd-Kurve
ist die Nutzervorlage, keine verifizierte vollständige G1-Standardtabelle.
G7 ist weiterhin nicht enthalten. Das ist ein plausibles Spielmodell, kein
Nachbau von Arma Reforger oder eine gemessene Patronensimulation.

`config/rifle_ammunition.json` enthält die Munitionsparameter:

- 760 m/s Mündungsgeschwindigkeit, 12,8 g Masse, 7,92 mm Durchmesser.
  Eigene Beispielkonfiguration für das Prototyp-Gewehr, keine zertifizierten
  Leistungsdaten einer historischen Patrone. Mündungsenergie: 3696,64 J.
- Luftdichte 1,225 kg/m³, Schallgeschwindigkeit 343 m/s, Formfaktor 1.
- Cd wird linear zwischen den Mach-Stützstellen interpoliert; außerhalb
  der Tabelle werden die Endwerte verwendet.
- Aerodynamik verwendet die Relativgeschwindigkeit zur Luft:
  F_drag = 0,5 × rho × Cd × Formfaktor × A × |v_rel|²,
  A = pi × (Durchmesser / 2)², a_drag = F_drag / Masse, gegen v_rel.
  Ein konventioneller G1-BC in lb/in² darf nicht unverändert in diese
  SI-Formel eingesetzt werden. Das Original `Cd / BC` braucht eine
  Definition und Umrechnung des BC; hier werden Masse und Fläche direkt
  verwendet. Der Formfaktor ist eine Skalierung der Beispielkurve.
- Schwerkraft 9,81 m/s², Wind 1,2 m/s in Welt-X-Richtung.
- RK2-Mittelpunktsintegration, maximal 1/240 Sekunde pro Teilschritt.
  Das sind Projektil-Teilschritte; keine Behauptung einer 240-Hz-Serverrate.
- Basisstreuung als Kreisdurchmesser 0,36 m bei 100 m. Richtungen werden
  gleichmäßig innerhalb eines Kreises gezogen. Bewegung, freies Schießen
  und Ducken verändern diesen Winkel; keine quadratische Zufallsfläche.
- Visier 100/200/300/400 m, numerisch aus derselben Flugkurve berechnet.
  Die Nulldistanz bezieht sich auf die waagerechte Visierlinie ohne Wind.

`config/impact_materials.json` enthält eigene Material-Spielwerte:

| Material | Energieverlust pro Wegmeter | Abprall ab Winkel zur Normalen | Restgeschwindigkeit |
| --- | ---: | ---: | ---: |
| Holz | 6500 J/m | 82° | 25 % |
| Stahl | 900000 J/m | 65° | 40 % |
| Boden | 70000 J/m | deaktiviert | 0 % |
| Unbekannt | 1000000 J/m | deaktiviert | 0 % |

0° ist ein senkrechter Treffer; 90° ist ein streifender Treffer. Abpraller
werden zuerst geprüft. 40 % Restgeschwindigkeit bedeutet 16 % Restenergie.
Die Werte sind für das Spiel kalibriert, keine belegten Materialkennwerte.
Dichte × Dicke × 1,25 aus der Vorlage liefert ohne weitere Einheiten keine
Energie in Joule. Wir verwenden Widerstand in J/m und tatsächliche Weglänge
in Metern: Energieverlust = Widerstand × Weglänge. Damit sind die Einheiten
konsistent; reale Penetration hängt zusätzlich von Geschossform, Deformation,
Materialfestigkeit und weiteren Eigenschaften ab, die hier fehlen.

Für BoxShape3D wird der Austritt im lokalen Kollisionsraum bestimmt und in
Weltmeter zurückgerechnet. Schräge Treffer, Rotation und Skalierung werden
berücksichtigt. Es wird die tatsächlich getroffene Kollisionsbox verwendet,
keine pauschale „5 mm“-Annahme. Ein Zugwagen ist derzeit eine massive Box,
kein hohler Wagen aus dünnem Blech; dieser Unterschied ist bewusst sichtbar.

Durchschläge verbrauchen Simulationszeit und verlieren Energie während der
Materialreise. Jedes weitere Hindernis wird erneut geprüft. Körper innerhalb
überlappender Materialien stoppen den Schuss konservativ; es gibt kein
vollständiges Modell für verschachtelte Mehrschichtpanzerung. Die Oberfläche
wird nicht für die restliche Flugbahn dauerhaft ignoriert. Nicht unterstützte
Formen oder unbekannte Materialien bleiben sichere Deckung. Normalenfreie
Innentreffer und mehr als sechs Einschläge beenden ein Projektil.

Treffer an Soldaten verbrauchen das Geschoss und reduzieren Gesundheit anhand
der verbleibenden relativen Energie. Eigene Kameraden können getroffen werden.
Es gibt noch keine Körperzonen, Rüstung, Wundsimulation, Geschossverformung,
Materialbruch, Coriolis-Effekte oder aerodynamische Stabilität. Kurze leuchtende
Projektile sind visuelle Rückmeldung, keine historisch genaue Leuchtspur.

Masse, Durchmesser, Mündungsgeschwindigkeit, Schallgeschwindigkeit und
Streuungsdistanz müssen positiv sein. Die Mach-Stützstellen müssen streng
aufsteigend sein, Cd und Materialwiderstände nicht negativ. Konfigurationen
werden beim Projektstart geladen; Godot nach Änderungen neu starten.

## Zerstörung und Explosionen – Erweiterung 0.3

Eigene Godot-Umsetzung, keine Frostbite-/Havok-Komponente. Die vom Nutzer
beschriebenen Frostbite-Interna wurden nicht anhand von Originalquellen
verifiziert. Die Umsetzung orientiert sich an den allgemeinen Prinzipien.

- Wachhütte: 60 Box-Kacheln (20 Spalten mit 3 Reihen), jede mit 100 HP und
  eigener Kollisionsform. 20 untere Felder dienen als logische Dachstützen.
- Geschosse übertragen nur ihre im Material verlorene Energie auf die Kachel:
  25 Joule pro HP. Ein Durchschlag bleibt ein Durchschlag; Wand-HP werden
  nicht mit Soldatengesundheit verwechselt. Das ist eine grobe Spielkalibrierung:
  eine 1-m-Kachel entspricht keinem realistischen einzelnen Einschussloch.
- Eine zerstörte Kachel verliert unmittelbar ihre Sichtbarkeit und Kollision.
  Drei vorgeschnittene Holzstücke und Splitter an verbleibenden Nachbarn
  ersetzen sie optisch. Die Splitter verschwinden mit ihrem tragenden Nachbarn.
- Bricht eine untere Stütze, werden die darüberliegenden Felder derselben
  Spalte entfernt. Nichttragende Schäden allein lösen keinen Dacheinsturz aus.
- Bei 45 % verlorenen Stützen beginnt eine 1,2-s-Dachsequenz. Die Dachkollision
  wird entfernt, das Dach abgesenkt und geneigt, dann durch ruhende Dachstreifen
  ersetzt. Verbliebene Felder ohne unmittelbare Stütze werden entfernt.
  Es handelt sich um einen Abhängigkeitsmechanismus, keine technische Statik-
  oder Lastberechnung. Die Partisanenhütte bleibt als Fluchtziel intakt.
- Gemeinsames Budget: höchstens 48 RigidBody3D-Fragmente; jedes lebt 4 s.
  Fragmente haben Masse, Dämpfung, Schwerkraft, Drehung und Weltkollision.
  Sie blockieren weder Figuren, Schüsse noch die KI-Sicht. Brückensprengungen
  werfen zusätzlich Metallfragmente aus; die ruhende Brückenruine bleibt.

Explosionen verwenden ein eigenes radiales Spielmodell:

`Schaden = Spitzenschaden × max(0, 1 - Distanz / Radius)² × Deckungsfaktor`.

Ein Strahl zum Oberkörper bzw. zur Wandkachel prüft Deckung. Deckung reduziert
Schaden auf 15 %. Alle Prüfungen werden vor Anwendung der Schäden aufgenommen:
Eine im selben Ereignis aufgerissene Wand nimmt ihren Schutz nicht rückwirkend
weg. Das ist keine Druck-, Gas-, Schall- oder Splitterflug-Simulation. Teildeckung,
mehrere Druckreflexionen und die Umströmung von Hindernissen fehlen.

G wirft eine physikalische Granate mit 3-s-Zünder, 9-m-Wirkungsradius und
220 Spitzenschaden. Der Spieler hat zwei Granaten. Die Position wird gegen
nahe Wände geprüft; der Zünder kann nur ein Explosionsereignis auslösen.
Brückenladungen nutzen ebenfalls den radialen Schaden. Figuren und Wandkacheln
nehmen Schaden; bestehende dynamische Trümmer erhalten einen Impuls.
Lichtblitz, expandierende und ausblendende Rauchkugeln sowie ein generiertes
Geräusch ergänzen den Effekt. Es werden keine 100000 Partikel erzeugt.

## Regen, Wasser und Materialien – Erweiterung 0.3

`config/destruction_weather.json` enthält Zerstörungsschwellen, Trümmerbudget,
Granatenwerte, Deckungsfaktor, Pfützenzahl und den globalen Nässewert.

- Nässe 0–1 dunkelt registrierte Außenmaterialien leicht ab und senkt deren
  Roughness. Stahl erhält zusätzlich einen Metallic-Wert. Albedo, Roughness
  und Metallic sind reguläre Godot-PBR-Materialparameter.
- 18 bewusst platzierte Pfützen nutzen elliptische Masken und animierte
  Normalenringe. Sie liegen auf den Wegen und haben keine Kollisionsformen.
  Es gibt keine automatisch berechnete Höhenkarte oder Wasseransammlung.
- Fluss: ein unterteiltes PlaneMesh mit zwei kleinen überlagerten Sinuswellen
  und analytischen Normalen. Ein Randstreifen imitiert schwachen Uferschaum.
  Das ist keine FFT, kein Bootsauftrieb und keine Wasserströmungssimulation.
- Intakte Dächer unterdrücken Regentropfen darunter und dämpfen das Regen-
  geräusch für den Spieler. Nach dem Einsturz fällt wieder Regen ins Gebäude.
- Regen bleibt auf 420 MultiMesh-Instanzen begrenzt. Nebel und warme
  Hüttenbeleuchtung sind weiterhin Teil des Compatibility-Renderers.

HDR-Augenanpassung, volumetrische Lichtstreuung, Screen-Space-Refraction,
Kielwellen und serverseitige Wassersynchronisation sind nicht enthalten.
Das Projekt hat weiterhin keinen Mehrspielerbetrieb und keinen Server.
Diese Einschränkungen halten den Prototyp klein und entsprechen dem gewählten
Compatibility-Renderer; die Bildrate auf dem Windows-Ziel-PC bleibt zu prüfen.

## Aufbau

`project.godot`: Compatibility-Renderer und Hauptszene.
`Mission.tscn`: Einstieg.
`scripts/mission.gd`: Welt, Zug, Missionszustände, Regen, HUD und Sprengung.
`scripts/player.gd`: First Person, Waffe und Eingaben.
`scripts/soldier.gd`: Truppbewegung und einfache Gegner.
`scripts/ballistics.gd`: Projektilsimulation, Drag-Kurve und Visierberechnung.
`scripts/impact_solver.gd`: Materialantwort und geometrische Austrittspunkte.
`config/*.json`: Munition, Cd-Kurve, Material-, Wetter- und Zerstörungswerte.
`scripts/destruction.gd`: Explosionen, Granaten und Trümmerbudget.
`scripts/destructible_hut.gd`, `scripts/wall_tile.gd`: Kacheln und Einsturz.
`scripts/weather.gd`, `shaders/*.gdshader`: Nässe, Pfützen und Fluss.
`scripts/tactical_map.gd`: Feldkarte.

Die Pfade und Dateinamen bleiben nach Entpacken unverändert. Die Szenengeometrie
entsteht beim Start im Code; sie wird daher im Editor vor dem Start nicht als
fertig aufgebaute Landschaft angezeigt. Der `.godot`-Ordner ist Cache und wird
beim ersten Import erzeugt. Er gehört nicht zum Lieferumfang.

## Qualität und Grenzen

In dieser Cloud wurde Godot 4.6.3 unter Linux verwendet. Die eingegebene
Windows-Version 4.7.2 und die Leistung auf i5 / 20 GB RAM / 2 GB VRAM wurden
nicht geprüft. Das Projekt verwendet den Compatibility-Renderer, einfache
Geometrie, 420 Regentropfen in einem MultiMesh, begrenzte Sichtweite und keine
Echtzeit-Schatten. Diese Entscheidungen reduzieren den Aufwand; eine
konkrete Bildrate auf deinem PC ist damit noch nicht belegt.

Grafische Startansicht und Feldkarte wurden mit einem virtuellen Bildschirm
und OpenGL-Software-Rendering betrachtet. Die Cloud hat keine Soundkarte;
Audio wurde dort nur über Godots Dummy-Treiber initialisiert. Godot 4.6.3
meldet beim Beenden der kurzen Testläufe noch zurückgehaltene
AudioStreamWAV-/AudioStreamPlaybackWAV-Objekte. Der Missions- und Eingabetest
besteht trotzdem; Audio und Beenden sollten auf Windows zusätzlich geprüft
werden. Die Warnung wurde nicht unterdrückt.

Die KI nutzt einfache Wegpunkte und direkte Bewegung statt vollständiger
Navigation. Die Brückenquerung und der freigehaltene Rückzugsweg sind für
sie vorgesehen; komplexe Umwege um beliebige Hindernisse sind noch begrenzt.
Es gibt zwei Truppbefehle; Positionsbefehle und Vorausgehen fehlen noch.
Keine Speicherstände, Multiplayer, Inventare oder Windows-EXE enthalten.
Die Sprengung ist eine vorbereitete Sequenz mit begrenzten dynamischen
Fragmenten, keine physikalische Stahlzerstörung. Rauch und Geräusche sind
technische Platzhalter; der Dacheinsturz ist ebenfalls eine vorbereitete Sequenz.

## Prüfbefehle

Im Projektordner, mit Godot im PATH (unter Windows alternativ den vollständigen
Pfad zur Godot-EXE verwenden):

```
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/ballistics_materials.gd
godot --headless --path . --script res://tests/destruction_weather.gd
godot --path . --script res://tests/player_controls.gd
godot --path . --script res://tests/capture.gd -- AUSGABEORDNER
```

22 Missionsprüfungen, 29 Ballistik-/Materialprüfungen, 33 Zerstörungs-/
Wetterprüfungen und 12 grafische Eingabeprüfungen (96 insgesamt). Der
Eingabetest benötigt einen Bildschirm und führt echte Physikschritte aus.
Die Smoke-Suite überprüft Projektile gegen Deckung und Gegner, die reale
Truppüberquerung, Sicherheitsbedingungen, beide Zugzielvarianten,
Zerstörungskollision, Verstärkungszahl sowie Erfolg und Spielertod.
Die Materialprüfungen decken Cd-Interpolation, SI-Einheiten, Energieverlust,
Abprall, schräge und transformierte Boxen, aufeinanderfolgende sowie
eingebettete Hindernisse und zeitlichen Materialdurchflug ab.
Die Zerstörungsprüfungen prüfen echte Projektiltreffer auf Kacheln, offene
Kollisionen, Stützenabhängigkeit und Abschluss der Dachsequenz, Explosions-
reichweite, Deckung vor und während Wandzerstörung, Trümmerbudget und
Freigabe, Granaten sowie Nässe und Dachabschirmung. Die grafischen Tests
prüfen zusätzlich den tatsächlichen G-Eingabepfad.
Die Tests setzen kontrollierte Szenenbedingungen; sie ersetzen keinen
vollständigen menschlichen Durchlauf auf Windows.

Bei Fehlern die ersten `SCRIPT ERROR`-Zeilen aus dem Godot-Ausgabefenster
kopieren. Nicht nur den Exit-Code beachten: Godot kann Parserfehler mit
Exit-Code 0 beenden; Tests müssen ihre `RESULT`-Zeile ausgeben.
