-- Banque hors ligne du Guide de Rotation CoA.
-- Les descriptions de specialisations viennent de CoA Build Hub et sont
-- recoupees avec les pages/changelogs officiels Ascension. Capture 2026-08-24,
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
        teaching = {
            identity = "Tu es un combattant de premiere ligne : tu installes ta banniere, tu construis la Glory, puis tu la transformes en gros impacts.",
            resource = "La Glory donne le rythme. Quand elle monte, prepare ton depensier ; quand elle est vide, repars sur Ram et Centurion Strike.",
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
    }
}

CoARotationGuideData = {
    schema = 2,
    sourceDate = "2026-08-24",
    talentPatch = "2026-08-19",
    officialPatchThrough = "2026-08-22",
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
