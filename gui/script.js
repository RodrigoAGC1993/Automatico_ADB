document.addEventListener('DOMContentLoaded', () => {
    const container = document.getElementById('drawflow');
    const generateJsonBtn = document.getElementById('generate-json-btn');
    const jsonOutput = document.getElementById('json-output');

    const editor = new Drawflow(container);
    editor.start();

    // --- A NOVA FUNÇÃO DE COLORAÇÃO ROBUSTA ---
    function forceEndpointColors() {
        // Pega todos os nós que estão no editor
        const allNodes = editor.getEditor().drawflow.Home.data;
        for (const nodeId in allNodes) {
            const nodeInfo = allNodes[nodeId];
            
            // Se for o nosso nó de decisão...
            if (nodeInfo.name === 'VerificarTela') {
                const nodeElement = document.getElementById('node-' + nodeId);
                if (nodeElement) {
                    // Encontra os pontos de conexão (endpoints)
                    const thenDot = nodeElement.querySelector('.output_1 .drawflow-dot');
                    const elseDot = nodeElement.querySelector('.output_2 .drawflow-dot');

                    // E força a cor diretamente no estilo do elemento
                    if (thenDot) {
                        thenDot.style.background = '#28a745'; // Verde
                    }
                    if (elseDot) {
                        elseDot.style.background = '#dc3545'; // Vermelho
                    }
                }
            }
        }
    }

    // --- EVENTOS DO DRAWFLOW QUE CHAMAM NOSSA FUNÇÃO ---
    // Usamos setTimeout para garantir que nosso código rode DEPOIS da API

    editor.on('nodeCreated', (id) => {
        setTimeout(forceEndpointColors, 0);
    });

    editor.on('connectionCreated', (connection) => {
        setTimeout(forceEndpointColors, 0);
    });

    editor.on('connectionRemoved', (connection) => {
        setTimeout(forceEndpointColors, 0);
    });
    
    // --- LÓGICA DE DRAG-AND-DROP (sem alterações) ---
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
                    html = `
                        <div class="node-title">👆 Ação: Tocar</div>
                        <div class="node-body">
                            <label>Elemento com Texto:</label>
                            <input type="text" df-elemento placeholder="Ex: 'Entrar' ou 'Próximo'">
                        </div>`;
                    break;
                case 'Digitar':
                    html = `
                        <div class="node-title">⌨️ Ação: Digitar</div>
                        <div class="node-body">
                            <label>Texto a Digitar:</label>
                            <input type="text" df-texto placeholder="Ex: 'meu_usuario'">
                        </div>`;
                    break;
                case 'VerificarTela':
                    outputs = 2;
                    html = `
                        <div class="node-title">❓ Verificar Tela (IF)</div>
                        <div class="if-node-body">
                            <label>Se encontrar elemento com texto:</label>
                            <input type="text" df-elemento placeholder="Ex: 'Bem-vindo'">
                        </div>
                        <div class="if-node-outputs">
                            <div class="then-label">THEN</div>
                            <div class="else-label">ELSE</div>
                        </div>`;
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

    // --- GERAÇÃO DO JSON (sem alterações) ---
    generateJsonBtn.addEventListener('click', () => {
        const exportedData = editor.export();
        const drawflowNodes = exportedData.drawflow.Home.data;
        const receita = {};

        for (const nodeId in drawflowNodes) {
            const node = drawflowNodes[nodeId];
            const nodeType = node.name;
            const properties = node.data;

            const thenConnection = node.outputs.output_1 ? node.outputs.output_1.connections[0] : null;
            const thenNodeId = thenConnection ? `passo_${thenConnection.node}` : null;

            const elseConnection = node.outputs.output_2 ? node.outputs.output_2.connections[0] : null;
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
            } else if (thenNodeId) {
                passo.Transicoes.push({
                    ChecarElementoComTexto: "*",
                    ProximoPasso: thenNodeId
                });
            }

            if (nodeType === 'Sucesso') passo.ProximoPassoFinal = "Fim";
            if (nodeType === 'Falha') passo.ProximoPassoFinal = "FimComErro";
            
            receita[`passo_${nodeId}`] = passo;
        }

        jsonOutput.textContent = JSON.stringify(receita, null, 2);
    });
});