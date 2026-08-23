CoA Heretic Proc HUD v3.8.1
===========================

PROFIL NIVEAU 39
----------------
- Profil cible : Cultist / Heretic heal, canevas exact "Cultist Healer M+ Ready".
- Source : https://coabuildhub.com/build/5ba4e749-4871-4e36-aeeb-52c0678bc26c
- Le canevas public est un build final de niveau 60. Au niveau 39, l'addon ne valide que les sorts reellement appris dans le grimoire du personnage.
- Un talent ou sort du canevas qui n'est pas encore appris ne peut donc ni activer le HUD ni faire avancer par erreur le compteur 1/3 -> 2/3.
- Les IDs publics du canevas sont utilises comme alias des IDs custom reels de CoA, sans dependre du nom FR/EN.
- Le niveau est relu automatiquement a la connexion, au changement de zone, de talents ou de sorts : aucune configuration manuelle a refaire en montant de niveau.
- Le guide recommande l'Intelligence pendant le leveling pour conserver assez de mana; son ordre Critique > Force/AP concerne surtout le personnage equipe a haut niveau. Cela ne change pas ce HUD et n'ajoute aucune consigne de rotation.

PROC SOIN OCCULTE
-----------------
- Aucune rotation.
- 1 petit point apres la premiere capacite melee valide, 2 apres la deuxieme, sans texte superflu.
- Au 3e declenchement, les points disparaissent et l'icone SOIN INSTANT apparait.
- L'icone 52 px montre le temps restant avec un balayage circulaire, le compteur et la touche de barre d'action si elle est detectable.
- Detection croisee par Spell ID, Combat Log et UNIT_SPELLCAST_SUCCEEDED. Les doubles evenements d'un meme cast sont fusionnes.
- Les IDs des capacites custom sont aussi recuperes depuis le grimoire lorsque CoA les expose.
- L'etat READY reste verrouille jusqu'au cast reussi de Soin occulte / Eldritch Mending ou expiration.

SANG NOIR
---------
- Tracker compact : icone + couverture (5/5) + un point colore par membre + stacks + temps restant + mini barre.
- Base actuelle : 10 s. Herald of the Depths est pris en compte a 20 s en fallback si l'aura est detectee.
- >3 s et groupe couvert : discret violet/bleu.
- <=3 s : orange + pulsation + RaidWarning net (plus aucun son de chuchotement).
- <=1,5 s : rouge + pulsation forte + seconde alarme critique.
- Un membre perd Sang noir : tracker rouge/orange + ! et avertissement.
- Plus personne n'a Sang noir : OFF + alerte rouge.
- Le son n'est joue qu'au changement d'etat, jamais en boucle.
- Le scan lourd des auras de groupe est limite a 5 fois/seconde; les evenements UNIT_AURA forcent toujours une mise a jour immediate.

COMMANDES
---------
/hh                 menu
/hh test            test visuel
/hh bbsound         test des deux alertes sonores Sang noir
/hh unlock          deplacer le proc
/hh lock            verrouiller le proc
/hh bbunlock        deplacer Sang noir
/hh bblock          verrouiller Sang noir
/hh progress        progression ON/OFF
/hh keybind         touche du proc ON/OFF
/hh button          bouton individuel de minicarte ON/OFF
/hh preset compact  disposition compacte
/hh preset central  disposition sous le personnage
/hh preset healer   disposition agrandie pour soigneur
/hh bbalways        tracker Sang noir toujours visible ON/OFF
/hh sound           sons ON/OFF
/hh scale 1         taille proc
/hh bbscale 1       taille tracker Sang noir
/hh trace           trace detection proc
/hh events          affiche les 12 derniers evenements captures par la trace
/hh trace clear     efface le journal de trace
/hh debug           diagnostic
/hh reset           reset positions/tracking
