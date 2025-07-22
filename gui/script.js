document.addEventListener('DOMContentLoaded', () => {
    const container = document.getElementById('drawflow');
    const generateJsonBtn = document.getElementById('generate-json-btn');
    const jsonOutput = document.getElementById('json-output');

    const editor = new Drawflow(container);
    editor.start();

    const observer = new MutationObserver(() => {
        const allNodes = editor.getEditor().drawflow.Home.data;
        for (const nodeId in allNodes) {
            const nodeInfo = allNodes[nodeId];
            if (nodeInfo.name === 'VerificarTela') {
                const nodeElement = document.getElementById('node-' + nodeId);
                if (nodeElement) {
                    const thenDot = nodeElement.querySelector('.output_1 .drawflow-dot');
                    const elseDot = nodeElement.querySelector('.output_2 .drawflow-dot');
                    if (thenDot) thenDot.style.background = '#28a745';
                    if (elseDot) elseDot.style.background = '#dc3545';
                }
            }
        }
    });
    observer.observe(container, { childList: true, subtree: true });

    let draggedElement = null;
    document.querySelectorAll('.toolbox-item').forEach(item => {
        item.addEventListener('dragstart', (e) => {
            draggedElement = e.target.dataset.node;
        });
    });

    container.addEventListener('dragover', (e) => e.preventDefault());

    container.addEventListener('drop', (e) => {
        e.preventDefault();
        if (draggedElement) {
            const nodeName = draggedElement;
            const x = e.clientX * (1 / editor.zoom) - (editor.precanvas.getBoundingClientRect().x * (1 / editor.zoom));
            const y = e.clientY * (1 / editor.zoom) - (editor.precanvas.getBoundingClientRect().y * (1 / editor.zoom));
            
            let html = '';
            let inputs = 1;
            let outputs = 1;
            let data = {};

            switch (nodeName) {
                case 'Inicio':
                    inputs = 0;
                    html = `<div class="node-title">▶ Início</div>`;
                    break;
                case 'Tocar':
                    html = `<div class="node-title">👆 Ação: Tocar</div><div class="node-body"><label>Elemento com Texto:</label><input type="text" df-elemento placeholder="Ex: 'Entrar'"></div>`;
                    break;
                case 'Digitar':
                    html = `<div class="node-title">⌨️ Ação: Digitar</div><div class="node-body"><label>Texto a Digitar:</label><input type="text" df-texto placeholder="Ex: 'meu_usuario'"></div>`;
                    break;
                case 'VerificarTela':
                    outputs = 2;
                    html = `<div class="node-title">❓ Verificar Tela (IF)</div><div class="if-node-body"><label>Se encontrar elemento:</label><input type="text" df-elemento placeholder="Ex: 'Bem-vindo'"></div><div class="if-node-outputs"><div class="then-label">THEN</div><div class="else-label">ELSE</div></div>`;
                    break;
                case 'Sucesso':
                    outputs = 0;
                    html = `<div class="node-title">✅ Fim (Sucesso)</div>`;
                    break;
                case 'Falha':
                    outputs = 0;
                    html = `<div class="node-title">❌ Fim (Falha)</div>`;
                    break;
            }
            
            editor.addNode(nodeName, inputs, outputs, x, y, nodeName, data, html);
            draggedElement = null;
        }
    });

    // --- GERAÇÃO DO JSON (LÓGICA FINAL COM BUSCA EM PROFUNDIDADE - DFS) ---
    generateJsonBtn.addEventListener('click', () => {
        const exportedData = editor.export();
        const drawflowNodes = exportedData.drawflow.Home.data;
        const receita = {};
        const visited = new Set(); // Para evitar loops infinitos

        // 1. Encontrar o nó inicial
        const startNodeId = Object.keys(drawflowNodes).find(id => drawflowNodes[id].name === 'Inicio');
        if (!startNodeId) {
            alert("Erro: Nenhum nó 'Início' encontrado no fluxo. Por favor, adicione um.");
            return;
        }

        // 2. Função recursiva para percorrer o grafo (DFS)
        function traverse(nodeId) {
            if (!nodeId || visited.has(nodeId)) {
                return; // Se já visitou ou o nó é nulo, para.
            }
            
            visited.add(nodeId);
            const node = drawflowNodes[nodeId];
            if (!node) return;

            // --- Constrói o passo atual ---
            const nodeType = node.name;
            const properties = node.data;
            const passoNome = (nodeType === 'Inicio') ? 'Inicio' : `passo_${nodeId}`;

            const thenConnection = node.outputs.output_1?.connections[0];
            const thenNodeId = thenConnection ? `passo_${thenConnection.node}` : null;

            const elseConnection = node.outputs.output_2?.connections[0];
            const elseNodeId = elseConnection ? `passo_${elseConnection.node}` : null;

            const passo = {
                Descricao: `Passo ${nodeId}: ${nodeType}`,
                Acao: null,
                Transicoes: [],
                PassoPadrao: elseNodeId || (nodeType !== 'VerificarTela' ? thenNodeId : "ErroInesperado"),
                ProximoPassoFinal: null
            };

            if (nodeType === 'Tocar') {
                passo.Acao = { Tipo: "Tocar", ElementoComTexto: properties.elemento };
            } else if (nodeType === 'Digitar') {
                passo.Acao = { Tipo: "Digitar", Texto: properties.texto };
            }

            if (nodeType === 'VerificarTela') {
                passo.Transicoes.push({
                    ChecarElementoComTexto: properties.elemento,
                    ProximoPasso: thenNodeId
                });
            }

            if (nodeType === 'Sucesso') passo.ProximoPassoFinal = "Fim";
            if (nodeType === 'Falha') passo.ProximoPassoFinal = "FimComErro";
            
            receita[passoNome] = passo;
            // --- Fim da construção do passo ---

            // --- Chamada recursiva para os próximos nós ---
            // A ordem aqui é importante: primeiro o caminho THEN, depois o ELSE.
            if (thenConnection) {
                traverse(thenConnection.node);
            }
            if (elseConnection) {
                traverse(elseConnection.node);
            }
        }

        // 3. Inicia a travessia a partir do nó inicial
        traverse(startNodeId);

        jsonOutput.textContent = JSON.stringify(receita, null, 2);
    });
});