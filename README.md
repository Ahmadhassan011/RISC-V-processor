# RISC-V Pipeline Visualizer

## Overview

This is a web-based RISC-V processor pipeline visualizer that allows users to simulate and visualize the execution of RISC-V assembly instructions through a 5-stage pipeline processor. The application provides an interactive interface to observe how instructions flow through the pipeline stages, register values, memory contents, and control signals in real-time.

## Features

- **Interactive Pipeline Visualization**: Step through each cycle of the RISC-V pipeline execution
- **Register and Memory Monitoring**: Track changes in register values and memory contents
- **Dual Simulation Modes**: 
  - Hardware simulation using Icarus Verilog (when available)
  - Software fallback simulation in Python
- **Example Programs**: Pre-loaded example RISC-V programs for quick testing
- **Instruction Input**: Support for both assembly and hex instruction formats
- **Execution Controls**: Play, pause, step forward/backward, and speed control
- **Performance Statistics**: Track instruction count, cycles, hazards, and stalls

## System Architecture

The application follows a client-server architecture with clear separation between frontend visualization and backend simulation processing:

**Frontend Architecture:**
- Single-page application built with vanilla JavaScript
- Tailwind CSS for responsive UI styling
- Real-time visualization of processor state changes
- Interactive controls for step-by-step execution

**Backend Architecture:**
- Flask web framework for API endpoints
- Subprocess integration with Icarus Verilog simulator
- File-based instruction processing
- JSON API for client-server communication

## Key Components

### Backend Components (`app.py`)
- **Flask Application**: Main web server handling HTTP requests
- **Simulation Controller**: Manages Verilog compilation and execution via subprocess calls
- **Instruction Processor**: Converts assembly instructions to hex format for simulation
- **API Endpoints**: 
  - `/` - Serves the main application interface
  - `/simulate` - Processes simulation requests and returns results
  - `/examples/<example_name>` - Serves example instruction files

### Frontend Components
- **RISCVVisualizer Class** (`static/script.js`): Main JavaScript controller managing:
  - User interaction handling
  - API communication with backend
  - Real-time UI updates
  - State management for cycle-by-cycle execution
- **Responsive UI** (`templates/index.html`): Interactive interface featuring:
  - Instruction input/upload capabilities
  - Register and memory visualization grids
  - Pipeline stage visualization
  - Execution controls (run, step, reset)

### Verilog Components
- **Processor Module** (`simulation/processor.v`): Core RISC-V processor implementation
- **Testbench** (`simulation/testbench.v`): Simulation driver and output generator
- **Basic Components**: Modular Verilog components including program counter, ALU, multiplexers

## Setup Instructions

### Prerequisites

- Python 3.6+
- Flask
- Icarus Verilog (optional, for hardware simulation)

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/riscv-pipeline-visualizer.git
   cd riscv-pipeline-visualizer
   ```

2. Install Python dependencies:
   ```
   pip install flask
   ```

3. (Optional) Install Icarus Verilog for hardware simulation:
   - **Windows**: Download from http://bleyer.org/icarus/
   - **Linux**: `sudo apt-get install iverilog`
   - **macOS**: `brew install icarus-verilog`

### Running the Application

1. Start the Flask server:
   ```
   python main.py
   ```

2. Open your web browser and navigate to:
   ```
   http://localhost:5000
   ```

## Usage

1. **Input Instructions**:
   - Type RISC-V assembly or hex instructions in the editor
   - Upload an instruction file
   - Select from pre-loaded examples

2. **Run Simulation**:
   - Click "Run" to start the simulation
   - Use the playback controls to navigate through cycles

3. **Analyze Results**:
   - Observe pipeline stages
   - Monitor register values (highlighted when changed)
   - Track memory contents
   - View performance statistics

## Example Programs

The repository includes several example programs in the `examples/` directory:

- `basic_arithmetic.hex`: Simple arithmetic operations
- `branch_control.hex`: Branch and control flow examples
- `logical_operations.hex`: Logical operation examples
- `memory_operations.hex`: Memory load/store operations
- `tutorial_program.hex`: Step-by-step tutorial program

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the [MIT License](LICENSE).

## Acknowledgments

- RISC-V Foundation for the instruction set architecture
- Icarus Verilog for the simulation engine
- Flask and Tailwind CSS for the web framework