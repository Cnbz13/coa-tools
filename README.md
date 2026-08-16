# CoA Tools

> Depuis la version 1.2.1, le manager installe le **véritable EventAlert 4.3.6** pour WoW 3.3.5 depuis sa publication CurseForge, accompagné d’un chargeur de compatibilité CoA minimal. Le chargeur survit aux réparations du dossier officiel par Ascension, conserve l’interface, les sons, les options et `/ea` d’origine, et apprend automatiquement les procs et réactions `SPELL_ACTIVE` de CoA.

Suite locale sans télémétrie regroupant trois outils :

- **CoA Combat Assistant** — addon WoW de recommandations visuelles et de mémoire des combats ;
- **CoA UI Manager** — gestionnaire complet de positions, profils, échelle et alpha ;
- **CoA Addon Manager** — application Windows qui détecte Project Ascension et gère automatiquement les addons CoA.

## Artefacts installables

Chaque release publie sept ZIP :

- `CoAAddonManager-vX.Y.Z-Windows.zip` : extrayez le dossier puis double-cliquez sur `CoAAddonManager.cmd`. Au premier lancement, le bootstrap Windows télécharge le moteur Node.js officiel, vérifie son SHA-256 et ouvre le gestionnaire. Si `4173` est occupé, un port libre est choisi automatiquement ;
- `CoACombatAssistant-vX.Y.Z.zip` : extrayez le dossier `CoACombatAssistant` dans le dossier `Interface/AddOns` de Project Ascension ;
- `CoAUIManager-vX.Y.Z.zip` : extrayez le dossier `CoAUIManager` dans le dossier `Interface/AddOns` de Project Ascension.
- `CoALootDecider-vX.Y.Z.zip` : compare automatiquement le butin avec l'équipement et le profil de spécialisation du personnage ;
- `CoAMessageCenter-vX.Y.Z.zip` : centralise les messages des addons CoA hors du chat général ;
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

CoA UI Manager remplace les fonctions essentielles de MoveAnything : `/cui unlock` affiche les movers, `/cui lock` enregistre, et `/cui profile global|character` change de profil. La molette règle l’échelle, Maj+molette règle l’alpha, et `/cui add NomDuFrame` ajoute un frame Lua personnalisé. Aucun frame sécurisé n’est déplacé pendant un combat.

## Gestion automatique des addons Ascension

Le manager privilégie automatiquement `C:\Ascension\Launcher\resources\ascension-live\Interface\AddOns`, puis le dernier chemin choisi et les installations usuelles. La configuration avancée permet de sélectionner et mémoriser un autre dossier `Interface\AddOns`.

Chaque sous-dossier qui contient un fichier `.toc` est scanné réellement. Le nom du dossier ainsi que les champs `Title`, `Version` et `Notes` sont affichés. Les addons Ascension existants restent distincts de CoA Combat Assistant et CoA UI Manager, qui sont toujours proposés depuis le manifeste GitHub.

Une installation ou mise à jour CoA télécharge le ZIP officiel, vérifie obligatoirement sa taille et son SHA-256, contrôle son chemin d’extraction et exige un `.toc` dans le dossier cible avant remplacement. Une sauvegarde automatique précède chaque remplacement et peut être restaurée depuis l’interface.

Les installations individuelles et la mise à jour globale sont suivies en direct : addon courant, étape, pourcentage, octets téléchargés et temps écoulé restent visibles, même après un rafraîchissement de l’interface. Un téléchargement réseau est interrompu avec une erreur explicite après deux minutes sans résultat.

## Veille hebdomadaire CoA

Le manager présente les changements susceptibles d’affecter Combat Assistant, EventAlertCoA, GridCoA ou UI Manager dans l’onglet **Mises à jour**. Chaque proposition indique la source, la date, les addons concernés, le niveau de confiance et la raison technique. Aucune règle d’addon n’est modifiée ou publiée automatiquement à partir d’un patch note.

La veille lit en priorité le [changelog officiel Conquest of Azeroth](https://ascension.gg/en/changelog/4), puis les [actualités officielles Ascension](https://ascension.gg/en/news/board). Elle utilise leurs API publiques, regroupe les changements rang par rang, conserve les empreintes des publications déjà vues dans `watch/state.json` et publie le rapport lisible dans `watch/report.json`.

Le workflow `Veille CoA hebdomadaire` s’exécute chaque lundi, teste le parseur et les règles d’impact, puis ne commit que le rapport et l’état anti-doublon. Une vérification manuelle peut être déclenchée depuis le manager ou localement :

```bash
npm run watch:coa
```

## Développement local

Prérequis : Node.js 24.14 ou supérieur.

```bash
npm install
npm start
```

Ouvrez ensuite <http://127.0.0.1:4173>. Les données locales sont stockées dans `data/`, ignoré par Git. Les chemins et le port peuvent être adaptés avec les variables de [`.env.example`](.env.example).

## Mises à jour sûres

Au démarrage puis toutes les six heures, le client interroge le `manifest.json` de la dernière release GitHub. Le manifeste liste séparément chaque composant avec sa version, son URL, son dossier cible, son chemin d’installation, sa taille et son SHA-256. Un artefact compatible est téléchargé dans `.updates/`, vérifié, puis un fichier `ready.json` atomique indique qu’il peut être appliqué. Un téléchargement invalide est supprimé et n’altère jamais l’installation courante.

Les métadonnées sont toujours relues par le serveur depuis le manifeste distant et ne sont jamais acceptées depuis le navigateur. Le bootstrap Windows vérifie également le moteur Node.js téléchargé avec le fichier officiel `SHASUMS256.txt` de nodejs.org.

Le launcher attend la réponse HTTP réelle du serveur pendant 60 secondes et surveille simultanément le processus Node. Les sorties sont conservées dans `%LOCALAPPDATA%\CoAAddonManager\logs` ; en cas d’arrêt ou de délai dépassé, stdout et stderr sont affichés au lieu d’un diagnostic générique sur le port.

## Générer une release

Le générateur ZIP est sans dépendance et produit des archives déterministes : mêmes sources, mêmes SHA-256 sur Windows et GitHub Actions.

```bash
npm run release
npm run validate:manifest -- dist/manifest.json
```

Pour publier :

1. Mettre à jour `version` dans `package.json`, `package-lock.json`, `manifest.json` et les deux fichiers `.toc`.
2. Exécuter `npm run release` et reporter les tailles et SHA-256 obtenus dans le manifeste versionné.
3. Pousser le commit puis le tag correspondant.
4. Le workflow `Release` teste, crée les sept ZIP puis publie les ZIP, `SHA256SUMS.txt` et `manifest.json`.

Le workflow peut aussi être lancé manuellement avec une version. Le client utilise par défaut le manifeste de la dernière release ; `COA_UPDATE_MANIFEST` permet de cibler un autre canal. `COA_WATCH_REPORT` permet de remplacer l’URL du rapport de veille.

## Vérification

```bash
npm test
npm run validate:manifest
```

Les tests analysent aussi la syntaxe des addons en Lua 5.1 et refusent les API Retail connues, notamment `BackdropTemplate`, `SetShown`, les événements Encounter et tout `.toc` différent de 30300.

Voir [SECURITY.md](SECURITY.md) pour le modèle de confiance des mises à jour.
