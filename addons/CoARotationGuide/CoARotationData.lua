-- Banque hors ligne du Guide de Rotation CoA.
-- Les descriptions de specialisations viennent de CoA Build Hub et sont
-- recoupees avec les pages/changelogs officiels Ascension. Capture 2026-08-26,
-- donnees de talents et changements publics du patch 2026-08-25.
-- Les priorites exactes ci-dessous sont toujours filtrees par les sorts
-- reellement appris : aucun nom absent du spellbook ne sera affiche en jeu.

local profiles = {}

local function Add(className, specName, role, focus, style)
    profiles[className .. ":" .. specName] = {
        className = className,
        specName = specName,
        role = role,
        focus = focus,
        style = style
    }
end

Add("Barbarian", "Brutality", "DAMAGE", { "direct", "combo", "execute", "aoe" }, "Reste au contact, enchaine tes frappes puis garde l'execution pour une cible affaiblie.")
Add("Barbarian", "Headhunting", "DAMAGE", { "direct", "builder", "execute", "aoe" }, "Garde la distance et alterne tes lancers sans gaspiller ton energie.")
Add("Barbarian", "Ancestry", "SUPPORT", { "buff", "summon", "direct", "aoe" }, "Installe l'esprit ancestral et les bonus du groupe avant de completer avec tes attaques.")

Add("Witch Doctor", "Shadowhunting", "DAMAGE", { "summon", "direct", "dot", "aoe" }, "Laisse ton compagnon et tes wards travailler pendant que tu maintiens la pression a distance.")
Add("Witch Doctor", "Voodoo", "DAMAGE", { "dot", "debuff", "direct", "aoe" }, "Pose d'abord tes maledictions, laisse-les agir, puis termine avec les degats directs.")
Add("Witch Doctor", "Brewing", "HEALER", { "heal", "hot", "aoe", "buff" }, "Prepare le bon melange pour le besoin present et evite de vider tes composants sans urgence.")

Add("Felsworn", "Infernal", "DAMAGE", { "direct", "dot", "spender", "aoe" }, "Monte ta Felfury a distance puis depense-la dans tes sorts fel les plus rentables.")
Add("Felsworn", "Slayer", "DAMAGE", { "combo", "direct", "spender", "execute" }, "Respecte l'ordre de tes attaques de glaive : le finisher vaut surtout si la chaine est propre.")
Add("Felsworn", "Tyrant", "TANK", { "mitigation", "heal", "aoe", "spender" }, "Regroupe les ennemis, stabilise ta mitigation et utilise ton auto-soin avant la zone rouge.")

Add("Witch Hunter", "Boltslinger", "DAMAGE", { "direct", "builder", "aoe", "execute" }, "Maintiens un tir soutenu et reserve les grosses rafales aux fenetres favorables.")
Add("Witch Hunter", "Houndmaster", "DAMAGE", { "summon", "direct", "buff", "aoe" }, "Fais travailler la meute, puis synchronise tes tirs avec ses fenetres d'attaque.")
Add("Witch Hunter", "Inquisition", "DAMAGE", { "combo", "direct", "buff", "execute" }, "Adapte Purity ou Wickedness au combat et termine ta chaine sans casser son rythme.")
Add("Witch Hunter", "Black Knight", "TANK", { "mitigation", "heal", "aoe", "direct" }, "Deflechis les gros coups, draine ce qui t'attaque et garde un tonique pour le vrai danger.")

Add("Stormbringer", "Wind", "DAMAGE", { "summon", "direct", "builder", "aoe" }, "Pose ton elemental, accumule la Static et profite des regroupements pour tes rafales de vent.")
Add("Stormbringer", "Maelstrom", "DAMAGE", { "debuff", "builder", "spender", "aoe" }, "Mouille d'abord les cibles, charge la Static, puis electrocute le groupe.")
Add("Stormbringer", "Lightning", "DAMAGE", { "builder", "spender", "direct", "execute" }, "Monte rapidement la Static sans la depasser, puis depense-la en Supercharged.")

Add("Knight of Xoroth", "Hellfire", "DAMAGE", { "buff", "direct", "dot", "aoe" }, "Alterne sort et frappe d'Infernal Blade pour entretenir le Hellfire sur le pack.")
Add("Knight of Xoroth", "Defiance", "TANK", { "summon", "mitigation", "aoe", "heal" }, "Garde tes demons actifs, rassemble le pack et absorbe seulement ce qu'ils ne prennent pas.")
Add("Knight of Xoroth", "War", "DAMAGE", { "builder", "spender", "direct", "execute" }, "Accumule la Deathfire avec tes frappes, puis depense-la dans un gros impact deux-mains.")

Add("Guardian", "Gladiator", "DAMAGE", { "combo", "direct", "spender", "aoe" }, "Construis Glory avec Ram et Centurion Strike, puis transforme la prochaine ouverture en gros impact.")
Add("Guardian", "Inspiration", "SUPPORT", { "buff", "aoe", "direct", "mitigation" }, "Place bannieres et ballades avant la pression, puis soutiens la ligne sans surconsommer l'energie.")
Add("Guardian", "Vanguard", "TANK", { "mitigation", "combo", "aoe", "direct" }, "Le bon bloc au bon moment vaut mieux qu'un bouton presse au hasard ; garde de l'energie pour reagir.")

Add("Templar", "Oathkeeper", "TANK", { "combo", "mitigation", "aoe", "heal" }, "Construis tes Holy Runes proprement et choisis le finisher defensif adapte au prochain coup.")
Add("Templar", "Zealot", "DAMAGE", { "combo", "direct", "spender", "execute" }, "Enchaine vite les frappes, mais ne lance le finisher qu'avec une vraie chaine a convertir.")
Add("Templar", "Crusader", "DAMAGE", { "combo", "aoe", "spender", "direct" }, "Regroupe les cibles, construis tes runes et termine avec tes attaques tournoyantes.")

Add("Bloodmage", "Fleshweaver", "HEALER", { "heal", "hot", "aoe", "mitigation" }, "Depense ta vie avec mesure : soigne fort, puis recupere avant de recommencer.")
Add("Bloodmage", "Sanguine", "DAMAGE", { "dot", "direct", "heal", "spender" }, "Fais saigner, siphonne pour te stabiliser et ne sacrifie pas ta vie sans retour immediat.")
Add("Bloodmage", "Accursed", "DAMAGE", { "buff", "direct", "aoe", "execute" }, "Passe du corps-a-corps a la distance selon la forme et l'ouverture disponible.")
Add("Bloodmage", "Eternal", "TANK", { "mitigation", "heal", "aoe", "buff" }, "Maintiens Ironfur et ton auto-soin avant de chercher davantage de degats de meute.")

Add("Ranger", "Archery", "DAMAGE", { "direct", "builder", "execute", "aoe" }, "Reste a portee, garde tes tirs majeurs pour la bonne cible et remplis sans casser ton rythme.")
Add("Ranger", "Farstrider", "SUPPORT", { "buff", "direct", "debuff", "aoe" }, "Pose l'utilitaire du groupe d'abord, puis maintiens une pression propre a distance.")
Add("Ranger", "Brigand", "DAMAGE", { "debuff", "combo", "direct", "execute" }, "Ouvre avec ton avantage, garde les effets de chasse actifs et frappe la faille creee.")

Add("Chronomancer", "Time", "HEALER", { "hot", "heal", "aoe", "mitigation" }, "Choisis l'Aeon utile, anticipe les degats et renverse-les plutot que de courir apres.")
Add("Chronomancer", "Infinite", "DAMAGE", { "debuff", "direct", "spender", "aoe" }, "Alterne Chaos et Order sans casser leur interaction, puis depense pendant la fenetre ouverte.")
Add("Chronomancer", "Artificer", "DAMAGE", { "debuff", "direct", "combo", "aoe" }, "Desactive la cible avec ta technologie, puis utilise la baguette pour convertir l'ouverture.")

Add("Necromancer", "Death", "DAMAGE", { "dot", "debuff", "direct", "execute" }, "Empile les maladies avant de drainer ; sur une cible courte, passe directement aux degats.")
Add("Necromancer", "Animation", "DAMAGE", { "summon", "builder", "spender", "dot", "aoe" }, "Prepare l'armee, construis la Runic Power sans la depasser, puis commande tes morts-vivants.")
Add("Necromancer", "Rime", "DAMAGE", { "debuff", "builder", "direct", "spender" }, "Installe le froid et ses ralentissements, puis laisse la montee en puissance payer sur la duree.")

