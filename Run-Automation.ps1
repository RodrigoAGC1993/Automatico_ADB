# --- INÍCIO DO MOTOR DE AUTOMAÇÃO (VERSÃO FINAL E ROBUSTA) ---

param(
    [Parameter(Mandatory=$false)]
    [string]$IpAddress
)

# --- Funções Auxiliares ---

function Get-ScreenData($adbTarget) {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Write-Host "Capturando hierarquia da UI (Tentativa $attempt)..."
            Start-Sleep -Milliseconds 250
            $dumpOutput = adb $adbTarget shell uiautomator dump
            if ($LASTEXITCODE -ne 0 -or $dumpOutput -like "*ERROR*") {
                Write-Warning "Comando 'uiautomator dump' falhou. Tentando novamente..."
                Start-Sleep -Seconds 1; continue
            }
            if ($dumpOutput -match 'dumped to: (/[\w/.-]+\.xml)') {
                $dumpPath = $Matches[1].Trim()
            } else {
                Write-Warning "Não foi possível encontrar o caminho do dump XML. Tentando novamente..."
                Start-Sleep -Seconds 1; continue
            }
            if (Test-Path ".\view.xml") { Remove-Item ".\view.xml" }
            adb $adbTarget pull $dumpPath view.xml > $null
            if ((Test-Path ".\view.xml") -and (Get-Item ".\view.xml").Length -gt 0) {
                $xmlContent = Get-Content -Raw -Path ".\view.xml" -Encoding UTF8
                return [PSCustomObject]@{
                    Xml = [xml]$xmlContent
                    Hash = (Get-FileHash -Algorithm MD5 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($xmlContent)))).Hash
                }
            }
        } catch { Write-Warning "Exceção na tentativa $attempt. $_"; Start-Sleep -Seconds 1 }
    }
    Write-Error "Falha crítica ao capturar a UI após 3 tentativas."
    return $null
}

function Wait-For-ScreenChange($adbTarget, $initialHash, [ref]$newXmlData) {
    $timeoutSeconds = 10
    Write-Host "Aguardando alteração na tela (timeout de $timeoutSeconds segundos)..."
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $timeoutSeconds) {
        $currentScreenData = Get-ScreenData -adbTarget $adbTarget
        if ($currentScreenData -and $currentScreenData.Hash -ne $initialHash) {
            $stopwatch.Stop(); Write-Host "Tela alterada! Prosseguindo..."; $newXmlData.Value = $currentScreenData; return $true
        }
        Start-Sleep -Seconds 1
    }
    $stopwatch.Stop(); Write-Error "TIMEOUT: A tela não mudou após $timeoutSeconds segundos."; return $false
}

function Find-Element($xml, $keyword) {
    if (-not $xml -is [System.Xml.XmlDocument] -or -not $keyword) { return $null }
    $sanitizedKeyword = $keyword.Replace("'", "''").ToLower()
    $query = "//node[contains(translate(@text, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$sanitizedKeyword') or contains(translate(@content-desc, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$sanitizedKeyword')]"
    return $xml.SelectSingleNode($query)
}

# >>> FUNÇÕES DE AÇÃO ATUALIZADAS <<<
function Invoke-TapAction($adbTarget, $xml, $keyword) {
    $element = Find-Element -xml $xml -keyword $keyword
    if (-not $element) {
        Write-Warning "Elemento '$keyword' para tocar não foi encontrado na tela atual."
        return $false # Retorna falha
    }
    $bounds = $element.bounds
    if ($bounds -notmatch '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') { Write-Warning "Formato de 'bounds' inválido: $bounds"; return $false }
    $xMid = ([int]$Matches[1] + [int]$Matches[3]) / 2
    $yMid = ([int]$Matches[2] + [int]$Matches[4]) / 2
    $elementText = if ($element.text) { $element.text } else { $element.'content-desc' }
    Write-Host "Ação: Tocando em '$elementText'..."
    adb $adbTarget shell input tap "$xMid $yMid"
    return $true # Retorna sucesso
}

function Invoke-TypeAction($adbTarget, $textToType) {
    $formattedText = $textToType.Replace(' ', '%s')
    Write-Host "Ação: Digitando o texto '$textToType'..."
    adb $adbTarget shell input text "'$formattedText'"
    return $true # Assume sucesso
}


