# Automação Visual com ADB e PowerShell

Este projeto oferece uma solução para automação de interações em dispositivos Android utilizando ADB (Android Debug Bridge) e uma interface visual para construção de fluxos de automação.

---

## Componentes do Projeto

### 1. Script PowerShell: `Apertar_botao.ps1`

Este script automatiza o toque em elementos da interface do usuário (UI) de um dispositivo Android. Ele conecta ao dispositivo via ADB, captura a hierarquia da UI, busca um elemento por palavra-chave e gera o comando para simular o toque.

#### Pré-requisitos

- ADB instalado e acessível no PATH do sistema.
- Dispositivo Android conectado via USB ou pela rede (IP e porta 5555).
- PowerShell para executar o script.

#### Uso

```powershell
.\Apertar_botao.ps1 -Keyword "TextoDoBotao"
```

Para conectar via rede:

```powershell
.\Apertar_botao.ps1 -Keyword "TextoDoBotao" -IpAddress "192.168.1.100"
```

---

### 2. Construtor de Automação Visual (GUI)

Uma interface web para criação visual de fluxos de automação, utilizando a biblioteca [Drawflow](https://github.com/jerosoler/Drawflow). Permite arrastar e soltar ações e decisões para montar um fluxo lógico de automação.

#### Funcionalidades

- Nós representando ações como:
  - Início
  - Tocar (simula toque em elemento com texto)
  - Digitar (simula digitação de texto)
  - Verificar Tela (condicional IF baseado em texto de elemento)
  - Fim (Sucesso ou Falha)
- Geração de uma "Receita JSON" que representa o fluxo criado, com passos, ações e transições.

#### Como usar

1. Arraste os elementos da caixa de ferramentas para o espaço principal.
2. Configure os parâmetros de cada nó (ex: texto do elemento, texto a digitar).
3. Conecte os nós para definir o fluxo da automação.
4. Clique em "Gerar Receita JSON" para exportar o fluxo em formato JSON.
5. Utilize o JSON gerado para alimentar scripts ou sistemas que executem a automação.

---

## Estrutura de Arquivos

- `Apertar_botao.ps1`: Script PowerShell para automação via ADB.
- `gui/index.html`: Interface web do construtor visual.
- `gui/script.js`: Lógica do construtor visual.
- `gui/style.css`: Estilos da interface web.
- `Receita.json`: Exemplo ou arquivo gerado com a receita JSON da automação.
- `Run-Automation.ps1`: (Possível script para executar a automação, verificar conteúdo)

---

## Observações

- Certifique-se de que o dispositivo Android tenha a depuração USB ativada e permita conexões ADB.
- A interface visual facilita a criação de fluxos complexos sem necessidade de programação direta.
- O JSON gerado pode ser integrado a scripts para execução automatizada.

---

## Licença

Este projeto é fornecido "no estado em que se encontra", sem garantias. Use por sua conta e risco.

---
