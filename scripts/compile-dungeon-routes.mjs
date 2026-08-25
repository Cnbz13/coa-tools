import { writeFile } from 'node:fs/promises';
import process from 'node:process';
import {
  arrayValues, getField, getScalar, loadSavedVariablesDatabase, tableEntries
} from './analyze-dungeon-savedvars.mjs';

const GENERATED_VERSION = 1;

const CATALOG = {
  'blackfathom deeps': {
    mapId: 689,
    summary: "Une longue descente avec beaucoup d'embranchements. Reste sur la trace et termine chaque salle avant de repartir.",
    bosses: ['Ghamoo-ra', 'Lady Sarevess', 'Gelihast', 'Lorgus Jett', 'Twilight Lord Kelris', "Aku'mai"]
  },
  'blackrock caverns': {
    mapId: 754,
    summary: "Un parcours assez direct, mais plusieurs salles punissent les pulls trop larges. Avance proprement et garde le groupe derrière toi.",
    bosses: ['Rom\'ogg Bonecrusher', 'Corla, Herald of Twilight', 'Karsh Steelbender', 'Beauty', 'Ascendant Lord Obsidius']
  },
  'deadmines': {
    mapId: 757,
    summary: "Suis les galeries jusqu'au chantier naval. Les couloirs sont étroits : place les packs sans bloquer la ligne de vue du soigneur.",
    bosses: ["Rhahk'Zor", 'Sneed', "Gilnid", 'Mr. Smite', 'Captain Greenskin', 'Cookie', 'Edwin VanCleef']
  },
  'dire maul': {
    mapId: 700,
    summary: "La route enregistrée traverse l'aile nord. Prends les gardes dans l'ordre et évite d'attirer les patrouilles des salles voisines.",
    bosses: ["Guard Mol'dar", 'Stomper Kreeg', 'Guard Fengus', "Guard Slip'kik", 'Captain Kromcrush', "Cho'Rush the Observer", 'King Gordok']
  },
  'gnomeregan': {
    mapId: 692,
    summary: "Le donjon est vertical et facile à confondre. Vérifie bien l'étage indiqué avant de suivre la flèche.",
    bosses: ['Grubbis', 'Viscous Fallout', 'Electrocutioner 6000', 'Crowd Pummeler 9-60', 'Dark Iron Ambassador', 'Mekgineer Thermaplugg']
  },
  'maraudon': {
    mapId: 751,
    summary: "Plusieurs ailes se croisent. La trace suit le passage réellement observé ; ne change pas de tunnel sans attendre le recalage.",
    bosses: ['Noxxion', 'Razorlash', 'Lord Vyletongue', 'Celebras the Cursed', 'Landslide', 'Tinkerer Gizlock', 'Rotgrip', 'Princess Theradras']
  },
  'ragefire chasm': {
    mapId: 681,
    summary: "Un itinéraire compact idéal pour apprendre à enchaîner sans distancer son soigneur.",
    bosses: ['Oggleflint', 'Taragaman the Hungerer', 'Jergosh the Invoker', 'Bazzalan']
  },
  'razorfen downs': {
    mapId: 761,
    summary: "Les rampes et les hauteurs rendent les raccourcis trompeurs. Reste sur le même niveau que la prochaine étape.",
    bosses: ["Tuten'kash", 'Mordresh Fire Eye', 'Glutton', 'Ragglesnout', 'Amnennar the Coldbringer']
  },
  'razorfen kraul': {
    mapId: 762,
    summary: "Le chemin serpente sur plusieurs passerelles. Laisse les patrouilles venir et évite de sauter hors de la trace.",
    bosses: ['Roogug', 'Aggem Thorncurse', 'Death Speaker Jargba', 'Overlord Ramtusk', 'Agathelos the Raging', 'Blind Hunter', 'Charlga Razorflank']
  },
  'scarlet monastery': {
    mapId: 763,
    summary: "Cette trace correspond à l'aile observée par le collecteur. Nettoie les salles dans l'ordre et surveille les lanceurs de sorts.",
    bosses: ['Interrogator Vishas', 'Fallen Champion', 'Ironspine', 'Azshir the Sleepless', 'Bloodmage Thalnos', 'Scorn']
  },
  'shadowfang keep': {
    mapId: 765,
    summary: "Beaucoup d'escaliers et de changements d'étage. Si la flèche paraît inversée, vérifie d'abord le niveau affiché.",
    bosses: ['Rethilgore', 'Razorclaw the Butcher', 'Baron Silverlaine', 'Commander Springvale', 'Odo the Blindwatcher', 'Fenrus the Devourer', 'Wolf Master Nandos', 'Archmage Arugal']
  },
  'sunken temple': {
    mapId: 2022,
    summary: "Le temple contient des boucles et des salles très proches sur la carte. Suis l'étage et le nom de la prochaine rencontre, pas seulement la direction brute.",
    bosses: ["Atal'alarion", 'Avatar of Hakkar', "Jammal'an the Prophet", 'Ogom the Wretched', 'Dreamscythe', 'Weaver', 'Morphaz', 'Hazzas', 'Shade of Eranikus']
  },
  'uldaman': {
    mapId: 693,
    summary: "Les couloirs se ressemblent et plusieurs salles sont optionnelles. La progression indique clairement le prochain combat enregistré.",
    bosses: ['Revelosh', 'Baelog', 'Ironaya', 'Obsidian Sentinel', 'Ancient Stone Keeper', 'Galgann Firehammer', 'Grimlok', 'Archaedas']
  },
  'vaults of the inquisition': {
    mapId: 2033,
    summary: "Donjon Ascension aux salles compactes. Coupe les incantations et termine les apparitions avant de déplacer le groupe.",
    bosses: ['The Deceiver\'s Presence', 'Inquisitorial Confessor Konrad', 'Merciless Echo', 'His Majesty Darkandle']
  },
  'wailing caverns': {
    mapId: 750,
    summary: "Un vrai labyrinthe : suis la trace sans prendre les ouvertures latérales et attends le groupe avant chaque changement de galerie.",
    bosses: ['Lady Anacondra', 'Lord Cobrahn', 'Kresh', 'Lord Pythas', 'Skum', 'Lord Serpentis', 'Verdan the Everliving', 'Mutanus the Devourer']
  }
};

