# mettre-a-jour.ps1 : à lancer à la racine du site (clic droit > Exécuter avec PowerShell).
# 1) Met à jour galerie/photos.json à partir des dossiers galerie/<catégorie>/ :
#  - une photo présente dans un dossier est ajoutée (titre = nom du fichier) ;
#  - une photo déjà connue garde son titre, ses dimensions et son cadrage ;
#  - une photo supprimée du dossier disparaît du fichier ;
#  - une photo placée dans plusieurs dossiers apparaît dans plusieurs onglets.
# 2) Crée donnees.js (photos + ventes/ventes.txt + locations/outils.txt) : sert uniquement à voir le site
#    en ouvrant les pages par double-clic sur l'ordinateur. Sur GitHub Pages, les fichiers sont lus directement.
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$root = $root.TrimEnd('\','/')
$galerie = Join-Path $root 'galerie'
$jsonPath = Join-Path $galerie 'photos.json'
$ext = '.jpg','.jpeg','.png','.webp','.gif','.avif'
$ignore = 'profil','logo'
if (-not (Test-Path $galerie)) { Write-Host "Dossier galerie introuvable ($galerie)" -ForegroundColor Red; exit 1 }

function Slug([string]$s) {
  $n = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($c in $n.ToCharArray()) { if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) } }
  ($sb.ToString().ToLower().Trim() -replace '[\s_]+','-')
}

# métadonnées existantes (titre, w, h, full), indexées par nom de fichier
$meta = @{}; $ordre = @()
if (Test-Path $jsonPath) {
  try {
    $old = [IO.File]::ReadAllText($jsonPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    foreach ($p in @($old)) { $k = ([IO.Path]::GetFileName([string]$p.src)).ToLower(); if (-not $meta.ContainsKey($k)) { $meta[$k] = $p; $ordre += $k } }
  } catch { Write-Host "photos.json existant illisible, il sera recréé." -ForegroundColor Yellow }
}

# photos réellement présentes dans les dossiers
$found = @{}
Get-ChildItem $galerie -Directory | Where-Object { $ignore -notcontains (Slug $_.Name) } | ForEach-Object {
  $cat = Slug $_.Name; $dossier = $_.Name
  Get-ChildItem $_.FullName -File | Where-Object { $ext -contains $_.Extension.ToLower() } | ForEach-Object {
    $k = $_.Name.ToLower()
    if (-not $found.ContainsKey($k)) { $found[$k] = [ordered]@{ src = "galerie/$dossier/$($_.Name)"; cats = @() } }
    if ($found[$k].cats -notcontains $cat) { $found[$k].cats += $cat }
  }
}

$out = @()
$cles = @($ordre | Where-Object { $found.ContainsKey($_) }) + @($found.Keys | Where-Object { $ordre -notcontains $_ } | Sort-Object)
foreach ($k in $cles) {
  $f = $found[$k]; $m = $meta[$k]
  $e = [ordered]@{ src = $f.src }
  if ($m -and $m.w -and $m.h) { $e['w'] = [int]$m.w; $e['h'] = [int]$m.h }
  if ($m -and $m.titre) { $e['titre'] = [string]$m.titre }
  else { $t = [IO.Path]::GetFileNameWithoutExtension($f.src) -replace '[-_]+',' '; $e['titre'] = $t.Substring(0,1).ToUpper() + $t.Substring(1) }
  $e['cat'] = @($f.cats)
  if ($m -and $m.full) { $e['full'] = $true } elseif (-not $m) { $e['full'] = $true }
  $out += [pscustomobject]$e
}
$json = ConvertTo-Json -InputObject @($out) -Depth 4
[IO.File]::WriteAllText($jsonPath, $json + "`n", (New-Object Text.UTF8Encoding($false)))
$nouv = @($cles | Where-Object { -not $meta.ContainsKey($_) }).Count
Write-Host "photos.json mis à jour : $($out.Count) photos ($nouv nouvelle(s))." -ForegroundColor Green

# --- donnees.js pour l'ouverture locale
function Lire($dossier, $noms) {
  $d = Join-Path $root $dossier
  if (-not (Test-Path $d)) { Write-Host "Dossier absent : $dossier" -ForegroundColor Yellow; return $null }
  $f = $null
  foreach ($n in $noms) { $c = Join-Path $d $n; if (Test-Path $c) { $f = $c; break } }
  if (-not $f) { $t = Get-ChildItem $d -Filter *.txt -File | Select-Object -First 1; if ($t) { $f = $t.FullName } }
  if (-not $f) { Write-Host "Aucun .txt dans $dossier" -ForegroundColor Yellow; return $null }
  Write-Host "Lu : $f"
  $b = [IO.File]::ReadAllBytes($f)
  try { return (New-Object Text.UTF8Encoding($false, $true)).GetString($b) }
  catch { return [Text.Encoding]::GetEncoding(1252).GetString($b) }
}
$data = [ordered]@{ photos = @($out) }
$v = Lire 'ventes' @('ventes.txt','articles.txt'); if ($v -ne $null) { $data['ventes'] = $v }
$l = Lire 'locations' @('outils.txt','locations.txt'); if ($l -ne $null) { $data['locations'] = $l }
$js = ConvertTo-Json -InputObject $data -Depth 6
[IO.File]::WriteAllText((Join-Path $root 'donnees.js'), "window.SITE_DATA = $js;`n", (New-Object Text.UTF8Encoding($false)))
Write-Host "donnees.js créé." -ForegroundColor Green
