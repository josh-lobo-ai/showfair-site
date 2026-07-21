# rollback.ps1 - Historico de deploys e rollback do site institucional showfair.com.br
# Listar os ultimos deploys (o que esta no ar = topo):
#   powershell -ExecutionPolicy Bypass -File rollback.ps1
# Voltar a producao para um deploy anterior (pelo SHA da lista):
#   powershell -ExecutionPolicy Bypass -File rollback.ps1 -To 5ec55be
#
# Como funciona: cada deploy e um commit. O rollback restaura o index.html daquele
# commit e publica como um NOVO commit (forward rollback) - o historico inteiro fica
# preservado, entao da pra "desfazer o desfazer" a qualquer momento. Nada se perde.

param(
  [string]$To   = "",
  [int]   $List = 15
)
$ErrorActionPreference = "Continue"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Definition
function GitOrDie([string[]]$gitArgs, [string]$erro) {
  & git -C $repo @gitArgs | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "$erro (git saiu com $LASTEXITCODE)" }
}

# sincroniza com o remoto
& git -C $repo pull --rebase --autostash origin main | Out-Null
$head = (& git -C $repo rev-parse --short HEAD).Trim()

if ($To -eq "") {
  Write-Host ""
  Write-Host "HISTORICO DE DEPLOYS (mais recente no topo; << NO AR marca o publicado):"
  Write-Host ("-" * 78)
  $log = & git -C $repo log -n $List --date=format:'%d/%m %H:%M' --format='%h|%ad|%s' -- index.html
  foreach ($line in $log) {
    $p = $line -split '\|', 3
    $mark = if ($p[0] -eq $head) { "  << NO AR" } else { "" }
    Write-Host ("{0}  {1}  {2}{3}" -f $p[0], $p[1], $p[2], $mark)
  }
  Write-Host ("-" * 78)
  Write-Host "Para reverter:  powershell -ExecutionPolicy Bypass -File rollback.ps1 -To <SHA>"
  Write-Host ""
  return
}

# --- ROLLBACK para $To ---
& git -C $repo cat-file -e ("{0}^{{commit}}" -f $To) 2>$null
if ($LASTEXITCODE -ne 0) { throw "Commit '$To' nao existe no historico." }

# restaura o index.html daquele deploy para a arvore de trabalho
& git -C $repo checkout $To -- index.html | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Nao consegui restaurar index.html de $To (o arquivo existia nesse commit?)." }

$pending = & git -C $repo status --porcelain -- index.html
if (-not $pending) { Write-Host "index.html ja esta identico ao de $To. Nada a reverter."; return }

$shortTo = $To.Substring(0, [Math]::Min(7, $To.Length))
GitOrDie @('add','--','index.html') "add falhou"
GitOrDie @('commit','-m',"rollback: restaura o site ao deploy $shortTo") "commit falhou"
& git -C $repo pull --rebase --autostash origin main | Out-Null
GitOrDie @('push','origin','main') "push falhou"

Write-Host ""
Write-Host "ROLLBACK PUBLICADO. index.html voltou ao estado do deploy $shortTo."
Write-Host "GitHub Pages reconstroi em ~30s -> https://www.showfair.com.br/"
Write-Host "(Para desfazer este rollback, rode a lista de novo e volte para o SHA anterior.)"