Add("Pyromancer", "Flameweaving", "HEALER", { "hot", "heal", "aoe", "buff" }, "Entretiens les soins de feu et garde ta grosse vague pour les degats de groupe.")
Add("Pyromancer", "Incineration", "DAMAGE", { "dot", "direct", "execute", "aoe" }, "Pose ce qui doit bruler, puis incinere pendant la bonne fenetre sans rafraichir trop tot.")
Add("Pyromancer", "Draconic", "DAMAGE", { "summon", "buff", "direct", "aoe" }, "Synchronise ta puissance draconique et tes sorts de feu pour une vraie rafale, pas sort par sort.")

Add("Cultist", "Heretic", "HEALER", { "buff", "direct", "heal", "spender", "aoe" }, "Garde Black Blood sur le groupe et transforme tes degats de melee en soins utiles.")
Add("Cultist", "Corruption", "DAMAGE", { "dot", "summon", "spender", "aoe" }, "Laisse les tentacules et corruptions s'installer avant de depenser ton Insanity.")
Add("Cultist", "Godblade", "DAMAGE", { "buff", "combo", "direct", "execute" }, "Charge la lame du vide, maintiens la pression melee et termine dans la bonne fenetre.")
Add("Cultist", "Dreadnought", "TANK", { "mitigation", "absorb", "aoe", "spender" }, "Fais tourner les absorptions et le bouclier avant de depenser ton Insanity en degats.")

Add("Starcaller", "Moon Priest", "HEALER", { "hot", "heal", "aoe", "buff" }, "Gere ta Mana comme une ressource de groupe : soins durables d'abord, urgence ensuite.")
Add("Starcaller", "Sentinel", "DAMAGE", { "direct", "builder", "execute", "aoe" }, "Garde ton arc actif a distance et depense la Mana seulement sur une vraie priorite.")
Add("Starcaller", "Warden", "DAMAGE", { "buff", "combo", "direct", "aoe" }, "Entre en melee sous la bonne influence lunaire, puis enchaine avant que la fenetre ne tombe.")
Add("Starcaller", "Moon Guard", "TANK", { "mitigation", "absorb", "aoe", "heal" }, "Convertis la Mana en survie avant le choc et conserve assez de marge pour le suivant.")

Add("Sun Cleric", "Piety", "DAMAGE", { "builder", "direct", "spender", "aoe" }, "Construis la Solar Power a distance puis depense-la dans la lumiere la plus rentable.")
Add("Sun Cleric", "Valkyrie", "DAMAGE", { "builder", "buff", "spender", "aoe" }, "Monte la Solar Power, ouvre Dawn au bon moment et deroule la rafale sans vider la barre trop tot.")
Add("Sun Cleric", "Seraphim", "TANK", { "mitigation", "absorb", "aoe", "spender" }, "Charge ton bouclier solaire avant le pack et laisse les attaquants se bruler dessus.")
Add("Sun Cleric", "Blessings", "HEALER", { "buff", "heal", "hot", "aoe" }, "Pose Guidance et les protections utiles, puis choisis le soin selon l'urgence reelle.")

Add("Tinker", "Demolition", "DAMAGE", { "builder", "direct", "aoe", "spender" }, "Charge les bonnes munitions, regroupe les cibles et enchaine poudre, roquettes et tir de finition.")
Add("Tinker", "Mechanics", "DAMAGE", { "summon", "builder", "spender", "aoe" }, "Pose tourelles et assistant, recolte le Scrap, puis passe en Mechsuit pour convertir la preparation.")
Add("Tinker", "Invention", "HEALER", { "hot", "heal", "summon", "aoe" }, "Repartis Nanobots et Beacons, puis utilise Repair Shot sur la cible qui en profite vraiment.")

Add("Venomancer", "Fortitude", "TANK", { "mitigation", "hot", "aoe", "spender" }, "Reste en forme de scorpid, entretiens l'exosquelette et regenere avant le prochain gros coup.")
Add("Venomancer", "Stalking", "DAMAGE", { "buff", "dot", "combo", "execute" }, "Ouvre depuis l'ombre, applique le poison puis profite de la cible deja affaiblie.")
Add("Venomancer", "Rotweaver", "DAMAGE", { "dot", "debuff", "spender", "aoe" }, "Superpose les poisons sans les ecraser trop tot et laisse la pourriture faire son travail.")
Add("Venomancer", "Vizier", "HEALER", { "hot", "absorb", "heal", "aoe" }, "Maintiens les soins de Shadra et utilise l'absorption avant que les degats n'arrivent.")

Add("Reaper", "Soul", "DAMAGE", { "builder", "direct", "spender", "execute" }, "Recolte les ames sans plafonner, puis depense-les sur la cible prioritaire.")
Add("Reaper", "Harvest", "DAMAGE", { "combo", "direct", "execute", "aoe" }, "Garde ta cadence melee et recolte les cibles faibles au lieu de gaspiller un gros coup.")
Add("Reaper", "Domination", "TANK", { "mitigation", "debuff", "aoe", "heal" }, "Controle le pack, reduis sa menace et garde ta mitigation pour les coups qui comptent.")

Add("Primalist", "Grovekeeper", "HEALER", { "hot", "heal", "summon", "aoe" }, "Installe les soins naturels et l'esprit utile avant de corriger les urgences.")
Add("Primalist", "Wildwalker", "DAMAGE", { "summon", "buff", "direct", "aoe" }, "Choisis l'esprit animal adapte et attaque avec lui plutot qu'a cote de lui.")
Add("Primalist", "Mountain King", "TANK", { "mitigation", "builder", "aoe", "spender" }, "Ancre-toi avant le choc, accumule ta ressource et depense-la pour tenir le pack.")
Add("Primalist", "Geomancy", "DAMAGE", { "debuff", "builder", "spender", "aoe" }, "Prepare le terrain elementaire, construis ta puissance puis declenche-la sur le groupe.")

Add("Runemaster", "Engravement", "DAMAGE", { "buff", "combo", "direct", "spender" }, "Grave les bonnes runes sur l'arme puis respecte leur chaine au corps-a-corps.")
Add("Runemaster", "Glyphic", "DAMAGE", { "buff", "debuff", "spender", "aoe" }, "Pose tes glyphes, laisse-les preparer la cible et declenche-les dans la bonne combinaison.")
Add("Runemaster", "Riftblade", "DAMAGE", { "buff", "combo", "direct", "aoe" }, "Entretiens les runes elementaires et frappe pendant que leur combinaison est active.")

-- Repères de méta hors ligne. Ils ne prétendent pas mesurer le DPS : CoA Build
-- Hub classe les builds par votes communautaires. Le guide présente donc ces
-- choix comme des favoris pratiques, datés, avec leur niveau de confiance.
local function Pick(spec, score, title, source, confidence, note, talents)
    return {
        spec = spec,
        score = score,
        title = title,
        source = source,
        confidence = confidence or "prudente",
        note = note,
        talents = talents or {}
    }
end

