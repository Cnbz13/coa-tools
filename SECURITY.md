# Sécurité

## Modèle de mise à jour

Une mise à jour n’est jamais appliquée directement. CoA Tools télécharge l’artefact dans un fichier temporaire, contrôle sa taille et son SHA-256 avec les valeurs du manifeste de release, puis le déplace atomiquement vers la zone de staging. L’installation explicite de l’artefact reste séparée afin qu’une interruption ne corrompe pas la version active.

SHA-256 garantit l’intégrité par rapport au manifeste. L’authenticité dépend de HTTPS et des permissions du dépôt GitHub : seules les GitHub Actions disposant de `contents: write` publient une release. Protégez donc la branche `main`, les tags et les workflows avec les règles GitHub adaptées.

## Signaler une vulnérabilité

Utilisez la fonctionnalité privée **Security advisories** du dépôt plutôt qu’une issue publique.
