# TrackerMania

Jeu de rythme libre inspiré de beatmania IIDX (7 touches + scratch), écrit en GDScript avec **Godot 4.7** (`/usr/bin/godot`).
Cibles : Windows, Linux, Android, HTML5. Scène de départ : `scenes/menu/test_menu.tscn`.

L'objectif d'origine : jouer directement des **modules Amiga (.MOD)**, le module étant la chart, avec des **keysounds** comme sur IIDX.
Les charts natives sont des beatmaps **Quaver (.qua)** avec leur MP3/OGG, lues directement ; elles cohabitent avec les modules et les **BMS** (.bms, .bme, .bml, .bmson), keysoundés eux aussi. Les PMS (pop'n music, 9 touches) sont hors sujet.

## Arborescence

```
project.godot            Config : autoloads, InputMap (p1_*/p2_*), viewport 1280x720
default_bus_layout.tres  Bus Master avec Chorus / Phaser / Reverb (effector de la sélection)
assets/                  Images, polices, sons (bgm de la sélection, frames, groove gauge, shader), shift_jis.tres (table Shift-JIS)
tools/                   qua2tm.py, make_shift_jis_table.py (génère assets/shift_jis.tres)
scripts/
  Global.gd              Autoload : options et résultats des 2 joueurs, chargement des touches remappées
  Loader.gd              Autoload : chart choisie (file_path, chart_difficulty), scan de fichiers, cache JSON de la sélection
  QuaChart.gd            Lecture d'une beatmap Quaver .qua (class_name QuaChart)
  Scores.gd              Meilleurs scores en solo (user://scores.cfg), lampes de clear et rangs (class_name Scores)
  mod/                   Modules Amiga keysoundés (voir plus bas)
  bms/                   BMS et bmson keysoundés (voir plus bas)
    BmsChart.gd          Lecture d'un BMS/bmson -> événements sonores, notes, mesures
    BmsPlayer.gd         Lecture audio : une voix par son, keysounds + BGM
    ShiftJIS.gd          Décodage Shift-JIS (CP932) ou UTF-8 des textes des BMS
    ModModule.gd         Lecture du .MOD + replay ProTracker -> liste de notes avec automation
    ModChart.gd          Génération de la chart (lanes, difficultés, niveau)
    ModPlayer.gd         Lecture audio : une voix par canal, keysounds + BGM
  menu/
    test_menu.gd         Menu titre
    music_select.gd      Sélection des musiques (scan user://songs, catégories, join P1/P2, effector)
    music_select/        song_entry.gd (lance la partie), category.gd, game_option_settings.gd, options_indicator.gd
                         song_preview.gd : aperçu de la musique sous le curseur (voir plus bas)
    controller_test/     CONTROLLER SETUP : controller_panel.gd (platine IIDX dessinée d'un joueur, test et remappage) ;
                         touches sauvées dans user://mappings.cfg via Global.save_key_mapping() (touche, "Button:n:pad", "Axis:n:signe:pad")
    customization_menu.gd  Choix de la BGM de la sélection (user://music_select_bgm/*.ogg)
  download/download.gd   Télécharge et dézippe un pack de musiques dans user://songs
  result/                Écrans de résultats solo et versus
scenes/
  game/main.gd + .tscn   Terrain de jeu d'un joueur (le coeur du gameplay)
  game/main_p2.tscn      main.tscn côté 2P seul (player = 2)
  game/main_2p.gd/.tscn  Versus local : deux main.tscn côte à côte, un AudioStreamPlayer partagé
  game/main_netplay.gd   Copie de main.gd pour le jeu en ligne (ne gère pas les .MOD)
  game/note.gd           Une note (normale ou longue) qui descend
  game/judge.gd          Règles IIDX partagées avec le netplay : fenêtres, EX-Score, jauge (class_name Judge)
  menu/, result/         Scènes des menus et résultats
  netplay/               Lobby et chat en ligne (ENet, RPC level_play)
```

Les musiques ne sont pas dans le dépôt : elles sont dans `user://songs` (sous Linux `~/.local/share/godot/app_userdata/TrackerMania/songs/`), scannées récursivement. Un chemin contenant `official` va dans la catégorie Official, le reste dans Downloaded. Les catégories FILE TYPE (MODULE, QUAVER, BMS), sous les ALPHABET, trient par extension et restent masquées tant qu'elles sont vides.

## Fonctionnement du jeu

### Flux des scènes
Menu titre -> sélection des musiques -> `song_entry._on_pressed()` règle `Loader.file_path` et `Loader.chart_difficulty`, puis ouvre :
- `main.tscn` (P1 seul), `main_p2.tscn` (P2 seul) ou `main_2p.tscn` (versus) ;
- en netplay, la sélection est ouverte dans le lobby et la partie se lance par RPC.

`main.gd` charge la chart avec `loadQuaChart()`, `loadModule()` ou `loadBms()` selon l'extension. Ensuite `main.gd.finish()` écrit les résultats dans `Global` et ouvre l'écran de résultats.
En solo (hors autoplay), il enregistre aussi la partie avec `Scores.save_play()` : une section par fichier de chart, une clé par difficulté, et chaque valeur (EX-Score, taux, lampe, combo) garde son meilleur séparément. Comme sur IIDX, l'auto-scratch et le 5 touches donnent au mieux un ASSIST CLEAR. La sélection l'affiche sous les infos de la musique, après la difficulté (`SongInfo/BestScore`).

### Aperçu dans la sélection (`song_preview.gd`)
Comme sur IIDX : 0.4 s après l'arrivée du curseur sur une musique, elle est chargée dans un thread (`WorkerThreadPool`) et jouée 20 s en boucle, avec fondu, sur le bus `Preview` (créé à la volée, envoyé vers Master : l'effector s'applique). La BGM de la sélection est en pause pendant ce temps et reprend sur une catégorie ou une entrée aléatoire.
- .qua : l'audio depuis `SongPreviewTime` (`QuaChart.previewTime`), sinon depuis le tiers de la musique.
- .mod : un `ModPlayer` sans chart (tout en BGM, bus `ModLeftPreview`/`ModRightPreview`), lancé par `play_from()` à la mesure la plus proche du tiers.
- BMS : le fichier `#PREVIEW` ou `preview_music` (`BmsChart.previewFile`) s'il existe, sinon un `BmsPlayer` comme pour un module.

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
- Chaque note connaît son heure (`note.hitTime`) : sa position est recalculée à chaque image depuis l'heure de la chanson (`notePosition()`), les lignes de mesure aussi. Les notes du netplay (sans `hitTime`) bougent encore par image (`coordPerFrame`).
- **Jugement comme IIDX**, sur l'écart en temps (`Judge.judge()`), fenêtres en ms symétriques : P-GREAT ±16.67, GREAT ±33.33, GOOD ±116.67, BAD ±250. Au-delà du BAD tardif, c'est un POOR.
  GOOD garde le combo, BAD et POOR le cassent. Tout passe par `addJudge()`.
- **EX-Score** : P-GREAT 2 points, GREAT 1, le reste 0. Une note longue compte pour 2 (appui et relâché, comme une CN) : relâchée trop tôt, POOR ; tenue plus de 250 ms après la fin, BAD.
  `Global.score` est le taux EX (EX / (notes × 2) × 100), `Global.ex_score` l'EX-Score. Le rang vaut un palier tous les 1/9 (AAA ≥ 8/9).
- **Jauge comme IIDX** (`Judge.gaugeChange()`, appliquée par `updateGauge()` à chaque jugement, plus par le combo) :
  - NORMAL et EASY partent de 22 %, ne descendent pas sous 2 %, et il faut 80 % à la fin. Un P-GREAT ou un GREAT rend 7.605 / (0.01 × notes + 6.5) %, soit un total de 7.605 × n / (0.01 n + 6.5) % pour la chart. Un GOOD rend la moitié.
  - Dégâts NORMAL : BAD −2, POOR −6, POOR vide −2. EASY : ×0.8.
  - HARD part de 100 %, P-GREAT/GREAT +0.16, GOOD 0, BAD −6, POOR −10, POOR vide −2, dégâts divisés par 2 à 30 % ou moins, échec à 0.
  - Affichage par paliers de 2 % (`gaugeDisplay()`), c'est cette valeur qui va dans `gauge_score`.
- **POOR vide** (`emptyPress()`) : une touche pressée sans note à frapper, alors qu'une note de la lane arrive dans moins de 500 ms, abîme la jauge sans casser le combo.
- L'horloge est `songPosition() - AudioServer.get_output_latency()` ; pour un MP3/OGG, `songPosition()` ajoute `AudioServer.get_time_since_last_mix()`, sinon elle avance par saccades de la taille d'un mixage (fatal avec des fenêtres de ±16 ms).
- RANDOM mélange seulement les touches (0~6, ou 0~4 en 5 touches) ; le scratch ne bouge jamais, comme sur IIDX. En 5 touches, les lanes 5 et 6 sont vidées au chargement.
- Côté 2P (`mirrored`) l'interface est inversée, avec le scratch à droite.

## Modules Amiga keysoundés (`scripts/mod/`)

Un fichier `.mod` dans `user://songs` crée **3 entrées** (Normal, Hyper, Another) dans la sélection. Leur niveau est calculé, et elles sont masquées en netplay.
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
- Pas de .MOD en netplay (`main_netplay.gd` est une copie séparée de `main.gd`, qui reprend le même jugement, l'EX-Score et la jauge via `Judge`). En fin de partie, l'EX-Score est envoyé dans le chat.
- La BGM est déclenchée à chaque image (environ 16 ms), avec une compensation du retard.
- Pas de notes longues générées. Le format FLT8 est lu de façon approximative.

## BMS keysoundés (`scripts/bms/`)

Chaque fichier .bms, .bme, .bml ou .bmson est une entrée de la sélection (catégorie BMS), masquée en netplay. Seul le SP est lu : un chart avec des notes 2P (canaux 2x/6x, bmson `beat-14k`) ou un autre mode (pop'n…) est refusé (`null`).

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
- Pas de BGA, de `#TOTAL`, de `#RANK`, de LNTYPE 2, de mines ; pas de DP ; pas de BMS en netplay.
- Godot transforme `\` en `/` dans les chemins : un dossier dont le nom contient un `\` (mojibake de zip) n'est pas lisible.
- Les titres japonais demandent une police système avec ces glyphes (`allow_system_fallback`).

## Conventions
- GDScript avec des tabulations. Fonctions et variables du gameplay en camelCase (`noteArray`, `keyPressed`) dans `main.gd`, `note.gd` et `scripts/mod/` ; snake_case dans les menus.
- Commentaires courts en anglais au-dessus du code. Textes et README en français.
- Godot génère les fichiers `.uid` : il faut les committer avec les scripts.
- Le lien `bms` à la racine (BMS de référence, non suivi) ne doit pas être modifié. Avant un `godot --import` ou un test, le déplacer hors du projet, sinon Godot importe ses milliers de .ogg.

## Tester
- `godot --headless --import` reconstruit le cache des classes après l'ajout d'un `class_name`.
- Les autoloads (`Global`, `Loader`) ne sont pas disponibles avec `--script`. Pour tester une scène, créer temporairement une scène avec un script `extends Node` qui règle `Loader.file_path` et `Loader.chart_difficulty`, instancie `scenes/game/main.tscn`, puis la lancer avec `godot --headless chemin.tscn`. Supprimer ensuite les fichiers temporaires.
- Les avertissements de fuite (RID, ObjectDB) à la sortie viennent d'un `quit()` en pleine scène.
