# CoA Tools

Suite locale sans télémétrie désormais dédiée à **Warmane Icecrown / WoW 3.3.5a**.

Les anciennes sources Project Ascension restent disponibles dans `addons/` à titre d’archive. Elles ne sont plus publiées dans les nouvelles releases, proposées par le manager ou réinstallées automatiquement.

Les composants actifs sont :

- **UI Manager - Warmane** — gestionnaire complet de positions, profils, échelle, alpha et erreurs de sorts ;
- **Loot Decider - Warmane** — comparateur de stuff pour les dix classes et tous les arbres de talents WotLK ;
- **CoA Addon Manager** — application Windows Warmane qui détecte ou mémorise un seul dossier `Interface\AddOns`.

## Artefacts installables

Chaque nouvelle release publie trois ZIP :

- `CoAAddonManager-vX.Y.Z-Windows.zip` : extrayez le dossier puis double-cliquez sur `CoAAddonManager.cmd`. Au premier lancement, le bootstrap Windows télécharge le moteur Node.js officiel, vérifie son SHA-256 et ouvre le gestionnaire. Si `4173` est occupé, un port libre est choisi automatiquement ;
- `CoAUIManager-Warmane-vX.Y.Z.zip` : édition Warmane Icecrown du gestionnaire de positions, profils, échelle et alpha. Elle peut aussi masquer séparément le son vocal et les messages rouges d’échec de sorts sans cacher les erreurs Lua ;
- `CoALootDecider-Warmane-vX.Y.Z.zip` : édition Warmane WotLK couvrant les dix classes et leurs arbres de talents, avec variantes Feral tank/DPS et Blood tank/DPS, comparaison de l'équipement, de la capacité des sacs, de la banque, des marchands et du butin. Les tooltips expliquent le verdict ; maintenir `MAJ` affiche le calcul détaillé.

Les deux addons ciblent strictement WoW 3.3.5a (`## Interface: 30300`) et Lua 5.1.

## Éditions Warmane Icecrown

Le manager détecte les emplacements Warmane usuels ou permet de sélectionner une fois le dossier qui contient `Interface\AddOns`. Il mémorise ce chemin unique et propose seulement **UI Manager - Warmane** et **Loot Decider - Warmane**.

UI Manager conserve `/cui unlock`, les profils global/personnage, les frames personnalisées, le bouton de minicarte et l’anti-reset hors combat. Le panneau contient deux réglages distincts pour le son d’échec et les messages rouges ; `/cui quiet on|off` bascule les deux ensemble.

Loot Decider détermine la classe et l’arbre actif avec les API talents WotLK, s’adapte au niveau d’armure disponible avant/après le niveau 40 et compare aussi les objets des PNJ, de la banque et des sacs. Les spécialisations ambiguës se règlent avec `/cld role tank|dps|auto`. Par prudence, les conseils visuels sont actifs dès l’installation mais les jets NEED/PASS automatiques doivent être explicitement activés avec `/cld auto`.

## Performances en jeu

Depuis la 1.20.1, Loot Decider met en cache les données immuables des objets, fusionne les rafales d’événements de sacs/talents et répartit les contours d’objets sur plusieurs images. Ouvrir un sac, un marchand ou une fenêtre de butin ne déclenche plus un rescan complet du spellbook et des talents. Le guide de donjon sépare aussi la flèche légère des cartes et conseils de loot plus coûteux, tandis qu’Essential Assistant temporise les auras de groupe et mémorise leurs tooltips.

Ces protections réduisent les causes de gels créées par les addons. Si un gel subsiste après la mise à jour, désactiver temporairement les addons Warmane tiers un par un reste utile pour identifier un autre responsable ; le manager ne peut pas corriger le client ou un addon externe sans erreur/profil précis.

## CoA Combat Assistant

L’interface se limite à une icône contextuelle de 56 px avec cooldown, glow et touche d’action. Elle n’affiche que des actions offensives contre une cible hostile valide, puis disparaît automatiquement lorsqu’il n’y a rien à attaquer. Les buffs, soins et invocations ne bloquent plus la rotation. Les détails restent accessibles avec les commandes de diagnostic.

