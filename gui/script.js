document.addEventListener('DOMContentLoaded', () => {
    const container = document.getElementById('drawflow');
    const generateJsonBtn = document.getElementById('generate-json-btn');
    const copyJsonBtn = document.getElementById('copy-json-btn');
    const jsonOutput = document.getElementById('json-output');

    const editor = new Drawflow(container);
    editor.start();
    editor.zoom_max = 1.6;
    editor.zoom_min = 0.4;
    editor.reroute = true;

    const keyEvents = [ "key_back", "key_home", "key_dpad_up", "key_dpad_down", "key_dpad_left", "key_dpad_right", "key_dpad_center", "key_volume_up", "key_volume_down", "key_power", "key_del", "key_enter", "key_escape", "key_menu", "key_app_switch" ];

    const observer = new MutationObserver(() => {
        const allNodes = editor.getEditor().drawflow.Home.data;
        for (const nodeId in allNodes) {
            const nodeInfo = allNodes[nodeId];
            const nodeElement = document.getElementById('node-' + nodeId);
            if (nodeElement) {
                if (nodeInfo.name === 'VerificarTela') {
                    const thenDot = nodeElement.querySelector('.output_1 .drawflow-dot');
                    const elseDot = nodeElement.querySelector('.output_2 .drawflow-dot');
                    if (thenDot) thenDot.style.background = '#34a853';
                    if (elseDot) elseDot.style.background = '#ea4335';
                }
                if (nodeInfo.name === 'Loop') {
                    const bodyDot = nodeElement.querySelector('.output_1 .drawflow-dot');
                    const endDot = nodeElement.querySelector('.output_2 .drawflow-dot');
                    if (bodyDot) bodyDot.style.background = '#007bff';
                    if (endDot) endDot.style.background = '#6c757d';
                }
            }
        }
    });
    observer.observe(container, { childList: true, subtree: true, attributes: true });

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

            const waitToggleHtml = `
                <div class="node-footer">
                    <span>Aguardar mudança na tela?</span>
                    <label class="toggle-switch">
                        <input type="checkbox" df-espera checked>
                        <span class="slider"></span>
                    </label>
                </div>`;

            switch (nodeName) {
                case 'Inicio':
                    inputs = 0;
                    html = `<div class="node-title">▶ Início</div>`;
                    break;
                case 'Tocar':
                    html = `<div class="node-title">👆 Ação: Tocar</div><div class="node-body"><label>Elemento com Texto:</label><input type="text" df-elemento></div>${waitToggleHtml}`;
                    data = { espera: true };
                    break;
                case 'Digitar':
                    html = `<div class="node-title">⌨️ Ação: Digitar</div><div class="node-body"><label>Texto a Digitar:</label><input type="text" df-texto></div>${waitToggleHtml}`;
                    data = { espera: true };
                    break;
                case 'KeyEvent':
                    const options = keyEvents.map(key => `<option value="${key}">${key.replace('key_', '').toUpperCase()}</option>`).join('');
                    html = `<div class="node-title">🔑 Ação: Evento de Tecla</div><div class="node-body"><label>Selecione o Evento:</label><select df-keyevent>${options}</select></div>${waitToggleHtml}`;
                    data = { espera: true, keyevent: keyEvents[0] };
                    break;
                case 'VerificarTela':
                    outputs = 2;
                    html = `<div class="node-title">❓ Verificar Tela (IF)</div>
                            <div class="if-node-body">
                                <label>Operador Lógico:</label>
                                <select df-operador class="operator-select">
                                    <option value="AND">E (todos devem ser verdadeiros)</option>
                                    <option value="OR">OU (pelo menos um deve ser verdadeiro)</option>
                                </select>
                                <div df-conditions>
                                    <div class="condition-row"><input type="text" placeholder="Elemento a verificar"><button onclick="removeCondition(this)">X</button></div>
                                </div>
                                <button class="add-condition-btn" onclick="addCondition(this)">+ Adicionar Condição</button>
                            </div>
                            <div class="if-node-outputs"><div class="then-label">THEN</div><div class="else-label">ELSE</div></div>`;
                    data = { operador: 'AND' };
                    break;
                case 'Loop':
                    outputs = 2;
                    html = `<div class="node-title">🔁 Loop</div>
                            <div class="loop-node-body">
                                <label>Tipo de Loop:</label>
                                <select df-loopType onchange="toggleLoopParams(this)">
                                    <option value="For">For (Repetir N vezes)</option>
                                    <option value="DoWhile">Do-While (Repetir até encontrar)</option>
                                </select>
                                <div class="loop-params" data-param="For">
                                    <label>Número de Repetições:</label>
                                    <input type="number" df-count value="5">
                                </div>
                                <div class="loop-params" data-param="DoWhile" style="display:none;">
                                    <label>Elemento da Condição de Parada:</label>
                                    <input type="text" df-conditionElement>
                                </div>
                            </div>
                            <div class="loop-outputs"><div class="loop-body-label">LOOP BODY</div><div class="loop-end-label">END LOOP</div></div>`;
                    data = { loopType: 'For', count: 5 };
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

    window.addCondition = function(button) {
        const newCondition = document.createElement('div');
        newCondition.className = 'condition-row';
        newCondition.innerHTML = '<input type="text" placeholder="Elemento a verificar"><button onclick="removeCondition(this)">X</button>';
        button.previousElementSibling.appendChild(newCondition);
    }
    window.removeCondition = function(button) {
        const conditionContainer = button.parentElement.parentElement;
        if (conditionContainer.children.length > 1) {
            button.parentElement.remove();
        }
    }
    window.toggleLoopParams = function(select) {
        const parent = select.closest('.loop-node-body');
        parent.querySelectorAll('.loop-params').forEach(p => p.style.display = 'none');
        parent.querySelector(`[data-param="${select.value}"]`).style.display = 'block';
    }

    generateJsonBtn.addEventListener('click', () => {
        const exportedData = editor.export();
        const drawflowNodes = exportedData.drawflow.Home.data;
        const receita = {};
        const visited = new Set();

        const startNodeId = Object.keys(drawflowNodes).find(id => drawflowNodes[id].name === 'Inicio');
        if (!startNodeId) { alert("Erro: Nenhum nó 'Início' encontrado no fluxo."); return; }

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
                PassoPadrao: elseNodeId || (nodeType !== 'VerificarTela' && nodeType !== 'Loop' ? thenNodeId : "ErroInesperado"),
                ProximoPassoFinal: null
            };

            if (nodeType === 'Tocar' || nodeType === 'Digitar' || nodeType === 'KeyEvent') {
                passo.Acao = { EsperaMudanca: properties.espera !== false };
                if (nodeType === 'Tocar') { passo.Acao.Tipo = "Tocar"; passo.Acao.ElementoComTexto = properties.elemento; }
                if (nodeType === 'Digitar') { passo.Acao.Tipo = "Digitar"; passo.Acao.Texto = properties.texto; }
                if (nodeType === 'KeyEvent') { passo.Acao.Tipo = "KeyEvent"; passo.Acao.Evento = properties.keyevent; }
            } else if (nodeType === 'VerificarTela') {
                const conditions = Array.from(document.querySelectorAll(`#node-${nodeId} [df-conditions] input`))
                                      .map(input => input.value).filter(val => val);
                passo.Transicoes.push({
                    Operador: properties.operador,
                    Condicoes: conditions,
                    ProximoPasso: thenNodeId
                });
            } else if (nodeType === 'Loop') {
                passo.Acao = {
                    Tipo: "Loop",
                    LoopType: properties.loopType,
                    Count: properties.count,
                    ConditionElement: properties.conditionElement,
                    LoopBodyPasso: thenNodeId,
                };
                passo.PassoPadrao = elseNodeId; // O que acontece depois do loop
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

    copyJsonBtn.addEventListener('click', () => {
        const jsonText = jsonOutput.textContent;
        if (jsonText) {
            navigator.clipboard.writeText(jsonText).then(() => {
                copyJsonBtn.innerHTML = '<i class="fa-solid fa-check"></i> Copiado!';
                setTimeout(() => { copyJsonBtn.innerHTML = '<i class="fa-solid fa-copy"></i> Copiar'; }, 2000);
            }).catch(err => { alert('Falha ao copiar o texto.'); });
        }
    });
});