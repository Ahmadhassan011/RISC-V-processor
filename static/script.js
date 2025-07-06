class RISCVVisualizer {
    constructor() {
        this.simulationData = [];
        this.currentCycle = 0;
        this.previousRegisters = new Array(32).fill(0);
        this.previousMemory = {};
        this.isAutoPlaying = false;
        this.autoPlayInterval = null;
        this.statistics = {
            instructions: 0,
            cycles: 0,
            hazards: 0,
            stalls: 0
        };
        
        this.initializeElements();
        this.initializeEventListeners();
        this.initializeRegisterGrid();
        this.initializeMemoryGrid();
        this.updateSpeedDisplay();
        this.handleExecutionModeChange();
    }

    initializeElements() {
        this.elements = {
            instructionsInput: document.getElementById('instructionsInput'),
            fileInput: document.getElementById('fileInput'),
            exampleSelect: document.getElementById('exampleSelect'),
            loadExampleBtn: document.getElementById('loadExampleBtn'),
            runBtn: document.getElementById('runBtn'),
            resetBtn: document.getElementById('resetBtn'),
            prevCycleBtn: document.getElementById('prevCycleBtn'),
            nextCycleBtn: document.getElementById('nextCycleBtn'),
            playBtn: document.getElementById('playBtn'),
            pauseBtn: document.getElementById('pauseBtn'),
            speedSlider: document.getElementById('speedSlider'),
            speedDisplay: document.getElementById('speedDisplay'),
            speedControl: document.getElementById('speedControl'),
            autoControls: document.getElementById('autoControls'),
            cycleDisplay: document.getElementById('cycleDisplay'),
            pcValue: document.getElementById('pcValue'),
            pipelineState: document.getElementById('pipelineState'),
            statusPanel: document.getElementById('statusPanel'),
            loadingState: document.getElementById('loadingState'),
            errorState: document.getElementById('errorState'),
            errorMessage: document.getElementById('errorMessage'),
            registerGrid: document.getElementById('registerGrid'),
            memoryGrid: document.getElementById('memoryGrid'),
            // Statistics elements
            statInstructions: document.getElementById('statInstructions'),
            statCycles: document.getElementById('statCycles'),
            statCPI: document.getElementById('statCPI'),
            statHazards: document.getElementById('statHazards'),
            statStalls: document.getElementById('statStalls'),
            statIPC: document.getElementById('statIPC')
        };
    }

    initializeEventListeners() {
        this.elements.runBtn.addEventListener('click', () => this.runSimulation());
        this.elements.resetBtn.addEventListener('click', () => this.reset());
        this.elements.prevCycleBtn.addEventListener('click', () => this.previousCycle());
        this.elements.nextCycleBtn.addEventListener('click', () => this.nextCycle());
        this.elements.playBtn.addEventListener('click', () => this.startAutoExecution());
        this.elements.pauseBtn.addEventListener('click', () => this.pauseAutoExecution());
        this.elements.fileInput.addEventListener('change', (e) => this.handleFileUpload(e));
        this.elements.exampleSelect.addEventListener('change', () => this.handleExampleSelect());
        this.elements.loadExampleBtn.addEventListener('click', () => this.loadSelectedExample());
        
        // Execution mode change handler
        document.querySelectorAll('input[name="executionMode"]').forEach(radio => {
            radio.addEventListener('change', () => this.handleExecutionModeChange());
        });
        
        // Speed slider handler
        this.elements.speedSlider.addEventListener('input', () => this.updateSpeedDisplay());
    }

    initializeRegisterGrid() {
        this.elements.registerGrid.innerHTML = '';
        for (let i = 0; i < 32; i++) {
            const registerCell = document.createElement('div');
            registerCell.id = `reg-${i}`;
            
            // Special styling for different register types
            let cellClass = 'register-cell rounded-xl p-3 text-center transition-all duration-300';
            if (i === 0) {
                cellClass += ' bg-gradient-to-br from-purple-900/50 to-purple-800/50 border-2 border-purple-500/30';
            } else if (i === 2 || i === 8) { // sp, fp
                cellClass += ' bg-gradient-to-br from-pink-900/30 to-pink-800/30 border-2 border-pink-500/20';
            } else {
                cellClass += ' bg-gradient-to-br from-slate-800/80 to-slate-700/60 border border-cyber-blue/20';
            }
            
            registerCell.className = cellClass;
            registerCell.innerHTML = `
                <div class="text-xs font-semibold mb-1 ${i === 0 ? 'text-purple-300' : i === 2 || i === 8 ? 'text-pink-300' : 'text-cyber-blue'}">
                    x${i}${i === 0 ? ' (zero)' : i === 2 ? ' (sp)' : i === 8 ? ' (fp)' : ''}
                </div>
                <div class="text-xs font-mono text-white font-bold">0x00000000</div>
            `;
            registerCell.addEventListener('mouseenter', () => this.showRegisterTooltip(i, registerCell));
            this.elements.registerGrid.appendChild(registerCell);
        }
    }

    initializeMemoryGrid() {
        this.elements.memoryGrid.innerHTML = '';
        for (let i = 0; i < 16; i++) {
            const memoryCell = document.createElement('div');
            memoryCell.id = `mem-${i * 4}`;
            memoryCell.className = 'memory-cell bg-gradient-to-br from-slate-800/80 to-slate-700/60 border border-cyber-orange/20 rounded-xl p-3 text-center transition-all duration-300';
            memoryCell.innerHTML = `
                <div class="text-xs font-semibold text-cyber-orange mb-1">
                    0x${(i * 4).toString(16).padStart(3, '0').toUpperCase()}
                </div>
                <div class="text-xs font-mono text-white font-bold">0x00000000</div>
            `;
            this.elements.memoryGrid.appendChild(memoryCell);
        }
    }

    async handleFileUpload(event) {
        const file = event.target.files[0];
        if (file) {
            const text = await file.text();
            this.elements.instructionsInput.value = text;
        }
    }

    handleExampleSelect() {
        const selectedValue = this.elements.exampleSelect.value;
        this.elements.loadExampleBtn.disabled = !selectedValue;
    }

    async loadSelectedExample() {
        const selectedExample = this.elements.exampleSelect.value;
        if (!selectedExample) return;

        try {
            this.showLoading(true);
            this.hideError();

            const response = await fetch(`/examples/${selectedExample}`);
            const result = await response.json();

            if (result.success) {
                // Clean the content by removing comments and empty lines
                const cleanContent = result.content
                    .split('\n')
                    .filter(line => line.trim() && !line.trim().startsWith('#'))
                    .join('\n');
                
                this.elements.instructionsInput.value = cleanContent;
                this.elements.exampleSelect.value = '';
                this.elements.loadExampleBtn.disabled = true;
                
                // Show success message briefly
                this.showSuccessMessage(`Loaded example: ${result.name.replace(/_/g, ' ')}`);
            } else {
                this.showError(`Failed to load example: ${result.error}`);
            }
        } catch (error) {
            this.showError(`Network error: ${error.message}`);
        } finally {
            this.showLoading(false);
        }
    }

    showSuccessMessage(message) {
        const successEl = document.createElement('div');
        successEl.className = 'fixed top-4 right-4 bg-gradient-to-r from-cyber-green to-emerald-500 text-white px-6 py-3 rounded-xl shadow-lg z-50 transform transition-all duration-300';
        successEl.innerHTML = `
            <div class="flex items-center space-x-2">
                <span>✅</span>
                <span>${message}</span>
            </div>
        `;
        
        document.body.appendChild(successEl);
        
        setTimeout(() => {
            successEl.style.transform = 'translateX(100%)';
            setTimeout(() => successEl.remove(), 300);
        }, 2000);
    }

    async runSimulation() {
        const instructions = this.elements.instructionsInput.value.trim();
        
        if (!instructions) {
            this.showError('Please enter instructions or upload a file');
            return;
        }

        this.showLoading(true);
        this.hideError();

        try {
            const response = await fetch('/simulate', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ instructions })
            });

            const result = await response.json();

            if (result.success) {
                this.simulationData = result.data;
                this.currentCycle = 0;
                this.updateDisplay();
            } else {
                this.showError(result.error);
            }
        } catch (error) {
            this.showError(`Network error: ${error.message}`);
        } finally {
            this.showLoading(false);
        }
    }

    updateDisplay() {
        if (this.simulationData.length === 0) return;

        const cycleData = this.simulationData[this.currentCycle] || {
            cycle: this.currentCycle,
            pc: 0,
            registers: new Array(32).fill(0),
            pipeline: {
                if_id: { pc: 0, instruction: '00000013' },
                id_ex: { pc: 0, instruction: '00000013' },
                ex_mem: { pc: 0, alu_result: 0 },
                mem_wb: { pc: 0, result: 0 }
            },
            memory: {}
        };

        // Update cycle display
        this.elements.cycleDisplay.textContent = `Cycle: ${cycleData.cycle}`;
        this.elements.pcValue.textContent = `0x${cycleData.pc.toString(16).padStart(8, '0').toUpperCase()}`;

        // Update pipeline stages
        this.updatePipelineStage('if', cycleData.pipeline.if_id);
        this.updatePipelineStage('id', cycleData.pipeline.id_ex);
        this.updatePipelineStage('ex', cycleData.pipeline.ex_mem);
        this.updatePipelineStage('mem', cycleData.pipeline.mem_wb);
        this.updatePipelineStage('wb', cycleData.pipeline.mem_wb);

        // Update registers
        this.updateRegisters(cycleData.registers);

        // Update memory
        this.updateMemory(cycleData.memory);

        // Update control signals
        this.updateControlSignals(cycleData.control_signals || {});

        // Update statistics
        this.updateStatistics();

        // Update navigation buttons
        this.elements.prevCycleBtn.disabled = this.currentCycle === 0;
        this.elements.nextCycleBtn.disabled = this.currentCycle >= this.simulationData.length - 1;
        
        // Update auto mode controls
        if (this.simulationData.length > 0) {
            this.elements.playBtn.disabled = false;
        }
    }

    updatePipelineStage(stage, data) {
        const pcElement = document.getElementById(`${stage}-pc`);
        const instrElement = document.getElementById(`${stage}-instr`);
        const aluElement = document.getElementById(`${stage}-alu`);
        const dataElement = document.getElementById(`${stage}-data`);
        const resultElement = document.getElementById(`${stage}-result`);

        if (pcElement) {
            pcElement.textContent = `0x${(data.pc || 0).toString(16).padStart(8, '0').toUpperCase()}`;
        }
        
        if (instrElement) {
            const instruction = data.instruction || '00000013';
            instrElement.textContent = typeof instruction === 'string' ? instruction.toUpperCase() : instruction.toString(16).padStart(8, '0').toUpperCase();
        }
        
        if (aluElement) {
            aluElement.textContent = `0x${(data.alu_result || 0).toString(16).padStart(8, '0').toUpperCase()}`;
        }
        
        if (dataElement) {
            dataElement.textContent = `0x${(data.alu_result || 0).toString(16).padStart(8, '0').toUpperCase()}`;
        }
        
        if (resultElement) {
            resultElement.textContent = `0x${(data.result || 0).toString(16).padStart(8, '0').toUpperCase()}`;
        }
    }

    updateRegisters(registers) {
        for (let i = 0; i < 32; i++) {
            const registerCell = document.getElementById(`reg-${i}`);
            const valueElement = registerCell.querySelector('.font-mono');
            const newValue = registers[i] || 0;
            
            valueElement.textContent = `0x${newValue.toString(16).padStart(8, '0').toUpperCase()}`;
            
            // Highlight changed registers
            if (newValue !== this.previousRegisters[i]) {
                registerCell.classList.add('changed');
                setTimeout(() => registerCell.classList.remove('changed'), 1000);
            }
        }
        
        this.previousRegisters = [...registers];
    }

    updateMemory(memory) {
        for (let i = 0; i < 16; i++) {
            const address = i * 4;
            const memoryCell = document.getElementById(`mem-${address}`);
            const valueElement = memoryCell.querySelector('.font-mono');
            const newValue = memory[address] || 0;
            
            valueElement.textContent = `0x${newValue.toString(16).padStart(8, '0').toUpperCase()}`;
            
            // Highlight changed memory
            if (newValue !== this.previousMemory[address]) {
                memoryCell.classList.add('changed');
                setTimeout(() => memoryCell.classList.remove('changed'), 1000);
            }
        }
        
        this.previousMemory = { ...memory };
    }

    previousCycle() {
        if (this.currentCycle > 0) {
            this.currentCycle--;
            this.updateDisplay();
        }
    }

    nextCycle() {
        if (this.currentCycle < this.simulationData.length - 1) {
            this.currentCycle++;
            this.updateDisplay();
        }
    }

    reset() {
        this.simulationData = [];
        this.currentCycle = 0;
        this.previousRegisters = new Array(32).fill(0);
        this.previousMemory = {};
        this.pauseAutoExecution(); // Stop any auto execution
        
        this.elements.instructionsInput.value = '';
        this.elements.fileInput.value = '';
        this.hideError();
        
        // Reset display
        this.elements.cycleDisplay.textContent = 'Cycle: 0';
        this.elements.pcValue.textContent = '0x00000000';
        this.elements.pipelineState.textContent = 'Ready';
        
        // Reset pipeline stages
        ['if', 'id', 'ex', 'mem', 'wb'].forEach(stage => {
            const pcElement = document.getElementById(`${stage}-pc`);
            const instrElement = document.getElementById(`${stage}-instr`);
            if (pcElement) pcElement.textContent = '0x00000000';
            if (instrElement) instrElement.textContent = '00000013';
        });
        
        // Reset registers and memory
        this.initializeRegisterGrid();
        this.initializeMemoryGrid();
        
        // Reset statistics
        this.resetStatistics();
        
        this.elements.prevCycleBtn.disabled = true;
        this.elements.nextCycleBtn.disabled = true;
        this.elements.playBtn.disabled = true;
    }

    showLoading(show) {
        this.elements.loadingState.classList.toggle('hidden', !show);
        this.elements.runBtn.disabled = show;
    }

    showError(message) {
        this.elements.errorMessage.textContent = message;
        this.elements.errorState.classList.remove('hidden');
    }

    hideError() {
        this.elements.errorState.classList.add('hidden');
    }

    updateControlSignals(signals) {
        const signalNames = ['regwrite', 'memread', 'memwrite', 'branch', 'alusrc', 'memtoreg'];
        
        signalNames.forEach(signal => {
            const indicator = document.getElementById(`${signal}-indicator`);
            const value = document.getElementById(`${signal}-value`);
            
            if (indicator && value) {
                const isActive = signals[signal] || false;
                value.textContent = isActive ? '1' : '0';
                
                if (isActive) {
                    indicator.className = 'w-3 h-3 bg-cyber-green rounded-full active-signal';
                } else {
                    indicator.className = 'w-3 h-3 bg-gray-600 rounded-full';
                }
            }
        });
    }

    showRegisterTooltip(regNum, element) {
        const value = this.previousRegisters[regNum] || 0;
        const regNames = {
            0: 'zero (always 0)',
            1: 'ra (return address)',
            2: 'sp (stack pointer)',
            3: 'gp (global pointer)',
            4: 'tp (thread pointer)',
            8: 'fp (frame pointer)',
            10: 'a0 (argument/return)',
            11: 'a1 (argument)',
        };
        
        const name = regNames[regNum] || `general purpose`;
        element.title = `x${regNum} (${name}): ${value} (0x${value.toString(16).padStart(8, '0').toUpperCase()})`;
    }

    handleExecutionModeChange() {
        const selectedMode = document.querySelector('input[name="executionMode"]:checked').value;
        
        if (selectedMode === 'auto') {
            this.elements.speedControl.classList.remove('hidden');
            this.elements.autoControls.classList.remove('hidden');
        } else {
            this.elements.speedControl.classList.add('hidden');
            this.elements.autoControls.classList.add('hidden');
            this.pauseAutoExecution();
        }
    }

    updateSpeedDisplay() {
        const speed = this.elements.speedSlider.value;
        const speedMap = {
            1: '1.0s', 2: '0.9s', 3: '0.8s', 4: '0.6s', 5: '0.5s',
            6: '0.4s', 7: '0.3s', 8: '0.2s', 9: '0.15s', 10: '0.1s'
        };
        this.elements.speedDisplay.textContent = `${speedMap[speed] || '0.5s'}`;
    }

    getAutoExecutionSpeed() {
        const speed = parseInt(this.elements.speedSlider.value);
        const speedMap = {
            1: 1000, 2: 900, 3: 800, 4: 600, 5: 500,
            6: 400, 7: 300, 8: 200, 9: 150, 10: 100
        };
        return speedMap[speed] || 500;
    }

    startAutoExecution() {
        if (!this.simulationData || this.simulationData.length === 0) {
            this.showError('Please run simulation first');
            return;
        }

        this.isAutoPlaying = true;
        this.elements.playBtn.classList.add('hidden');
        this.elements.pauseBtn.classList.remove('hidden');
        this.elements.pipelineState.textContent = 'Auto Playing';

        const speed = this.getAutoExecutionSpeed();
        this.autoPlayInterval = setInterval(() => {
            if (this.currentCycle < this.simulationData.length - 1) {
                this.nextCycle();
            } else {
                this.pauseAutoExecution();
                this.elements.pipelineState.textContent = 'Completed';
            }
        }, speed);
    }

    pauseAutoExecution() {
        this.isAutoPlaying = false;
        if (this.autoPlayInterval) {
            clearInterval(this.autoPlayInterval);
            this.autoPlayInterval = null;
        }
        this.elements.playBtn.classList.remove('hidden');
        this.elements.pauseBtn.classList.add('hidden');
        this.elements.pipelineState.textContent = 'Paused';
    }

    updateStatistics() {
        if (!this.simulationData || this.simulationData.length === 0) {
            this.resetStatistics();
            return;
        }

        const currentData = this.simulationData[this.currentCycle];
        
        // Count instructions executed (non-NOP instructions)
        const totalInstructions = this.simulationData.filter(cycle => 
            cycle.pipeline && 
            cycle.pipeline.WB && 
            cycle.pipeline.WB.instruction && 
            cycle.pipeline.WB.instruction !== '00000013'
        ).length;

        // Calculate CPI (Cycles Per Instruction)
        const cpi = totalInstructions > 0 ? (this.currentCycle + 1) / totalInstructions : 0;
        
        // Calculate IPC (Instructions Per Cycle)
        const ipc = this.currentCycle > 0 ? totalInstructions / (this.currentCycle + 1) : 0;

        // Update statistics display
        this.elements.statInstructions.textContent = totalInstructions;
        this.elements.statCycles.textContent = this.currentCycle + 1;
        this.elements.statCPI.textContent = cpi.toFixed(2);
        this.elements.statIPC.textContent = ipc.toFixed(2);
        
        // Simulate hazard and stall detection (placeholder values)
        const hazards = Math.floor(totalInstructions * 0.1); // Assume 10% hazard rate
        const stalls = Math.floor(totalInstructions * 0.05); // Assume 5% stall rate
        
        this.elements.statHazards.textContent = hazards;
        this.elements.statStalls.textContent = stalls;
    }

    resetStatistics() {
        this.elements.statInstructions.textContent = '0';
        this.elements.statCycles.textContent = '0';
        this.elements.statCPI.textContent = '0.00';
        this.elements.statIPC.textContent = '0.00';
        this.elements.statHazards.textContent = '0';
        this.elements.statStalls.textContent = '0';
    }
}

// Initialize the visualizer when the page loads
document.addEventListener('DOMContentLoaded', () => {
    new RISCVVisualizer();
});