Le profil Nécromancien Animation est construit uniquement à partir des sorts réellement appris. Sa boucle offensive suit les informations actuellement disponibles : `Blight` en ouverture sur une cible durable, `Command: Undead` lorsque la puissance runique et une invocation sont disponibles, puis `Crypt Swarm` comme filler/générateur. Il évalue aussi la cible, la portée, les cooldowns, la santé, la mémoire des résistances et le nombre d’ennemis. Il ne lance jamais automatiquement un sort.

La mémoire suit le joueur, son pet, ses summons et ses guardians via le combat log 3.3.5. Pour chaque créature, elle conserve le GUID, le nom, les rencontres, les morts observées, les dégâts, le temps de combat, la dernière rencontre et la zone.

Commandes :

- `/cca status`, `/cca scan`, `/cca unlock`, `/cca lock` ;
- `/cca memory [filtre|clear]` pour inspecter ou vider la mémoire ;
- `/cca debug` pour expliquer la recommandation et les rejets ;
- `/cca aoe 3` pour régler le seuil AOE ;
- `/cca show`, `/cca hide`, `/cca reset`.

## CoA UI Manager

CoA UI Manager permet de repositionner et personnaliser l’interface : `/cui unlock` affiche les movers, le bouton toujours visible **TERMINER LE DÉPLACEMENT** ou `/cui lock` enregistre et quitte ce mode, et `/cui profile global|character` change de profil. La molette règle l’échelle, Maj+molette règle l’alpha, et `/cui add NomDuFrame` ajoute un frame Lua personnalisé. Aucun frame sécurisé n’est déplacé pendant un combat.

## CoA Stormbringer Helper

Le compagnon Stormbringer fonctionne dès le niveau 1. Il surveille les gains de niveau, le spellbook et les talents, puis détecte automatiquement le choix **Lightning**, **Maelstrom** ou **Wind** à partir du catalogue CoA lorsqu'il est disponible et des sorts/talents réellement actifs en fallback. Au niveau 10, le changement de spécialisation remplace immédiatement les priorités sans réglage manuel.

Le HUD reste compact et se cache lorsqu'aucune action utile n'est disponible. Son icône montre le sort conseillé, son cooldown, son glow, la touche correspondante, la Static exposée par Ascension et une explication courte. Lightning gère notamment la construction/dépense de Static, Volt, Forked Lightning, les fenêtres de Storm Ascendance et Arm of Thorim ; Maelstrom suit Conductive et les Thunder Orbs ; Wind suit l'Air Elemental/Wind Servant, Gale et les fenêtres Typhoon. Les conseils restent filtrés par la cible, la portée, la ressource, les cooldowns et les sorts réellement appris. L'addon ne lance jamais de sort.

Le panneau est accessible depuis **Centre CoA → Storm**, son bouton autonome de minicarte ou `/storm`. Commandes utiles : `/storm status`, `/storm scan`, `/storm unlock`, `/storm lock`, `/storm test`, `/storm debug` et `/storm reset`.

## CoA Primalist Helper

Le compagnon Primalist fonctionne dès le niveau 1 avec les capacités réellement apprises. À chaque gain de niveau, nouveau sort ou changement de talent, il rescane automatiquement le personnage. Au niveau 10, il reconnaît le choix **Wildwalker (Primal)**, **Geomancy**, **Grovekeeper (Life)** ou **Mountain King**, puis remplace immédiatement son moteur de priorité.

Le HUD n'affiche qu'une action actuellement utilisable avec son cooldown, sa touche et une raison courte. Wildwalker suit le familier, la Rage, les saignements et le cleave ; Geomancy suit Earthshaping, Aftershock et les dépenses de Rage ; Mountain King sépare menace, regroupement et défensifs ; Grovekeeper analyse aussi les membres du groupe et nomme l'allié à soigner ou à purifier lorsqu'un poison ou une maladie peut réellement être retiré. Il ne cible jamais un joueur et ne lance jamais de sort.