const BOSS_TIPS = {
  'rom\'ogg bonecrusher': "Place-le au centre. Quand le groupe est immobilisé, libère les chaînes puis éloigne-toi de son attaque de zone.",
  'corla, herald of twilight': "Place Corla sans la promener. Le groupe gère les rayons ; toi, surveille surtout ses incantations et les adds.",
  'karsh steelbender': "Fais-lui toucher la lave brièvement quand le groupe est prêt, puis ressors-le et stabilise les dégâts.",
  'beauty': "Tourne Beauty dos au groupe et évite de ramasser toute la salle en même temps.",
  'ascendant lord obsidius': "Garde le boss stable et laisse le groupe gérer les ombres. Reprends immédiatement la menace après chaque déplacement.",
  'twilight lord kelris': "Interromps autant que possible et garde le boss dos au groupe.",
  'archmage arugal': "Garde la caméra sur lui pendant ses déplacements et récupère-le dès qu'il réapparaît.",
  'shade of eranikus': "Place-le loin du groupe, tourne-le dos aux alliés et garde de la place pour bouger.",
  'his majesty darkandle': "Attends que tout le groupe soit entré avant d'engager, puis garde le boss stable au centre de la zone sûre."
};

function normalize(value) {
  return String(value || '').trim().toLowerCase();
}

function round(value, digits = 5) {
  const scale = 10 ** digits;
  return Math.round((Number(value) || 0) * scale) / scale;
}

function values(node) {
  return tableEntries(node).map(([, value]) => value);
}

function readPosition(node) {
  if (!node) return null;
  const x = Number(getScalar(node, 'x', 0));
  const y = Number(getScalar(node, 'y', 0));
  if (!(x > 0 || y > 0) || x < 0 || x > 1 || y < 0 || y > 1) return null;
  return {
    t: Number(getScalar(node, 't', 0)), x: round(x), y: round(y),
    floor: Number(getScalar(node, 'floor', 0)), mapId: Number(getScalar(node, 'mapId', 0)),
    reason: String(getScalar(node, 'reason', 'sample'))
  };
}

