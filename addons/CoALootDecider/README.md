# CoA Loot Decider

**Un comparateur de butin adaptatif pour Project Ascension — Conquest of Azeroth.**

[Télécharger la dernière version](https://github.com/Cnbz13/coa-loot-decider/releases/latest) · [Signaler un problème](https://github.com/Cnbz13/coa-loot-decider/issues) · [CoA Addon Manager](https://github.com/Cnbz13/coa-tools/releases/latest)

CoA Loot Decider répond à une question simple : **« Est-ce que cet objet est réellement meilleur pour le personnage que je joue maintenant ? »**

Il ne se contente pas de comparer le niveau d’objet. Il détecte la classe, la spécialisation CoA, le niveau, les talents actifs, les sorts appris, les restrictions d’armure et d’armes, puis compare le candidat avec l’équipement porté **et** les meilleures pièces déjà présentes dans les sacs.

## Ce que l’addon analyse

- les fenêtres de butin et les jets de groupe ;
- tous les sacs, y compris avec AdiBags ;
- la banque lorsqu’elle est ouverte ;
- les objets vendus par un PNJ ;
- les liens d’objets affichés dans un tooltip ;
- 21 classes et 70 spécialisations actuellement répertoriées pour CoA ;
- les profils hybrides, les armes à une ou deux mains, la vitesse d’arme et les incompatibilités de statistiques.
- une **barrière d’adéquation** avant le score brut : famille d’armure, cohérence de spécialisation et statistiques réellement utiles sont vérifiées avant qu’un objet puisse devenir un NEED automatique ;
- les 21 classes disposent d’une règle d’armure ; les spécialisations dont l’itemisation est clairement distincte disposent d’une surcharge dédiée, sans inventer de règle lorsque les sources publiques restent ambiguës.

Les objets franchement meilleurs sont signalés en vert. Les cas incertains ou sous le seuil restent jaunes et demandent une vérification. Les objets moins bons peuvent être affichés en rouge. Un effet spécial que l’addon ne sait pas chiffrer n’est jamais présenté comme une certitude.

## Installation

### Installation directe

1. Télécharge l’archive `CoALootDecider-vX.Y.Z.zip` depuis la [dernière release](https://github.com/Cnbz13/coa-loot-decider/releases/latest).
2. Extrais le dossier `CoALootDecider` dans le dossier `Interface\AddOns` de Project Ascension.
3. Vérifie que ce chemin existe : `Interface\AddOns\CoALootDecider\CoALootDecider.toc`.
4. Relance le jeu ou utilise `/reload`.

### Avec CoA Addon Manager

Le [gestionnaire CoA Tools](https://github.com/Cnbz13/coa-tools/releases/latest) détecte le dossier Ascension, télécharge l’archive, vérifie son SHA-256, sauvegarde l’ancienne version et installe la mise à jour.

## Utilisation

Une **icône dorée dédiée** apparaît autour de la minicarte :

- clic gauche : ouvrir ou fermer le comparateur ;
- clic droit : ouvrir l’historique des décisions ;
- glisser : déplacer le bouton autour de la minicarte.

Loot Decider fonctionne seul. **CoA UI Manager n’est pas requis.**

## Commandes utiles

| Commande | Fonction |
| --- | --- |
| `/cld gear` | Ouvre le comparateur des sacs, de la banque et du marchand. |
| `/cld status` | Affiche le profil et les réglages détectés. |
| `/cld scan` | Rescanne immédiatement le personnage. |
| `/cld talents` | Explique les talents, sorts et ajustements utilisés. |
| `/cld history` | Ouvre l’historique visuel. |
| `/cld visuals` | Active ou désactive les contours et diagnostics. |
| `/cld downgrades` | Affiche ou masque les objets moins bons. |
| `/cld minimap show` | Réaffiche le bouton dédié. |
| `/cld minimap hide` | Masque le bouton dédié. |
| `/cld minimap reset` | Replace le bouton à sa position par défaut. |
| `/cld help` | Affiche toutes les commandes disponibles. |

## Décisions automatiques et sécurité

L’automatisation des jets NEED/PASS est configurable avec `/cld auto`. L’addon ne remplace jamais volontairement une pièce, n’achète pas d’objet chez un marchand et ne joue pas à la place du joueur.

Les coffres verrouillés sont traités séparément afin de ne pas être rejetés comme de simples objets non équipables. Leur comportement peut être changé avec `/cld chests`.

## Compatibilité

- Project Ascension — Conquest of Azeroth ;
- client WoW 3.3.5a ;
- `## Interface: 30300` ;
- Lua 5.1 ;
- aucune API Retail requise.

La détection tissu/cuir/maille/plaque utilise les identifiants d'objet lorsqu'Ascension les expose et bascule automatiquement sur le sous-type localisé de `GetItemInfo` sur un client 3.3.5.

## Données et méthode

Les profils de statistiques partent des poids BisBeard, sont recoupés avec CoA Build Hub et les tooltips Ascension, puis adaptés localement aux talents et aux sorts réellement présents sur le personnage. Les données de talents épinglent une révision précise du projet public `srhinos/coa-datamine` afin qu’une mise à jour externe ne modifie jamais silencieusement le comportement de l’addon.

Un poids statistique reste une aide à la décision : les effets de proc, bonus de set ou interactions très particulières peuvent demander un jugement manuel. Quand la confiance n’est pas suffisante, l’interface le dit au lieu de fabriquer une réponse.


Depuis la version 1.22.0, le score statistique n’est plus suffisant à lui seul pour déclencher un NEED. Un objet classé `MAUVAIS` en adéquation est bloqué, et une pièce d’armure hors famille documentée est rejetée avant comparaison. Cette séparation **FIT → UPGRADE** évite qu’une grosse quantité d’une statistique secondaire ou hybride compense artificiellement un objet hors profil.

## Retours et contributions

Pour signaler une mauvaise recommandation, ouvre une [issue GitHub](https://github.com/Cnbz13/coa-loot-decider/issues) avec :

- ta classe, ta spécialisation et ton niveau ;
- les deux liens d’objets comparés ;
- une capture du tooltip et du diagnostic Loot Decider ;
- le résultat de `/cld talents` si le problème semble lié au build.

CoA Loot Decider est un projet communautaire indépendant, non affilié à Project Ascension. Code distribué sous licence MIT.
