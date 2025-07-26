# --- INÍCIO DO MOTOR DE AUTOMAÇÃO (VERSÃO FINAL COM "GUARDIÃO ANR") ---

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

function Test-ElementExists($xml, $keyword) {
    return (Find-Element -xml $xml -keyword $keyword) -ne $null
}

function Invoke-TapAction($adbTarget, $xml, $keyword) {
    $element = Find-Element -xml $xml -keyword $keyword
    if (-not $element) { Write-Warning "Elemento '$keyword' para tocar não foi encontrado."; return $false }
    $bounds = $element.bounds
    if ($bounds -notmatch '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') { Write-Warning "Formato de 'bounds' inválido: $bounds"; return $false }
    $xMid = ([int]$Matches[1] + [int]$Matches[3]) / 2
    $yMid = ([int]$Matches[2] + [int]$Matches[4]) / 2
    Write-Host "Ação: Tocando em '$($element.text)'..."
    adb $adbTarget shell input tap "$xMid $yMid"
    return $true
}

function Invoke-TypeAction($adbTarget, $textToType) {
    $formattedText = $textToType.Replace(' ', '%s')
    Write-Host "Ação: Digitando o texto '$textToType'..."
    adb $adbTarget shell input text "'$formattedText'"
    return $true
}

function Invoke-KeyEventAction($adbTarget, $keyEventName) {
    $keyEventMap = @{ "key_back" = 4; "key_home" = 3; "key_dpad_up" = 19; "key_dpad_down" = 20; "key_dpad_left" = 21; "key_dpad_right" = 22; "key_dpad_center" = 23; "key_volume_up" = 24; "key_volume_down" = 25; "key_power" = 26; "key_del" = 67; "key_enter" = 66; "key_escape" = 111; "key_menu" = 82; "key_app_switch" = 187 }
    if ($keyEventMap.ContainsKey($keyEventName)) {
        $keyCode = $keyEventMap[$keyEventName]
        Write-Host "Ação: Enviando evento de tecla '$keyEventName' (código $keyCode)..."
        adb $adbTarget shell input keyevent $keyCode
        return $true
    } else { Write-Warning "Evento de tecla '$keyEventName' desconhecido."; return $false }
}

function Evaluate-Conditions($xml, $conditionBlock) {
    if (-not $conditionBlock.Condicoes) { return $false }
    $operator = $conditionBlock.Operador
    $allConditions = $conditionBlock.Condicoes
    if ($operator -eq 'OR') {
        foreach ($condition in $allConditions) { if (Test-ElementExists $xml $condition) { return $true } }
        return $false
    } else {
        foreach ($condition in $allConditions) { if (-not (Test-ElementExists $xml $condition)) { return $false } }
        return $true
    }
}

# >>> NOVA FUNÇÃO "GUARDIÃO" PARA LIDAR COM ERROS DO SISTEMA <<<
function Handle-SystemDialogs($adbTarget, [ref]$screenData) {
    $xml = $screenData.Value.Xml
    # Verifica se o diálogo "não está a responder" (ANR) está na tela
    if (Test-ElementExists -xml $xml -keyword "não está a responder") {
        Write-Warning "Detectado diálogo 'IU não está a responder'. Tentando tocar em 'Aguardar'."
        $initialHash = $screenData.Value.Hash
        
        $tappedWait = Invoke-TapAction -adbTarget $adbTarget -xml $xml -keyword "Aguardar"
        
        if ($tappedWait) {
            # Espera o diálogo desaparecer
            $dialogDismissed = Wait-For-ScreenChange -adbTarget $adbTarget -initialHash $initialHash -newXmlData ([ref]$screenData)
            if (-not $dialogDismissed) {
                Write-Error "Tocou em 'Aguardar', mas o diálogo não desapareceu."
            }
            return $true # Indica que um diálogo foi tratado e o passo deve ser repetido
        } else {
            Write-Warning "Diálogo ANR detectado, mas o botão 'Aguardar' não foi encontrado."
            return $false
        }
    }
    return $false # Nenhum diálogo do sistema encontrado
}


# --- Lógica Principal do Motor ---

Write-Host "Carregando receita do arquivo 'receita.json'..."
try { $receita = Get-Content -Raw -Path ".\receita.json" -Encoding UTF8 | ConvertFrom-Json } catch { Write-Error "Não foi possível encontrar ou ler o arquivo 'receita.json'."; exit }

$adbTarget = ""
if ($PSBoundParameters.ContainsKey('IpAddress')) {
    if ($IpAddress -notlike "*:*") { $IpAddress = "$IpAddress:5555" }
    Write-Host "Conectando e direcionando comandos para $IpAddress..."; adb connect $IpAddress > $null; $adbTarget = "-s $IpAddress"
}

$passoAtualNome = ($receita.PSObject.Properties | Where-Object { $_.Name -eq 'Inicio' }).Name
if (-not $passoAtualNome) { Write-Error "Ponto de partida 'Inicio' não encontrado na receita.json."; exit }

$maxPassos = 100; $passoCount = 0; $fatalError = $false
$loopCounters = @{}
$callStack = [System.Collections.Stack]::new()