function readEnemy(node) {
  return {
    name: String(getScalar(node, 'name', 'Créature inconnue')),
    firstSeen: Number(getScalar(node, 'firstSeen', 0)),
    kills: Number(getScalar(node, 'kills', 0)),
    maxHealth: Number(getScalar(node, 'maxHealth', 0)),
    classification: String(getScalar(node, 'classification', '')),
    positions: arrayValues(getField(node, 'positions')).map(readPosition).filter(Boolean)
  };
}

function readPull(node) {
  const enemyNames = values(getField(node, 'enemies')).map((enemy) => String(getScalar(enemy, 'name', 'Créature inconnue')));
  return {
    index: Number(getScalar(node, 'index', 0)),
    started: Number(getScalar(node, 'started', 0)),
    ended: Number(getScalar(node, 'ended', 0)),
    enemyCount: Number(getScalar(node, 'enemyCount', enemyNames.length)),
    kills: Number(getScalar(node, 'kills', 0)),
    damageTaken: Number(getScalar(node, 'damageTaken', 0)),
    position: readPosition(getField(node, 'startPosition')),
    enemyNames: [...new Set(enemyNames)]
  };
}

function readLoot(node) {
  return {
    itemId: Number(getScalar(node, 'itemId', 0)),
    name: String(getScalar(node, 'name', 'Objet inconnu')),
    quality: Number(getScalar(node, 'quality', 0)),
    itemLevel: Number(getScalar(node, 'itemLevel', 0)),
    sourceName: String(getScalar(node, 'sourceName', 'Source inconnue'))
  };
}

function readSession(node, index) {
  const instance = getField(node, 'instance');
  return {
    index,
    name: String(getScalar(instance, 'name', 'Instance inconnue')),
    difficultyIndex: Number(getScalar(instance, 'difficultyIndex', 0)),
    duration: Number(getScalar(node, 'duration', 0)),
    deaths: Number(getScalar(node, 'deaths', 0)),
    coordinatesAvailable: Boolean(getScalar(node, 'coordinatesAvailable', false)),
    points: arrayValues(getField(node, 'points')).map(readPosition).filter(Boolean),
    pulls: arrayValues(getField(node, 'pulls')).map(readPull),
    enemies: values(getField(node, 'enemies')).map(readEnemy),
    markers: arrayValues(getField(node, 'markers')).map((marker) => ({
      kind: String(getScalar(marker, 'kind', 'note')),
      note: String(getScalar(marker, 'note', '')),
      ...readPosition(marker)
    })).filter((marker) => marker.x),
    loot: arrayValues(getField(node, 'loot')).map(readLoot).filter((item) => item.itemId > 0)
  };
}

function observedBosses(session, catalog) {
  const byName = new Map(session.enemies.map((enemy) => [normalize(enemy.name), enemy]));
  return catalog.bosses
    .map((name) => ({ name, enemy: byName.get(normalize(name)) }))
    .filter((entry) => entry.enemy && entry.enemy.kills > 0);
}

function routeScore(session, catalog) {
  if (!session.coordinatesAvailable || session.points.length < 80 || session.pulls.length < 2) return -1;
  return observedBosses(session, catalog).length * 100000
    + Math.min(session.enemies.length, 250) * 100
    + Math.min(session.points.length, 2500)
    - session.deaths * 200;
}

function pointDistanceToSegment(point, start, end) {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  if (dx === 0 && dy === 0) return Math.hypot(point.x - start.x, point.y - start.y);
  const ratio = Math.max(0, Math.min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)));
  return Math.hypot(point.x - (start.x + ratio * dx), point.y - (start.y + ratio * dy));
}

function simplify(points, epsilon = 0.006) {
  if (points.length <= 2) return points;
  let farthest = 0;
  let split = 0;
  for (let index = 1; index < points.length - 1; index += 1) {
    const distance = pointDistanceToSegment(points[index], points[0], points[points.length - 1]);
    if (distance > farthest) {
      farthest = distance;
      split = index;
    }
  }
  if (farthest <= epsilon) return [points[0], points[points.length - 1]];
  return [...simplify(points.slice(0, split + 1), epsilon).slice(0, -1), ...simplify(points.slice(split), epsilon)];
}