local meta = {
    ["Barbarian"] = {
        DAMAGE = Pick("Headhunting", 3, "HH Spearheads on Foreheads", "https://coabuildhub.com/build/357b736e-2be8-48bc-9052-fc4f9aa7c2e6", "moyenne", "Le choix distance le plus soutenu par les retours publics ; Brutality reste plus direct au corps-a-corps."),
        SUPPORT = Pick("Ancestry", 1, "Ancestry Barbarian", "https://coabuildhub.com/build/d7224a9d-7c7e-4382-af9e-0fe3c8dec13a", "prudente", "À choisir pour aider le groupe avec les esprits plutôt que pour viser le meilleur DPS personnel.")
    },
    ["Witch Doctor"] = {
        DAMAGE = Pick("Shadowhunting", 3, "Shadowhunter Witch Doctor build", "https://coabuildhub.com/build/f9b4830a-0000-492c-936a-afe69c347fc9", "moyenne", "Le familier et les wards donnent un leveling régulier et pardonnent bien les erreurs."),
        HEALER = Pick("Brewing", 3, "WD Brewing", "https://coabuildhub.com/build/fd4e200d-cfe4-45dc-b0a2-366e8971591d", "moyenne", "Le favori public pour soigner ; il demande surtout de choisir le bon mélange au bon moment.")
    },
    ["Felsworn"] = {
        DAMAGE = Pick("Slayer", 5, "Felsworn Slayer General Use", "https://coabuildhub.com/build/23902404-fe70-4869-98ab-ee1ef2e08f3e", "moyenne", "La recommandation DPS la plus approuvée ; Infernal reste une option distance plus souple."),
        TANK = Pick("Tyrant", 10, "IMMORTAL TYRANT - Walking Fortress", "https://coabuildhub.com/build/ae283725-5e17-4da9-b724-6729e0729a54", "haute", "Un des tanks les plus appréciés publiquement, axé survie et stabilité.")
    },
    ["Witch Hunter"] = {
        DAMAGE = Pick("Houndmaster", 5, "Houndmaster Deep Dive", "https://coabuildhub.com/build/e4e89e4c-e64d-41df-b93a-62e7a56fc887", "moyenne", "La meute rend le leveling confortable et le guide public est détaillé."),
        TANK = Pick("Black Knight", 1, "Black Knight - Leveling Tank", "https://coabuildhub.com/build/20a2dbac-85fd-49cb-8ffa-ea87affdfa38", "prudente", "Choix tank cohérent, mais encore peu voté sur le patch actuel.")
    },
    ["Stormbringer"] = {
        DAMAGE = Pick("Lightning", 3, "Lightning Stormbringer Leveling", "https://coabuildhub.com/build/96c001c3-21f3-432d-8028-e9a6cac7f103", "prudente", "Le favori leveling actuel, mais Volt, Arm of Thorim et Forked Lightning ont changé le 25 août.", { "Cloudburst", "Charge", "Body of Lightning", "Wind Shift", "Arcane Lightning", "Conjuration Mastery" })
    },
    ["Knight of Xoroth"] = {
        DAMAGE = Pick("Hellfire", 13, "KOX Hellfire balanced AOE+ST M+ build", "https://coabuildhub.com/build/45c0c353-08f3-487f-80c0-c47930763571", "haute", "Le choix DPS public le plus nettement approuvé pour mélanger cible unique et packs."),
        TANK = Pick("Defiance", 5, "M+, Tank, Defiance, Block, Beginner Friendly", "https://coabuildhub.com/build/86d49631-f22d-486d-92da-217af8ea965a", "moyenne", "Une base tank accessible, pensée pour apprendre les donjons.")
    },
    ["Guardian"] = {
        DAMAGE = Pick("Gladiator", 2, "Gladiator - PvE", "https://coabuildhub.com/build/164da105-e964-4a5f-969c-c990037bd745", "moyenne", "Le meilleur repère DPS PvE public de la classe."),
        TANK = Pick("Vanguard", 5, "Vanguard PvE", "https://coabuildhub.com/build/42d434c2-50ac-4f13-96ca-d69aaf05435d", "moyenne", "Le favori tank public ; le blocage au bon moment reste le cœur du gameplay."),
        SUPPORT = Pick("Inspiration", 3, "Inspiration Guardian PvE", "https://coabuildhub.com/build/0f6836ab-b365-4f6d-9090-6a2d78eacda4", "moyenne", "Pour renforcer le groupe avec bannières et ballades.")
    },
    ["Templar"] = {
        DAMAGE = Pick("Crusader", 9, "crusader aoe", "https://coabuildhub.com/build/5cb8e685-f728-4360-b867-9b4b2eec22c0", "haute", "Le favori DPS public, surtout dès que plusieurs ennemis sont regroupés."),
        TANK = Pick("Oathkeeper", 3, "Deadmanfred Oathkeeper Tank", "https://coabuildhub.com/build/a7792a90-0e37-4798-a849-30dd1ed291da", "moyenne", "Le choix tank naturel de la classe, centré sur les runes défensives.")
    },
    ["Bloodmage"] = {
        DAMAGE = Pick("Accursed", 2, "Accursed Big AOE DPS", "https://coabuildhub.com/build/a7fddb88-f32b-45e6-8255-d990785d79eb", "prudente", "Bon repère AOE ; les retours ST sont plus mitigés."),
        TANK = Pick("Eternal", 2, "Eternal Big AoE PVE - TANK", "https://coabuildhub.com/build/b73f2b5f-a47b-4f49-bbeb-4ba46452fd4e", "moyenne", "Le choix tank public le plus fréquent."),
        HEALER = Pick("Fleshweaver", 4, "The Fistweaver", "https://coabuildhub.com/build/2eb43843-d2ab-45f9-987c-fb7c73a3dd1b", "moyenne", "Un soigneur de mêlée apprécié en donjon et Mythique+.")
    },
    ["Ranger"] = {
        DAMAGE = Pick("Archery", 4, "Archery - PvE", "https://coabuildhub.com/build/1a626108-5840-4b3b-aaf7-33777a358433", "moyenne", "Le repère DPS le plus simple et le mieux soutenu ; Brigand est préféré pour le corps-a-corps."),
        SUPPORT = Pick("Farstrider", 1, "Farstrider Ranger Support", "https://coabuildhub.com/build/40b1536a-eca5-456f-813c-b50de9ee2540", "prudente", "Option utilitaire encore peu documentée publiquement.")
    },
    ["Chronomancer"] = {
        DAMAGE = Pick("Infinite", 0, "Infinite PvE", "https://coabuildhub.com/build/eb1748d8-859e-4a72-8b91-f89d5aa258c5", "prudente", "Le choix DPS le plus lisible dans les données actuelles, mais sans vote significatif."),
        HEALER = Pick("Time", 9, "Updated after rework - Mythic+ Time", "https://coabuildhub.com/build/d0ca993a-cdea-4318-8ca8-129dcb617a31", "haute", "Le choix soin public le plus solide après sa refonte.")
    },
    ["Necromancer"] = {
        DAMAGE = Pick("Animation", 5, "3 Crypt Fiend Animation ST", "https://coabuildhub.com/build/f268b2a3-20e4-49df-bf9e-9c85ff7ae167", "moyenne", "Le favori public en cible unique et en leveling ; adapte ensuite le nombre d'invocations aux packs.")
    },
    ["Pyromancer"] = {
        DAMAGE = Pick("Incineration", 0, "Incineration Pyromancer Raid", "https://coabuildhub.com/build/c3f534e6-5b44-425b-8631-da8129688e82", "prudente", "Spécialisation DPS logique, mais les votes publics restent insuffisants pour parler de domination."),
        HEALER = Pick("Flameweaving", 6, "The Phoenix Healer", "https://coabuildhub.com/build/95a75263-aeef-43f3-8203-91182b522da6", "moyenne", "Le favori soin public de la classe.")
    },
    ["Cultist"] = {
        DAMAGE = Pick("Godblade", 2, "GodBlade Dungeon/M+", "https://coabuildhub.com/build/45f7910c-ba9b-4ed6-89ce-a7982bced34f", "moyenne", "Le meilleur repère DPS PvE public ; Corruption attire davantage les retours PvP."),
        TANK = Pick("Dreadnought", 4, "Big Tentacle Boy - Raid", "https://coabuildhub.com/build/54cb9a25-8641-49be-badc-e4ee4aa1ade7", "moyenne", "Le choix tank communautaire le plus soutenu."),
        HEALER = Pick("Heretic", 12, "Cultist Healer M+ Ready", "https://coabuildhub.com/build/5ba4e749-4871-4e36-aeeb-52c0678bc26c", "haute", "Un des builds soin les plus approuvés de toute la liste publique.")
    },
    ["Starcaller"] = {
        DAMAGE = Pick("Warden", 2, "Warden AOE M+", "https://coabuildhub.com/build/9bf37522-d3ec-40bb-9f59-fddc92bb15fd", "moyenne", "Le meilleur signal DPS PvE public de la classe."),
        TANK = Pick("Moon Guard", 3, "Moon Guard - Dungeon Farm", "https://coabuildhub.com/build/34420169-e989-4c4d-8775-d964755620fe", "moyenne", "Le favori tank public pour donjons et farm."),
        HEALER = Pick("Moon Priest", 3, "Moon Priest leveling healer", "https://coabuildhub.com/build/256af7c1-f9e5-47af-9d04-b6d521f51a68", "prudente", "Le parcours soin le mieux documenté, mais pas encore revalidé après le dernier patch.")
    },
    ["Sun Cleric"] = {
        DAMAGE = Pick("Valkyrie", 12, "PvE Valkyrie for Dungeons", "https://coabuildhub.com/build/01175a7b-9331-48b6-98a0-fc2ce22ce560", "haute", "Le favori DPS public très net de la classe."),
        TANK = Pick("Seraphim", 2, "Seraphim M+ build", "https://coabuildhub.com/build/cab6d340-702c-4db6-9cb5-78d749f1eb0d", "moyenne", "Le choix tank naturel, déjà documenté pour Mythique+."),
        HEALER = Pick("Blessings", 2, "Blessings Battle Cleric", "https://coabuildhub.com/build/e8ee75b8-8e51-4d3a-af1b-a47d6c4d13b7", "moyenne", "Le meilleur repère soin public actuel.")
    },
    ["Tinker"] = {
        DAMAGE = Pick("Demolition", 8, "Tinker Demolition PvE", "https://coabuildhub.com/build/367f91fe-9108-4d77-9994-054ff4dd090c", "haute", "Le choix DPS public le plus soutenu, particulièrement en AOE."),
        HEALER = Pick("Invention", 6, "Nanobots, Explosions and Zap!", "https://coabuildhub.com/build/1caf4376-e491-4896-a12e-bcddfb926158", "moyenne", "Le favori soin public, basé sur Nanobots et Beacons.")
    },
    ["Venomancer"] = {
        DAMAGE = Pick("Rotweaver", 3, "ROT BUILD Fungal Assailant", "https://coabuildhub.com/build/dcc2e0ce-fbc3-46f4-8b1d-516105d87d0e", "moyenne", "Le meilleur signal DPS PvE ; Stalking est surtout représenté en PvP."),
        TANK = Pick("Fortitude", 15, "HUGE MDI-Style Pulls Veno Tank", "https://coabuildhub.com/build/c11e12da-fd1d-4449-b16a-41aac69dd37b", "haute", "À égalité au sommet des votes publics : très bon repère tank et leveling."),
        HEALER = Pick("Vizier", 9, "Vizier Healing leveling/dungeons", "https://coabuildhub.com/build/6861f8ca-3e80-44c4-9d10-9969d29710f6", "haute", "Le choix soin public le plus clair de la classe.")
    },
    ["Reaper"] = {
        DAMAGE = Pick("Harvest", 2, "Harvest PvE", "https://coabuildhub.com/build/ec7a42ab-af15-4d17-8b31-8e756a34f215", "moyenne", "Le meilleur repère PvE public ; son score très élevé vient surtout du PvP."),
        TANK = Pick("Domination", 6, "Reaper Tank Dungeons/Raid", "https://coabuildhub.com/build/88596de6-f880-4259-81d5-df050640d357", "haute", "Le tank Reaper le mieux soutenu publiquement.")
    },
    ["Primalist"] = {
        DAMAGE = Pick("Wildwalker", 4, "Wildwalker AoE Dungeon Build", "https://coabuildhub.com/build/06a3a629-dd8e-4c6f-a0e1-6e9e17d63f74", "moyenne", "Le meilleur signal DPS public de la classe."),
        TANK = Pick("Mountain King", 15, "Optimal Build for Raids/M+", "https://coabuildhub.com/build/604248d9-5113-4057-9363-af68741259e8", "haute", "À égalité au sommet des votes et mis à jour après les buffs du 25 août."),
        HEALER = Pick("Grovekeeper", 5, "Grovekeeper General Purpose", "https://coabuildhub.com/build/e4f93380-6b16-429b-abf6-7add7b0fb7b6", "moyenne", "Le favori soin/hybride public de la classe.")
    },
    ["Runemaster"] = {
        DAMAGE = Pick("Riftblade", 6, "THE runeGOD PvE Riftblade", "https://coabuildhub.com/build/9c593168-2745-4972-aa1f-23266e0999f9", "haute", "Le choix DPS PvE le plus soutenu publiquement ; Engravement reste une bonne alternative plus méthodique.")
    }
}

