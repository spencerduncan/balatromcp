// Balatro MCP Web UI JavaScript
class BalatroUI {
    constructor() {
        this.gameState = null;
        this.autoRefreshInterval = null;
        this.isAutoRefreshEnabled = true;
        this.connectionStatus = 'connecting';
        this.currentModal = null;
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.startAutoRefresh();
        this.checkServerHealth();
    }

    setupEventListeners() {
        // Auto refresh toggle
        document.getElementById('refreshToggle').addEventListener('click', () => {
            this.toggleAutoRefresh();
        });

        // Modal close events
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal')) {
                this.closeModal();
            }
        });

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeModal();
            }
        });
    }

    async checkServerHealth() {
        try {
            const response = await fetch('/health');
            const data = await response.json();
            if (data.status === 'ok') {
                this.setConnectionStatus('connected');
            } else {
                this.setConnectionStatus('disconnected');
            }
        } catch (error) {
            this.setConnectionStatus('disconnected');
            this.logAction('Health check failed: ' + error.message, 'error');
        }
    }

    setConnectionStatus(status) {
        this.connectionStatus = status;
        const statusElement = document.getElementById('connectionStatus');
        statusElement.className = `status-indicator ${status}`;
        
        const statusText = {
            'connected': 'Connected',
            'disconnected': 'Disconnected',
            'connecting': 'Connecting...'
        };
        
        statusElement.textContent = statusText[status] || 'Unknown';
    }

    toggleAutoRefresh() {
        this.isAutoRefreshEnabled = !this.isAutoRefreshEnabled;
        const button = document.getElementById('refreshToggle');
        
        if (this.isAutoRefreshEnabled) {
            this.startAutoRefresh();
            button.textContent = 'Auto Refresh: ON';
            button.className = 'btn btn-primary';
        } else {
            this.stopAutoRefresh();
            button.textContent = 'Auto Refresh: OFF';
            button.className = 'btn btn-secondary';
        }
    }

    startAutoRefresh() {
        if (this.autoRefreshInterval) {
            clearInterval(this.autoRefreshInterval);
        }
        
        this.fetchGameState(); // Initial fetch
        this.autoRefreshInterval = setInterval(() => {
            if (this.isAutoRefreshEnabled) {
                this.fetchGameState();
            }
        }, 2000);
    }

    stopAutoRefresh() {
        if (this.autoRefreshInterval) {
            clearInterval(this.autoRefreshInterval);
            this.autoRefreshInterval = null;
        }
    }

    async fetchGameState() {
        try {
            const response = await fetch('/state');
            const data = await response.json();
            
            if (data.status === 'success' && data.data) {
                this.gameState = data.data;
                this.updateUI();
                this.setConnectionStatus('connected');
            } else {
                this.setConnectionStatus('disconnected');
                this.logAction('No game state available', 'warning');
            }
        } catch (error) {
            this.setConnectionStatus('disconnected');
            this.logAction('Failed to fetch game state: ' + error.message, 'error');
        }
    }

    updateUI() {
        if (!this.gameState) return;

        this.updateGameOverview();
        this.updateHandCards();
        this.updateJokers();
        this.updateConsumables();
        this.updateBlindInfo();
        this.updateShopContents();
        this.updateAvailableActions();
    }

    updateGameOverview() {
        const coreState = this.gameState?.data?.state?.core_state;
        if (!coreState) return;
        
        this.setElementText('currentPhase', coreState.current_phase || 'Unknown');
        this.setElementText('currentAnte', coreState.ante || '0');
        this.setElementText('currentMoney', '$' + (coreState.money || '0'));
        this.setElementText('handsRemaining', coreState.hands_remaining || '0');
        this.setElementText('discardsRemaining', coreState.discards_remaining || '0');
        this.setElementText('sessionId', coreState.session_id || 'Unknown');
    }

    updateHandCards() {
        const container = document.getElementById('handCards');
        const cards = this.gameState?.data?.state?.card_data?.hand_cards || [];
        
        if (cards.length === 0) {
            container.innerHTML = '<div class="no-data">No hand cards available</div>';
            return;
        }

        container.innerHTML = cards.map((card, index) => {
            const suitClass = this.getSuitClass(card.suit);
            const suitSymbol = this.getSuitSymbol(card.suit);
            
            return `
                <div class="playing-card ${suitClass}" data-card-index="${index}" data-card-id="${card.id}">
                    <div class="card-rank">${card.rank || '?'}</div>
                    <div class="card-suit">${suitSymbol}</div>
                    ${card.enhancement ? `<div class="card-enhancement enhancement-${card.enhancement}"></div>` : ''}
                    ${card.edition ? `<div class="card-edition edition-${card.edition}"></div>` : ''}
                    ${card.seal ? `<div class="card-seal seal-${card.seal}"></div>` : ''}
                </div>
            `;
        }).join('');
    }

    updateJokers() {
        const container = document.getElementById('jokersList');
        const jokers = this.gameState?.data?.state?.core_state?.jokers || [];
        
        if (jokers.length === 0) {
            container.innerHTML = '<div class="no-data">No jokers available</div>';
            return;
        }

        container.innerHTML = jokers.map((joker, index) => `
            <div class="joker-card" data-joker-index="${index}" data-joker-id="${joker.id}">
                <div class="joker-name">${joker.name || 'Unknown Joker'}</div>
                <div class="joker-position">Position: ${joker.position || index + 1}</div>
                <div class="joker-properties">${this.formatJokerProperties(joker.properties)}</div>
            </div>
        `).join('');
    }

    updateConsumables() {
        const container = document.getElementById('consumablesList');
        const consumables = this.gameState?.data?.state?.core_state?.consumables || [];
        
        if (consumables.length === 0) {
            container.innerHTML = '<div class="no-data">No consumables available</div>';
            return;
        }

        container.innerHTML = consumables.map((consumable, index) => `
            <div class="consumable-card" data-consumable-index="${index}" data-consumable-id="${consumable.id}">
                <div class="consumable-name">${consumable.name || 'Unknown'}</div>
                <div class="consumable-type">${consumable.card_type || 'Consumable'}</div>
            </div>
        `).join('');
    }

    updateBlindInfo() {
        const container = document.getElementById('blindInfo');
        const blind = this.gameState?.data?.state?.core_state?.current_blind;
        
        if (!blind) {
            container.innerHTML = '<div class="no-data">No blind information available</div>';
            return;
        }

        container.innerHTML = `
            <div class="blind-name">${blind.name || 'Unknown Blind'}</div>
            <div class="blind-details">
                <div class="blind-detail">
                    <strong>Type:</strong><br>${blind.blind_type || 'Unknown'}
                </div>
                <div class="blind-detail">
                    <strong>Requirement:</strong><br>${blind.requirement || 'Unknown'}
                </div>
                <div class="blind-detail">
                    <strong>Reward:</strong><br>$${blind.reward || '0'}
                </div>
            </div>
        `;
    }

    updateShopContents() {
        const container = document.getElementById('shopContents');
        const shop = this.gameState?.data?.state?.core_state?.shop_contents || [];
        
        if (shop.length === 0) {
            container.innerHTML = '<div class="no-data">Shop not available</div>';
            return;
        }

        container.innerHTML = shop.map((item, index) => `
            <div class="shop-item" data-shop-index="${index}">
                <div class="shop-item-name">${item.name || 'Unknown Item'}</div>
                <div class="shop-item-type">${item.item_type || 'Item'}</div>
                <div class="shop-item-cost">$${item.cost || '0'}</div>
            </div>
        `).join('');
    }

    updateAvailableActions() {
        const container = document.getElementById('availableActions');
        const actions = this.gameState?.data?.state?.core_state?.available_actions || [];
        
        if (actions.length === 0) {
            container.innerHTML = '<div class="no-data">No actions available</div>';
            return;
        }

        container.innerHTML = actions.map(action => `
            <div class="action-item">${action}</div>
        `).join('');
    }

    // Utility methods
    setElementText(id, text) {
        const element = document.getElementById(id);
        if (element) {
            element.textContent = text;
        }
    }

    getSuitClass(suit) {
        const suitMap = {
            'Hearts': 'suit-hearts',
            'Diamonds': 'suit-diamonds',
            'Clubs': 'suit-clubs',
            'Spades': 'suit-spades'
        };
        return suitMap[suit] || 'suit-unknown';
    }

    getSuitSymbol(suit) {
        const symbolMap = {
            'Hearts': '♥',
            'Diamonds': '♦',
            'Clubs': '♣',
            'Spades': '♠'
        };
        return symbolMap[suit] || '?';
    }

    formatJokerProperties(properties) {
        if (!properties || typeof properties !== 'object') {
            return 'No properties';
        }
        
        return Object.entries(properties)
            .map(([key, value]) => `${key}: ${value}`)
            .join(', ');
    }

    // Command execution methods
    async executeCommand(command, params = {}) {
        try {
            this.logAction(`Executing command: ${command}`, 'info');
            
            const payload = {
                command: command,
                params: params,
                timestamp: new Date().toISOString()
            };

            const response = await fetch('/actions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            });

            const result = await response.json();
            
            if (result.status === 'success') {
                this.logAction(`Command executed successfully: ${command}`, 'success');
                // Refresh game state after command execution
                setTimeout(() => this.fetchGameState(), 500);
            } else {
                this.logAction(`Command failed: ${result.message || 'Unknown error'}`, 'error');
            }
            
            return result;
        } catch (error) {
            this.logAction(`Command execution error: ${error.message}`, 'error');
            throw error;
        }
    }

    // Modal and form methods
    showCardForm(command) {
        const cards = this.gameState?.data?.state?.card_data?.hand_cards || [];
        if (cards.length === 0) {
            this.logAction('No cards available for this action', 'warning');
            return;
        }

        let formHTML = '';
        
        if (command === 'play_hand' || command === 'discard_cards') {
            formHTML = `
                <div class="form-group">
                    <label>Select Cards (hold Ctrl for multiple):</label>
                    <select multiple size="8" id="cardIndices" style="height: 200px;">
                        ${cards.map((card, index) => 
                            `<option value="${index}">${card.rank || '?'} of ${card.suit || '?'}</option>`
                        ).join('')}
                    </select>
                </div>
            `;
        } else if (command === 'move_playing_card') {
            formHTML = `
                <div class="form-group">
                    <label>Card to Move:</label>
                    <select id="fromIndex">
                        ${cards.map((card, index) => 
                            `<option value="${index}">${card.rank || '?'} of ${card.suit || '?'}</option>`
                        ).join('')}
                    </select>
                </div>
                <div class="form-group">
                    <label>New Position:</label>
                    <input type="number" id="toIndex" min="0" max="${cards.length - 1}" value="0">
                </div>
            `;
        }

        this.showModal(`${command.replace('_', ' ').toUpperCase()}`, formHTML, () => {
            this.submitCardCommand(command);
        });
    }

    showIndexForm(command) {
        let items = [];
        let label = '';
        
        if (command.includes('joker')) {
            items = this.gameState?.data?.state?.core_state?.jokers || [];
            label = 'Select Joker:';
        } else if (command.includes('consumable')) {
            items = this.gameState?.data?.state?.core_state?.consumables || [];
            label = 'Select Consumable:';
        } else if (command.includes('buy_item')) {
            items = this.gameState?.data?.state?.core_state?.shop_contents || [];
            label = 'Select Shop Item:';
        }

        if (items.length === 0) {
            this.logAction('No items available for this action', 'warning');
            return;
        }

        const formHTML = `
            <div class="form-group">
                <label>${label}</label>
                <select id="itemIndex">
                    ${items.map((item, index) => 
                        `<option value="${index}">${item.name || `Item ${index + 1}`}</option>`
                    ).join('')}
                </select>
            </div>
        `;

        this.showModal(command.replace('_', ' ').toUpperCase(), formHTML, () => {
            this.submitIndexCommand(command);
        });
    }

    showReorderForm() {
        const jokers = this.gameState?.data?.state?.core_state?.jokers || [];
        if (jokers.length === 0) {
            this.logAction('No jokers available to reorder', 'warning');
            return;
        }

        const formHTML = `
            <div class="form-group">
                <label>From Position:</label>
                <select id="fromPosition">
                    ${jokers.map((joker, index) => 
                        `<option value="${index}">${joker.name || `Joker ${index + 1}`}</option>`
                    ).join('')}
                </select>
            </div>
            <div class="form-group">
                <label>To Position:</label>
                <input type="number" id="toPosition" min="0" max="${jokers.length - 1}" value="0">
            </div>
        `;

        this.showModal('REORDER JOKERS', formHTML, () => {
            this.submitReorderCommand();
        });
    }

    showModal(title, bodyHTML, submitCallback) {
        const modal = document.getElementById('commandModal');
        const modalTitle = document.getElementById('modalTitle');
        const modalBody = document.getElementById('modalBody');
        
        modalTitle.textContent = title;
        modalBody.innerHTML = bodyHTML;
        modal.style.display = 'block';
        
        this.currentModal = {
            submitCallback: submitCallback
        };
    }

    closeModal() {
        const modal = document.getElementById('commandModal');
        modal.style.display = 'none';
        this.currentModal = null;
    }

    submitCommand() {
        if (this.currentModal && this.currentModal.submitCallback) {
            this.currentModal.submitCallback();
        }
        this.closeModal();
    }

    submitCardCommand(command) {
        const params = {};
        
        if (command === 'play_hand' || command === 'discard_cards') {
            const select = document.getElementById('cardIndices');
            const selectedIndices = Array.from(select.selectedOptions).map(option => parseInt(option.value));
            params.card_indices = selectedIndices;
        } else if (command === 'move_playing_card') {
            params.from_index = parseInt(document.getElementById('fromIndex').value);
            params.to_index = parseInt(document.getElementById('toIndex').value);
        }

        this.executeCommand(command, params);
    }

    submitIndexCommand(command) {
        const index = parseInt(document.getElementById('itemIndex').value);
        const params = {};
        
        if (command.includes('joker')) {
            params.joker_index = index;
        } else if (command.includes('consumable')) {
            params.consumable_index = index;
        } else if (command === 'buy_item') {
            params.shop_index = index;
        }

        this.executeCommand(command, params);
    }

    submitReorderCommand() {
        const params = {
            from_position: parseInt(document.getElementById('fromPosition').value),
            to_position: parseInt(document.getElementById('toPosition').value)
        };

        this.executeCommand('reorder_jokers', params);
    }

    // Logging
    logAction(message, type = 'info') {
        const logContainer = document.getElementById('actionLog');
        const timestamp = new Date().toLocaleTimeString();
        
        const logEntry = document.createElement('div');
        logEntry.className = `log-entry ${type}`;
        logEntry.textContent = `[${timestamp}] ${message}`;
        
        logContainer.appendChild(logEntry);
        logContainer.scrollTop = logContainer.scrollHeight;
        
        // Keep only last 100 entries
        while (logContainer.children.length > 100) {
            logContainer.removeChild(logContainer.firstChild);
        }
    }
}

// Global command functions for button onclick handlers
let ui;

function executeCommand(command, params = {}) {
    if (ui) {
        ui.executeCommand(command, params);
    }
}

function showCardForm(command) {
    if (ui) {
        ui.showCardForm(command);
    }
}

function showIndexForm(command) {
    if (ui) {
        ui.showIndexForm(command);
    }
}

function showReorderForm() {
    if (ui) {
        ui.showReorderForm();
    }
}

function closeModal() {
    if (ui) {
        ui.closeModal();
    }
}

function submitCommand() {
    if (ui) {
        ui.submitCommand();
    }
}

// Initialize the UI when the page loads
document.addEventListener('DOMContentLoaded', function() {
    ui = new BalatroUI();
    window.balatroUI = ui; // Make it globally accessible for debugging
});