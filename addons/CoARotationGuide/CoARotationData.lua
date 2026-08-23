-- Banque hors ligne du Guide de Rotation CoA.
-- Les descriptions de specialisations viennent de CoA Build Hub et sont
-- recoupees avec les pages/changelogs officiels Ascension. Capture 2026-08-23,
-- donnees de talents du patch communautaire 2026-08-19.
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

local curated = {
    ["Guardian:Gladiator"] = {
        quality = "Guide PvE verifie pour le patch talents du 19 aout",
        source = "https://coabuildhub.com/build/164da105-e964-4a5f-969c-c990037bd745",
        maintenance = { "Assault Formation", "Weighted Reinforcement" },
        st = { "Battle Rush", "Standard of Supremacy", "Glorious Arena", "Ram", "Centurion Strike", "Reprisal", "Pulverize" },
        aoe = { "Battle Rush", "Standard of Valiance", "Centurion Strike", "Broad Sweep", "Reprisal" },
        talentPromotions = {
            ["Heroic Effort"] = { "Ram", "Centurion Strike" },
            ["Calculated Strike"] = { "Reprisal", "Broad Sweep" }
        }
    },
    ["Necromancer:Animation"] = {
        quality = "Guides ST/AOE communautaires sans talent directement change au 19 aout",
        source = "https://coabuildhub.com/build/f268b2a3-20e4-49df-bf9e-9c85ff7ae167",
        secondarySource = "https://coabuildhub.com/build/8d9620a1-137b-41dc-8147-6e1a800b2682",
        maintenance = { "Glacial Ward", "Greater Grim Mandate", "Greater Foul Mandate", "Greater Razorice", "Greater Chill of the Tomb" },
        st = { "Harvest Plague", "Call of the Grave", "Animate: Plaguefather", "Animate: Tomb King", "Animate: Frost Wyrm", "Unholy Frenzy", "Command: Undead", "Blight", "Glacial Tap", "Runic Harvest", "Crypt Swarm", "Lichfrost" },
        aoe = { "Call of the Grave", "Animate: Skeletal Archer", "Animate: Bone Wraith", "Animate: Plaguefather", "Animate: Frost Wyrm", "Unholy Frenzy", "March of the Dead", "Glacial Tap", "Runic Harvest", "Crypt Swarm", "Command: Undead" },
        talentPromotions = {
            ["Bone King"] = { "Command: Undead", "Lichfrost" },
            ["Long March"] = { "March of the Dead" }
        }
    },
    ["Cultist:Heretic"] = {
        quality = "Guide M+ recoupe avec les retours de joueurs et le spellbook actif",
        source = "https://coabuildhub.com/build/5ba4e749-4871-4e36-aeeb-52c0678bc26c",
        maintenance = { "Presence of C'Thun", "Presence of N'Zoth", "Presence of Y'Shaarj", "Whispers of N'Zoth", "Whispers of C'Thun", "Malevolence" },
        st = { "Malevolence", "Blade of the Empire", "Hammer of Twilight", "Herald of the Depths", "Gaze of C'Thun", "Sanity Tap", "Eldritch Mending" },
        aoe = { "Malevolence", "Blade of the Empire", "Entropic Slam", "Herald of the Depths", "Forbidden Ritual", "Void Shield", "Gaze of C'Thun", "Sanity Tap" },
        talentPromotions = {
            ["Abyssal Covenant"] = { "Blade of the Empire", "Dark Prophet" },
            ["Dark Chants"] = { "Malevolence", "Forbidden Ritual" },
            ["Eldritch Eye"] = { "Eldritch Mending" }
        }
    },
    ["Sun Cleric:Valkyrie"] = {
        quality = "Guide M+ verifie pour le patch talents du 19 aout",
        source = "https://coabuildhub.com/build/01175a7b-9331-48b6-98a0-fc2ce22ce560",
        maintenance = { "Solar Invocation: Conquest", "Vow of Dawn", "Vow of the Valkyr" },
        st = { "Dawn", "Paragon", "Dawnfall", "Champion of the Sun", "Radiance", "Divine Retribution", "Sunslam", "Glorious Execution", "Horusath Blast", "Gavel of Grace", "Justice", "Radiant Conversion", "Solar Invocation: Conquest" },
        aoe = { "Dawn", "Paragon", "Dawnfall", "Champion of the Sun", "Radiance", "Divine Retribution", "Judgement Day", "Sunslam", "Glorious Execution", "Valkyr's Calling", "Horusath Blast", "Justice", "Gavel of Grace", "Radiant Conversion", "Solar Invocation: Conquest" },
        talentPromotions = {
            ["Blessed Hammer"] = { "Sunslam", "Glorious Execution" },
            ["Herald of Purity"] = { "Champion of the Sun", "Radiance" }
        }
    }
}

CoARotationGuideData = {
    schema = 1,
    sourceDate = "2026-08-23",
    talentPatch = "2026-08-19",
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
    curated = curated
}

