document.addEventListener('DOMContentLoaded', () => {
    const container = document.getElementById('drawflow');
    const generateJsonBtn = document.getElementById('generate-json-btn');
    const copyJsonBtn = document.getElementById('copy-json-btn');
    const jsonOutput = document.getElementById('json-output');

    const editor = new Drawflow(container);
    editor.start();

    // Habilita o zoom com o scroll do mouse
    editor.zoom_max = 1.6;
    editor.zoom_min = 0.4;
    editor.reroute = true;

    // --- Lista de Key Events (baseado no seu JSON) ---
    const keyEvents = [
        "key_back", "key_home", "key_dpad_up", "key_dpad_down", "key_dpad_left", "key_dpad_right", "key_dpad_center",
        "key_volume_up", "key_volume_down", "key_power", "key_del", "key_enter", "key_escape", "key_menu", "key_app_switch"
        // Adicionei apenas os mais comuns para manter a lista gerenciável
    ];

    // --- Lógica de Coloração e Observação ---
    const observer = new MutationObserver(() => {
        const allNodes = editor.getEditor().drawflow.Home.data;
        for (const nodeId in allNodes) {
            const nodeInfo = allNodes[nodeId];
            if (nodeInfo.name === 'VerificarTela') {
                const nodeElement = document.getElementById('node-' + nodeId);
                if (nodeElement) {
                    const thenDot = nodeElement.querySelector('.output_1 .drawflow-dot');
                    const elseDot = nodeElement.querySelector('.output_2 .drawflow-dot');
                    if (thenDot) thenDot.style.background = '#34a853';
                    if (elseDot) elseDot.style.background = '#ea4335';
                }
            }
        }
    });
    observer.observe(container, { childList: true, subtree: true });

    // --- Lógica de Drag-and-Drop ---
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
                // >>> NOVO NÓ KEYEVENT <<<
                case 'KeyEvent':
                    const options = keyEvents.map(key => `<option value="${key}">${key.replace('key_', '').toUpperCase()}</option>`).join('');
                    html = `<div class="node-title">🔑 Ação: Evento de Tecla</div><div class="node-body"><label>Selecione o Evento:</label><select df-keyevent>${options}</select></div>`;
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

    // --- Geração e Cópia do JSON ---
    generateJsonBtn.addEventListener('click', () => {
        const exportedData = editor.export();
        const drawflowNodes = exportedData.drawflow.Home.data;
        const receita = {};
        const visited = new Set();

        const startNodeId = Object.keys(drawflowNodes).find(id => drawflowNodes[id].name === 'Inicio');
        if (!startNodeId) {
            alert("Erro: Nenhum nó 'Início' encontrado no fluxo.");
            return;
        }

        function traverse(nodeId) {
            if (!nodeId || visited.has(nodeId)) return;
            visited.add(nodeId);
            const node = drawflowNodes[nodeId];
            if (!node) return;

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
            } else if (nodeType === 'KeyEvent') { // >>> LÓGICA PARA KEYEVENT <<<
                passo.Acao = { Tipo: "KeyEvent", Evento: properties.keyevent };
            } else if (nodeType === 'VerificarTela') {
                passo.Transicoes.push({ ChecarElementoComTexto: properties.elemento, ProximoPasso: thenNodeId });
            }

            if (nodeType === 'Sucesso') passo.ProximoPassoFinal = "Fim";
            if (nodeType === 'Falha') passo.ProximoPassoFinal = "FimComErro";
            
            receita[passoNome] = passo;

            if (thenConnection) traverse(thenConnection.node);
            if (elseConnection) traverse(elseConnection.node);
        }

        traverse(startNodeId);
        jsonOutput.textContent = JSON.stringify(receita, null, 2);
    });

    // >>> LÓGICA DO BOTÃO COPIAR <<<
    copyJsonBtn.addEventListener('click', () => {
        const jsonText = jsonOutput.textContent;
        if (jsonText) {
            navigator.clipboard.writeText(jsonText).then(() => {
                copyJsonBtn.innerHTML = '<i class="fa-solid fa-check"></i> Copiado!';
                setTimeout(() => {
                    copyJsonBtn.innerHTML = '<i class="fa-solid fa-copy"></i> Copiar';
                }, 2000);
            }).catch(err => {
                alert('Falha ao copiar o texto.');
            });
        }
    });
});