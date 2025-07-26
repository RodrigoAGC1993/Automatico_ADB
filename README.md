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

### 3. Motor de Automação PowerShell

Este motor executa a automação baseada na "Receita JSON" gerada pela interface visual, interagindo com o dispositivo Android via ADB.

#### Versões do Motor

- `Run-Automation.ps1`: Versão robusta e final do motor de automação, que executa ações de toque e digitação, com detecção de mudanças na tela e transições condicionais.

- `Run-Automation-Updated.ps1`: Versão aprimorada do motor com as seguintes melhorias:
  - **Guardião ANR**: Detecta e trata automaticamente diálogos de "Aplicativo não está a responder" (ANR), tocando no botão "Aguardar" para tentar recuperar a aplicação.
  - **Suporte a Eventos de Tecla**: Permite enviar eventos de tecla como voltar, home, volume, entre outros.
  - **Estruturas de Repetição (Loops)**: Suporta loops do tipo For (n repetições) e DoWhile (repetição condicional).
  - **Avaliação Avançada de Condições**: Permite usar operadores AND/OR para transições condicionais mais complexas.
  - **Maior Robustez**: Aumenta o limite máximo de passos e melhora a lógica de pré-verificação e tratamento de erros.

#### Uso

Para executar o motor de automação, utilize um dos scripts conforme a necessidade:

```powershell
.\Run-Automation.ps1 [-IpAddress "192.168.1.100"]
```

ou

```powershell
.\Run-Automation-Updated.ps1 [-IpAddress "192.168.1.100"]
```

O parâmetro `-IpAddress` é opcional e permite conectar ao dispositivo Android via rede.

---

## Estrutura de Arquivos

- `Apertar_botao.ps1`: Script PowerShell para automação via ADB.
- `Run-Automation.ps1`: Motor de automação robusto para executar receitas JSON.
- `Run-Automation-Updated.ps1`: Motor de automação aprimorado com guardião ANR, eventos de tecla e loops.
- `gui/index.html`: Interface web do construtor visual.
- `gui/script.js`: Lógica do construtor visual.
- `gui/style.css`: Estilos da interface web.
- `Receita.json`: Exemplo ou arquivo gerado com a receita JSON da automação.

---

## Observações

- Certifique-se de que o dispositivo Android tenha a depuração USB ativada e permita conexões ADB.
- A interface visual facilita a criação de fluxos complexos sem necessidade de programação direta.
- O JSON gerado pode ser integrado a scripts para execução automatizada.

---

## Licença

Este projeto é fornecido "no estado em que se encontra", sem garantias. Use por sua conta e risco.

---
