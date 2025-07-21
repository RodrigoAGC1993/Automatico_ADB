# Define os parâmetros do script
param(
    # Palavra-chave para buscar na tela (obrigatório)
    [Parameter(Mandatory=$true)]
    [string]$Keyword,

    # Endereço IP do dispositivo Android (opcional)
    [Parameter(Mandatory=$false)]
    [string]$IpAddress
)

# --- Seção de Configuração do Dispositivo ---
$adbTarget = "" # Variável que guardará o alvo do ADB

# Verifica se o parâmetro -IpAddress foi fornecido
if ($PSBoundParameters.ContainsKey('IpAddress')) {
    Write-Host "Parâmetro -IpAddress fornecido."
    
    # Adiciona a porta padrão (5555) se não for especificada
    if ($IpAddress -notlike "*:*") {
        $IpAddress = "$IpAddress:5555"
        Write-Host "Porta não especificada, usando o padrão: $IpAddress"
    }

    Write-Host "Tentando conectar ao dispositivo em: $IpAddress..."
    adb connect $IpAddress
    
    # Define o alvo para todos os comandos adb subsequentes
    $adbTarget = "-s $IpAddress"
    Write-Host "Todos os comandos serão direcionados para o dispositivo $IpAddress."

} else {
    Write-Host "Nenhum IP especificado. Usando o dispositivo padrão (conectado via USB ou único emulador)."
}


# 1. Despejar e puxar a hierarquia da UI
Write-Host "Capturando a hierarquia da UI do dispositivo..."
try {
    # Adiciona a variável $adbTarget ao comando
    $dumpOutput = adb $adbTarget shell uiautomator dump
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Falha ao executar 'uiautomator dump'. Verifique a conexão com o dispositivo ($IpAddress)."
        exit
    }
    $dumpPath = $dumpOutput -match '[^ ]+.xml' | ForEach-Object { $_.Matches[0].Value }
    # Adiciona a variável $adbTarget ao comando
    adb $adbTarget pull $dumpPath view.xml
} catch {
    Write-Error "Ocorreu um erro ao capturar a UI. Certifique-se de que o 'adb' está no seu PATH e o dispositivo está acessível."
    exit
}


# 2. Analisar o XML
$xml = [xml](Get-Content view.xml)

# 3. Função de busca recursiva pelo nó com a palavra-chave
function Find-Node($node) {
    if (($node.text -like "*$Keyword*") -or ($node.'content-desc' -like "*$Keyword*")) {
        $node
    }
    foreach ($child in $node.node) {
        Find-Node $child
    }
}

# 4. Encontrar o nó e tratar o resultado
Write-Host "Procurando por um elemento com o texto: '$Keyword'..."
$foundNode = Find-Node $xml.hierarchy | Select-Object -First 1

if ($foundNode) {
    Write-Host "Elemento encontrado! Calculando coordenadas..."

    # 5. Extrair coordenadas e calcular o ponto médio
    $bounds = $foundNode.bounds
    $bounds -match '\[(.*?)\]\[(.*?)\]'
    $p1 = $Matches[1] -split ','
    $p2 = $Matches[2] -split ','
    $xMid = ([int]$p1[0] + [int]$p2[0]) / 2
    $yMid = ([int]$p1[1] + [int]$p2[1]) / 2
    $coords = "$xMid $yMid"

    # 6. Exibir coordenadas e preparar o comando de toque
    $elementText = if (-not [string]::IsNullOrEmpty($foundNode.text)) { $foundNode.text } else { $foundNode.'content-desc' }
    Write-Host "Coordenadas para '$elementText': $coords"

    # Adiciona a variável $adbTarget ao comando de toque
    $tapCommand = "adb $adbTarget shell input tap $coords"
    Write-Host "Comando para tocar: $tapCommand"
    
    # Para usar, remova o '#' da linha abaixo
    # Invoke-Expression $tapCommand

} else {
    Write-Error "Nenhum elemento com o texto '$Keyword' foi encontrado na tela atual."
}

# Limpa o arquivo XML baixado
Remove-Item view.xml