function simplifyRoute(points, expectedMapId) {
  const usable = points.filter((point) => point.mapId === expectedMapId);
  const segments = [];
  let segment = [];
  for (const point of usable) {
    const previous = segment[segment.length - 1];
    if (previous && (previous.floor !== point.floor || point.t - previous.t > 25)) {
      if (segment.length) segments.push(segment);
      segment = [];
    }
    segment.push(point);
  }
  if (segment.length) segments.push(segment);
  return segments.flatMap((part) => simplify(part));
}

function nearestRoutePoint(points, time, fallback) {
  let best = fallback || null;
  let bestDelta = Number.POSITIVE_INFINITY;
  for (const point of points) {
    const delta = Math.abs(point.t - time);
    if (delta < bestDelta) {
      best = point;
      bestDelta = delta;
    }
  }
  return best;
}

function packInstruction(pull, bosses) {
  const bossNames = new Set(bosses.map((boss) => normalize(boss.name)));
  const regular = pull.enemyNames.filter((name) => !bossNames.has(normalize(name)));
  const casters = regular.filter((name) => /(mage|warlock|oracle|acolyte|geomancer|shaman|sapper|confessor|necromancer|evoker|loreseeker|aquamancer|shadowmage|frostwing)/i.test(name));
  if (casters.length) return `Ramène le pack contre toi et interromps en priorité ${casters.slice(0, 2).join(' / ')}.`;
  if (pull.enemyCount >= 8) return "Gros pack : rassemble tout avant d'avancer et garde un défensif si les dégâts montent.";
  if (pull.enemyCount >= 5) return "Pack dense : pose-le proprement, laisse le groupe finir, puis seulement après suis la flèche.";
  return "Prends ce pack face à toi, tourne-le dos au groupe et vérifie que tout est mort avant de repartir.";
}

function bossTip(name) {
  return BOSS_TIPS[normalize(name)] || "Attends le groupe, place le boss dos aux alliés et garde-le stable. Coupe ses incantations dangereuses si tu peux.";
}

function checkpointsFor(session, catalog) {
  const routePoints = simplifyRoute(session.points, catalog.mapId);
  if (routePoints.length < 2) return [];
  const bosses = observedBosses(session, catalog);
  const events = routePoints.map((point, index) => ({
    t: point.t, x: point.x, y: point.y, floor: point.floor, mapId: point.mapId,
    kind: index === 0 ? 'start' : index === routePoints.length - 1 ? 'finish' : 'route',
    title: index === 0 ? 'Point de départ' : index === routePoints.length - 1 ? 'Fin du parcours observé' : 'Suis le chemin',
    text: index === 0 ? "Le guide est calé sur ta position. Avance vers la flèche quand le groupe est prêt."
      : index === routePoints.length - 1 ? "La trace enregistrée s'arrête ici. Vérifie que l'objectif du donjon est terminé."
        : "Continue dans cette direction sans prendre l'embranchement voisin."
  }));

  for (const pull of session.pulls) {
    const position = pull.position && pull.position.mapId === catalog.mapId
      ? pull.position : nearestRoutePoint(routePoints, pull.started, routePoints[0]);
    if (!position) continue;
    const pullBosses = bosses.filter((boss) => pull.enemyNames.some((name) => normalize(name) === normalize(boss.name)));
    if (pullBosses.length) {
      const name = pullBosses[0].name;
      events.push({
        t: pull.started, x: position.x, y: position.y, floor: position.floor, mapId: catalog.mapId,
        kind: 'boss', title: name, text: bossTip(name), enemies: pull.enemyNames.slice(0, 6)
      });
    } else {
      events.push({
        t: pull.started, x: position.x, y: position.y, floor: position.floor, mapId: catalog.mapId,
        kind: 'pack', title: `Pack ${String(pull.index).padStart(2, '0')}`,
        text: packInstruction(pull, bosses), enemies: pull.enemyNames.slice(0, 4), count: pull.enemyCount
      });
    }
  }

  for (const marker of session.markers) {
    if (marker.mapId !== catalog.mapId) continue;
    events.push({
      t: marker.t, x: marker.x, y: marker.y, floor: marker.floor, mapId: marker.mapId,
      kind: marker.kind, title: marker.kind === 'skip' ? 'Pack à éviter' : marker.kind === 'shortcut' ? 'Raccourci' : 'Repère',
      text: marker.note || "Suis ce repère avant de continuer."
    });
  }

  events.sort((left, right) => left.t - right.t || (left.kind === 'route' ? -1 : 1));
  const compact = [];
  for (const event of events) {
    const previous = compact[compact.length - 1];
    if (event.kind === 'route' && previous && previous.kind === 'route'
      && previous.floor === event.floor && Math.hypot(previous.x - event.x, previous.y - event.y) < 0.012) continue;
    compact.push(event);
  }
  return compact.map((event) => {
    const result = {
      x: event.x, y: event.y, floor: event.floor, kind: event.kind
    };
    if (event.kind !== 'route') {
      result.title = event.title;
      result.text = event.text;
    }
    if (event.count) result.count = event.count;
    return result;
  });
}

