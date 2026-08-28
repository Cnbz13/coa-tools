# Historique des versions

## 1.22.0

- ajout d'une barriere d'adéquation universelle avant toute décision NEED : un objet `MAUVAIS` (< 35/100) ne peut plus devenir une amélioration automatique pendant le leveling ;
- ajout des familles d'armure pour les 21 classes, avec règles de spécialisation lorsque la documentation actuelle les distingue clairement ;
- détection de la famille d'armure compatible 3.3.5 : `GetItemInfoInstant` si disponible, sinon repli sur le sous-type localisé de `GetItemInfo` (FR/EN) ;
- correction du cas Chevalier de Xoroth Hellfire : un torse en tissu est désormais rejeté avant le calcul du score, même s'il contient de l'Intelligence ;
- correction générique des objets hybrides : une statistique principale inutile n'annule plus à elle seule un objet qui possède aussi des statistiques réellement utiles ;
- préservation de l'exception historique Bloodmage Sanguine (tissu/cuir) afin de ne pas introduire de régression avec la nouvelle barrière d'armure ;
- diagnostic enrichi dans les tooltips : adéquation, famille d'armure attendue et affinité de statistique principale faible ;
- couverture statique vérifiée sur les 70 profils de spécialisation.

## 1.16.1

- ajout d’un bouton de minicarte propre à CoA Loot Decider ;
- ouverture directe du comparateur au clic gauche et de l’historique au clic droit ;
- position du bouton mémorisée et commandes `show`, `hide` et `reset` ;
- suppression de l’entrée Loot Decider dans le panneau partagé de CoA UI Manager ;
- fonctionnement autonome explicitement testé sans CoA UI Manager.

## 1.16.0

- détection adaptative du niveau, de la spécialisation, du spellbook et des talents CoA ;
- catalogue de 70 spécialisations et données de talents épinglées ;
- comparaison de l’équipement, des sacs, de la banque, des marchands et du butin ;
- historique visuel, diagnostics de confiance et politique sécurisée pour les effets non chiffrables ;
- gestion dédiée des coffres verrouillés.
