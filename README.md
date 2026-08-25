# CoA Tools

> Depuis la version 1.2.1, le manager installe le **véritable EventAlert 4.3.6** pour WoW 3.3.5 depuis sa publication CurseForge, accompagné d’un chargeur de compatibilité CoA minimal. Le chargeur survit aux réparations du dossier officiel par Ascension, conserve l’interface, les sons, les options et `/ea` d’origine, et apprend automatiquement les procs et réactions `SPELL_ACTIVE` de CoA.

Suite locale sans télémétrie regroupant les outils CoA suivants :

- **CoA Combat Assistant** — addon WoW de recommandations visuelles et de mémoire des combats ;
- **CoA UI Manager** — gestionnaire complet de positions, profils, échelle et alpha ;
- **CoA Rotation Guide** — guide hors ligne consultable, adapté à la classe, la spécialisation, au niveau, au spellbook et aux talents actifs ;
- **CoA Dungeon Navigator** — véritable guide de tank hors ligne avec flèche, trace d'étage, prochaines rencontres et recalage automatique, doublé d'un collecteur de parcours ;
- **CoA Addon Manager** — application Windows qui détecte Project Ascension et gère automatiquement les addons CoA.

## Artefacts installables

Chaque release publie dix ZIP :

- `CoAAddonManager-vX.Y.Z-Windows.zip` : extrayez le dossier puis double-cliquez sur `CoAAddonManager.cmd`. Au premier lancement, le bootstrap Windows télécharge le moteur Node.js officiel, vérifie son SHA-256 et ouvre le gestionnaire. Si `4173` est occupé, un port libre est choisi automatiquement ;
- `CoACombatAssistant-vX.Y.Z.zip` : extrayez le dossier `CoACombatAssistant` dans le dossier `Interface/AddOns` de Project Ascension ;
- `CoAUIManager-vX.Y.Z.zip` : extrayez le dossier `CoAUIManager` dans le dossier `Interface/AddOns` de Project Ascension.
- `CoALootDecider-vX.Y.Z.zip` : compare automatiquement le butin, les sacs, la banque, les vendeurs PNJ et tout lien d'objet avec l'équipement et le profil de spécialisation du personnage ; ajoute des contours vert/jaune/rouge, un pourcentage dans les icônes, un diagnostic dans les tooltips et une fenêtre accessible par son propre bouton de minicarte ou `/cld gear` ;
- `CoAMessageCenter-vX.Y.Z.zip` : centralise les messages des addons CoA hors du chat général ;
- `CoARotationGuide-vX.Y.Z.zip` : ouvre un guide de priorités ST/AOE et solo/groupe filtré par les sorts réellement appris, avec parcours de leveling et d'équipement niveau 60 ;
- `CoADungeonNavigator-vX.Y.Z.zip` : guide automatiquement 15 donjons déjà observés, affiche la direction et les prochaines étapes, puis continue d'apprendre les trajets sans enregistrer le chat ni le nom des autres joueurs ;
- `CoAHereticHelper-v3.9.0.zip` : HUD visuel compact dédié au Cultist Heretic heal, avec diagnostic au survol, sons séparés, seuils Sang noir réglables, proc de Soin occulte et couverture membre par membre ;
- `GridCoA-vX.Y.Z.zip` : compagnon du véritable Grid ; il détecte les dissipations apprises et réserve l’icône centrale aux seuls affaiblissements que le personnage peut retirer.
- `EventAlertCoA-vX.Y.Z.zip` : couche de compatibilité appliquée automatiquement par le manager au véritable EventAlert 4.3.6. Le code original, sous licence « All Rights Reserved », est téléchargé séparément depuis [sa fiche CurseForge officielle](https://www.curseforge.com/wow/addons/event-alert/files/456081), puis vérifié par taille et SHA-256.

Les addons et la couche EventAlert ciblent strictement le client Project Ascension / WoW 3.3.5a (`## Interface: 30300`) et Lua 5.1.

## EventAlert pour CoA

Ce projet ne réinvente pas EventAlert et ne republie pas son code. Le manager compose localement l’archive officielle EventAlert 4.3.6 avec `EventAlertCoA.lua`. La couche prépare les tables pour les jetons de classes CoA tels que `NECROMANCER`, migre les réglages d’anciens ports Ascension, détecte les auras de proc émises par le joueur et les réactions `SPELL_ACTIVE`, puis les affiche dans les vrais frames EventAlert. Les procs appris sont conservés dans les SavedVariables d’EventAlert et apparaissent dans ses options après rechargement.

Commandes complémentaires : `/ea coa`, `/ea coa learn`, `/ea coa scan`. Toutes les autres commandes `/ea` restent celles d’origine.

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

CoA UI Manager remplace les fonctions essentielles de MoveAnything : `/cui unlock` affiche les movers, le bouton toujours visible **TERMINER LE DÉPLACEMENT** ou `/cui lock` enregistre et quitte ce mode, et `/cui profile global|character` change de profil. La molette règle l’échelle, Maj+molette règle l’alpha, et `/cui add NomDuFrame` ajoute un frame Lua personnalisé. Aucun frame sécurisé n’est déplacé pendant un combat.

## CoA Rotation Guide

Le guide est fermé par défaut et s’ouvre depuis **Centre CoA → Rotations**, avec `/rotation`, ou par son bouton de minicarte autonome lorsque UI Manager n’est pas chargé. Il détecte la classe, la spécialisation CoA active, le niveau, les talents investis et chaque sort réellement appris. Les priorités sourcées sont utilisées lorsqu’un guide suffisamment précis existe ; le reste passe par un classement adaptatif prudent fondé sur les tooltips du spellbook et le rôle du personnage. Un sort absent ou passif n’est jamais proposé.

La fenêtre est organisée comme un petit parcours : **Comprendre** raconte naturellement l’identité de la spécialisation, son rythme, le déroulé d’un combat et un exercice adapté au niveau ; **Rotation** donne l’ordre des sorts en expliquant ce que chaque transition cherche réellement à obtenir ; **Situations** sépare l’ouverture, le passage ST/AOE, la gestion de ressource et les soins, défensifs ou contrôles réactifs ; **Progression** indique quoi travailler ou obtenir au niveau actuel, récupère les statistiques du profil Loot Decider et détaille au niveau 60 le circuit Heroïque/Mythique+, les caches, Mythic Coins et services d’Edrim Skysong ; **Actus** affiche les changements Ascension qui ressemblent à la classe, à la spécialisation ou aux sorts appris ; **Sources** explique l’origine et la fraîcheur des conseils.

Le niveau, la spécialisation, les rangs du spellbook et la signature des talents CoA sont surveillés en continu. Chaque gain de niveau, nouveau sort ou changement de talent déclenche plusieurs lectures espacées pour couvrir le délai du serveur ; **Actualiser maintenant** reste disponible comme contrôle manuel. Les trois spécialisations Runemaster disposent désormais de parcours distincts : marques et Runeblade pour Engravement, génération/consommation des glyphes pour Glyphic et cadence élémentaire/Runeblade pour Riftblade.

La préparation reste séparée de la rotation principale pour que les buffs ne masquent pas l’ordre d’action. Chaque étape affiche désormais **quoi faire**, **pourquoi le sort vient ici** et **ce qui doit suivre**. L’interface rappelle qu’il s’agit d’une liste de priorité : on lit de haut en bas, on prend le premier sort disponible dont la condition est remplie, puis on recommence. Les guides longs disposent de pages Précédent/Suivant et le survol d’une ligne affiche le tooltip original du sort.

Les modes **Solo/Groupe** et **ST/AOE** sont sélectionnables dans la fenêtre. Les explications précises issues d’un guide sont distinguées des repères prudents déduits du tooltip, du rôle et des talents. Les soins ou défensifs contextuels ne sont plus injectés dans la boucle offensive uniquement parce qu’ils sont disponibles. Commandes : `/rotation comprendre`, `/rotation pourquoi`, `/rotation situations`, `/rotation progression`, `/rotation actus`, `/rotation scan`, `/rotation status`, `/rotation st|aoe`, `/rotation solo|groupe`, `/rotation sources`, `/rotation reset`.

La veille hebdomadaire lit le changelog et les actualités officiels Ascension. À chaque ouverture du manager, le rapport est transformé en un petit fichier Lua 5.1 puis transmis au guide installé. Au prochain lancement ou `/reload`, une alerte en jeu apparaît uniquement si une note non lue correspond au personnage. L’alerte est conservatrice : elle signale le changement et garde la note officielle, mais ne réécrit jamais silencieusement une priorité non vérifiée. Le jeu 3.3.5 ne pouvant pas accéder lui-même à Internet, le manager doit avoir été ouvert au moins une fois depuis la publication du rapport.

## CoA Dungeon Navigator

Le navigateur contient maintenant 15 routes hors ligne compilées à partir de 36 passages réels sur Ascension. Dès l'entrée dans un donjon connu, un HUD compact affiche une flèche relative à l'orientation du personnage, la prochaine étape, une consigne naturelle, l'étage, la progression et la prochaine rencontre importante. Les étapes de pack ou de boss attendent la fin du combat avant de continuer. Si le personnage quitte la trace, le moteur recherche un point cohérent sur le bon étage ; le bouton **Me recaler** permet de forcer immédiatement cette récupération.

La grande fenêtre présente la trace de l'étage, la position du joueur, la prochaine étape, les rencontres à venir et les objets déjà observés évaluables par CoA Loot Decider. Les commandes `/cdg next`, `/cdg prev`, `/cdg recal`, `/cdg reset` et `/cdg hud` permettent de corriger le suivi sans ouvrir le panneau. Le HUD et la fenêtre sont déplaçables directement ou depuis `/cui unlock`.

Le mode apprentissage reste disponible depuis **Collecte** ou par clic droit sur le bouton de minicarte. Il démarre automatiquement dans une instance de type donjon et s'arrête à la sortie. Il mémorise des points de parcours espacés, les changements de carte et d'étage disponibles, les pulls du groupe, les créatures rencontrées, les morts observées, les boss potentiels et les objets réellement vus dans les fenêtres de butin. Il ne relève jamais le chat ni le nom des autres joueurs et ne prend jamais automatiquement un objet.

La fenêtre **Centre CoA → Donjons** permet de poser en un clic un repère Raccourci, Porte, Escalier, Danger, Boss ou Pack évité. **Exporter** produit un bloc texte sélectionné automatiquement avec `Ctrl+C`, destiné à être comparé à d'autres passages avant de devenir une route guidée. Le petit témoin vert n'apparaît que pendant l'enregistrement et peut être déplacé.

Commandes : `/cdn`, `/cdn start`, `/cdn stop`, `/cdn status`, `/cdn auto on|off`, `/cdn mark raccourci|porte|escalier|danger|boss|skip [note]` et `/cdn export`.

La version guidée finale ajoutera un onglet **Butins intéressants ici**. Les tables de butin seront rattachées aux boss réellement présents dans la route puis évaluées par le profil actif de CoA Loot Decider : classe, spécialisation, niveau, talents, objets équipés et objets déjà possédés. L'objectif n'est pas d'afficher tout le catalogue du donjon, mais uniquement les améliorations plausibles avec le boss concerné et la raison de l'intérêt.

## CoA Loot Decider

Les 70 profils de spécialisation servent de base, puis sont affinés localement en fonction du niveau, des sorts réellement présents dans le spellbook et des talents actifs. La base embarque les 3 618 nœuds des 21 classes CoA issus de la capture publique du builder Ascension du 6 août 2026. L’addon interroge directement les rangs avec `C_CharacterAdvancement.GetTalentRankByID` et `GetTalentRankBySpellID` ; l’ouverture de la fenêtre de talents n’est donc pas requise.

Les ajustements sont volontairement bornés : un talent renforce uniquement une statistique déjà autorisée par le profil de spécialisation. Il ne peut jamais réactiver une famille interdite ni remplacer un poids réglé manuellement. Un dernier profil fiable est mémorisé par personnage et spécialisation pour couvrir les quelques secondes où l’API de talents peut être vide pendant la connexion.

Commandes complémentaires : `/cld talents` affiche l’arbre, le nombre de talents et de sorts détectés ainsi que la confiance ; `/cld explain` liste les talents qui influencent le stuff et les ajustements appliqués. `/cld scan` force une nouvelle détection, `/cld gear` ouvre la comparaison visuelle triable par gain ou emplacement et `/cld history` ouvre l’historique détaillé des décisions.

Les coffres verrouillés proposés dans une fenêtre de jet constituent une exception aux objets non équipables : Loot Decider choisit **NEED** lorsqu’il est disponible, sinon **CUPIDITÉ**, au lieu de les passer. La règle est active par défaut et peut être inversée avec `/cld chests` ou `/cld coffres`.

## Gestion automatique des addons Ascension

Le manager privilégie automatiquement `C:\Ascension\Launcher\resources\ascension-live\Interface\AddOns`, puis le dernier chemin choisi et les installations usuelles. La configuration avancée permet de sélectionner et mémoriser un autre dossier `Interface\AddOns`.

Chaque sous-dossier qui contient un fichier `.toc` est scanné réellement. Le nom du dossier ainsi que les champs `Title`, `Version` et `Notes` sont affichés. Les addons Ascension existants restent distincts de CoA Combat Assistant et CoA UI Manager, qui sont toujours proposés depuis le manifeste GitHub.

Une installation ou mise à jour CoA télécharge le ZIP officiel, vérifie obligatoirement sa taille et son SHA-256, contrôle son chemin d’extraction et exige un `.toc` dans le dossier cible avant remplacement. Une sauvegarde automatique précède chaque remplacement et peut être restaurée depuis l’interface.

Chaque addon CoA peut être exclu des mises à jour globales et automatiques tout en restant installé et disponible pour une mise à jour manuelle. Le bouton **Désinstaller** crée d’abord une sauvegarde restaurable, retire uniquement le dossier exact de l’addon, puis l’exclut automatiquement afin qu’une mise à jour globale ne le réinstalle pas. EventAlert reste volontairement protégé de ces deux actions.

Les installations individuelles et la mise à jour globale sont suivies en direct : addon courant, étape, pourcentage, octets téléchargés et temps écoulé restent visibles, même après un rafraîchissement de l’interface. Un téléchargement réseau est interrompu avec une erreur explicite après deux minutes sans résultat.

## Veille hebdomadaire CoA

Le manager présente les changements susceptibles d’affecter Combat Assistant, Loot Decider, EventAlertCoA, GridCoA ou UI Manager dans l’onglet **Mises à jour**. Chaque proposition indique la source, la date, les addons concernés, le niveau de confiance et la raison technique. Aucune règle d’addon n’est modifiée ou publiée automatiquement à partir d’un patch note.

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
4. Le workflow `Release` teste, crée les dix ZIP puis publie les ZIP, `SHA256SUMS.txt` et `manifest.json`.

Le workflow peut aussi être lancé manuellement avec une version. Le client utilise par défaut le manifeste de la dernière release ; `COA_UPDATE_MANIFEST` permet de cibler un autre canal. `COA_WATCH_REPORT` permet de remplacer l’URL du rapport de veille.

## Vérification

```bash
npm test
npm run validate:manifest
```

Les tests analysent aussi la syntaxe des addons en Lua 5.1 et refusent les API Retail connues, notamment `BackdropTemplate`, `SetShown`, les événements Encounter et tout `.toc` différent de 30300.

Voir [SECURITY.md](SECURITY.md) pour le modèle de confiance des mises à jour.
