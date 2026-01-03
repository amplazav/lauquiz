<#
Publish project to GitHub and enable GitHub Pages (root on main branch)
Usage:
  .\publish-to-github.ps1 -RepoName 'lauluphine_quiz' [-Private]

Requirements:
  - Git installed and on PATH
  - GitHub CLI (`gh`) installed, and authenticated (gh auth login)
#>

param(
    [string]$RepoName = 'lauluphine_quiz',
    [switch]$Private
)

function Check-Cmd($cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd no está instalado o no está en PATH. Instálalo y vuelve a ejecutar el script."
        exit 1
    }
}

Check-Cmd git
Check-Cmd gh

$repoVisibility = if ($Private) { 'private' } else { 'public' }
$repoPath = (Get-Location).Path

Write-Host "Usando repo: $RepoName ($repoVisibility) en $repoPath"

# Inicializar git si hace falta
if (-not (Test-Path "$repoPath\.git")) {
    Write-Host "Inicializando repo git y creando rama 'main'..."
    git init
    git checkout -b main
} else {
    Write-Host "Ya existe un repositorio git local."
}

# Asegurar que .gitignore y README existen (opcional)
if (-not (Test-Path "$repoPath\.gitignore")) {
    "# Node modules`nnode_modules/" | Out-File -FilePath "$repoPath\.gitignore" -Encoding UTF8
    Write-Host "Se creó .gitignore"
}
if (-not (Test-Path "$repoPath\README.md")) {
    "# $RepoName`n`nPequeña aplicación web." | Out-File -FilePath "$repoPath\README.md" -Encoding UTF8
    Write-Host "Se creó README.md"
}

# Commit inicial si hay cambios
git add -A
$porcelain = git status --porcelain
if ([string]::IsNullOrEmpty($porcelain)) {
    Write-Host "No hay cambios para commitear."
} else {
    git commit -m "Initial commit"
    Write-Host "Commit inicial realizado"
}

# Crear repo remoto y pushear
Write-Host "Creando repositorio en GitHub y push..."
Write-Host "gh repo create $RepoName --$repoVisibility --source=\"$repoPath\" --remote=origin --push --confirm"
& gh repo create $RepoName --$repoVisibility --source="$repoPath" --remote=origin --push --confirm

# Obtener owner
$owner = gh api user --jq .login
if (-not $owner) { Write-Error "No he podido obtener el usuario autenticado de GitHub."; exit 1 }

# Habilitar GitHub Pages (main, raíz)
Write-Host "Habilitando GitHub Pages (branch=main, path=/)..."
try {
    gh api -X PUT "/repos/$owner/$RepoName/pages" -f source.branch='main' -f source.path='/' > $null
    Start-Sleep -Seconds 2
    $pagesUrl = gh api "/repos/$owner/$RepoName/pages" --jq .html_url
    if ($pagesUrl) {
        Write-Host "GitHub Pages habilitado: $pagesUrl"
    } else {
        Write-Host "Se intentó habilitar Pages pero la URL aún no está disponible. Puedes comprobar en la configuración del repo."    
    }
} catch {
    Write-Warning "No se pudo habilitar GitHub Pages automáticamente: $_"
    Write-Host "Puedes habilitarlo manualmente en https://github.com/$owner/$RepoName/settings/pages"
}

Write-Host "Listo. Repositorio: https://github.com/$owner/$RepoName"