Le panneau est accessible depuis **Centre CoA → Primalist**, son bouton de minicarte ou `/primal`. Commandes utiles : `/primal status`, `/primal scan`, `/primal unlock`, `/primal lock`, `/primal test`, `/primal debug` et `/primal reset`.

## CoA Rotation Guide

Le guide est fermé par défaut et s’ouvre depuis **Centre CoA → Rotations**, avec `/rotation`, ou par son bouton de minicarte autonome lorsque UI Manager n’est pas chargé. Il détecte la classe, la spécialisation CoA active, le niveau, les talents investis et chaque sort réellement appris. Les priorités sourcées sont utilisées lorsqu’un guide suffisamment précis existe ; le reste passe par un classement adaptatif prudent fondé sur les tooltips du spellbook et le rôle du personnage. Un sort absent ou passif n’est jamais proposé.

La fenêtre est organisée comme un petit parcours : **Comprendre** raconte naturellement l’identité de la spécialisation, son rythme, le déroulé d’un combat et un exercice adapté au niveau ; **Rotation** donne l’ordre des sorts en expliquant ce que chaque transition cherche réellement à obtenir ; **Situations** sépare l’ouverture, le passage ST/AOE, la gestion de ressource et les soins, défensifs ou contrôles réactifs ; **Progression** indique quoi travailler ou obtenir au niveau actuel, récupère les statistiques du profil Loot Decider et détaille au niveau 60 le circuit Heroïque/Mythique+, les caches, Mythic Coins et services d’Edrim Skysong ; **Actus** affiche les changements Ascension qui ressemblent à la classe, à la spécialisation ou aux sorts appris ; **Sources** explique l’origine et la fraîcheur des conseils.

Le niveau, la spécialisation, les rangs du spellbook et la signature des talents CoA sont surveillés en continu. Chaque gain de niveau, nouveau sort ou changement de talent déclenche plusieurs lectures espacées pour couvrir le délai du serveur ; **Actualiser maintenant** reste disponible comme contrôle manuel. Les trois spécialisations Runemaster disposent désormais de parcours distincts : marques et Runeblade pour Engravement, génération/consommation des glyphes pour Glyphic et cadence élémentaire/Runeblade pour Riftblade.

La préparation reste séparée de la rotation principale pour que les buffs ne masquent pas l’ordre d’action. Chaque étape affiche désormais **quoi faire**, **pourquoi le sort vient ici** et **ce qui doit suivre**. L’interface rappelle qu’il s’agit d’une liste de priorité : on lit de haut en bas, on prend le premier sort disponible dont la condition est remplie, puis on recommence. Les guides longs disposent de pages Précédent/Suivant et le survol d’une ligne affiche le tooltip original du sort.

Les modes **Solo/Groupe** et **ST/AOE** sont sélectionnables dans la fenêtre. Les explications précises issues d’un guide sont distinguées des repères prudents déduits du tooltip, du rôle et des talents. Les soins ou défensifs contextuels ne sont plus injectés dans la boucle offensive uniquement parce qu’ils sont disponibles. Commandes : `/rotation comprendre`, `/rotation pourquoi`, `/rotation situations`, `/rotation progression`, `/rotation actus`, `/rotation scan`, `/rotation status`, `/rotation st|aoe`, `/rotation solo|groupe`, `/rotation sources`, `/rotation reset`.

La veille hebdomadaire lit le changelog et les actualités officiels Ascension. À chaque ouverture du manager, le rapport est transformé en un petit fichier Lua 5.1 puis transmis au guide installé. Au prochain lancement ou `/reload`, une alerte en jeu apparaît uniquement si une note non lue correspond au personnage. L’alerte est conservatrice : elle signale le changement et garde la note officielle, mais ne réécrit jamais silencieusement une priorité non vérifiée. Le jeu 3.3.5 ne pouvant pas accéder lui-même à Internet, le manager doit avoir été ouvert au moins une fois depuis la publication du rapport.

## CoA Essential Assistant

L’assistant Essentiel est indépendant du Guide de Rotation. Il ne donne aucun ordre de sorts et masque par défaut l’icône de rotation en combat. Il relit automatiquement la classe, la spécialisation, le niveau, les talents et le spellbook, puis n’affiche que des informations immédiatement utiles : proc court confirmé par une aura réelle, charges, ressource proche d’un seuil important, effet essentiel posé sur la cible ou couverture de groupe déjà observée.

