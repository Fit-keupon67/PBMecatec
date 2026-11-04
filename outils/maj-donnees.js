#!/usr/bin/env node
/* ============================================================
   maj-donnees.js — génère automatiquement :
     - galerie/photos.json  (liste des photos des dossiers galerie/<catégorie>/)
     - donnees.js           (copie pour l'ouverture locale du site)
   Aucune dépendance : Node.js 18+ suffit.
   Utilisation :
     node outils/maj-donnees.js
   Sur GitHub, le fichier .github/workflows/maj-donnees.yml
   l'exécute tout seul à chaque ajout de photo ou de texte.
   ============================================================ */
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const GALERIE = path.join(ROOT, 'galerie');
const PHOTOS_JSON = path.join(GALERIE, 'photos.json');
const DONNEES_JS = path.join(ROOT, 'donnees.js');
const EXT = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif']);
const IGNORE = new Set(['profil', 'logo']);

const UTF8 = new TextDecoder('utf-8', { fatal: true });

/* même normalisation que gallery.html : accents retirés, minuscules, espaces -> tirets */
function slug(value) {
  return String(value)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[\s_]+/g, '-');
}

function readText(file) {
  const buf = fs.readFileSync(file);
  if (buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf) {
    return buf.subarray(3).toString('utf8');
  }
  try {
    return UTF8.decode(buf);
  } catch {
    return buf.toString('latin1');
  }
}

function readJson(file) {
  try {
    return JSON.parse(readText(file));
  } catch {
    return null;
  }
}

function writeText(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text, 'utf8');
}

/* ---------- 1. galerie/photos.json ---------- */

/* métadonnées existantes (titre, dimensions, cadrage), indexées par nom de fichier */
const meta = new Map();
const ordre = [];
const ancien = readJson(PHOTOS_JSON);
if (Array.isArray(ancien)) {
  for (const p of ancien) {
    const src = p && (p.src || p.image || p.file || p.photo);
    if (!src) continue;
    const key = path.basename(String(src)).toLowerCase();
    if (!meta.has(key)) {
      meta.set(key, p);
      ordre.push(key);
    }
  }
}

/* photos réellement présentes dans galerie/<catégorie>/ */
const found = new Map(); // clé = nom de fichier en minuscules
if (fs.existsSync(GALERIE)) {
  const dossiers = fs.readdirSync(GALERIE, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !IGNORE.has(slug(d.name)))
    .sort((a, b) => a.name.localeCompare(b.name, 'fr'));

  for (const dossier of dossiers) {
    const cat = slug(dossier.name);
    const dir = path.join(GALERIE, dossier.name);
    const fichiers = fs.readdirSync(dir, { withFileTypes: true })
      .filter((f) => f.isFile() && EXT.has(path.extname(f.name).toLowerCase()))
      .sort((a, b) => a.name.localeCompare(b.name, 'fr'));

    for (const fichier of fichiers) {
      const key = fichier.name.toLowerCase();
      if (!found.has(key)) {
        found.set(key, {
          src: `galerie/${dossier.name}/${fichier.name}`,
          cats: [],
        });
      }
      const entry = found.get(key);
      if (!entry.cats.includes(cat)) entry.cats.push(cat);
    }
  }
}

/* ordre : photos déjà connues d'abord, puis les nouvelles par ordre alphabétique */
const cles = [
  ...ordre.filter((k) => found.has(k)),
  ...[...found.keys()].filter((k) => !ordre.includes(k)).sort((a, b) => a.localeCompare(b, 'fr')),
];

const photos = cles.map((key) => {
  const f = found.get(key);
  const m = meta.get(key);
  const entry = { src: f.src };
  if (m && m.w && m.h) {
    entry.w = Number(m.w);
    entry.h = Number(m.h);
  }
  if (m && m.titre) {
    entry.titre = String(m.titre);
  } else {
    const t = path.basename(f.src).replace(/\.[^.]+$/, '').replace(/[-_]+/g, ' ').trim();
    entry.titre = t.charAt(0).toUpperCase() + t.slice(1);
  }
  entry.cat = f.cats;
  if (m && m.full) entry.full = true;
  else if (!m) entry.full = true;
  return entry;
});

writeText(PHOTOS_JSON, JSON.stringify(photos, null, 2) + '\n');
const nouvelles = cles.filter((k) => !meta.has(k)).length;
console.log(`galerie/photos.json : ${photos.length} photo(s), ${nouvelles} nouvelle(s).`);

/* ---------- 2. donnees.js (ouverture locale) ---------- */

function premierTexte(dossier, noms) {
  const dir = path.join(ROOT, dossier);
  if (!fs.existsSync(dir)) {
    console.log(`Dossier absent : ${dossier}`);
    return null;
  }
  for (const nom of noms) {
    const file = path.join(dir, nom);
    if (fs.existsSync(file)) return readText(file);
  }
  const txt = fs.readdirSync(dir).find((n) => n.toLowerCase().endsWith('.txt'));
  return txt ? readText(path.join(dir, txt)) : null;
}

const data = { photos };
const ventes = premierTexte('ventes', ['ventes.txt', 'articles.txt']);
if (ventes !== null) data.ventes = ventes;
const locations = premierTexte('locations', ['locations.txt', 'outils.txt']);
if (locations !== null) data.locations = locations;

writeText(DONNEES_JS, `window.SITE_DATA = ${JSON.stringify(data, null, 2)};\n`);
console.log('donnees.js créé.');