local curated = {
    ["Guardian:Gladiator"] = {
        quality = "Guide PvE verifie pour le patch talents du 19 aout",
        source = "https://coabuildhub.com/build/164da105-e964-4a5f-969c-c990037bd745",
        teaching = {
            identity = "Tu es un combattant de premiere ligne : tu installes ta banniere, tu construis la Glory, puis tu la transformes en gros impacts.",
            resource = "La Glory donne le rythme. Quand elle monte, prepare ton depensier ; quand elle est vide, repars sur Ram et Centurion Strike.",
            opening = "Entre au contact avec Battle Rush, pose Standard of Supremacy, puis installe Glorious Arena. À ce moment-là seulement, tes gros coups ont une vraie scène pour frapper.",
            loop = "Ram et Centurion Strike remettent la machine en route. Quand la Glory est prête, dépense-la ; si Reprisal s'allume, prends-le sans arrêter tout le reste pour l'attendre.",
            goldenRule = "Ne lance pas les gros coups avant d'avoir place la cible et la banniere. Ton burst commence par la preparation.",
            mistake = "Attendre un proc comme Reprisal en ne faisant rien. S'il n'est pas actif, descends simplement dans la priorite."
        },
        maintenance = { "Assault Formation", "Weighted Reinforcement" },
        st = { "Battle Rush", "Standard of Supremacy", "Glorious Arena", "Ram", "Centurion Strike", "Reprisal", "Pulverize" },
        aoe = { "Battle Rush", "Standard of Valiance", "Centurion Strike", "Broad Sweep", "Reprisal" },
        talentPromotions = {
            ["Heroic Effort"] = { "Ram", "Centurion Strike" },
            ["Calculated Strike"] = { "Reprisal", "Broad Sweep" }
        },
        explanations = {
            st = {
                ["Battle Rush"] = { why = "Tu fermes la distance tout de suite : taper dans le vide, ca ne construit aucune pression.", after = "Une fois au contact, pose Standard of Supremacy avant tes gros impacts." },
                ["Standard of Supremacy"] = { why = "La banniere doit etre en place avant la rafale, sinon tes attaques suivantes ne profitent pas de sa fenetre.", after = "Enchaine avec Glorious Arena pour installer proprement ta zone de combat." },
                ["Glorious Arena"] = { why = "Tu poses le terrain avant de depenser tes meilleures frappes ; c'est plus rentable que de l'utiliser apres la rafale.", after = "Passe ensuite a Ram pour construire ta Glory." },
                ["Ram"] = { why = "Ram sert a faire monter la Glory et prepare la partie lourde du cycle.", after = "Centurion Strike convertit cette preparation en vraie pression." },
                ["Centurion Strike"] = { why = "C'est une frappe prioritaire une fois la cible placee et la Glory en route.", after = "Si Reprisal est disponible, prends le proc ; sinon passe directement a Pulverize." },
                ["Reprisal"] = { why = "Reprisal est une priorite conditionnelle : utilise-le quand son declenchement le rend rentable, ne l'attends pas les bras croises.", after = "Pulverize termine la sequence quand tes ressources sont pretes." },
                ["Pulverize"] = { why = "C'est la conversion finale de ta preparation : ne le force pas sans ressource.", after = "Apres ca, repars en haut de la priorite et reprends le premier sort disponible." }
            },
            aoe = {
                ["Battle Rush"] = { why = "Tu rejoins le pack avant de lancer tes outils de zone.", after = "Pose Standard of Valiance pendant que les ennemis sont regroupes." },
                ["Standard of Valiance"] = { why = "La banniere ouvre la fenetre de groupe ; elle vaut davantage avant les frappes de zone qu'apres.", after = "Construis ensuite avec Centurion Strike." },
                ["Centurion Strike"] = { why = "Tu gardes une frappe solide tout en mettant la rotation en mouvement.", after = "Broad Sweep prend le relais des que plusieurs cibles sont bien alignees." },
                ["Broad Sweep"] = { why = "C'est ton vrai bouton de cleave : sur un pack, il passe devant une attaque purement monocible.", after = "Prends Reprisal s'il est actif, puis recommence la priorite." },
                ["Reprisal"] = { why = "Le proc est rentable, mais tu ne bloques jamais la rotation en l'attendant.", after = "Repars sur Battle Rush ou la premiere etape encore disponible." }
            }
        }
    },
    ["Necromancer:Animation"] = {
        quality = "Guides ST/AOE communautaires sans talent directement change au 19 aout",
        source = "https://coabuildhub.com/build/f268b2a3-20e4-49df-bf9e-9c85ff7ae167",
        secondarySource = "https://coabuildhub.com/build/8d9620a1-137b-41dc-8147-6e1a800b2682",
        teaching = {
            identity = "Tu joues un chef d'armee : tes morts-vivants travaillent en continu pendant que tu geres maladies, procs et Runic Power.",
            resource = "Tes generateurs remplissent la Runic Power ; Command: Undead la depense en ST et March of the Dead prend le relais sur les gros packs.",
            opening = "Prépare d'abord l'armée et les maladies, puis lance Unholy Frenzy quand tes invocations sont déjà là pour en profiter. Tu commandes ensuite un groupe installé, pas un champ de bataille vide.",
            loop = "Glacial Tap, Runic Harvest et Crypt Swarm reconstruisent la Runic Power. Command: Undead la dépense en ST ; sur un vrai pack, March of the Dead prend davantage de valeur.",
            goldenRule = "Installe les invocations avant Unholy Frenzy, puis ne laisse jamais la Runic Power deborder.",
            mistake = "Ecraser Blight trop tot. Son dernier tick est important : sur proc, laisse l'effet aller au bout avant de le remettre."
        },
        maintenance = { "Glacial Ward", "Greater Grim Mandate", "Greater Foul Mandate", "Greater Razorice", "Greater Chill of the Tomb" },
        st = { "Harvest Plague", "Call of the Grave", "Animate: Plaguefather", "Animate: Tomb King", "Animate: Frost Wyrm", "Unholy Frenzy", "Command: Undead", "Blight", "Glacial Tap", "Runic Harvest", "Crypt Swarm", "Lichfrost" },
        aoe = { "Call of the Grave", "Animate: Skeletal Archer", "Animate: Bone Wraith", "Animate: Plaguefather", "Animate: Frost Wyrm", "Unholy Frenzy", "March of the Dead", "Glacial Tap", "Runic Harvest", "Crypt Swarm", "Command: Undead" },
        talentPromotions = {
            ["Bone King"] = { "Command: Undead", "Lichfrost" },
            ["Long March"] = { "March of the Dead" }
        },
        explanations = {
            st = {
                ["Harvest Plague"] = { why = "Pose la maladie tot : elle a besoin de temps pour travailler et participe a ton installation.", after = "Call of the Grave lance ensuite la partie invocations de l'ouverture." },
                ["Call of the Grave"] = { why = "Tu demarres l'armee avant les buffs, histoire que les morts-vivants profitent vraiment de la fenetre.", after = "Complete maintenant avec tes invocations apprises." },
                ["Animate: Plaguefather"] = { why = "Tu poses cette invocation pendant l'ouverture pour qu'elle travaille durant toute la rafale.", after = "Continue a installer l'armee avant Unholy Frenzy." },
                ["Animate: Tomb King"] = { why = "Le Tomb King doit etre actif avant de commander l'armee et de chercher les interactions de Bone King.", after = "Ajoute la prochaine invocation disponible, puis buffe l'ensemble." },
                ["Animate: Frost Wyrm"] = { why = "Tu termines l'installation des gros serviteurs avant le buff offensif.", after = "Unholy Frenzy arrive juste apres, quand un maximum d'invocations peut en profiter." },
                ["Unholy Frenzy"] = { why = "Le lancer apres les invocations evite de gaspiller une partie de sa fenetre sans ton armee.", after = "Depense ensuite ta Runic Power avec Command: Undead." },
                ["Command: Undead"] = { why = "C'est ton depensier principal en monocible : utilise-le avec assez de Runic Power, pas a vide.", after = "Un proc gratuit peut ouvrir Blight ; sinon reconstruis ta ressource." },
                ["Blight"] = { why = "Utilise Blight sur son proc et laisse aller la duree au bout : l'ecraser trop tot perd son dernier gros tick.", after = "Si Blight est deja actif et que Bone King te donne un proc, Lichfrost devient une bonne sortie." },
                ["Glacial Tap"] = { why = "C'est un generateur : tu y reviens quand Command: Undead t'a vide, pas quand ta Runic Power deborde.", after = "Complete avec Runic Harvest ou Crypt Swarm selon ce qui est disponible." },
                ["Runic Harvest"] = { why = "Tu reconstruis la Runic Power pour alimenter le prochain Command: Undead.", after = "Crypt Swarm peut finir le remplissage sans depasser le maximum." },
                ["Crypt Swarm"] = { why = "C'est le remplissage efficace quand il te manque encore de la Runic Power.", after = "Des que la ressource suffit, remonte sur Command: Undead." },
                ["Lichfrost"] = { why = "Garde-le pour un proc gratuit avec Blight deja present ; sinon Command: Undead reste la depense prioritaire.", after = "Apres la depense, retourne aux generateurs puis relis la priorite depuis le haut." }
            },
            aoe = {
                ["Call of the Grave"] = { why = "Installe ton armee avant d'engager le vrai cycle de zone.", after = "Ajoute tes invocations apprises avant Unholy Frenzy." },
                ["Animate: Skeletal Archer"] = { why = "L'archer travaille pendant tout le pack, donc tu le poses tot et tu le relances a son retour.", after = "Continue l'installation des serviteurs." },
                ["Animate: Bone Wraith"] = { why = "Tu veux ses degats actifs pendant toute la duree du pack, pas sur les deux dernieres secondes.", after = "Complete l'armee avant de la renforcer." },
                ["Unholy Frenzy"] = { why = "Le buff arrive apres les invocations pour que toute l'armee profite de la meme fenetre.", after = "Sur trois cibles ou plus, prepare March of the Dead." },
                ["March of the Dead"] = { why = "C'est ta grosse depense de zone : utilise-la sur un pack stable et vise bien, car elle avance et peut attirer d'autres ennemis.", after = "Pendant son indisponibilite, reconstruis puis utilise Command: Undead." },
                ["Glacial Tap"] = { why = "Tu reconstruis rapidement la Runic Power necessaire a March of the Dead et Command: Undead.", after = "Runic Harvest puis Crypt Swarm completent la generation sans surcharger la barre." },
                ["Runic Harvest"] = { why = "Il remet du carburant entre deux depenses de zone.", after = "Passe a Crypt Swarm si la Runic Power n'est pas encore suffisante." },
                ["Crypt Swarm"] = { why = "Le sort remplit la ressource tout en restant adapte a plusieurs cibles.", after = "Depense ensuite avec March of the Dead, ou Command: Undead pendant son cooldown." },
                ["Command: Undead"] = { why = "C'est ton depensier de secours pendant le cooldown de March of the Dead.", after = "Repars ensuite sur tes generateurs et garde les maladies actives." }
            }
        }
    },
    ["Cultist:Heretic"] = {
        quality = "Guide M+ recoupe avec les retours de joueurs et le spellbook actif",
        source = "https://coabuildhub.com/build/5ba4e749-4871-4e36-aeeb-52c0678bc26c",
        teaching = {
            identity = "Tu es un soigneur de melee : tu poses ton lien, tu frappes pour produire de la valeur de soin, puis tu reagis aux urgences sans casser tout ton rythme.",
            resource = "La Sanity et le mana doivent rester stables. Hammer of Twilight sert le ST ; Entropic Slam devient interessant sur trois cibles ou plus.",
            opening = "Pose Malevolence, entre au contact avec Blade of the Empire, puis choisis Hammer of Twilight en ST ou Entropic Slam sur un pack. Tes soins directs restent disponibles, mais ils ne remplacent cette boucle que lorsqu'une barre de vie le réclame vraiment.",
            loop = "Tant que le groupe tient, continue ta pression de mêlée et surveille la Sanity. Si quelqu'un chute, soigne-le, puis reviens simplement à Malevolence et à ta première attaque disponible.",
            goldenRule = "Malevolence vient avant les degats. Les soins directs, eux, ne font pas partie d'une boucle fixe : tu les utilises seulement quand quelqu'un en a besoin.",
            mistake = "Lancer Eldritch Mending ou un defensif juste parce qu'il est disponible. En l'absence de danger, continue ta pression melee."
        },
        situational = { "Eldritch Mending", "Void Shield" },
        maintenance = { "Presence of C'Thun", "Presence of N'Zoth", "Presence of Y'Shaarj", "Whispers of N'Zoth", "Whispers of C'Thun", "Malevolence" },
        st = { "Malevolence", "Blade of the Empire", "Hammer of Twilight", "Herald of the Depths", "Gaze of C'Thun", "Sanity Tap", "Eldritch Mending" },
        aoe = { "Malevolence", "Blade of the Empire", "Entropic Slam", "Herald of the Depths", "Forbidden Ritual", "Void Shield", "Gaze of C'Thun", "Sanity Tap" },
        talentPromotions = {
            ["Abyssal Covenant"] = { "Blade of the Empire", "Dark Prophet" },
            ["Dark Chants"] = { "Malevolence", "Forbidden Ritual" },
            ["Eldritch Eye"] = { "Eldritch Mending" }
        },
        explanations = {
            st = {
                ["Malevolence"] = { why = "Tu poses Malevolence avant de frapper : tes degats suivants doivent arriver pendant que le lien utile au soin est en place.", after = "Entre ensuite au contact avec Blade of the Empire." },
                ["Blade of the Empire"] = { why = "C'est ta base melee et elle lance la partie offensive du cycle une fois Malevolence active.", after = "Sur une seule cible, Hammer of Twilight devient la depense prioritaire." },
                ["Hammer of Twilight"] = { why = "En monocible, cette depense concentre mieux ta ressource qu'un outil de zone.", after = "Place Herald of the Depths pendant que la cible reste stable." },
                ["Herald of the Depths"] = { why = "Tu l'utilises dans la fenetre installee, pas avant Malevolence et ta premiere frappe.", after = "Gaze of C'Thun maintient ensuite la pression a distance si necessaire." },
                ["Gaze of C'Thun"] = { why = "C'est une continuation offensive quand les priorites melee ne sont pas disponibles.", after = "Sanity Tap sert ensuite a remettre la ressource en ordre." },
                ["Sanity Tap"] = { why = "Tu corriges ta ressource apres les depenses ; ne le presse pas machinalement si tout va bien.", after = "Eldritch Mending reste un soin reactif, puis tu repars sur Malevolence." },
                ["Eldritch Mending"] = { why = "C'est une securite de soin, pas un bouton a glisser automatiquement dans chaque cycle offensif.", after = "Une fois le danger passe, relis la priorite depuis Malevolence." }
            },
            aoe = {
                ["Malevolence"] = { why = "Pose le lien avant de distribuer les degats sur le pack.", after = "Blade of the Empire demarre ensuite la pression au contact." },
                ["Blade of the Empire"] = { why = "Tu installes d'abord ta base melee et tes interactions de talent.", after = "Avec trois cibles ou plus, Entropic Slam passe devant Hammer of Twilight." },
                ["Entropic Slam"] = { why = "Sa valeur monte avec le nombre d'ennemis : sur un vrai pack, c'est la depense logique.", after = "Herald of the Depths prolonge ensuite la fenetre de zone." },
                ["Herald of the Depths"] = { why = "Tu le places quand le pack est deja regroupe et marque, pour ne pas gaspiller son effet.", after = "Forbidden Ritual prend de la valeur si les ennemis restent dans la zone." },
                ["Forbidden Ritual"] = { why = "Le rituel demande des cibles stables : lance-le apres le regroupement, pas pendant que tout bouge.", after = "Void Shield couvre le risque avant de poursuivre les degats." },
                ["Void Shield"] = { why = "Tu securises la phase dangereuse sans casser completement ta pression.", after = "Reviens ensuite a Gaze of C'Thun ou a la premiere priorite disponible." }
            }
        }
    },
    ["Sun Cleric:Valkyrie"] = {
        quality = "Guide M+ verifie pour le patch talents du 19 aout",
        source = "https://coabuildhub.com/build/01175a7b-9331-48b6-98a0-fc2ce22ce560",
        teaching = {
            identity = "Tu es un DPS melee a fenetres : tu construis la Solar Power, tu actives Dawn, puis tu concentres tes meilleurs cooldowns avant de reconstruire.",
            resource = "Monte a 20 Solar Power pour Dawn. Vers 7 a 10 stacks restants, Radiant Conversion puis Solar Invocation: Conquest relancent la boucle.",
            opening = "Monte à 20 Solar Power, ouvre Dawn, puis empile Paragon, Dawnfall, Champion of the Sun et Radiance avant les gros impacts. Toute la spécialisation tourne autour de cette fenêtre.",
            loop = "Dépense les stacks de Dawn sans aller jusqu'à l'épuisement. Vers 7 à 10 stacks, Radiant Conversion et Solar Invocation: Conquest reconstruisent la ressource pour repartir sur une nouvelle Dawn.",
            goldenRule = "Dawn reste prioritaire. Un gros sort lance hors de cette fenetre perd une bonne partie de sa valeur.",
            mistake = "Vider tous les stacks de Dawn avec Sunslam sans garder de quoi convertir et reconstruire la Solar Power."
        },
        maintenance = { "Solar Invocation: Conquest", "Vow of Dawn", "Vow of the Valkyr" },
        st = { "Dawn", "Paragon", "Dawnfall", "Champion of the Sun", "Radiance", "Divine Retribution", "Sunslam", "Glorious Execution", "Horusath Blast", "Gavel of Grace", "Justice", "Radiant Conversion", "Solar Invocation: Conquest" },
        aoe = { "Dawn", "Paragon", "Dawnfall", "Champion of the Sun", "Radiance", "Divine Retribution", "Judgement Day", "Sunslam", "Glorious Execution", "Valkyr's Calling", "Horusath Blast", "Justice", "Gavel of Grace", "Radiant Conversion", "Solar Invocation: Conquest" },
        talentPromotions = {
            ["Blessed Hammer"] = { "Sunslam", "Glorious Execution" },
            ["Herald of Purity"] = { "Champion of the Sun", "Radiance" }
        },
        explanations = {
            st = {
                ["Dawn"] = { why = "Dawn est le coeur du cycle : tu l'actives avec ta Solar Power pleine pour ouvrir les stacks a depenser.", after = "Paragon et Dawnfall arrivent pendant cette fenetre, pas avant." },
                ["Paragon"] = { why = "C'est un long cooldown de rafale ; le lancer apres Dawn aligne sa puissance avec la vraie fenetre offensive.", after = "Dawnfall prolonge immediatement ce debut de burst." },
                ["Dawnfall"] = { why = "Tu l'empiles avec les autres cooldowns majeurs pour obtenir une seule grosse fenetre plutot que plusieurs petites.", after = "Champion of the Sun et Radiance renforcent maintenant la suite." },
                ["Champion of the Sun"] = { why = "Tu l'actives avant les gros boutons de degats afin qu'ils profitent de son bonus.", after = "Radiance termine l'installation de la rafale." },
                ["Radiance"] = { why = "Elle doit couvrir Sunslam, Horusath Blast et Glorious Execution, donc elle vient juste avant eux.", after = "Divine Retribution puis Sunslam lancent les vrais degats." },
                ["Divine Retribution"] = { why = "Tu la places dans la fenetre complete, quand Dawn et tes cooldowns sont deja actifs.", after = "Sunslam devient ensuite la priorite de degats." },
                ["Sunslam"] = { why = "C'est une de tes plus grosses attaques, mais elle consomme plusieurs stacks de Dawn : garde assez de marge avant de la lancer.", after = "Horusath Blast puis Glorious Execution prennent le relais." },
                ["Horusath Blast"] = { why = "C'est ton plus gros bouton regulier : des qu'il est disponible dans la fenetre, il passe en tete.", after = "Glorious Execution remplit le prochain temps fort." },
                ["Glorious Execution"] = { why = "Elle suit Horusath Blast et profite de ses resets ou de ses talents sans retarder ton plus gros sort.", after = "Gavel of Grace puis Justice servent de remplissage." },
                ["Radiant Conversion"] = { why = "Vers 7 a 10 stacks de Dawn, tu rends les stacks restants en Solar Power au lieu de tomber completement a sec.", after = "Solar Invocation: Conquest te rapproche immediatement des 20 points necessaires au prochain Dawn." },
                ["Solar Invocation: Conquest"] = { why = "Elle reconstruit rapidement 10 Solar Power apres la conversion.", after = "Complete la ressource avec tes generateurs, puis reactive Dawn." }
            },
            aoe = {
                ["Dawn"] = { why = "Avec Vow of Dawn, cette fenetre transforme ta Solar Power en vraie pression de zone.", after = "Empile Paragon, Dawnfall, Champion et Radiance avant les gros impacts." },
                ["Paragon"] = { why = "Tu regroupes les longs cooldowns dans la meme fenetre pour que le pack prenne tout en meme temps.", after = "Dawnfall continue l'installation du burst." },
                ["Dawnfall"] = { why = "Elle vient avant les attaques de zone pour renforcer la phase qui suit.", after = "Champion of the Sun et Radiance terminent la preparation." },
                ["Champion of the Sun"] = { why = "Active-le avant Divine Retribution, Judgement Day et Sunslam.", after = "Radiance couvre ensuite toute la rafale." },
                ["Radiance"] = { why = "Elle augmente la valeur de la suite tant que les ennemis restent regroupes.", after = "Divine Retribution puis Judgement Day commencent les degats de zone." },
                ["Divine Retribution"] = { why = "Le talent est particulierement rentable en cleave et AOE, donc il passe dans la fenetre complete.", after = "Judgement Day touche le pack avant Sunslam." },
                ["Judgement Day"] = { why = "C'est un vrai bouton de zone : sur une seule cible, saute-le ; sur un pack, utilise-le avant le remplissage.", after = "Sunslam reste ensuite une priorite majeure." },
                ["Sunslam"] = { why = "Les gros degats valent le cout, mais surveille tes stacks de Dawn pour ne pas casser la boucle.", after = "Horusath Blast et Justice prennent la suite selon le nombre de cibles." },
                ["Valkyr's Calling"] = { why = "Sa valeur augmente avec le pack ; ne retarde toutefois pas Horusath Blast pour l'attendre.", after = "Horusath Blast reste la priorite reguliere la plus forte." },
                ["Radiant Conversion"] = { why = "Convertis autour de 7 a 10 stacks restants pour ne pas tomber a zero Solar Power.", after = "Solar Invocation: Conquest relance immediatement la reconstruction." },
                ["Solar Invocation: Conquest"] = { why = "Elle remet 10 Solar Power et raccourcit le trou entre deux Dawn.", after = "Complete jusqu'a 20, reactive Dawn et repars en haut." }
            }
        }
    },
    ["Runemaster:Engravement"] = {
        quality = "Guide PvE Runemaster actualise et recoupe avec le spellbook",
        source = "https://coabuildhub.com/build/dca788b3-5300-440f-92e9-f0f6d118956a",
        secondarySource = "https://coatavern.com/class/32",
        teaching = {
            identity = "Tu graves tes armes puis tu fais exploser les marques de Runic Brand avec Runeblade. La specialisation est simple a lire, mais elle punit vite une marque posee puis oubliee.",
            resource = "Runic Brand pose les marques ; Runeblade les fait partir. Primordial Blast remet des charges de Runeblade et relance donc la boucle au lieu d'etre un sort jete au hasard.",
            opening = "Choisis tes gravures avant le combat. Sur une cible, lance Primordial Blast tot, pose Runic Brand, puis fais partir la marque avec Runeblade. Garde Zenith pour une cible qui vivra assez longtemps.",
            loop = "Repose Runic Brand des que tu peux l'exploiter, consomme avec Runeblade et utilise Primordial Blast des qu'il est rentable pour recuperer des charges. Fist of the Ancients bouche les vrais temps morts.",
            goldenRule = "Une marque sans Runeblade derriere ne rapporte rien. Pense en duo : je marque, puis je declenche.",
            mistake = "Marteler Fist of the Ancients alors qu'une marque ou Primordial Blast est disponible. C'est un remplissage, pas le coeur du build."
        },
        maintenance = { "Runic Tattoos: Water", "Weapon Engraving: Frost", "Weapon Engraving: Fire", "Weapon Engraving: Earth" },
        st = { "Zenith", "Primordial Blast", "Runic Brand", "Runeblade", "Fist of the Ancients" },
        aoe = { "Zenith", "Runic Brand", "Runeblade", "Primordial Blast", "Fist of the Ancients" },
        situational = { "Ley Lock", "Guarding Rune", "Warpdagger" },
        talentPromotions = {
            ["Runelord"] = { "Zenith", "Runic Brand" },
            ["Fists of Power"] = { "Fist of the Ancients" }
        },
        explanations = {
            st = {
                ["Zenith"] = { why = "C'est ta vraie fenetre de puissance. Utilise-la sur une cible solide, pas sur un ennemi qui va tomber avant la fin.", after = "Primordial Blast lance la boucle et commence a remettre Runeblade en place." },
                ["Primordial Blast"] = { why = "Il frappe fort en monocible et redonne une charge de Runeblade : tu gagnes a la fois maintenant et pour la marque suivante.", after = "Pose Runic Brand, puisque tu as justement de quoi la faire exploser." },
                ["Runic Brand"] = { why = "La marque prepare le vrai impact. Elle passe devant le remplissage tant que Runeblade pourra la consommer.", after = "Declenche-la avec Runeblade sans laisser la cible mourir avec la marque." },
                ["Runeblade"] = { why = "C'est le detonateur de Runic Brand et ton filler principal. Ses charges ont plus de valeur quand elles font partir une marque.", after = "Reviens a Primordial Blast ou Runic Brand ; Fist ne sert que si les deux attendent." },
                ["Fist of the Ancients"] = { why = "Il entretient les chances de gravure pendant un trou, mais ses degats seuls ne justifient pas de retarder le duo marque/detonation.", after = "Des que Primordial Blast ou Runic Brand revient, remonte immediatement dans la priorite." }
            },
            aoe = {
                ["Zenith"] = { why = "Sur un pack durable, Zenith renforce toute la serie de marques et d'explosions.", after = "Marque une cible prioritaire avec Runic Brand." },
                ["Runic Brand"] = { why = "La marque explose autour de la cible : choisis celle qui restera au milieu du pack.", after = "Runeblade fait partir la marque et transforme le monocible en cleave." },
                ["Runeblade"] = { why = "Il declenche les marques et leurs explosions. Ne change pas de cible juste avant de les faire partir.", after = "Primordial Blast rend des charges pour recommencer." },
                ["Primordial Blast"] = { why = "La remise de charge garde la chaine de Runeblade active quand le pack dure.", after = "Repose une marque ; utilise Fist uniquement pendant le prochain creux." },
                ["Fist of the Ancients"] = { why = "C'est ton remplissage quand marques, charges et Primordial Blast ne sont pas disponibles.", after = "Repars en haut des qu'un element central revient." }
            }
        }
    },
    ["Runemaster:Glyphic"] = {
        quality = "Guide Glyphic recoupe : donnees de sorts, retours PvE et changements officiels",
        source = "https://coabuildhub.com/builds/runemaster",
        secondarySource = "https://conquestofazeroth.online/fr/builds/conquest-of-azeroth-glyphic-guide",
        teaching = {
            identity = "Tu fabriques une suite de glyphes elementaires, puis tu la consommes. Ce n'est pas une liste de cooldowns : c'est une petite phrase qu'il faut terminer avant d'en recommencer une.",
            resource = "Elemental Burst et Primordial Blast generent les glyphes. En ST, deux glyphes suffisent souvent ; sur un vrai pack, attends le troisieme pour profiter de la partie Arcane en zone.",
            opening = "Sur un pull important, ouvre avec Zenith puis Primordial Pulse. Genere ensuite tes glyphes avec Elemental Burst et Primordial Blast, consomme-les avec Glyphic Ruin ou Thaumaturgy, puis marque une tres courte pause avant de regagner un glyphe.",
            loop = "Genere, consomme, laisse le serveur enregistrer la consommation, puis recommence. En AOE, Primordial Pulse reste ton point de repere et Primordial Blast aide a le recuperer plus vite.",
            goldenRule = "Ne relance pas un generateur dans la meme fraction de seconde que la consommation : une courte respiration evite de perdre un glyphe cote serveur.",
            mistake = "Depenser un seul glyphe sur un pack ou attendre le troisieme sur une cible qui va mourir. Le bon nombre depend du combat."
        },
        maintenance = { "Runic Tattoos: Water", "Weapon Engraving: Arcane", "Weapon Engraving: Frost", "Weapon Engraving: Earth" },
        st = { "Zenith", "Elemental Burst", "Primordial Blast", "Glyphic Ruin", "Thaumaturgy", "Primordial Pulse", "Runic Obliteration" },
        aoe = { "Zenith", "Primordial Pulse", "Elemental Burst", "Primordial Blast", "Glyphic Ruin", "Thaumaturgy", "Runic Obliteration" },
        situational = { "Ley Lock", "Glacial Rune", "Warpdagger", "Phase Out" },
        talentPromotions = {
            ["Archmage"] = { "Glyphic Ruin" },
            ["Runestone Apprentice"] = { "Elemental Burst", "Primordial Blast" },
            ["Glyph Master"] = { "Glyphic Ruin", "Thaumaturgy" }
        },
        explanations = {
            st = {
                ["Zenith"] = { why = "Utilise la fenetre sur un elite ou un boss ; sur une petite cible, garde-la pour le prochain combat.", after = "Commence a fabriquer tes glyphes avec Elemental Burst." },
                ["Elemental Burst"] = { why = "C'est ton generateur stable et ton filler de degats. Il construit la sequence au lieu de simplement remplir un temps mort.", after = "Primordial Blast ajoute le glyphe suivant et accelere tes outils majeurs." },
                ["Primordial Blast"] = { why = "Il fait avancer les glyphes tout en participant aux reductions de cooldown importantes du build.", after = "Avec deux glyphes en ST, consomme avec Glyphic Ruin ou Thaumaturgy." },
                ["Glyphic Ruin"] = { why = "C'est la depense lourde de la sequence. En monocible, ne retarde pas tout le cycle juste pour chercher un troisieme glyphe peu rentable.", after = "Respire un instant, puis repars sur Elemental Burst." },
                ["Thaumaturgy"] = { why = "C'est l'option de consommation plus rapide quand elle est disponible et que tes glyphes sont prets.", after = "Laisse la consommation etre enregistree avant le prochain generateur." },
                ["Primordial Pulse"] = { why = "Sur une cible durable il vaut son cooldown, mais il passe derriere une consommation de glyphes deja prete.", after = "Reprends ta boucle de generation." },
                ["Runic Obliteration"] = { why = "Garde ce reset pour une vraie fenetre : depense d'abord les glyphes presents et Primordial Pulse s'il est pret.", after = "Tu repars ensuite avec des outils frais, pas avec des charges gaspillees." }
            },
            aoe = {
                ["Zenith"] = { why = "Le pack doit vivre assez longtemps pour rembourser la fenetre de burst.", after = "Primordial Pulse demarre le cooldown cle au plus tot." },
                ["Primordial Pulse"] = { why = "C'est le moteur AOE : le lancer tot permet aussi de commencer tout de suite a reduire son prochain cooldown.", after = "Fabrique trois glyphes avec tes generateurs." },
                ["Elemental Burst"] = { why = "Il construit la sequence et garde les degats concentres sur la cible prioritaire.", after = "Primordial Blast poursuit la chaine et aide a recuperer Pulse." },
                ["Primordial Blast"] = { why = "Il genere un glyphe et rapproche Primordial Pulse. Sur un pack, cette double utilite le rend central.", after = "A trois glyphes, consomme avec Glyphic Ruin ou Thaumaturgy." },
                ["Glyphic Ruin"] = { why = "Trois glyphes donnent la vraie valeur de zone. Choisis une cible au milieu du pack avant de consommer.", after = "Attends un battement, puis reconstruis les glyphes." },
                ["Thaumaturgy"] = { why = "Elle consomme rapidement la sequence complete quand Glyphic Ruin n'est pas le meilleur choix disponible.", after = "Ne colle pas Primordial Blast instantanement derriere : laisse le serveur valider." },
                ["Runic Obliteration"] = { why = "Depense les glyphes et Pulse avant le reset, sinon tu effaces toi-meme une partie de sa valeur.", after = "Relance Pulse et reconstruis une sequence complete." }
            }
        }
    },
    ["Runemaster:Riftblade"] = {
        quality = "Parcours Riftblade PvE recoupe avec la base de sorts Runemaster",
        source = "https://ascensionsidekick.com/runemaster/riftblade",
        secondarySource = "https://coabuildhub.com/builds/runemaster",
        teaching = {
            identity = "Tu es un melee elementaire : Primordial Blast et tes frappes remettent des charges de Runeblade, puis Runeblade sert de fil rouge entre les cooldowns.",
            resource = "Le mana part vite. Le troisieme Runeblade rend des ressources avec les bons talents ; garde donc la cadence au lieu de vider tous les sorts chers en meme temps.",
            opening = "Ferme la distance avec Primordial Blast, pose Genesis assez tot sur une cible solide, puis alterne tes frappes elementaires et Runeblade. Zenith accompagne une vraie cible de burst.",
            loop = "Smolder, Fracture et Hoarfrost passent quand ils sont utiles ; Runeblade remplit et profite de ses remises de charge. Hurricane demande une fenetre ou tu peux rester en place.",
            goldenRule = "Runeblade n'est pas un bouton de secours : il relie toute la rotation et son troisieme passage aide ton mana.",
            mistake = "Tout lancer des que ca s'allume et finir sans mana. Garde une cadence et reserve les outils de zone aux packs qui resteront groupes."
        },
        maintenance = { "Runic Tattoos: Water", "Weapon Engraving: Fire", "Weapon Engraving: Frost" },
        st = { "Zenith", "Genesis", "Primordial Blast", "Smolder", "Fracture", "Hoarfrost", "Hurricane", "Runeblade" },
        aoe = { "Zenith", "Turbulence", "Primordial Blast", "Hoarfrost", "Hurricane", "Smolder", "Runeblade" },
        situational = { "Ley Lock", "Magebreaker", "Granite Resolve", "Warpdagger" },
        talentPromotions = {
            ["Riftblade"] = { "Primordial Blast", "Smolder", "Runeblade" },
            ["Runic Omen"] = { "Runeblade" },
            ["Surging Slash"] = { "Runeblade" }
        },
        explanations = {
            st = {
                ["Zenith"] = { why = "C'est ton burst : aligne-le avec une cible qui ne mourra pas pendant l'installation.", after = "Pose Genesis tot si la cible est assez solide." },
                ["Genesis"] = { why = "La marque accumule une partie de tes degats avant d'exploser ; plus tu la poses tot sur un elite, plus elle travaille.", after = "Primordial Blast lance ensuite la cadence de frappes." },
                ["Primordial Blast"] = { why = "Il frappe immediatement et remet une charge de Runeblade, donc il alimente directement le coeur melee.", after = "Passe sur Smolder puis tes autres frappes elementaires." },
                ["Smolder"] = { why = "Cette frappe de Feu remet elle aussi Runeblade en mouvement avec Riftblade.", after = "Fracture et Hoarfrost prennent la suite selon la cible." },
                ["Fracture"] = { why = "La frappe de Givre apporte ses degats et sa pression sur le mana quand la cible en possede.", after = "Hoarfrost ou Hurricane continuent si leurs conditions sont bonnes." },
                ["Hoarfrost"] = { why = "Le cone vaut surtout si tu peux garder la cible dans son axe ; ne tourne pas le dos au placement pour le forcer.", after = "Hurricane est fort seulement si tu peux terminer la canalisation." },
                ["Hurricane"] = { why = "La canalisation et sa fenetre de hate/crit valent un vrai temps d'arret, pas un combat ou tu dois bouger tout de suite.", after = "Runeblade remplit ensuite jusqu'au retour des frappes." },
                ["Runeblade"] = { why = "C'est ton filler central, recharge par Primordial Blast et Smolder ; le troisieme passage aide aussi a tenir le mana.", after = "Repars au premier cooldown elementaire disponible." }
            },
            aoe = {
                ["Zenith"] = { why = "Utilise-le quand le pack est stabilise et suffisamment durable.", after = "Turbulence pose ta vraie zone de travail." },
                ["Turbulence"] = { why = "La zone gagne sa valeur si les ennemis restent dedans ; attends que le tank ait fini de les deplacer.", after = "Primordial Blast puis Hoarfrost gardent une cible prioritaire sous pression." },
                ["Primordial Blast"] = { why = "Il conserve le focus principal tout en rechargeant Runeblade.", after = "Aligne Hoarfrost dans le pack." },
                ["Hoarfrost"] = { why = "Son cone et son effet persistant en font un vrai outil de cleave si le pack est bien tourne.", after = "Hurricane suit quand tu peux canaliser sans bouger." },
                ["Hurricane"] = { why = "Les frappes multiples prennent de la valeur en zone, mais uniquement si la canalisation peut aller au bout.", after = "Smolder et Runeblade entretiennent ensuite la cadence." },
                ["Runeblade"] = { why = "Il remplit les creux, profite des charges rendues et evite de laisser mourir ton cycle de mana.", after = "Remonte vers Turbulence ou la premiere frappe revenue." }
            }
        }
    }
}

