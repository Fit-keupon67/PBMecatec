# PBMecatec

Site statique publié sur GitHub Pages.

## Ajouter ou supprimer des photos de la galerie

1. Déposez les photos dans le dossier de la catégorie voulue :
   `galerie/<catégorie>/` (ex. `galerie/soudure/ma-photo.webp`).
   Pour créer une nouvelle catégorie, créez simplement un nouveau dossier
   (son nom devient le filtre de la galerie).
2. Publiez le changement (upload GitHub, `git push`, etc.). **C'est tout.**

À chaque publication, le workflow `.github/workflows/maj-donnees.yml`
exécute automatiquement `outils/maj-donnees.js`, qui :

- régénère `galerie/photos.json` à partir des dossiers réellement présents ;
- régénère `donnees.js` (utile uniquement pour ouvrir le site en double-clic
  sur un ordinateur, sans serveur) ;
- publie ces fichiers via un commit automatique, ce qui déclenche la mise à
  jour de GitHub Pages.

Il n'y a donc plus à lancer un `.ps1` ni à re-uploader tout le site.
Les titres, dimensions et cadrages déjà enregistrés dans `photos.json` sont
conservés ; seules les nouvelles photos sont ajoutées et les disparues
retirées.

> Si `photos.json` est absent ou pas encore régénéré, `gallery.html` liste
> directement les dossiers via l'API GitHub (résultat mis en cache 30 min
> dans le navigateur). Une limite de 60 requêtes/heure s'applique par IP.

## Ajouter un article à vendre

Tout se passe dans `ventes/` :

1. déposez la photo dans `ventes/` ;
2. ajoutez un bloc dans `ventes/ventes.txt` :

```
Photo: perceuse.jpg
Titre: Perceuse à colonne
Prix: 120 €
Description: Très bon état, vendue avec ses mors.
Disponible: oui
```

Publiez : `ventes.html` lit `ventes/ventes.txt` directement, sans
régénération. Mettez `Disponible: non` pour griser l'article.

## Ajouter un outil à louer

Même principe dans `locations/` : déposez la photo, ajoutez un bloc dans
`locations/locations.txt`, publiez. `locations.html` lit le fichier
directement.

## Utilisation locale (optionnelle)

Pour prévisualiser le site en double-clic (protocole `file://`, où les
navigateurs bloquent `fetch`) :

- Windows : lancer `mettre-a-jour.ps1` (ou `mettre-a-jour.exe`) ;
- avec Node.js : `node outils/maj-donnees.js`.

Ces commandes régénèrent `photos.json` et `donnees.js` en local. Elles ne
sont **pas** nécessaires pour le site en ligne.

## Structure

- `index.html`, `gallery.html`, `ventes.html`, `locations.html`, `dons.html`,
  `mentions.html` : pages du site.
- `galerie/<catégorie>/` : photos de la galerie.
- `ventes/` : photos + `ventes.txt` des articles à vendre.
- `locations/` : photos + `locations.txt` des outils à louer.
- `galerie/photos.json`, `donnees.js` : fichiers générés (ne pas éditer à la main).
- `outils/maj-donnees.js` : générateur (Node.js, sans dépendance).
- `.github/workflows/maj-donnees.yml` : automatisation sur GitHub.
