# FPGA-Based-BiLSTM-for-Localization

This project implements position estimation (X, Y, Z coordinates) from Inertial Measurement Unit (IMU) data using a Bi-directional Long Short-Term Memory (BiLSTM) network. The model predicts position coordinates from sequences of IMU sensor data, including 3-axis acceleration and angular velocity measurements. To ensure robustness, the dataset is divided into different levels of complexity (easy, medium, and difficult).

This repository contains the complete RTL design, testbenches, weight/bias files, and supporting scripts for an FPGA-based hardware accelerator implementing this Inertial Network. The design is built around a BiLSTM core with fully connected layers to perform real-time localization on IMU data. It targets deployment on the Microchip PolarFire® SoC FPGA, leveraging its parallel processing capabilities, fixed-point hardware-friendly design (Q4.12), and on-chip memory resources for an efficient, low-power embedded solution.

## ✨ Project Highlights
- BiLSTM-based inertial position estimation
- Hardware-friendly fixed-point (Q4.12) implementation
- Verilog/SystemVerilog RTL hierarchy
- Parameterized memory initialization for weights/biases
- Separate weight sets for easy, medium, and difficult datasets
- Fully integrated testbenches and Python support scripts

---

## Network Architecture
The following diagram illustrates the architecture of the BiLSTM model used for position estimation:

![Block_Diagram](https://github.com/user-attachments/assets/6de97adc-6e68-434c-93c4-3af0c82c621c)

---

## 📂 Repository Structure

### Top-Level Files
- `Inertial_Network_System_Top.sv`, `Inertial_control_unit.sv`  
  → Top-level RTL modules for the full inertial network system  
- Testbenches:  
  - `Inertial_network_TOP_TB.sv`
- Memory initialization files (`.mem`):  
  - Weight and bias files for LSTM gates and FC layers  
  - E.g., `bilstm_weight_ih_l0_input_gate.mem`, `fc1_weight.mem`, etc.  
- Utility:  
  - `sourcefile.txt`, `run.txt`

---

### `/BiLSTM/`
- RTL implementation of the BiLSTM module  
- Includes:  
  - `BiLSTM_TOP.sv`, `BiLSTM_Control_Unit.sv`  
  - Submodules for FIFO, gate control, activation functions, and element-wise computation  
  - Nested hierarchy for:
    - **Activation_Function** (CORDIC-based tanh/sigmoid)
    - **Element_Wise** (Multipliers, Control Units)
    - **Gate** (Input/Hidden MACs, Gate Control)
    - **Memories** (Parameterized weight/bias memories)

---

### `/FC_bilstm/`
- RTL for fully connected layers following the BiLSTM
- Includes:  
  - `FC1_TOP.sv`, `FC2_TOP.sv`, `FCs_TOP.sv`  
  - Memory modules: `BIAS_MEM.sv`, `WEIGHT_MEM.sv`  
  - Testbenches for FC layers
  - MAC units and control logic

---

### `/ReLU/`
- `relu_function.v`: Simple RTL implementation of ReLU activation used between FC1 and FC2

---

### Weight/Memory Folders
Separate folders for weights/biases tailored to dataset difficulty:

- `/Easy_Weights/`
- `/Medium_Weights/`
- `/Difficult_Weights/`

✅ Contains fixed-point `.mem` files for:  
  - Input-to-hidden and hidden-to-hidden weights  
  - Gate biases  
  - FC layer weights and biases
⚠️ Usage Note:
When you want to simulate a specific difficulty level, copy the desired .mem files into the top-level directory. The simulation loads weights from this main location, so you need to move the appropriate set there before running.

---

### `/Test Inertial Network/`
- Python scripts to prepare test inputs and to compare both RTL outputs and software (python) outputs:
  - `Generate_inputs.py`, `compare_outputs.py`
- Pre-trained PyTorch models:
  - `imu_model_easy.pth`, `imu_model_medium.pth`, `imu_model_difficult.pth`
- Input/output data for simulation validation:
  - `input_memory_*.mem`, `test_inputs_*.txt`, `test_labels_*.txt`, `test_outputs_*.txt`
  - Normalized datasets in CSV

---

## 🛠️ How to Use
1. **Simulation**  
   - Compile RTL sources using your preferred simulator (e.g., ModelSim, Questa, Synopsys VCS)  
   - Example top-level testbench: `Inertial_network_TOP_TB.sv`  

2. **Weight Initialization**  
   - Choose difficulty level (Easy/Medium/Difficult)
   - Move the corresponding `.mem` files to the main directory  

3. **Python Support**  
   - Use provided scripts to verify outputs generated in `xyz_positions.txt`
   - Compare RTL output to high-level PyTorch model predictions

---

## ✅ Features
- **CORDIC-based tanh/sigmoid** for hardware-friendly activation
- **Fixed-point Q4.12** weight representation
- Parameterized memories for easy adaptation
- Modular design for clean integration
- Validated against PyTorch model outputs

---

## 📌 Requirements
- Verilog/SystemVerilog simulator
- Microchip Libero SoC (for synthesis / place-and-route targeting PolarFire)
- Python 3.x (for support scripts)

---

📦 Dataset
This project is originally based on The EuRoC MAV Dataset:
👉 [EuRoC MAV Dataset](https://projects.asl.ethz.ch/datasets/doku.php?id=kmavvisualinertialdatasets)
In this implementation, you don't need to download the dataset just to run simulations or test the RTL. All necessary input sequences, labels, and the high-level model outputs (from Python) are already exported and included in the repository.

✅ You only need to download the EuRoC dataset if you intend to retrain the model or generate new weight files.

---

## 🎯 Future Work
- Integration of Visual Network (CNN) alongside the Inertial Network
- Fusion Network combining outputs for better prediction accuracy
- Mapping functionality in addition to localization for a complete SLAM application
- Deployment on larger FPGA devices to accommodate combined models
- Live sensor interfacing (I2C, SPI, MIPI)
