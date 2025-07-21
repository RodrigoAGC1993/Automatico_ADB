# --- INÍCIO DO MOTOR DE AUTOMAÇÃO ---

# Parâmetros do script (como antes)
param(
    [Parameter(Mandatory=$false)]
    [string]$IpAddress
)

# --- Funções Auxiliares ---

# Função para obter a hierarquia da UI atual
function Get-ScreenXml($adbTarget) {
    try {
        Write-Host "Capturando hierarquia da UI..."
        $dumpOutput = adb $adbTarget shell uiautomator dump
        if ($LASTEXITCODE -ne 0) { return $null }
        $dumpPath = $dumpOutput -match '[^ ]+.xml' | ForEach-Object { $_.Matches[0].Value }
        adb $adbTarget pull $dumpPath view.xml > $null
        return [xml](Get-Content view.xml)
    } catch {
        Write-Error "Falha ao capturar a UI."
        return $null
    }
}

# Função para verificar se um elemento existe na tela
function Test-ElementExists($xml, $keyword) {
    # Busca por texto ou descrição de conteúdo
    $node = $xml.SelectNodes("//node[@text and contains(@text, '$keyword')]")
    if ($node) { return $true }
    
    $node = $xml.SelectNodes("//node[@content-desc and contains(@content-desc, '$keyword')]")
    if ($node) { return $true }

    return $false
}

# Função para encontrar um elemento e retornar seus dados
function Find-Element($xml, $keyword) {
    $node = $xml.SelectSingleNode("//node[contains(@text, '$keyword') or contains(@content-desc, '$keyword')]")
    return $node
}

# Função para executar a ação de Tocar
function Invoke-Tap($adbTarget, $element) {
    if (-not $element) {
        Write-Error "Elemento para tocar não foi encontrado."
        return
    }
    $bounds = $element.bounds
    $bounds -match '\[(.*?)\]\[(.*?)\]'
    $p1 = $Matches[1] -split ','
    $p2 = [regex]::Split($Matches[2], ',')
    $xMid = ([int]$p1[0] + [int]$p2[0]) / 2
    $yMid = ([int]$p1[1] + [int]$p2[1]) / 2
    $coords = "$xMid $yMid"
    
    $elementText = if ($element.text) { $element.text } else { $element.'content-desc' }
    Write-Host "Ação: Tocando em '$elementText' nas coordenadas $coords"
    adb $adbTarget shell input tap $coords
}


# --- Lógica Principal do Motor ---

# 1. Configuração do Dispositivo (igual ao script anterior)
$adbTarget = ""
if ($PSBoundParameters.ContainsKey('IpAddress')) {
    if ($IpAddress -notlike "*:*") { $IpAddress = "$IpAddress:5555" }
    Write-Host "Conectando e direcionando comandos para $IpAddress..."
    adb connect $IpAddress > $null
    $adbTarget = "-s $IpAddress"
}

# 2. Loop de Execução da Automação
$passoAtualNome = 'Inicio' # Define o ponto de partida
$maxPassos = 20 # Um limite de segurança para evitar loops infinitos
$passoCount = 0

while ($passoAtualNome -ne "Fim" -and $passoAtualNome -ne "FimComErro" -and $passoCount -lt $maxPassos) {
    $passoCount++
    $passoAtual = $receita[$passoAtualNome]
    
    Write-Host "---"
    Write-Host "Passo ($passoCount/$maxPassos): $($passoAtual.Descricao) ($passoAtualNome)"
    
    # Captura o estado atual da tela
    $xmlDaTela = Get-ScreenXml $adbTarget
    if (-not $xmlDaTela) {
        $passoAtualNome = "ErroInesperado"
        continue
    }

    # Executa a ação definida para o passo atual
    if ($passoAtual.Acao) {
        switch ($passoAtual.Acao.Tipo) {
            "Tocar" {
                $elementoParaTocar = Find-Element $xmlDaTela $passoAtual.Acao.ElementoComTexto
                Invoke-Tap $adbTarget $elementoParaTocar
                Start-Sleep -Seconds 2 # Espera um pouco para a UI atualizar após o toque
            }
            # Futuramente, você pode adicionar outras ações aqui: "Digitar", "Rolar", etc.
        }
        # Após uma ação, é bom recapturar a tela para verificar a transição
        $xmlDaTela = Get-ScreenXml $adbTarget
    }

    # Decide qual será o próximo passo (Lógica de Bifurcação)
    $proximoPassoDefinido = $false
    foreach ($transicao in $passoAtual.Transicoes) {
        if (Test-ElementExists $xmlDaTela $transicao.ChecarElementoComTexto) {
            Write-Host "Condição satisfeita: Elemento '$($transicao.ChecarElementoComTexto)' encontrado. Indo para o passo '$($transicao.ProximoPasso)'."
            $passoAtualNome = $transicao.ProximoPasso
            $proximoPassoDefinido = $true
            break # Sai do loop de transições
        }
    }

    # Se nenhuma transição foi satisfeita, usa o passo padrão ou final
    if (-not $proximoPassoDefinido) {
        if ($passoAtual.ProximoPassoFinal) {
            $passoAtualNome = $passoAtual.ProximoPassoFinal
        } else {
            $passoAtualNome = $passoAtual.PassoPadrao
        }
    }
}

# --- Fim da Execução ---
Write-Host "---"
if ($passoAtualNome -eq "Fim") {
    Write-Host "Automação concluída com sucesso!"
} else {
    Write-Error "Automação finalizada. Estado final: $passoAtualNome"
}

# Limpeza
Remove-Item view.xml -ErrorAction SilentlyContinue