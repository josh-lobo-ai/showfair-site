# deploy.ps1 - Rota de publicacao do site institucional showfair.com.br
# Uso:
#   Editar direto o index.html do repo e publicar:
#     powershell -ExecutionPolicy Bypass -File deploy.ps1
#   Importar um build novo (ex: HTML gerado por um artifact/outra sessao) e publicar:
#     powershell -ExecutionPolicy Bypass -File deploy.ps1 -Source "C:\caminho\build.html"
#   Forcar publicacao mesmo que o build seja mais antigo que o ultimo:
#     powershell -ExecutionPolicy Bypass -File deploy.ps1 -Source "..." -Force
#
# Seguranca embutida:
#  - Sincroniza com o remoto ANTES e DEPOIS (pull --rebase) -> nao diverge de outra sessao.
#  - Stage EXPLICITO (nunca 'git add -A') -> nao varre WIP de sessao paralela.
#  - TRAVA ANTI-STALE: recusa importar um build mais ANTIGO que o ultimo publicado (a nao ser com -Force).
#  - Todo deploy vira 1 commit -> historico do git = backup; nada publicado se perde.
# Deploy = push na main -> GitHub Pages -> https://www.showfair.com.br/

param(
  [string]$Source  = "",
  [string]$Message = "",
  [switch]$Force
)
# Continue (nao Stop): git escreve infos no stderr que, com Stop, viram erro fatal no PS 5.1.
# Erros reais de arquivo (.NET) e 'throw' continuam abortando; git checamos por $LASTEXITCODE.
$ErrorActionPreference = "Continue"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Definition
$enc  = New-Object System.Text.UTF8Encoding($false)
$metaPath = Join-Path $repo ".deploy-meta.json"

function ReadUtf8([string]$p) {
  [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))
}
function GitOrDie([string[]]$gitArgs, [string]$erro) {
  & git -C $repo @gitArgs | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "$erro (git saiu com $LASTEXITCODE)" }
}

# 0. Sincroniza com o remoto ANTES de mexer (pega o estado mais novo; nao perde deploy de outra sessao)
& git -C $repo pull --rebase --autostash origin main | Out-Null

# 1. Import opcional de um build novo -> vira index.html (com trava anti-stale)
if ($Source -ne "") {
  if (-not (Test-Path $Source)) { throw "Source nao encontrado: $Source" }
  $srcItem  = Get-Item $Source
  $newTicks = $srcItem.LastWriteTimeUtc.Ticks

  # TRAVA ANTI-STALE: nao deixa um build velho sobrescrever um mais novo ja publicado
  if ((Test-Path $metaPath) -and -not $Force) {
    $meta = ReadUtf8 $metaPath | ConvertFrom-Json
    if ($meta.sourceTicks) {
      $lastTicks = [int64]::Parse($meta.sourceTicks)
      if ($newTicks -lt $lastTicks) {
        Write-Host "ABORTADO (trava anti-stale): o build informado e MAIS ANTIGO que o ultimo publicado."
        Write-Host ("  ultimo publicado: " + $meta.sourceMtime + "   " + $meta.sourcePath)
        Write-Host ("  build informado:  " + $srcItem.LastWriteTime + "   " + $Source)
        Write-Host "  Se tem CERTEZA que quer sobrescrever com o mais antigo, rode de novo com -Force."
        return
      }
    }
  }

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

  # registra a proveniencia deste deploy (usado pela trava anti-stale no proximo)
  $metaObj = [ordered]@{
    sourcePath  = $Source
    sourceMtime = $srcItem.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    sourceTicks = "$newTicks"
    deployedAt  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  }
  [System.IO.File]::WriteAllText($metaPath, ($metaObj | ConvertTo-Json), $enc)
  Write-Host ("Importado de: " + $Source + "  (build de " + $srcItem.LastWriteTime + ")")
}

# 2. Garante arquivos de infra (dominio + sem jekyll)
if (-not (Test-Path (Join-Path $repo "CNAME")))     { [System.IO.File]::WriteAllText((Join-Path $repo "CNAME"), "www.showfair.com.br", $enc) }
if (-not (Test-Path (Join-Path $repo ".nojekyll"))) { [System.IO.File]::WriteAllText((Join-Path $repo ".nojekyll"), "", $enc) }

# 3. Stage EXPLICITO (nunca 'git add -A' - nao varrer WIP de sessao paralela)
$toStage = @('index.html','CNAME','.nojekyll')
if (Test-Path $metaPath) { $toStage += '.deploy-meta.json' }
& git -C $repo add -- $toStage
$pending = & git -C $repo status --porcelain -- $toStage
if (-not $pending) { Write-Host "Nada mudou no site. Nada a publicar."; return }

# 4. Commit + sincroniza de novo (concorrencia) + push
if ($Message -eq "") { $Message = "deploy: atualiza site institucional showfair" }
GitOrDie @('commit','-m',$Message) "commit falhou"
& git -C $repo pull --rebase --autostash origin main | Out-Null
GitOrDie @('push','origin','main') "push falhou"

Write-Host ""
Write-Host "Publicado. GitHub Pages vai reconstruir em ~30s."
Write-Host "Site: https://www.showfair.com.br/"
