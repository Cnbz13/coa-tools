# CoA Tools

Suite locale sans télémétrie regroupant trois outils dans un tableau de bord unique :

- **CoA Combat Assistant** — sessions, chronologie tactique et événements en direct ;
- **CoA UI Manager** — thèmes, densité et préférences persistantes ;
- **CoA Addon Manager** — installation depuis un dossier local, activation et suppression.

## Démarrage

Prérequis : Node.js 20 ou supérieur.

```bash
npm install
npm start
```

Ouvrez ensuite <http://127.0.0.1:4173>. Les données locales sont stockées dans `data/`, ignoré par Git. Les chemins et le port peuvent être adaptés avec les variables de [`.env.example`](.env.example).

## Mises à jour sûres

Au démarrage puis toutes les six heures, le client interroge le `manifest.json` de la dernière release GitHub. Un artefact compatible est automatiquement téléchargé dans `.updates/`, sa taille et son empreinte SHA-256 sont vérifiées, puis un fichier `ready.json` atomique indique qu’il peut être appliqué. Un téléchargement invalide est supprimé et n’altère jamais l’installation courante. Les métadonnées de téléchargement sont toujours relues par le serveur depuis le manifeste distant et ne sont jamais acceptées depuis le navigateur.

Le manifeste versionné à la racine décrit le format. Celui attaché à chaque release contient l’URL, la taille et le SHA-256 réels de l’artefact :

```bash
npm run release
npm run validate:manifest -- dist/manifest.json
```

## Publier une release

1. Mettre à jour `version` dans `package.json` et `manifest.json`.
2. Pousser un tag correspondant, par exemple `v1.1.0`.
3. Le workflow `Release` teste, package, calcule le SHA-256 et publie l’archive, son checksum et le manifeste.

Le workflow peut aussi être lancé manuellement avec une version. Le client utilise par défaut l’asset `manifest.json` de la dernière release ; `COA_UPDATE_MANIFEST` permet de cibler un autre canal.

## Vérification

```bash
npm test
npm run validate:manifest
```

Voir [SECURITY.md](SECURITY.md) pour le modèle de confiance des mises à jour.
