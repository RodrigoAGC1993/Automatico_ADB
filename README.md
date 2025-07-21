# Apertar_botao.ps1

## Descrição
Este script PowerShell automatiza o toque em um elemento da interface do usuário (UI) em um dispositivo Android usando o ADB (Android Debug Bridge). Ele conecta ao dispositivo (via USB ou IP), captura a hierarquia atual da UI, busca um elemento da UI por uma palavra-chave especificada (que corresponde ao texto ou descrição do conteúdo), calcula as coordenadas do elemento e gera um comando ADB para simular um toque nesse elemento.

## Pré-requisitos
- O ADB deve estar instalado e acessível no PATH do seu sistema.
- Um dispositivo Android conectado via USB ou acessível pela rede (com IP e porta 5555).
- PowerShell para executar o script.

## Parâmetros
- `-Keyword` (string, obrigatório): A palavra-chave para buscar nos textos ou descrições dos elementos da UI.
- `-IpAddress` (string, opcional): O endereço IP do dispositivo Android para conectar. Se não fornecido, o script usa o dispositivo padrão conectado via USB ou o único emulador.

## Uso
Abra o PowerShell e execute o script com o parâmetro obrigatório `Keyword`:

```powershell
.\Apertar_botao.ps1 -Keyword "TextoDoBotao"
```

Para conectar a um dispositivo pela rede, forneça o endereço IP (a porta 5555 será adicionada automaticamente se não especificada):

```powershell
.\Apertar_botao.ps1 -Keyword "TextoDoBotao" -IpAddress "192.168.1.100"
```

## Como funciona
1. Conecta ao dispositivo Android via ADB (usando IP se fornecido).
2. Captura a hierarquia da UI do dispositivo em um arquivo XML.
3. Analisa o XML para encontrar o primeiro elemento da UI que contenha a palavra-chave no texto ou na descrição do conteúdo.
4. Calcula as coordenadas do ponto médio dos limites do elemento.
5. Exibe o comando ADB para tocar no elemento nas coordenadas calculadas.
6. (Opcional) Você pode descomentar a linha no script para executar automaticamente o comando de toque.

## Observações
- Certifique-se de que seu dispositivo permite conexões ADB e depuração ativada.
- O script atualmente apenas exibe o comando de toque; para executá-lo automaticamente, remova o comentário da linha correspondente no script.
- O script remove o arquivo XML capturado após a execução.

## Licença
Este script é fornecido "no estado em que se encontra", sem garantias. Use por sua conta e risco.
