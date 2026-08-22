# CoA Loot Decider — audit d’optimisation (23 août 2026)

## Conclusion

Un poids unique « physique / caster / tank / heal » n’est pas adapté à Conquest of Azeroth. Les 21 classes couvrent 70 spécialisations, plusieurs sont hybrides, et des talents convertissent une statistique en une autre. Le moteur utilise donc désormais un profil numérique par spécialisation, puis les données réelles de l’objet fournies par le client.

Le résultat est une recommandation de progression, pas une simulation parfaite : un bijou, un bonus de set ou un effet `Équipé/Utiliser` dont la valeur dépend du combat reste volontairement en choix manuel.

## Hiérarchie des sources

1. [Changelog officiel Ascension](https://ascension.gg/en/changelog/resources/media/landing) : référence prioritaire pour les changements de mécanique et d’équilibrage.
2. [Catalogue CoA Build Hub](https://coabuildhub.com/skills) : environ 3 000 capacités, talents et passifs avec leurs tooltips ; 21 classes et 70 spécialisations.
3. [Guides CoA Build Hub](https://coabuildhub.com/) : 209 builds publics analysés, dont 160 guides détaillés. Les sections `Stats` ont été croisées par fraîcheur, vues et cohérence mécanique.
4. [BisBeard CoA](https://coa.bisbeard.com/) : poids EP numériques par spécialisation et règles d’équipement. Les poids intégrés proviennent de l’instantané public du 22 août 2026.
5. [CoA Ascension Logs](https://coa.ascensionlogs.gg/) : utile pour valider la performance réelle, mais les logs ne permettent pas à eux seuls de calculer la valeur marginale de chaque statistique.

Les wikis non officiels qui recommandent `Mastery` ou `Versatility` ont été exclus : ces statistiques ne correspondent pas au client CoA/WoW 3.3.5 ciblé.

## Couverture

| Classe | Spécialisations couvertes |
|---|---|
| Barbarian | Brutality, Headhunting, Ancestry |
| Witch Doctor | Voodoo, Brewing, Shadowhunting |
| Felsworn | Slayer, Infernal, Tyrant |
| Witch Hunter | Boltslinger, Houndmaster, Inquisition, Black Knight |
| Stormbringer | Lightning, Wind, Maelstrom |
| Knight of Xoroth | Hellfire, War, Defiance |
| Guardian | Vanguard, Inspiration, Gladiator |
| Templar | Zealot, Oathkeeper, Crusader |
| Bloodmage | Sanguine, Accursed, Eternal, Fleshweaver |
| Ranger | Farstrider, Archery, Brigand |
| Chronomancer | Infinite, Artificer, Time |
| Necromancer | Death, Rime, Animation |
| Pyromancer | Flameweaving, Incineration, Draconic |
| Cultist | Godblade, Corruption, Heretic, Dreadnought |
| Starcaller | Moon Guard, Moon Priest, Sentinel, Warden |
| Sun Cleric | Piety, Blessings, Seraphim, Valkyrie |
| Tinker | Demolition, Invention, Mechanics |
| Venomancer | Venom/Rotweaver, Stalking, Fortitude, Vizier |
| Reaper | Harvest, Soul, Domination |
| Primalist | Primal/Wildwalker, Geomancy, Life/Grovekeeper, Mountain King |
| Runemaster | Runic/Engravement, Arcane/Glyphic, Riftblade |

Les doubles noms correspondent aux renommages observés entre le catalogue CoA actuel et BisBeard ; l’addon possède des alias explicites pour ne pas perdre le profil.

## Mécaniques déterminantes confirmées

- **Cultist Heretic** : le changelog officiel du 8 août fixe `Power of Yogg-Saron` à **2,5 AP par point de Crit Rating**. Le poids EP total reste proche de 3, car le même point conserve aussi sa valeur critique propre. Les guides récents convergent vers `Crit > Force/AP > SP/Int > Hâte`, arme 2M lente. Ce poids exceptionnel n’est activé qu’à partir du niveau 50, niveau de la passive.
- **Tanks bloc** : Dreadnought, Vanguard, Defiance et plusieurs tanks hybrides ont des poids dédiés pour Endurance, Défense, Blocage, Valeur de blocage, Esquive, Parade et Armure.
- **Hybrides** : Hellfire, Seraphim, Warden, Demolition, Heretic et d’autres peuvent valoriser simultanément AP et SP. L’ancien rejet automatique d’une « famille incompatible » était donc faux.
- **Pets/invocations** : Animation, Houndmaster et autres profils gardent les statistiques transmises aux créatures (SP/AP, Intellect, Crit, Hâte, Toucher) au lieu d’appliquer une règle de caster générique.
- **Armes** : le DPS d’arme est chiffré séparément. La vitesse est lue dans le tooltip 3.3.5 pour les profils documentés comme arme lente ou rapide.
- **Caps** : Toucher et Expertise sont précieux jusqu’au cap seulement. Les poids intégrés restent modérés ; une future étape pourra calculer leur valeur marginale avec le score total du personnage et les bonus de groupe actifs.

## Garanties du moteur

- profil exact par classe et spécialisation, avec repli prudent si les API CoA ne renvoient pas le catalogue attendu ;
- aucune statistique Retail ; Lua 5.1 et Interface 30300 ;
- score fondé sur les statistiques utiles, sans bonus arbitraire d’ilvl ;
- comparaison correcte des deux anneaux, deux bijoux, main gauche/main droite et arme 2M contre l’ensemble remplacé ;
- vérification de compatibilité avant le score ;
- choix manuel obligatoire pour bijoux, procs, effets `Équipé/Utiliser`, bonus de set ou objet sans statistiques chiffrables ;
- explication du profil et de la source via `/cld status`.

## Limites connues et maintenance

CoA est encore activement équilibré. Les poids sont un instantané daté, et un profil parfait dépend aussi du niveau, des caps, du contenu, des talents choisis, des buffs de groupe, des bonus de set et de la durée des combats. Toute mise à jour automatique devra comparer le changelog officiel, le catalogue de tooltips, les poids BisBeard et les guides récents, puis exiger les tests de cohérence avant publication.
