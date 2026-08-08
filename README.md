# CoA Tools

Suite locale sans télémétrie regroupant trois outils :

- **CoA Combat Assistant** — addon WoW avec chronomètre et suivi des rencontres ;
- **CoA UI Manager** — addon WoW de réglage rapide de l’interface ;
- **CoA Addon Manager** — application Windows pour installer, activer et supprimer des addons.

## Artefacts installables

Chaque release publie trois ZIP indépendants :

- `CoAAddonManager-vX.Y.Z-Windows.zip` : extrayez le dossier puis double-cliquez sur `CoAAddonManager.cmd`. Au premier lancement, le bootstrap Windows télécharge le moteur Node.js officiel, vérifie son SHA-256 et ouvre le gestionnaire ;
- `CoACombatAssistant-vX.Y.Z.zip` : extrayez le dossier `CoACombatAssistant` dans `World of Warcraft/_retail_/Interface/AddOns` ;
- `CoAUIManager-vX.Y.Z.zip` : extrayez le dossier `CoAUIManager` dans `World of Warcraft/_retail_/Interface/AddOns`.

Dans le jeu, `/coacombat` affiche ou masque l’assistant (`/coacombat reset` réinitialise sa position) et `/coaui` ouvre le gestionnaire d’interface.

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

Voir [SECURITY.md](SECURITY.md) pour le modèle de confiance des mises à jour.