Le filtre est volontairement strict. Nourriture, parchemins, montures, bonus d’expérience, métiers et buffs longs sont rejetés. Un mécanisme doit correspondre au profil de la spécialisation ou porter dans son tooltip une signature explicite de proc — prochain sort, lancement instantané, coût annulé, recharge réinitialisée ou charges maximales. Un clic droit permet de bannir immédiatement un faux positif ; les réglages permettent ensuite de tout réactiver.

Les 21 classes ont leurs couleurs et leur disposition : ligne, colonne, arc, runes, totem, horloge, noyau technique, sang, vide ou constellation. Les quatre modules **Procs**, **Ressource**, **Effet cible** et **Couverture groupe** se déplacent séparément et possèdent chacun leur activation, échelle et alpha. Les positions sont enregistrées en profil global ou par personnage. Le panneau et son bouton autonome de minicarte restent accessibles même avec UI Manager. Commandes : `/cea`, `/cea unlock`, `/cea lock`, `/cea test`, `/cea scan`, `/cea profile`, `/cea sound`, `/cea rotation`, `/cea reset` et `/cea status`.

Sur Cultist Hérétique, le suivi spécialisé existant conserve automatiquement la main afin de ne pas perdre la détection précise du troisième coup, du soin instantané et de Sang noir. Les HUD de recommandations Stormbringer et Primalist sont masqués au profit des signaux essentiels du nouveau moteur. L’addon ne cible rien et ne lance jamais de sort.

## CoA Dungeon Navigator

Le navigateur contient maintenant 15 routes hors ligne compilées à partir de 36 passages réels sur Ascension. Dès l'entrée dans un donjon connu, une petite flèche sans panneau de fond apparaît au-dessus du personnage et tourne selon son orientation. Elle ne garde à l'écran que la direction et la distance ; boss, danger, raccourci ou changement d'étage déclenchent un cartouche latéral temporaire qui disparaît ensuite. Les étapes de pack ou de boss attendent la fin du combat avant de continuer. Si le personnage quitte la trace, le moteur recherche un point cohérent sur le bon étage ; le bouton **Me recaler** permet de forcer immédiatement cette récupération.

La grande fenêtre ne s'affiche que sur demande et présente la trace de l'étage, la position du joueur, la prochaine étape, les rencontres à venir et les objets déjà observés évaluables par CoA Loot Decider. Les commandes `/cdg next`, `/cdg prev`, `/cdg recal`, `/cdg reset` et `/cdg hud` permettent de corriger le suivi sans ouvrir le panneau. `/cdg unlock` permet de glisser la flèche, puis `/cdg lock` la rend à nouveau non interactive ; elle reste aussi disponible depuis `/cui unlock`.

Le mode apprentissage reste disponible depuis **Collecte** ou par clic droit sur le bouton de minicarte. Il démarre automatiquement dans une instance de type donjon et s'arrête à la sortie. Il mémorise des points de parcours espacés, les changements de carte et d'étage disponibles, les pulls du groupe, les créatures rencontrées, les morts observées, les boss potentiels et les objets réellement vus dans les fenêtres de butin. Il ne relève jamais le chat ni le nom des autres joueurs et ne prend jamais automatiquement un objet.

La fenêtre **Centre CoA → Donjons** permet de poser en un clic un repère Raccourci, Porte, Escalier, Danger, Boss ou Pack évité. **Exporter** produit un bloc texte sélectionné automatiquement avec `Ctrl+C`, destiné à être comparé à d'autres passages avant de devenir une route guidée. Le petit témoin vert n'apparaît que pendant l'enregistrement et peut être déplacé.

Commandes : `/cdn`, `/cdn start`, `/cdn stop`, `/cdn status`, `/cdn auto on|off`, `/cdn mark raccourci|porte|escalier|danger|boss|skip [note]` et `/cdn export`.