function luaString(value) {
  return `"${String(value ?? '').replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\r', '').replaceAll('\n', '\\n')}"`;
}

function luaValue(value, indent = 0) {
  if (value === null || value === undefined) return 'nil';
  if (typeof value === 'string') return luaString(value);
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : '0';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  const pad = ' '.repeat(indent);
  const childPad = ' '.repeat(indent + 4);
  if (Array.isArray(value)) {
    if (!value.length) return '{}';
    return `{\n${value.map((entry) => `${childPad}${luaValue(entry, indent + 4)}`).join(',\n')}\n${pad}}`;
  }
  const entries = Object.entries(value).filter(([, entry]) => entry !== undefined);
  if (!entries.length) return '{}';
  return `{\n${entries.map(([key, entry]) => `${childPad}[${luaString(key)}] = ${luaValue(entry, indent + 4)}`).join(',\n')}\n${pad}}`;
}

async function main() {
  const [savedVariablesPath, outputPath = 'addons/CoADungeonNavigator/CoADungeonRoutes.lua'] = process.argv.slice(2);
  if (!savedVariablesPath) throw new Error('Usage: npm run compile:dungeons -- <CoADungeonNavigator.lua> [output.lua]');
  const database = await loadSavedVariablesDatabase(savedVariablesPath);
  const sessions = arrayValues(getField(database, 'sessions')).map((session, index) => readSession(session, index + 1));
  const routes = {};

  for (const [key, catalog] of Object.entries(CATALOG)) {
    const candidates = sessions.filter((session) => normalize(session.name) === key);
    const ranked = [...candidates].sort((left, right) => routeScore(right, catalog) - routeScore(left, catalog));
    const selected = ranked[0];
    if (!selected || routeScore(selected, catalog) < 0) continue;
    const checkpoints = checkpointsFor(selected, catalog);
    if (checkpoints.length < 2) continue;
    const allLoot = [];
    const seenLoot = new Set();
    for (const session of candidates) {
      for (const item of session.loot) {
        if (seenLoot.has(item.itemId)) continue;
        seenLoot.add(item.itemId);
        allLoot.push(item);
      }
    }
    routes[key] = {
      name: selected.name,
      mapId: catalog.mapId,
      difficultyIndex: selected.difficultyIndex,
      summary: catalog.summary,
      sourceRuns: candidates.length,
      selectedRun: selected.index,
      duration: Math.round(selected.duration),
      confidence: candidates.length >= 3 ? 'haute' : candidates.length >= 2 ? 'bonne' : 'à confirmer',
      observedBosses: observedBosses(selected, catalog).map((boss) => boss.name),
      knownBosses: catalog.bosses,
      loot: allLoot,
      checkpoints
    };
    console.log(`${selected.name}: run #${selected.index}, ${checkpoints.length} étapes, ${routes[key].observedBosses.length} boss observés, ${candidates.length} run(s)`);
  }

  const output = `-- Generated by scripts/compile-dungeon-routes.mjs. Do not edit by hand.\n`
    + `-- Contains only anonymized dungeon geometry and encounter data.\n\n`
    + `CoADungeonRouteData = ${luaValue({ schema: GENERATED_VERSION, generatedAt: new Date().toISOString(), routeCount: Object.keys(routes).length, routes })}\n`;
  await writeFile(outputPath, output, 'utf8');
  console.log(`Écrit ${outputPath} (${Object.keys(routes).length} routes).`);
}

await main();
