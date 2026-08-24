-- Parcours hors ligne de progression pour Conquest of Azeroth.
-- Les conseils generaux restent volontairement prudents : les recompenses et
-- les couts peuvent changer cote serveur. Le guide distingue donc les faits
-- confirmes des habitudes communautaires et renvoie vers la veille du manager.

CoAProgressionGuideData = {
    schema = 1,
    sourceDate = "2026-08-24",
    sources = {
        {
            name = "Ascension - Mythic+ Releases",
            url = "https://ascension.gg/en/news/mythic-releases-on-warcraft-reborn/522",
            kind = "OFFICIEL"
        },
        {
            name = "Project Ascension Wiki - Edrim Skysong",
            url = "https://project-ascension.fandom.com/wiki/Edrim_Skysong",
            kind = "COMMUNAUTE VERIFIEE"
        },
        {
            name = "Project Ascension Wiki - Mythic+ Guide",
            url = "https://project-ascension.fandom.com/wiki/Mythic%2B_Guide",
            kind = "COMMUNAUTE VERIFIEE"
        },
        {
            name = "CoA Build Hub - builds et retours de joueurs",
            url = "https://coabuildhub.com/",
            kind = "COMMUNAUTE"
        },
        {
            name = "CoA Tavern - sorts, rangs et specialisations",
            url = "https://coatavern.com/classes",
            kind = "DONNEES"
        }
    },
    bands = {
        {
            maximum = 9,
            title = "Apprendre sans se disperser",
            goal = "Avance dans les quetes et prends le temps d'identifier ton attaque principale, ton soin ou defensif et ton moyen de deplacement.",
            activity = "Equipe les ameliorations evidentes et garde les objets dont les statistiques correspondent a ton role. Le Loot Decider peut deja comparer tes sacs.",
            checkpoint = "Au niveau 10, ouvre de nouveau ce guide : la specialisation et ses premiers talents changent vraiment la facon de jouer."
        },
        {
            maximum = 19,
            title = "Installer le noyau de la specialisation",
            goal = "Teste les nouveaux sorts au fur et a mesure. Le guide se rescane automatiquement apres chaque niveau, nouveau sort ou changement de talent.",
            activity = "Quetes et donjons servent surtout a apprendre le role. Ne depense pas beaucoup pour une piece que tu remplaceras dans quelques niveaux.",
            checkpoint = "Quand une nouvelle capacite apparait, regarde ROTATION : elle n'est ajoutee que si elle existe vraiment dans ton spellbook."
        },
        {
            maximum = 39,
            title = "Construire une vraie boucle de combat",
            goal = "Travaille l'ouverture, la ressource et la difference entre une cible et un pack. C'est le bon moment pour corriger les mauvaises habitudes.",
            activity = "Continue le leveling par le contenu que tu termines regulierement. Compare les loots de quete, de donjon et de marchand avant d'acheter.",
            checkpoint = "Vers le niveau 30, les Essences et talents commencent a modifier fortement le noyau du build : actualise apres chaque changement."
        },
        {
            maximum = 49,
            title = "Stabiliser le build avant la fin du leveling",
            goal = "Ton kit est presque complet. Cherche surtout la regularite : cooldowns alignes, ressource stable, interruption et defensifs au bon moment.",
            activity = "Garde de l'or et ne poursuis pas une optimisation parfaite sur un objet temporaire. Les bonnes statistiques comptent plus que la couleur de la piece.",
            checkpoint = "Si ton profil change, le guide et le Loot Decider doivent afficher la meme classe, specialisation et le meme niveau."
        },
        {
            maximum = 59,
            title = "Preparer proprement le niveau 60",
            goal = "Finalise tes raccourcis, lis la page SITUATIONS et identifie les statistiques utiles de ton profil dans le Loot Decider.",
            activity = "Donjons, quetes et caches de leveling restent utiles, mais evite d'investir lourdement dans une piece qui n'a pas tes statistiques prioritaires.",
            checkpoint = "Au niveau 60, reviens ici : la page bascule automatiquement vers un parcours endgame avec Heroiques, Call Board et Mythique+."
        },
        {
            maximum = 999,
            title = "Ton parcours de stuff au niveau 60",
            goal = "Commence par consolider un ensemble coherent, puis monte progressivement : contenu de capitale et Heroiques, Mythique bas niveau, ameliorations, puis difficultes superieures.",
            activity = "Les Mythiques termines donnent des caches et des Mythic Coins. Edrim Skysong sert a acheter ou ameliorer du materiel, gerer la keystone et recycler les objets Mythiques inutiles.",
            checkpoint = "Ne recycle jamais machinalement : compare d'abord l'objet avec ton equipement et ton profil. Une mauvaise piece pour toi peut aussi servir a un autre ensemble."
        }
    }
}
