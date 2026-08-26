CoA Stormbringer Helper v1.1.0
================================

Compagnon visuel strictement informatif pour Project Ascension / Conquest of Azeroth 3.3.5a.

- Fonctionne des le niveau 1 et detecte automatiquement le passage au niveau 10.
- Distingue Lightning, Maelstrom et Wind via l'API CoA, les talents actifs et le spellbook reel.
- Ne propose jamais un sort absent, passif, hors portee, en recharge ou inutilisable.
- Suit la Static via l'API de puissance Ascension lorsqu'elle est exposee.
- Suit les procs, Conductive, les Thunder Orbs, l'Air Elemental/Wind Servant et les ennemis actifs.
- Affiche une icone compacte avec cooldown, glow, touche, raison et ressource.
- Aucune automatisation : l'addon ne lance jamais de sort.

Commandes
---------
/storm                 ouvrir/fermer les reglages
/storm status          diagnostic du personnage
/storm scan            rescanner niveau, sorts et talents
/storm unlock          deplacer le HUD
/storm lock            verrouiller le HUD
/storm test            test visuel de huit secondes
/storm sound           son des procs importants ON/OFF
/storm text            texte compact ON/OFF
/storm burst           grosses fenetres de burst ON/OFF
/storm minimap         bouton de minicarte ON/OFF
/storm debug           raison du conseil actuel
/storm reset           reinitialiser les reglages et positions

Sources recoupees au 26 aout 2026 :
- Changelog officiel Ascension Conquest of Azeroth
- CoA Build Hub, profils et descriptions Stormbringer
- srhinos/coa-datamine, donnees client Stormbringer
- Ascension Sidekick, analyses Lightning/Wind
- spellbook, talents et auras reels du personnage (source prioritaire en jeu)