while ($passoAtualNome -and $passoAtualNome -ne "Fim" -and $passoAtualNome -ne "FimComErro" -and $passoCount -lt $maxPassos -and (-not $fatalError)) {
    $passoCount++
    $passoAtual = $receita.($passoAtualNome)
    if (-not $passoAtual) { Write-Error "O passo '$passoAtualNome' não foi encontrado."; $fatalError = $true; continue }

    Write-Host "---"; Write-Host "Passo ($passoCount/$maxPassos): $($passoAtual.Descricao) ($passoAtualNome)"
    
    # >>> NOVA LÓGICA DE PRÉ-VERIFICAÇÃO <<<
    $dialogHandled = $false
    do {
        $telaAtualData = Get-ScreenData $adbTarget
        if (-not $telaAtualData) { Write-Error "Não foi possível obter a hierarquia da UI."; $fatalError = $true; break }

        # O "Guardião" é chamado aqui. Ele atualiza $telaAtualData se lidar com um diálogo.
        $dialogHandled = Handle-SystemDialogs -adbTarget $adbTarget -screenData ([ref]$telaAtualData)

    } while ($dialogHandled -and (-not $fatalError)) # Continua no loop enquanto diálogos de erro estiverem sendo tratados

    if ($fatalError) { continue } # Se a captura da UI falhou, pula para o fim

    if ($passoAtual.Acao -and $passoAtual.Acao.Tipo) {
        $hashAntesDaAcao = $telaAtualData.Hash
        $acaoBemSucedida = $false

        switch ($passoAtual.Acao.Tipo) {
            "Tocar"    { $acaoBemSucedida = Invoke-TapAction -adbTarget $adbTarget -xml $telaAtualData.Xml -keyword $passoAtual.Acao.ElementoComTexto }
            "Digitar"  { $acaoBemSucedida = Invoke-TypeAction -adbTarget $adbTarget -textToType $passoAtual.Acao.Texto }
            "KeyEvent" { $acaoBemSucedida = Invoke-KeyEventAction -adbTarget $adbTarget -keyEventName $passoAtual.Acao.Evento }
            "Loop"     {
                if (-not $loopCounters.ContainsKey($passoAtualNome)) {
                    if ($passoAtual.Acao.LoopType -eq 'For') { $loopCounters[$passoAtualNome] = [int]$passoAtual.Acao.Count }
                }
                $acaoBemSucedida = $true
            }
        }
        
        if ($acaoBemSucedida -and $passoAtual.Acao.EsperaMudanca -ne $false -and $passoAtual.Acao.Tipo -ne 'Loop') {
            $telaMudou = Wait-For-ScreenChange -adbTarget $adbTarget -initialHash $hashAntesDaAcao -newXmlData ([ref]$telaAtualData)
            if (-not $telaMudou) { $fatalError = $true; continue }
        }
    }

    $xmlDaTela = $telaAtualData.Xml
    $proximoPassoDefinido = $false

    if ($passoAtual.Acao.Tipo -eq 'Loop') {
        $loopInfo = $passoAtual.Acao
        if ($loopInfo.LoopType -eq 'For') {
            if ($loopCounters[$passoAtualNome] -gt 0) {
                Write-Host "Loop 'For': Repetições restantes $($loopCounters[$passoAtualNome]). Entrando no corpo do loop."
                $loopCounters[$passoAtualNome]--
                $callStack.Push($passoAtualNome)
                $passoAtualNome = $loopInfo.LoopBodyPasso
            } else {
                Write-Host "Loop 'For' concluído. Saindo do loop."
                $loopCounters.Remove($passoAtualNome)
                $passoAtualNome = $passoAtual.PassoPadrao
            }
        } elseif ($loopInfo.LoopType -eq 'DoWhile') {
            if (-not (Test-ElementExists $xmlDaTela $loopInfo.ConditionElement)) {
                Write-Host "Loop 'DoWhile': Condição de parada não encontrada. Entrando no corpo do loop."
                $callStack.Push($passoAtualNome)
                $passoAtualNome = $loopInfo.LoopBodyPasso
            } else {
                Write-Host "Loop 'DoWhile': Condição de parada encontrada. Saindo do loop."
                $passoAtualNome = $passoAtual.PassoPadrao
            }
        }
        $proximoPassoDefinido = $true
    }
    
    if ((-not $proximoPassoDefinido) -and $passoAtual.Transicoes) {
        foreach ($transicao in $passoAtual.Transicoes) {
            if (Evaluate-Conditions $xmlDaTela $transicao) {
                Write-Host "Condição IF satisfeita. Indo para o passo '$($transicao.ProximoPasso)'."
                $passoAtualNome = $transicao.ProximoPasso; $proximoPassoDefinido = $true; break
            }
        }
    }

    if (-not $proximoPassoDefinido) {
        if (($passoAtual.PassoPadrao -eq $null) -and ($passoAtual.ProximoPassoFinal -eq $null) -and ($callStack.Count -gt 0)) {
            Write-Host "Fim do corpo do loop. Retornando para reavaliação do loop."
            $passoAtualNome = $callStack.Pop()
        } else {
            if ($passoAtual.ProximoPassoFinal) {
                $passoAtualNome = $passoAtual.ProximoPassoFinal
            } else {
                $passoAtualNome = $passoAtual.PassoPadrao
            }
        }
    }
}

# --- Fim da Execução ---
Write-Host "---"
if ($passoAtualNome -eq "Fim") { Write-Host "Automação concluída com sucesso!" }
else { Write-Error "Automação finalizada. Estado final: $passoAtualNome" }

Remove-Item view.xml -ErrorAction SilentlyContinue