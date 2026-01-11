# AXI2APB BRIDGE VERIFICATION USING UVM

### 

### 1\. Introduction



 	Modern SoC designs integrate multiple IP blocks using different communication protocols. AXI is widely used for high-performance interconnects, while APB is used for low-power peripheral access. An AXI2APB bridge is required to enable communication between high-speed AXI masters and low-speed APB peripherals.



 	Verification of such protocol conversion is critical because any mismatch in address, data, or control timing can lead to system failures. This project focuses on developing a SystemVerilog UVM-based verification environment to validate the functional correctness of an AXI to APB bridge.



### 2\. Project Objective

The primary objectives of this project are:

- To design a reusable UVM-based verification environment for an AXI2APB bridge.
- To generate AXI transactions and ensure correct translation into APB protocol.
- To monitor both interfaces and verify:
  - Address mapping  
  - Data integrity  
  - Read/Write direction correctness  
  - Response handling and error signaling  


### 3\. Verification Methodology

The environment follows standard UVM layered architecture:

1. **Test Layer** – Controls test scenarios and sequences.
2. **Environment Layer** – Integrates protocol agents and checking components.
3. **Agent Layer** – Encapsulates driver, sequencer, and monitor for each protocol.
4. **Transaction Layer** – Defines protocol-specific sequence items.
5. **Scoreboard** – Compares AXI input transactions with APB output transactions.


### 4\. High-Level Architecture

#### UVM Structure

```
Test
 └── Environment
      ├── AXI Agent
      │     ├── Sequencer
      │     ├── Driver
      │     └── Monitor
      ├── APB Agent
      │     ├── Sequencer
      │     ├── Driver
      │     └── Monitor
      └── Scoreboard
```


### 5\. File and Folder Structure

The verification environment is organized for clarity, reusability, and scalability.

```
uvm/
│
├── tb/                           // Top-level testbench
│   └── testbench.sv             // DUT instantiation, interface binding, run_test()
│
├── env/                          // Environment and checking components
│   ├── axi2apb_env.sv           // Integrates agents and scoreboard
│   ├── axi2apb_scoreboard.sv    // Compares AXI and APB transactions
│   └── axi2apb_cov.sv           // Functional coverage
│
├── tests/                        // Test cases
│   ├── axi2apb_test_base.sv      // Base test class
│   ├── axi2apb_test_rw.sv        // Read/Write test
│   └── axi2apb_test_random.sv    // Randomized traffic test
│
├── axi_vip/                      // AXI verification IP
│   ├── axi_if.sv                 // AXI interface
│   ├── axi_types.sv              // AXI typedefs, enums
│   ├── axi_agent_config.sv       // Configuration object
│   ├── axi_agent.sv              // AXI agent
│   ├── axi_sequencer.sv          // Sequencer
│   ├── axi_driver.sv             // Driver
│   ├── axi_monitor.sv            // Monitor
│   ├── axi_item_base.sv          // Base transaction
│   ├── axi_item_drv.sv           // Driver transaction
│   ├── axi_item_mon.sv           // Monitor transaction
│   ├── axi_sequence_base.sv      // Base sequence
│   ├── axi_sequence_rw.sv        // Read/Write sequence
│   └── axi_sequence_random.sv    // Random traffic
│
├── apb_vip/                      // APB verification IP
│   ├── apb_if.sv                 // APB interface
│   ├── apb_types.sv              // APB typedefs, enums
│   ├── apb_agent_config.sv       // Configuration object
│   ├── apb_agent.sv              // APB agent
│   ├── apb_sequencer.sv          // Sequencer
│   ├── apb_driver.sv             // Driver
│   ├── apb_monitor.sv            // Monitor
│   ├── apb_item_base.sv          // Base transaction
│   ├── apb_item_drv.sv           // Driver transaction
│   └── apb_item_mon.sv           // Monitor transaction
│
└── packages/                     // Package files
    ├── axi_pkg.sv                // AXI package
    ├── apb_pkg.sv                // APB package
    └── axi2apb_env_pkg.sv        // Environment and test package
```


### 6\. Class Hierarchy Overview

##### AXI Side

```
axi\_item\_base         → uvm\_sequence\_item
axi\_item\_drv          → axi\_item\_base
axi\_item\_mon          → axi\_item\_base

axi\_sequencer          → uvm\_sequencer
axi\_driver             → uvm\_driver
axi\_monitor            → uvm\_monitor

axi\_sequence\_base     → uvm\_sequence
axi\_sequence\_rw       → axi\_sequence\_base
axi\_sequence\_random   → axi\_sequence\_base

axi\_agent\_config      → uvm\_component
axi\_agent              → uvm\_agent
```

##### APB Side
```
apb\_item\_base         → uvm\_sequence\_item
apb\_item\_mon          → apb\_item\_base

apb\_sequencer          → uvm\_sequencer
apb\_monitor            → uvm\_monitor
apb\_driver             → uvm\_driver

apb\_agent\_config      → uvm\_component
apb\_agent              → uvm\_agent
```