# --- Lógica Principal do Motor ---

Write-Host "Carregando receita do arquivo 'receita.json'..."
try { $receita = Get-Content -Raw -Path ".\receita.json" | ConvertFrom-Json } catch { Write-Error "Não foi possível encontrar ou ler o arquivo 'receita.json'."; exit }

$adbTarget = ""
if ($PSBoundParameters.ContainsKey('IpAddress')) {
    if ($IpAddress -notlike "*:*") { $IpAddress = "$IpAddress:5555" }
    Write-Host "Conectando e direcionando comandos para $IpAddress..."; adb connect $IpAddress > $null; $adbTarget = "-s $IpAddress"
}

$passoAtualNome = ($receita.PSObject.Properties | Where-Object { $_.Name -eq 'Inicio' }).Name
if (-not $passoAtualNome) { Write-Error "Ponto de partida 'Inicio' não encontrado na receita.json."; exit }

$maxPassos = 20; $passoCount = 0; $fatalError = $false

while ($passoAtualNome -and $passoAtualNome -ne "Fim" -and $passoAtualNome -ne "FimComErro" -and $passoCount -lt $maxPassos -and (-not $fatalError)) {
    $passoCount++
    $passoAtual = $receita.($passoAtualNome)
    if (-not $passoAtual) { Write-Error "O passo '$passoAtualNome' não foi encontrado."; $fatalError = $true; continue }

    Write-Host "---"; Write-Host "Passo ($passoCount/$maxPassos): $($passoAtual.Descricao) ($passoAtualNome)"
    
    $telaAtualData = Get-ScreenData $adbTarget
    if (-not $telaAtualData) { Write-Error "Não foi possível obter a hierarquia da UI."; $fatalError = $true; continue }

    # >>> LÓGICA DE AÇÃO E ESPERA REFEITA <<<
    if ($passoAtual.Acao -and $passoAtual.Acao.Tipo) {
        $hashAntesDaAcao = $telaAtualData.Hash
        $acaoBemSucedida = $false

        switch ($passoAtual.Acao.Tipo) {
            "Tocar"   { $acaoBemSucedida = Invoke-TapAction -adbTarget $adbTarget -xml $telaAtualData.Xml -keyword $passoAtual.Acao.ElementoComTexto }
            "Digitar" { $acaoBemSucedida = Invoke-TypeAction -adbTarget $adbTarget -textToType $passoAtual.Acao.Texto }
        }
        
        # Só espera por mudança na tela se a ação foi realmente executada
        if ($acaoBemSucedida) {
            $telaMudou = Wait-For-ScreenChange -adbTarget $adbTarget -initialHash $hashAntesDaAcao -newXmlData ([ref]$telaAtualData)
            if (-not $telaMudou) { $fatalError = $true; continue }
        }
    }

    # A verificação de transição usa os dados da tela mais recentes
    $xmlDaTela = $telaAtualData.Xml
    $proximoPassoDefinido = $false
    if ($passoAtual.Transicoes) {
        foreach ($transicao in $passoAtual.Transicoes) {
            if ($transicao.ChecarElementoComTexto -and (Find-Element $xmlDaTela $transicao.ChecarElementoComTexto)) {
                Write-Host "Condição satisfeita: Elemento '$($transicao.ChecarElementoComTexto)' encontrado. Indo para o passo '$($transicao.ProximoPasso)'."
                $passoAtualNome = $transicao.ProximoPasso; $proximoPassoDefinido = $true; break
            }
        }
    }

    if (-not $proximoPassoDefinido) {
        if ($passoAtual.ProximoPassoFinal) {
            $passoAtualNome = $passoAtual.ProximoPassoFinal
        } else {
            Write-Host "Nenhuma condição satisfeita. Seguindo para o passo padrão: '$($passoAtual.PassoPadrao)'."
            $passoAtualNome = $passoAtual.PassoPadrao
        }
    }
}

# --- Fim da Execução ---
Write-Host "---"
if ($passoAtualNome -eq "Fim") { Write-Host "Automação concluída com sucesso!" }
else { Write-Error "Automação finalizada. Estado final: $passoAtualNome" }

Remove-Item view.xml -ErrorAction SilentlyContinue