La version guidée finale ajoutera un onglet **Butins intéressants ici**. Les tables de butin seront rattachées aux boss réellement présents dans la route puis évaluées par le profil actif de CoA Loot Decider : classe, spécialisation, niveau, talents, objets équipés et objets déjà possédés. L'objectif n'est pas d'afficher tout le catalogue du donjon, mais uniquement les améliorations plausibles avec le boss concerné et la raison de l'intérêt.

## CoA Loot Decider

Les 70 profils de spécialisation servent de base, puis sont affinés localement en fonction du niveau, des sorts réellement présents dans le spellbook et des talents actifs. La base embarque les 3 618 nœuds des 21 classes CoA issus de la capture publique du builder Ascension du 6 août 2026. L’addon interroge directement les rangs avec `C_CharacterAdvancement.GetTalentRankByID` et `GetTalentRankBySpellID` ; l’ouverture de la fenêtre de talents n’est donc pas requise.

Les ajustements sont volontairement bornés : un talent renforce uniquement une statistique déjà autorisée par le profil de spécialisation. Il ne peut jamais réactiver une famille interdite ni remplacer un poids réglé manuellement. Un dernier profil fiable est mémorisé par personnage et spécialisation pour couvrir les quelques secondes où l’API de talents peut être vide pendant la connexion.

Depuis la v1.22.0, une barrière d’adéquation précède le score brut : les familles d’armure documentées des 21 classes, la cohérence des statistiques principales et l’utilité réelle de l’objet sont vérifiées avant toute décision automatique. Une pièce hors famille ou classée `MAUVAIS` ne peut plus devenir un faux NEED simplement grâce à son niveau ou à une grosse statistique secondaire ; les objets hybrides réellement utiles restent évaluables et les cas ambigus restent manuels.

Commandes complémentaires : `/cld talents` affiche l’arbre, le nombre de talents et de sorts détectés ainsi que la confiance ; `/cld explain` liste les talents qui influencent le stuff et les ajustements appliqués. `/cld scan` force une nouvelle détection, `/cld gear` ouvre la comparaison visuelle triable par gain ou emplacement et `/cld history` ouvre l’historique détaillé des décisions.

Les coffres verrouillés proposés dans une fenêtre de jet constituent une exception aux objets non équipables : Loot Decider choisit **NEED** lorsqu’il est disponible, sinon **CUPIDITÉ**, au lieu de les passer. La règle est active par défaut et peut être inversée avec `/cld chests` ou `/cld coffres`.

## Gestion automatique des addons Warmane

Le manager recherche les installations Warmane usuelles, puis utilise le dernier dossier `Interface\AddOns` choisi manuellement. Il n’existe plus de sélecteur Ascension/Warmane ni de second chemin actif.

Chaque sous-dossier qui contient un fichier `.toc` est scanné réellement. Le nom du dossier ainsi que les champs `Title`, `Version` et `Notes` sont affichés.

Une installation ou mise à jour CoA télécharge le ZIP officiel, vérifie obligatoirement sa taille et son SHA-256, contrôle son chemin d’extraction et exige un `.toc` dans le dossier cible avant remplacement. Une sauvegarde automatique précède chaque remplacement et peut être restaurée depuis l’interface.

Chaque addon CoA peut être exclu des mises à jour globales et automatiques tout en restant installé. Le bouton **Désinstaller** crée d’abord une sauvegarde restaurable, le désactive dans les profils de tous les personnages, retire uniquement son dossier exact, puis bloque aussi les installations manuelles. Ce choix est mémorisé à deux endroits — dans les données du manager et dans `Interface\AddOns\.coa-disabled-addons.json` — afin qu’un rafraîchissement, une mise à jour du manager ou la perte d’un seul réglage ne le réinstalle jamais. Le bouton **Réactiver l’installation** est la seule action qui l’autorise de nouveau.

Les installations individuelles et la mise à jour globale sont suivies en direct : addon courant, étape, pourcentage, octets téléchargés et temps écoulé restent visibles, même après un rafraîchissement de l’interface. Un téléchargement réseau est interrompu avec une erreur explicite après deux minutes sans résultat.

## Archive de la veille CoA