CoARotationGuideData = {
    schema = 4,
    sourceDate = "2026-08-26",
    talentPatch = "2026-08-25",
    officialPatchThrough = "2026-08-25",
    sources = {
        {
            name = "Ascension - changelog officiel Conquest of Azeroth",
            url = "https://ascension.gg/en/changelog/4",
            kind = "OFFICIEL"
        },
        {
            name = "CoA Build Hub - builds, rotations et votes communautaires",
            url = "https://coabuildhub.com/",
            kind = "COMMUNAUTE"
        },
        {
            name = "srhinos/coa-datamine - arbres et talents publics",
            url = "https://github.com/srhinos/coa-datamine/tree/master/data/talents/coa",
            kind = "DONNEES"
        },
        {
            name = "Spellbook et talents actifs du personnage",
            url = "local://player",
            kind = "JEU"
        }
    },
    aliases = {
        ["Barbarian:Tactics"] = "Barbarian:Headhunting",
        ["Felsworn:Felblood"] = "Felsworn:Infernal",
        ["Felsworn:Slaying"] = "Felsworn:Slayer",
        ["Felsworn:Demonology"] = "Felsworn:Tyrant",
        ["Witch Hunter:Darkness"] = "Witch Hunter:Houndmaster",
        ["Guardian:Protection"] = "Guardian:Vanguard",
        ["Templar:Discipline"] = "Templar:Oathkeeper",
        ["Templar:Fighting"] = "Templar:Zealot",
        ["Templar:Runes"] = "Templar:Crusader",
        ["Bloodmage:Blood"] = "Bloodmage:Sanguine",
        ["Bloodmage:Ferocity"] = "Bloodmage:Accursed",
        ["Bloodmage:Packleader"] = "Bloodmage:Eternal",
        ["Ranger:Dueling"] = "Ranger:Farstrider",
        ["Ranger:Survival"] = "Ranger:Brigand",
        ["Chronomancer:Duality"] = "Chronomancer:Infinite",
        ["Chronomancer:Displacement"] = "Chronomancer:Artificer",
        ["Pyromancer:Destruction"] = "Pyromancer:Flameweaving",
        ["Starcaller:Tides"] = "Starcaller:Moon Priest",
        ["Starcaller:Moonbow"] = "Starcaller:Sentinel",
        ["Starcaller:Astral Warfare"] = "Starcaller:Moon Guard",
        ["Tinker:Firearms"] = "Tinker:Demolition",
        ["Venomancer:Venom"] = "Venomancer:Rotweaver",
        ["Reaper:Reaping"] = "Reaper:Harvest",
        ["Primalist:Life"] = "Primalist:Grovekeeper",
        ["Primalist:Primal"] = "Primalist:Wildwalker",
        ["Runemaster:Runic"] = "Runemaster:Engravement",
        ["Runemaster:Arcane"] = "Runemaster:Glyphic"
    },
    profiles = profiles,
    curated = curated,
    meta = meta
}
