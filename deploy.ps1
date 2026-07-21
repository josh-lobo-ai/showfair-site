# deploy.ps1 - Rota de publicacao do site institucional showfair.com.br
# Uso:
#   Editar direto o index.html do repo e publicar:
#     powershell -ExecutionPolicy Bypass -File deploy.ps1
#   Importar um build novo (ex: HTML gerado por um artifact/outra sessao) e publicar:
#     powershell -ExecutionPolicy Bypass -File deploy.ps1 -Source "C:\caminho\para\build.html"
# Fragmentos de artifact (sem <!doctype>) sao envelopados automaticamente com head.tmpl.html.
# Deploy = push na branch main -> GitHub Pages publica em ~30s -> https://www.showfair.com.br/

param(
  [string]$Source  = "",
  [string]$Message = ""
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Definition
$enc  = New-Object System.Text.UTF8Encoding($false)

function ReadUtf8([string]$p) {
  [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))
}

# 1. Import opcional de um build novo -> vira index.html
if ($Source -ne "") {
  if (-not (Test-Path $Source)) { throw "Source nao encontrado: $Source" }
  $raw = ReadUtf8 $Source
  if ($raw -match '(?is)<!doctype|<html[\s>]') {
    $doc = $raw
  } else {
    $title = "showfair"
    $m = [regex]::Match($raw, '^\s*<title>(.*?)</title>\s*', 'Singleline')
    if ($m.Success) { $title = $m.Groups[1].Value; $raw = $raw.Substring($m.Length) }
    $head = (ReadUtf8 (Join-Path $repo "head.tmpl.html")).Replace("{{TITLE}}", $title)
    $doc  = $head + $raw + "`r`n</body>`r`n</html>`r`n"
  }
  [System.IO.File]::WriteAllText((Join-Path $repo "index.html"), $doc, $enc)
  Write-Host "Importado de: $Source"
}

# 2. Garante arquivos de infra (dominio + sem jekyll)
if (-not (Test-Path (Join-Path $repo "CNAME")))     { [System.IO.File]::WriteAllText((Join-Path $repo "CNAME"), "www.showfair.com.br", $enc) }
if (-not (Test-Path (Join-Path $repo ".nojekyll"))) { [System.IO.File]::WriteAllText((Join-Path $repo ".nojekyll"), "", $enc) }

# 3. Stage EXPLICITO (nunca 'git add -A' - lição do youni: nao varrer WIP de outra sessao)
git -C $repo add -- index.html CNAME .nojekyll
$pending = git -C $repo status --porcelain -- index.html CNAME .nojekyll
if (-not $pending) { Write-Host "Nada mudou no site. Nada a publicar."; return }

# 4. Commit + sincroniza + push
if ($Message -eq "") { $Message = "deploy: atualiza site institucional showfair" }
git -C $repo commit -m $Message | Out-Null
git -C $repo pull --rebase --autostash origin main | Out-Null
git -C $repo push origin main

Write-Host ""
Write-Host "Publicado. GitHub Pages vai reconstruir em ~30s."
Write-Host "Site: https://www.showfair.com.br/"