Le code et les anciens rapports de veille CoA restent archivés pour l’historique, mais le manager Warmane ne les charge plus et le workflow hebdomadaire Ascension est désactivé.

La veille lit en priorité le [changelog officiel Conquest of Azeroth](https://ascension.gg/en/changelog/4), puis les [actualités officielles Ascension](https://ascension.gg/en/news/board). Elle surveille aussi la révision des [données publiques des arbres CoA](https://github.com/srhinos/coa-datamine/tree/master/data/talents/coa). Elle utilise leurs API publiques, regroupe les changements rang par rang, conserve les empreintes déjà vues dans `watch/state.json` et publie le rapport lisible dans `watch/report.json`.

Le workflow `Veille CoA hebdomadaire` s’exécute chaque lundi, teste le parseur et les règles d’impact, puis ne commit que le rapport et l’état anti-doublon. Une vérification manuelle peut être déclenchée depuis le manager ou localement :

```bash
npm run watch:coa
```

## Développement local

Prérequis : Node.js 24.14 ou supérieur.

```bash
npm install
npm start
npm run generate:loot-talents
```

Ouvrez ensuite <http://127.0.0.1:4173>. Les données locales sont stockées dans `data/`, ignoré par Git. Les chemins et le port peuvent être adaptés avec les variables de [`.env.example`](.env.example).

## Mises à jour sûres

Au démarrage puis toutes les heures, le manager interroge le `manifest.json` de la dernière release GitHub, même si son onglet de navigateur est fermé. Le manifeste liste séparément chaque composant avec sa version, son URL, son dossier cible, son chemin d’installation, sa taille et son SHA-256. Une nouvelle version du manager est téléchargée dans `.updates/`, vérifiée, puis signalée une seule fois par une alerte Windows. Au lancement suivant, le lanceur arrête uniquement les anciens processus CoA Manager, applique le ZIP vérifié et redémarre sur la bonne version. Un téléchargement invalide est supprimé et n’altère jamais l’installation courante.

Les addons CoA sont mis à jour automatiquement à l’ouverture du manager, avec une sauvegarde avant chaque remplacement. Les deux automatismes et les alertes Windows peuvent être activés ou désactivés dans **UI Manager** ; ils sont actifs par défaut.

Les métadonnées sont toujours relues par le serveur depuis le manifeste distant et ne sont jamais acceptées depuis le navigateur. Le bootstrap Windows vérifie également le moteur Node.js téléchargé avec le fichier officiel `SHASUMS256.txt` de nodejs.org.

Le launcher attend la réponse HTTP réelle du serveur pendant 60 secondes et surveille simultanément le processus Node. Les sorties sont conservées dans `%LOCALAPPDATA%\CoAAddonManager\logs` ; en cas d’arrêt ou de délai dépassé, stdout et stderr sont affichés au lieu d’un diagnostic générique sur le port.

## Générer une release

Le générateur ZIP est sans dépendance et produit des archives déterministes : mêmes sources, mêmes SHA-256 sur Windows et GitHub Actions.

```bash
npm run release
npm run validate:manifest -- dist/manifest.json
```

Pour publier :

1. Mettre à jour `version` dans `package.json`, `package-lock.json`, `manifest.json` et les métadonnées `.toc`.
2. Exécuter `npm run release` et reporter les tailles et SHA-256 obtenus dans le manifeste versionné.
3. Pousser le commit puis le tag correspondant.
4. Le workflow `Release` teste, crée les trois ZIP puis publie les ZIP, `SHA256SUMS.txt` et `manifest.json`.

Le workflow peut aussi être lancé manuellement avec une version. Le client utilise par défaut le manifeste de la dernière release ; `COA_UPDATE_MANIFEST` permet de cibler un autre canal.

## Vérification

```bash
npm test
npm run validate:manifest
```

Les tests analysent aussi la syntaxe des addons en Lua 5.1 et refusent les API Retail connues, notamment `BackdropTemplate`, `SetShown`, les événements Encounter et tout `.toc` différent de 30300.

Voir [SECURITY.md](SECURITY.md) pour le modèle de confiance des mises à jour.
