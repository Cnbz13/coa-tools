# CoA Tools

Suite locale sans télémétrie regroupant trois outils :

- **CoA Combat Assistant** — addon WoW avec chronomètre et suivi des rencontres ;
- **CoA UI Manager** — addon WoW de réglage rapide de l’interface ;
- **CoA Addon Manager** — application Windows qui détecte Project Ascension et gère automatiquement les addons CoA.

## Artefacts installables

Chaque release publie trois ZIP indépendants :

- `CoAAddonManager-vX.Y.Z-Windows.zip` : extrayez le dossier puis double-cliquez sur `CoAAddonManager.cmd`. Au premier lancement, le bootstrap Windows télécharge le moteur Node.js officiel, vérifie son SHA-256 et ouvre le gestionnaire. Si `4173` est occupé, un port libre est choisi automatiquement ;
- `CoACombatAssistant-vX.Y.Z.zip` : extrayez le dossier `CoACombatAssistant` dans le dossier `Interface/AddOns` de Project Ascension ;
- `CoAUIManager-vX.Y.Z.zip` : extrayez le dossier `CoAUIManager` dans le dossier `Interface/AddOns` de Project Ascension.

Les deux addons ciblent strictement le client Project Ascension / WoW 3.3.5a (`## Interface: 30300`) et Lua 5.1.

Dans le jeu, CoA Combat Assistant fournit `/cca status`, `/cca scan`, `/cca unlock`, `/cca lock` et `/cca memory`. Il analyse le spellbook et le combat log pour proposer une recommandation ST/AOE, avec priorité au Nécromancien Animation, sans jamais lancer de sort.

CoA UI Manager remplace les fonctions essentielles de MoveAnything : `/cui unlock` affiche les movers, `/cui lock` enregistre, et `/cui profile global|character` change de profil. La molette règle l’échelle, Maj+molette règle l’alpha, et `/cui add NomDuFrame` ajoute un frame Lua personnalisé. Aucun frame n’est déplacé pendant un combat.

## Gestion automatique des addons Ascension

Le manager privilégie automatiquement `C:\Ascension\Launcher\resources\ascension-live\Interface\AddOns`, puis le dernier chemin choisi et les installations usuelles. La configuration avancée permet de sélectionner et mémoriser un autre dossier `Interface\AddOns`.

Chaque sous-dossier qui contient un fichier `.toc` est scanné réellement. Le nom du dossier ainsi que les champs `Title`, `Version` et `Notes` sont affichés. Les addons Ascension existants restent distincts de CoA Combat Assistant et CoA UI Manager, qui sont toujours proposés depuis le manifeste GitHub.

Une installation ou mise à jour CoA télécharge le ZIP officiel, vérifie obligatoirement sa taille et son SHA-256, contrôle son chemin d’extraction et exige un `.toc` dans le dossier cible avant remplacement. Une sauvegarde automatique précède chaque remplacement et peut être restaurée depuis l’interface.

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
3. Pousser un tag correspondant, par exemple `v1.1.0`.
4. Le workflow `Release` teste, crée les trois ZIP puis publie les ZIP, `SHA256SUMS.txt` et `manifest.json`.

Le workflow peut aussi être lancé manuellement avec une version. Le client utilise par défaut le manifeste de la dernière release ; `COA_UPDATE_MANIFEST` permet de cibler un autre canal.

## Vérification

```bash
npm test
npm run validate:manifest
```

Les tests analysent aussi la syntaxe des addons en Lua 5.1 et refusent les API Retail connues, notamment `BackdropTemplate`, `SetShown`, les événements Encounter et tout `.toc` différent de 30300.

Voir [SECURITY.md](SECURITY.md) pour le modèle de confiance des mises à jour.
