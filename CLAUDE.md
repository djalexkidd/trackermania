# TrackerMania

Jeu de rythme libre inspiré de beatmania IIDX (7 touches + scratch), écrit en GDScript avec **Godot 4.7** (`/usr/bin/godot`).
Cibles : Windows, Linux, Android, HTML5. Scène de départ : `scenes/menu/main_menu.tscn`.

L'objectif d'origine : jouer directement des **modules Amiga (.MOD)**, le module étant la chart, avec des **keysounds** comme sur IIDX.
Les charts natives sont des beatmaps **Quaver (.qua)** avec leur MP3/OGG, lues directement ; elles cohabitent avec les modules et les **BMS** (.bms, .bme, .bml, .bmson), keysoundés eux aussi. Les PMS (pop'n music, 9 touches) sont hors sujet.

## Arborescence

```
project.godot            Config : autoloads, InputMap (p1_*/p2_*), viewport 1280x720
default_bus_layout.tres  Bus Master vide : les effets sont ajoutés par Effector.gd
assets/                  Images, polices, sons (bgm de la sélection, frames, groove gauge, shader), shift_jis.tres (table Shift-JIS)
scripts/
  Global.gd              Autoload : options et résultats des 2 joueurs, touches remappées, réglages système (user://settings.cfg)
  Effector.gd            Autoload : effector (presets d'effets sur le bus Master), voir plus bas
  Loader.gd              Autoload : chart choisie (file_path, chart_difficulty), scan de fichiers, cache JSON de la sélection
  QuaChart.gd            Lecture d'une beatmap Quaver .qua (class_name QuaChart)
  netplay/               Netplay.gd (autoload réseau), NetplayUI.gd (style des écrans), lobby.gd, scoreboard.gd, netplay_result.gd
  Scores.gd              Meilleurs scores en solo (user://scores.cfg), lampes de clear et rangs (class_name Scores)
  arcade/                Mode ARCADE (voir plus bas) : Arcade.gd (class_name Arcade, état statique et classement),
                         arcade_timer.gd (TIME REMAIN), name_entry.gd, ranking.gd
  mod/                   Modules Amiga keysoundés (voir plus bas)
  bms/                   BMS et bmson keysoundés (voir plus bas)
    BmsChart.gd          Lecture d'un BMS/bmson -> événements sonores, notes, mesures
    BmsPlayer.gd         Lecture audio : une voix par son, keysounds + BGM
    ShiftJIS.gd          Décodage Shift-JIS (CP932) ou UTF-8 des textes des BMS
    ModModule.gd         Lecture du .MOD + replay ProTracker -> liste de notes avec automation
    ModChart.gd          Génération de la chart (lanes, difficultés, niveau)
    ModPlayer.gd         Lecture audio : une voix par canal, keysounds + BGM
  menu/
    main_menu.gd         Menu principal (MENU SELECT)
    music_select.gd      Sélection des musiques (scan user://songs, catégories, join P1/P2, effector)
    loading_screen.gd    Écran NOW LOADING façon Amstrad CPC (CanvasLayer) posé sur la sélection pendant qu'elle se construit
    music_select/        song_entry.gd (lance la partie), category.gd, game_option_settings.gd, options_indicator.gd
                         song_preview.gd : aperçu de la musique sous le curseur (voir plus bas)
                         game_option_settings.gd : panneau OPTION SETTING (START maintenu), dessiné dans _draw() comme sur IIDX :
                         choix des touches noires (RANDOM, GAUGE, STYLE) au-dessus de la platine, AUTO PLAY et HI-SPEED sous les touches 1 et 7.
                         Ouverture (music_select.gd) : en P1 la roue sort à droite puis le panneau entre par la droite ; en P2 le panneau entre seul par la gauche
    controller_test/     CONTROLLER SETUP : controller_panel.gd (platine IIDX dessinée d'un joueur, test et remappage) ;
                         touches sauvées dans user://mappings.cfg via Global.save_key_mapping() (touche, "Button:n:pad", "Axis:n:signe:pad")
    customization_menu.gd  Choix de la BGM de la sélection (user://music_select_bgm/*.ogg)
    options_menu.gd      Menu OPTIONS façon IIDX console (voir plus bas), scène scenes/menu/options.tscn
  download/download.gd   Télécharge et dézippe un pack de musiques dans user://songs
  result/                result.gd (écran de résultats unique, solo et versus) et result_panel.gd (panneau d'un joueur)
scenes/
  game/main.gd + .tscn   Scène de jeu unique (1P, 2P, versus) : deux terrains P1/P2 toujours affichés, un AudioStreamPlayer partagé, plaque centrale (titre, BPM)
  game/playfield.gd/.tscn Un terrain (class_name Playfield) : chart, notes, jugement, layout (lanes, touches, jauge, HUD) ; le côté non joué reste affiché, vide et assombri
  game/note.gd           Une note (normale ou longue) qui descend
  game/judge.gd          Règles IIDX : fenêtres, EX-Score, jauge (class_name Judge)
  menu/                  Scènes des menus
  result/result.tscn     Écran de résultats (solo et versus local)
  arcade/                name_entry.tscn, ranking.tscn
  netplay/               lobby.tscn (salles et salle), result.tscn (résultats du round), img/crown.png
```

Les musiques ne sont pas dans le dépôt : elles sont dans `user://songs` (sous Linux `~/.local/share/godot/app_userdata/TrackerMania/songs/`), scannées récursivement. Un chemin contenant `official` va dans la catégorie Official, le reste dans Downloaded. Les catégories FILE TYPE (MODULE, QUAVER, BMS), sous les ALPHABET, trient par extension et restent masquées tant qu'elles sont vides.

## Fonctionnement du jeu

### Flux des scènes
Menu principal (FREE) -> sélection des musiques -> `song_entry._on_pressed()` règle `Loader.file_path` et `Loader.chart_difficulty`, puis ouvre :
- `main.tscn` dans tous les cas (P1 seul, P2 seul ou versus) : `main.gd` règle quel terrain joue d'après `Global.p1_joined`/`p2_joined` ;
- en netplay, la sélection est ouverte depuis le lobby (choix de l'hôte), le round lance `main.tscn` sur chaque machine (voir Netplay).

`main.gd` charge la chart avec `loadQuaChart()`, `loadModule()` ou `loadBms()` selon l'extension. Ensuite `main.gd.finish()` écrit les résultats dans `Global` et ouvre l'écran de résultats (`scenes/result/result.tscn`, aussi pour le versus local).
En solo (hors autoplay), il enregistre aussi la partie avec `Scores.save_play()` : une section par fichier de chart, une clé par difficulté, et chaque valeur (EX-Score, taux, lampe, combo) garde son meilleur séparément. Comme sur IIDX, l'auto-scratch et le 5 touches donnent au mieux un ASSIST CLEAR. La sélection l'affiche sous les infos de la musique, après la difficulté (`SongInfo/BestScore`).

### Écran de résultats (`scripts/result/`)
Un seul écran comme sur IIDX : 1P à gauche, 2P à droite (un seul panneau en solo, du côté du joueur), la musique au milieu, WIN/LOSE en versus. Pas d'image de fond pour l'instant.
- `finish()` remplit `Global.result` / `p2_result` : `counts` (jugements, POOR vides compris), `fast`/`slow` (GREAT, GOOD, BAD en avance ou en retard, comme sur IIDX), `combo_break`, `miss_count` (BAD + POOR), `note_count`, `gauge_history` (jauge affichée après chaque jugement, en `Vector2(progression 0~1, jauge)`) et `previous_best` (le meilleur score lu avant `Scores.save_play()`). `Global.song_info` : titre, artiste, difficulté, niveau.
- `result_panel.gd` dessine tout dans `_draw()` : le graphe de la jauge (zone rouge au-dessus de 80 %, ligne verte puis rouge, rouge en HARD) avec le DJ LEVEL par-dessus, SP / difficulté / niveau / notes, puis CLEAR TYPE, DJ LEVEL, EX SCORE et MISS COUNT (meilleur | cette partie, flèches UP!/DOWN et écarts vers le milieu), TARGET (pacemaker du DJ LEVEL suivant, MAX après AAA, avec les options de la partie), les jugements, COMBO BREAK, MAX COMBO, FAST/SLOW, le taux et la barre FAST/SLOW.
- Apparition : la ligne de la jauge se dessine, le DJ LEVEL apparaît, les lignes arrivent une à une et les nombres défilent. Une première pression (START, touche 1 ou 7, Entrée, clic) termine l'animation, la suivante ramène à la sélection.
- `Scores.save_play()` garde aussi le plus petit `miss_count`, sauf pour une partie échouée.

### Chargement de la sélection (`loading_screen.gd`)
`music_select.gd` pose l'écran en premier, construit les entrées par lots (une image toutes les 8 ms) pour qu'il reste animé, puis `await loading_screen.finish()`.
- Fond bleu CPC, police `assets/font/amstrad_cpc464.ttf` (importée sans anticrénelage), en bas à droite le personnage (`assets/loading/walk.0~2.png`, marche 0 1 2 1) puis « NOW LOADING... » et un curseur jaune qui clignote. Un pixel du sprite ou de la police = 4 px.
- `finish()` attend au moins `MIN_TIME`, fait courir le personnage vers la droite (il efface chaque lettre qu'il dépasse), puis rend la main : le fond part en bandes horizontales vers la droite (la plus proche du personnage d'abord), pendant que la BGM démarre et que la roue entre par la droite.

### Aperçu dans la sélection (`song_preview.gd`)
Comme sur IIDX : 0.4 s après l'arrivée du curseur sur une musique, elle est chargée dans un thread (`WorkerThreadPool`) et jouée 20 s en boucle, avec fondu, sur le bus `Preview` (créé à la volée, envoyé vers Master : l'effector s'applique). La BGM de la sélection est en pause pendant ce temps et reprend sur une catégorie ou une entrée aléatoire.
- .qua : l'audio depuis `SongPreviewTime` (`QuaChart.previewTime`), sinon depuis le tiers de la musique.
- .mod : un `ModPlayer` sans chart (tout en BGM, bus `ModLeftPreview`/`ModRightPreview`), lancé par `play_from()` à la mesure la plus proche du tiers.
- BMS : le fichier `#PREVIEW` ou `preview_music` (`BmsChart.previewFile`) s'il existe, sinon un `BmsPlayer` comme pour un module.

### Effector (`Effector.gd`)
Touche EFFECT comme sur IIDX, dans la sélection et en jeu (`main.gd`, l'un ou l'autre joueur) : passe au preset suivant de `NAMES` (EFFECTOR OFF, CHORUS, PHASER, FLANGER, REVERB, ECHO, STADIUM, COMPRESSOR, FILTER SWEEP, WOBBLE, RADIO, UNDERWATER, BITCRUSH, MEGA BASS, GARGLE, 8D AUDIO, CHIPMUNK, MONSTER, DRUNK). La maintenir `OFF_HOLD_MS` (1 s) remet EFFECTOR OFF : `Effector.update_button()`, appelée à chaque image avec les actions EFFECT des joueurs, gère l'appui et le maintien.
- `set_effect()` retire les effets du preset précédent (en fin de bus Master), ajoute ceux de `build()` puis un `AudioEffectHardLimiter`. Tout passe par Master : aperçu, keysounds et BGM.
- Les presets animés (filtre, gargle, panoramique, hauteur) sont mis à jour dans `_process`, sur une horloge lancée au choix du preset. Le gain ne change qu'à chaque image : GARGLE (triangle sur le volume, comme le Gargle DirectX d'IIDX) tourne à `GARGLE_HZ` = 12 Hz au lieu de 20.
- BITCRUSH réduit seulement le nombre de bits (`AudioEffectDistortion` LOFI) : Godot n'a pas de réduction de fréquence d'échantillonnage.
- Les pitch shifters utilisent une FFT de 512 (`PITCH_FFT`) : environ 8 ms de retard, une plus grande décalerait le son.
- Le preset survit aux changements de scène ; le menu principal le coupe. En jeu, son nom remplace le titre de la plaque centrale pendant `EFFECTOR_SHOW_TIME`.

### Menu principal (`main_menu.gd`)
MENU SELECT des IIDX console, dessiné dans `_draw()` avec le thème sombre du menu OPTIONS (grille, bandeau `music_select_info.png` dont la case OPTIONS est masquée).
- Modes dans `modes` : ARCADE (sélection avec `"arcade": true`, qui appelle `Arcade.start()`), FREE (sélection), NETPLAY (lobby), OPTIONS, DOWNLOAD. Écran MENU INFORMATION (titre penché, cubes et bandes orange), onglets, barre du bas avec tous les modes.
- Platine (ou flèches, molette) : choisir, en boucle ; touche blanche : valider ; touche noire deux fois : quitter (rien en web).

### Mode ARCADE (`scripts/arcade/`)
Comme sur IIDX : 3 stages (`Arcade.STAGES`), puis NAME ENTRY et classement. L'état est dans des variables statiques de `Arcade` (`active`, `stages`, `last_rank`), qui survivent aux changements de scène ; le menu principal l'arrête (`Arcade.stop()`) dans `_ready()`.
- `Arcade.start()` coupe l'AUTO PLAY des deux joueurs ; `game_option_settings.gd` ne le laisse pas activer (case « --- ») et `playfield.gd` l'ignore. Le mode se joue seul : l'autre côté ne peut pas rejoindre.
- Sélection : une musique déjà jouée n'est pas ajoutée, quelle que soit sa difficulté (`Arcade.song_key()` : le chemin pour un .mod, son dossier pour un .qua ou un BMS). `arcade_timer.gd` affiche TIME REMAIN (60 s, `SELECT_TIME`, rouge clignotant sous 10 s) par-dessus les cases OK/EXIT du bandeau, et le stage (1ST, 2ND, FINAL STAGE) à la place de la case OPTIONS, masquée (START ouvre toujours les options). À zéro (`_on_arcade_timeout()`), la musique sous le curseur est lancée, sinon une musique au hasard de la catégorie (ou de ALL MUSIC). Les touches noires et META ne quittent la sélection (et la partie) qu'avant le 1er stage (`can_leave()`). S'il ne reste aucune musique, on passe au NAME ENTRY.
- Fin d'une partie solo : `playfield.finish()` appelle `Arcade.add_stage()` (musique, EX-Score, EX max, lampe ; FAILED si la lampe vaut 0, donc aussi une jauge NORMAL/EASY sous 80 % ou un abandon). L'écran de résultats titre « 1ST STAGE RESULT »… puis, à la sortie : GAME OVER (3 s, retour au menu principal) après un stage échoué, NAME ENTRY après le dernier, sinon la sélection.
- NAME ENTRY (`name_entry.gd`, `scenes/arcade/name_entry.tscn`) : 6 lettres pré-remplies avec le DJ NAME, platine : lettre, touche blanche : suivante (valide sur la dernière), touche noire : précédente, START : valide ; clavier aussi. Timer de 30 s (`NAME_ENTRY_TIME`) qui valide. Affiche les 3 stages et le total EX avec son DJ LEVEL.
- Classement (`ranking.gd`) : `user://arcade_ranking.cfg`, liste `entries` triée par total EX (`name`, `ex_score`, `rate`, `songs`, `date`, 100 au plus). Les 10 premiers, la nouvelle partie clignote (en 11e ligne si elle est plus bas). Une touche ou 20 s ramène au menu principal.

### Menu OPTIONS (`options_menu.gd`)
Ouvert depuis OPTIONS du menu principal. Tout est dessiné dans `_draw()` comme les menus IIDX console : roue des catégories à gauche, titre et réglages à droite, aide en bas. Thème sombre de la sélection : grille animée (`Background`, `show_behind_parent`) et bandeau `music_select_info.png` en haut, dont la case OPTIONS/START est recouverte par DEFAULT/EFFECT.
- Platine : choisir ; touche blanche : valider (OK) ; touche noire : retour / annuler (EXIT) ; EFFECT : valeurs par défaut (du réglage, ou de la catégorie sur la roue). Clavier (flèches, Entrée, Échap, Suppr) et souris aussi.
- Niveaux : catégories -> réglages -> édition (la valeur change en direct, une touche noire remet l'ancienne). Les réglages sont décrits dans `categories` (`var` de Global, type bool/int/choice/action/name).
- DISPLAY (plein écran, V-SYNC, timing en ms), SOUND (volume, audio offset, calibration, BGM de la sélection ; la musique des menus est coupée pour l’instant), DJ NAME (6 lettres à la platine, `Netplay.set_dj_name()`), CONTROLLER SET UP (ouvre `test_controller.tscn`).
- `Global.SETTING_DEFAULTS` liste les réglages sauvés dans `user://settings.cfg` (`save_settings()`, `load_settings()` au démarrage, `apply_settings()` pour la fenêtre, la V-SYNC et le volume du bus Master).

### Options des joueurs (`Global.gd`)
Les variables de P1 n'ont pas de préfixe, celles de P2 sont préfixées par `p2_` : passer par `Global.get_player_var(player, name)` et `set_player_var`.
Options : `hispeed` (temps de chute d'une note, en secondes, de 0.45 à 1.0), `keys_mode` (7 ou 5), `random`, `auto_play`, `auto_scratch`, `gauge_level` (0 normal, 1 easy, 2 hard).

### Beatmaps Quaver (`QuaChart.gd`)
Chaque `.qua` de `user://songs` est une entrée de la sélection. `QuaChart.load_file()` lit le petit sous-ensemble YAML écrit par Quaver (champs du haut, listes `TimingPoints` et `HitObjects`, le reste comme les `KeySounds` est ignoré) et renvoie `null` si le mode n'est pas jouable.
- Champs utilisés : `Title`, `Artist`, `DifficultyName` (libre, couleur seulement pour Beginner/Normal/Hyper/Another/Leggendaria), `AudioFile` (mp3 ou ogg, à côté du .qua), `Mode`, `HasScratchKey`.
- Lanes : `Keys7` va sur les touches 1~7, `Keys4` sur les touches 2~5 ; avec `HasScratchKey`, la dernière lane Quaver est le scratch (lane 7).
- Une note `StartTime` (absent = 0) en ms, une note longue a un `EndTime`. Résultat : `noteArray`, 8 lanes, `[temps]` ou `[temps, durée]` en secondes, triées.
- `LEAD_IN` (2 s) est ajouté aux notes et aux mesures au chargement : le fichier n'a pas de silence à prévoir. Dans `main.gd`, `songPosition()` compte ce temps avec `Time.get_ticks_usec()` puis lance la musique (`play()` au bon décalage) et suit sa position + `LEAD_IN`. Après la fin de la musique, l'horloge continue seule.
- `measures` : une ligne à chaque `TimingPoint` (BPM, `Signature` Triple = 3 temps, sinon 4), puis une par mesure jusqu'au suivant ; le premier tempo remonte jusqu'au début.
- Il n'y a pas de niveau dans un .qua : `level` vient de la densité (`QuaChart.densityLevel()`, utilisé aussi par les BMS) (moyenne × `LEVEL_PER_NPS` + pic sur 2 s × `LEVEL_PER_PEAK_NPS`), borné entre 1 et 8.

### `main.gd` (repris de gd-rhythm)
- Les temps des notes sont décalés de `speed` (hispeed) : une note apparaît en y=0 à `t - speed` et atteint `PERFECT_YPOS` (500) au temps `t`.
- Chaque note connaît son heure (`note.hitTime`) : sa position est recalculée à chaque image depuis l'heure de la chanson (`notePosition()`), les lignes de mesure aussi.
- **Jugement comme IIDX**, sur l'écart en temps (`Judge.judge()`), fenêtres en ms symétriques : P-GREAT ±16.67, GREAT ±33.33, GOOD ±116.67, BAD ±250. Au-delà du BAD tardif, c'est un POOR.
  GOOD garde le combo, BAD et POOR le cassent. Tout passe par `addJudge()`.
- **EX-Score** : P-GREAT 2 points, GREAT 1, le reste 0. Une note longue compte pour 2 (appui et relâché, comme une CN) : relâchée trop tôt, POOR ; tenue plus de 250 ms après la fin, BAD.
  `Global.score` est le taux EX (EX / (notes × 2) × 100), `Global.ex_score` l'EX-Score. Le rang vaut un palier tous les 1/9 (AAA ≥ 8/9).
- **Jauge comme IIDX** (`Judge.gaugeChange()`, appliquée par `updateGauge()` à chaque jugement, plus par le combo) :
  - NORMAL et EASY partent de 22 %, ne descendent pas sous 2 %, et il faut 80 % à la fin. Un P-GREAT ou un GREAT rend 7.605 / (0.01 × notes + 6.5) %, soit un total de 7.605 × n / (0.01 n + 6.5) % pour la chart. Un GOOD rend la moitié.
  - Dégâts NORMAL : BAD −2, POOR −6, POOR vide −2. EASY : ×0.8.
  - HARD part de 100 %, P-GREAT/GREAT +0.16, GOOD 0, BAD −6, POOR −10, POOR vide −2, dégâts divisés par 2 à 30 % ou moins, échec à 0.
  - Affichage par paliers de 2 % (`gaugeDisplay()`), c'est cette valeur qui va dans `gauge_score`.
  - Le dernier segment rempli reste allumé, les 2 d'avant clignotent (0 à 2 allumés depuis la gauche, tirés au hasard toutes les 50 ms, `flickerGauge()`), comme sur IIDX.
- **POOR vide** (`emptyPress()`) : une touche pressée sans note à frapper, alors qu'une note de la lane arrive dans moins de 500 ms, abîme la jauge sans casser le combo.
- L'horloge est `songPosition() - AudioServer.get_output_latency()` ; pour un MP3/OGG, `songPosition()` ajoute `AudioServer.get_time_since_last_mix()`, sinon elle avance par saccades de la taille d'un mixage (fatal avec des fenêtres de ±16 ms).
- RANDOM mélange seulement les touches (0~6, ou 0~4 en 5 touches) ; le scratch ne bouge jamais, comme sur IIDX. En 5 touches, les lanes 5 et 6 sont vidées au chargement.
- Les touches (`p1_frame.png`, scratch `p1_frame_scratch.png` + disque) et la jauge (`groove_gauge.png` / `progress.png`, `_hard` en HARD) viennent des assets, à l'échelle `KEY_SCALE` (0.4, donc des lanes de 40 px) et `SCRATCH_SCALE` (0.6, platine plus haute que les touches comme sur IIDX). Les touches enfoncées s'allument en rouge en redessinant leur zone teintée (`drawKeys()`, `KEY_WHITE_RECT`/`KEY_BLACK_RECT`, une touche tous les `KEY_SPACING` px). Touches, jauge et HUD sont dessinés dans `Overlay`, au-dessus des notes.
- Habillage façon IIDX (`playfield.gd`, rectangles du côté 1P, inversés par `sideRect()`/`sideX()` en 2P) : lanes noires, rails métalliques de chaque côté (la progression de la chanson descend dans le rail extérieur), la bande rouge du haut des touches sert de ligne de jugement (`KEYS_TOP` = 497). Sous les lanes, une plaque métallique (`drawPlate()`) porte des écrans noirs (`drawScreen()`) : pourcentage de la jauge, jauge (« P1 GROOVE GAUGE »), SCORE / MAXCOMBO et difficulté + niveau, chiffres en 7 segments avec les segments éteints (`drawNumber()`, police digitalix). `drawMetal()`, `drawScreen()` et `drawNumber()` sont statiques : `main.gd` s'en sert pour la plaque centrale (titre, BPM).
- Le jugement et le combo sont sur une ligne au-dessus des touches (« GREAT 113 », `drawJudge()`), 0.8 s, P-GREAT en couleurs alternées ; une note frappée fait un éclat sur la ligne (`drawBursts()`, aussi en autoplay).
- Côté 2P (`mirrored`) l'interface est inversée, avec le scratch à droite.

## Modules Amiga keysoundés (`scripts/mod/`)

Un fichier `.mod` dans `user://songs` crée **3 entrées** (Normal, Hyper, Another) dans la sélection. Leur niveau est calculé.
Dans `main.gd`, `loadModule()` remplace `loadQuaChart()` quand l'extension est `mod`.

### 1. `ModModule` : lecture et replay
- `parse()` : titre, 31 samples (ou 15 pour les vieux Soundtracker sans tag), ordre, patterns, PCM 8 bits signé.
  Le nombre de canaux vient du tag à l'offset 1080 (`M.K.`, `xCHN`, `xxCH`, `TDZx`…). Les boucles mal enregistrées sont corrigées.
- `replay()` rejoue toute la chanson **tick par tick comme ProTracker**, sans son :
  - tempo et vitesse (`Fxx`), `Bxx`, `Dxx`, `E6x` (boucle de pattern), `EEx` (délai de pattern), et arrêt si la chanson boucle (ligne déjà visitée hors boucle E6x) ;
  - effets : arpège, slides, portamento (`3xx`/`5xy`, qui ne créent pas de note), vibrato, trémolo, volume et volume slides, offset `9xx`, retrigger `E9x`, note cut `ECx`, note delay `EDx`.
- Résultat : `notes`, triées par temps, `length`, et `measures` (heure de début de chaque mesure, toutes les `ROWS_PER_MEASURE` = 16 lignes, donc au rythme du tempo et des `Fxx`). Chaque note est un keysound :
  `{time, channel, sample, period, offset, row, env}`.
  `env` est l'automation de la note : 4 valeurs par changement (temps depuis la note, période, volume 0~64, retrigger). Une note qui serait muette (sample vide, offset trop loin) n'est pas créée.

### 2. `ModChart` : génération de la chart
Construit avec `ModChart.new(module, difficulté, keys)`. Il donne `noteArray` (même format que `QuaChart`, avec `LEAD_IN` = 2 s ajouté), un `keysoundArray` parallèle (index de chaque note dans `module.notes`) et `level`.
- **Sélection** (`selectNotes`) : les notes sont prises d'abord sur les lignes fortes du pattern (`rowWeight` : ligne 0, puis les multiples de 32, 16, 8…).
  Chaque difficulté fixe un plafond de densité (`max_nps` sur une fenêtre de 2 s) et de taille des accords (`max_chord`). Another garde toutes les notes.
- **Lanes** (`assignLanes`) :
  - Chaque instrument (sample, pas le canal) a une lane de base ; plus la note est aiguë, plus elle va à droite.
  - Si la lane voulue est occupée, la note va sur la plus proche libre : d'abord avec un écart confortable de 0.25 s, ce qui transforme les flux rapides en trilles, puis avec l'écart minimum de 0.1 s.
  - Le sample le moins fréquent (au moins 4 notes) va sur le scratch, en Hyper et Another.
- **Une note sans place reste dans la BGM** : rien n'est jamais perdu à l'écoute.
- Le niveau vaut la densité de notes × `LEVEL_PER_NPS`, borné entre 1 et 8. Tous les réglages sont des constantes en tête du fichier.

### 3. `ModPlayer` : lecture audio
- C'est un `Node` ajouté comme enfant de l'`AudioStreamPlayer` du terrain, sous le nom `ModPlayer`. En versus les deux terrains le partagent : le premier le crée, le second le retrouve.
- Chaque sample devient un `AudioStreamWAV` (8 bits, 8363 Hz, boucle avant). Il y a **une voix (`AudioStreamPlayer`) par canal**, monophonique comme sur l'Amiga.
  Hauteur : `pitch_scale = 3546895 / période / 8363 × finetune`. Volume : `volume/64 / sqrt(canaux)`.
  Stéréo gauche-droite-droite-gauche adoucie, via les bus `ModLeft` et `ModRight` créés à la volée et envoyés vers Master, donc l'effector s'applique.
- L'horloge est `Time.get_ticks_usec()` depuis `play()`. `get_playback_position()` imite celle d'`AudioStreamPlayer`.
- `claim()` : chaque terrain réserve les notes de sa chart (`owners`). En autoplay rien n'est réservé, et en auto-scratch la lane 7 non plus : ces notes sont jouées à l'heure par la BGM.
- À chaque image, `_process` traite les notes arrivées à leur heure :
  - **note de BGM** (non réservée) : jouée, en rattrapant le retard de l'image. Exception : si une note plus récente du canal a déjà été frappée en avance, la BGM ne la coupe pas.
  - **note de chart pas encore frappée** : la voix du canal est coupée, comme une nouvelle note de module coupe la précédente. Une note ratée reste donc muette.
- `hit(i)` : appelée par `main.keyPressed()` quand une note est jugée, même un Bad, comme sur IIDX. Elle joue le keysound s'il n'a pas déjà été joué.
- `preview(i)` : une touche pressée sans note à frapper joue le son de la prochaine note de la lane (`previewKeysound()` dans main.gd), sans la marquer comme jouée.
- `updateVoice()` applique l'enveloppe de la note en cours, alignée sur l'heure prévue de la note, pas sur l'heure de la frappe. Une note frappée en avance garde son état initial jusqu'à son heure.

### Lien avec `main.gd`
- `keysoundPlayer` (non typé) est le `ModPlayer` ou le `BmsPlayer` : mêmes méthodes (`claim`, `play`, `get_playback_position`, `hit`, `preview`, `length`, `playing`).
- `keysoundArray` suit `noteArray` partout : chargement, mélange RANDOM, vidage en 5 touches, création des notes (`note.keysound`, `lastKeysound`).
- `keyPressed()` renvoie `false` s'il n'y avait aucune note à frapper. Dans ce cas, les pressions digitales (touches, turntable digital) appellent `previewKeysound()`. La turntable analogique n'en déclenche pas, sinon elle jouerait le son à chaque image.
- La fin de partie est au minimum à `keysoundPlayer.length + ENDPOS_BIAS`.
- Les lignes de mesure suivent `module.measures` (+ `LEAD_IN`), mises dans `measures` comme celles d'un .qua. Sans mesures, une ligne par seconde (`SUBLINE_LENGTH`).

### Limites connues
- La BGM est déclenchée à chaque image (environ 16 ms), avec une compensation du retard.
- Pas de notes longues générées. Le format FLT8 est lu de façon approximative.

## BMS keysoundés (`scripts/bms/`)

Chaque fichier .bms, .bme, .bml ou .bmson est une entrée de la sélection (catégorie BMS). Seul le SP est lu : un chart avec des notes 2P (canaux 2x/6x, bmson `beat-14k`) ou un autre mode (pop'n…) est refusé (`null`).

### `BmsChart` : lecture
- `BmsChart.load_file(path, random)` : les octets sont lus en Latin-1 (`get_string_from_ascii`, un caractère par octet). Les textes (`#TITLE` + `#SUBTITLE`, `#ARTIST`, noms des `#WAV`) passent par `ShiftJIS.decode()` : ASCII tel quel, UTF-8 s'il est valide, sinon CP932 (table `assets/shift_jis.tres`).
- BMS : `#WAVxx`, `#BPM`, `#BPMxx` + canal 08, canal 03 (hex), `#STOPxx` + canal 09 (en 1/192 de mesure), canal 02 (longueur de mesure), `#LNOBJ`, canaux 5x (LNTYPE 1 : un objet ouvre, le suivant ferme), `#VOLWAV`, `#BASE 62`.
  `#RANDOM`/`#SETRANDOM`/`#IF`/`#ELSEIF`/`#ELSE`/`#ENDIF`/`#ENDRANDOM` : branche au hasard en jeu, la première pour la sélection (`random = false`).
  Lanes : canaux 11~15 -> touches 1~5, 18/19 -> touches 6/7, 16 -> scratch. Le canal 01 (BGM) et la pédale 17 vont dans la BGM. Notes invisibles (3x) et mines (Dx/Ex) ignorées.
- bmson : `info` (`title`, `subtitle`, `artist`, `level`, `chart_name`, `resolution`, `init_bpm`, `mode_hint` beat-7k ou beat-5k), `bpm_events`, `stop_events`, `lines`, `sound_channels`.
  `x` 1~7 touches, 8 scratch, le reste BGM ; `l` donne une note longue. Un son de canal est découpé en tranches : une note sans `c` le relance, une note avec `c` le reprend à `offset` = temps depuis la dernière relance.
- Le temps vient d'une ligne de temps (`buildTimeline`, `beatToTime`) : un changement de BPM s'applique avant un STOP au même temps, une note sur un STOP est jouée au début du STOP.
- Résultat : `keysounds` (tous les sons triés par temps, `{time, sound, offset, cut}`), `noteArray` et `keysoundArray` (index dans `keysounds`, -1 pour une note sans son), `measures` (avec `LEAD_IN` = 2 s comme les autres formats).
- Difficulté : `#DIFFICULTY` 1~5 (Beginner, Normal, Hyper, Another, Leggendaria = INSANE), sinon un mot du titre, du `chart_name` ou du nom de fichier, sinon `Lv.` + `#PLAYLEVEL`. Le niveau 1~8 vient de la densité, pas de `#PLAYLEVEL`.

### `BmsPlayer` : lecture audio
- Même principe que `ModPlayer` (`owners`, `triggered`, `hit()`, `preview()`, horloge `Time.get_ticks_usec()`), enfant de l'`AudioStreamPlayer` du terrain sous le nom `BmsPlayer`. En versus, le second terrain réutilise son `chart` : mêmes branches `#RANDOM` (`noteArray` copié par terrain).
- Une voix (`AudioStreamPlayer`) par son utilisé : rejouer un son le coupe, comme LR2/beatoraja. Volume `#VOLWAV`, bus Master.
- Fichiers cherchés dans le dossier de la chart et ses sous-dossiers, sans casse, `\` -> `/`, et avec une autre extension si besoin (ogg, wav, mp3), car un `.wav` déclaré est souvent un `.ogg`.
- bmson (`cut`) : une note de chart pas encore frappée coupe la tranche précédente de son son. Une tranche `c` qui suit celle en cours n'est pas relancée si la position est à moins de `CONTINUE_TOLERANCE`.
- `length` : fin du dernier son (coupé par la reprise suivante du même son) + `LEAD_IN`.

### Limites
- Pas de BGA, de `#TOTAL`, de `#RANK`, de LNTYPE 2, de mines ; pas de DP.
- Godot transforme `\` en `/` dans les chemins : un dossier dont le nom contient un `\` (mojibake de zip) n'est pas lisible.
- Les titres japonais demandent une police système avec ces glyphes (`allow_system_fallback`).

## Netplay (`scripts/netplay/`)

Autoload `Netplay` (ENet, port 47800) : il survit aux changements de scène, toutes les RPC passent par lui (`/root/Netplay`). L'hôte fait autorité : il garde `room` (`name`, `state` lobby/loading/playing, `song`, `seed`, `round`) et `players` (id -> `name`, `slot`, `ready`, `where`, `song_state`, `progress`, `ping`) et les renvoie à tous (`_sync_room`, `_sync_players`). Les clients demandent par `update_me()`, `say()` ; `_to_host()` appelle directement quand on est l'hôte. `PROTOCOL` refuse une autre version, 8 joueurs max, noms de 6 lettres en majuscules (`user://netplay.cfg`).
- **LAN** : l'hôte envoie une balise JSON en broadcast UDP (port 47801, chaque seconde, 255.255.255.255 et le /24 de chaque adresse). Le navigateur de salles écoute ce port (un seul jeu par machine peut l'écouter, sinon il reste la connexion par adresse).
- **Musique** : identifiée par son chemin sous `user://songs/` et le md5 du fichier de chart. Un client cherche `user://songs/<chemin>` puis `user://songs/netplay/<chemin>` (`find_song`), sinon la demande à l'hôte : le dossier entier pour un BMS, chart + audio pour un .qua, le fichier pour un .mod, la chart en dernier (`song_files`). Morceaux de 64 Ko, au plus 16 non acquittés par client, écrits en `.part` puis renommés, chemins vérifiés (`safe_path`). Ensuite `Loader.clear_song_catalog()`.
- **Round** : l'hôte lance (`start_round`) quand les joueurs du lobby sont prêts ; `round` = joueurs prêts + l'hôte. Chacun ouvre `main.tscn` (`main.gd` : `netplay = Netplay.in_round()`, `seed(room.seed)` pour les mêmes `#RANDOM`), signale `mark_loaded()`, et attend `wait_begin()` (tous chargés, ou `LOAD_TIMEOUT`). Scores en direct par `send_live()` (5 fois/s, non fiable), affichés par `scoreboard.gd` à droite du terrain. `finish()` envoie le résultat (`send_result`, avec `judgeCounts`) et ouvre `scenes/netplay/result.tscn`. Le round se termine quand tous ont un résultat ou sont partis.
- La sélection en netplay : seul P1, toutes les musiques ; l'hôte choisit (`choose_song`), un client suggère dans le chat ; les touches noires ramènent au lobby.
- Pas de netplay dans la version web (pas d'ENet).

## Conventions
- GDScript avec des tabulations. Fonctions et variables du gameplay en camelCase (`noteArray`, `keyPressed`) dans `main.gd`, `note.gd` et `scripts/mod/` ; snake_case dans les menus.
- Commentaires courts en anglais au-dessus du code. Textes et README en français.
- Godot génère les fichiers `.uid` : il faut les committer avec les scripts.
- Le lien `bms` à la racine (BMS de référence, non suivi) ne doit pas être modifié. Avant un `godot --import` ou un test, le déplacer hors du projet, sinon Godot importe ses milliers de .ogg.

## Tester
- `godot --headless --import` reconstruit le cache des classes après l'ajout d'un `class_name`.
- Les autoloads (`Global`, `Loader`) ne sont pas disponibles avec `--script`. Pour tester une scène, créer temporairement une scène avec un script `extends Node` qui règle `Loader.file_path` et `Loader.chart_difficulty`, instancie `scenes/game/main.tscn`, puis la lancer avec `godot --headless chemin.tscn`. Supprimer ensuite les fichiers temporaires.
- Les avertissements de fuite (RID, ObjectDB) à la sortie viennent d'un `quit()` en pleine scène.
