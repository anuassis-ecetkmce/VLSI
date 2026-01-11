# AXI2APB BRIDGE VERIFICATION USING UVM

### 

### 1\. Introduction



 	Modern SoC designs integrate multiple IP blocks using different communication protocols. AXI is widely used for high-performance interconnects, while APB is used for low-power peripheral access. An AXI2APB bridge is required to enable communication between high-speed AXI masters and low-speed APB peripherals.



 	Verification of such protocol conversion is critical because any mismatch in address, data, or control timing can lead to system failures. This project focuses on developing a SystemVerilog UVM-based verification environment to validate the functional correctness of an AXI to APB bridge.



### 2\. Project Objective



The primary objectives of this project are:



* To design a reusable UVM-based verification environment for an AXI2APB bridge.
* To generate AXI transactions and ensure correct translation into APB protocol.
* To monitor both interfaces and verify:

 	\* Address mapping

 	\* Data integrity

 	\* Read/Write direction correctness

 	\*Response handling and error signaling



### 3\. Verification Methodology



The environment follows standard UVM layered architecture:



1. Test Layer &emsp;&emsp;– Controls test scenarios and sequences.
2. Environment Layer &emsp;– Integrates protocol agents and checking components.
3. Agent Layer &emsp;&emsp;– Encapsulates driver, sequencer, and monitor for each protocol.
4. Transaction Layer &emsp;– Defines protocol-specific sequence items.
5. Scoreboard &emsp;&emsp;– Compares AXI input transactions with APB output transactions.



### 4\. High-Level Architecture



#### UVM Structure



Test

 └── Environment
      ├── AXI Agent (Active)
      │     ├── Sequencer
      │     ├── Driver
      │     └── Monitor
      ├── APB Agent (Passive)
      │     └── Monitor
      └── Scoreboard



### 5\. File and Folder Structure



The verification environment is organized for clarity, reusability, and scalability.



uvm/
|
├── tb/				// Top-level testbench
|   └── testbench.sv		// DUT instantiation, interface binding, run\_test()
|
├── env/			// Environment and checking components
|   ├── axi2apb\_env.sv		// Integrates agents and scoreboard
|   ├── axi2apb\_scoreboard.sv	// Compares AXI and APB transactions
|   └── axi2apb\_cov.sv		// Functional coverage (optional)
|
├── tests/			// Test cases
|   ├── axi2apb\_test\_base.sv	// Base test class
|   ├── axi2apb\_test\_rw.sv	// Read/Write test
|   └── axi2apb\_test\_random.sv	// Randomized traffic test
|
├── axi\_vip/			// AXI verification IP
|   ├── axi\_if.sv		// AXI interface
|   ├── axi\_types.sv		// AXI typedefs, enums
|   ├── axi\_agent\_config.sv	// Configuration object
|   ├── axi\_agent.sv		// AXI agent
|   ├── axi\_sequencer.sv	// Sequencer
|   ├── axi\_driver.sv		// Driver
|   ├── axi\_monitor.sv		// Monitor
|   ├── axi\_item\_base.sv	// Base transaction
|   ├── axi\_item\_drv.sv		// Driver transaction
|   ├── axi\_item\_mon.sv		// Monitor transaction
|   ├── axi\_sequence\_base.sv	// Base sequence
|   ├── axi\_sequence\_rw.sv	// Read/Write sequence
|   └── axi\_sequence\_random.sv	// Random traffic
|
├── apb\_vip/			// APB verification IP
|  ├── apb\_if.sv		// APB interface
|  ├── apb\_types.sv		// APB typedefs, enums
|  ├── apb\_agent\_config.sv	// Configuration object
|  ├── apb\_agent.sv		// APB agent
|  ├── apb\_sequencer.sv		// Sequncer
|  ├──  apb\_driver.sv		// Driver
|  ├── apb\_monitor.sv		// Monitor
|  ├── apb\_item\_base.sv		// Base transaction
|  ├──	 apb\_item\_drv.sv	// Driver transaction
|  └── apb\_item\_mon.sv		// Monitor transaction
|
└── packages/			// Package files
   ├── axi\_pkg.sv		// AXI package
   ├── apb\_pkg.sv		// APB package
   └── axi2apb\_env\_pkg.sv	// Environment and test package





### 6\. Class Hierarchy Overview



##### AXI Side



axi\_item\_base        → uvm\_sequence\_item

axi\_item\_drv         → axi\_item\_base

axi\_item\_mon         → axi\_item\_base



axi\_sequencer        → uvm\_sequencer

axi\_driver           → uvm\_driver

axi\_monitor          → uvm\_monitor



axi\_sequence\_base    → uvm\_sequence

axi\_sequence\_rw      → axi\_sequence\_base

axi\_sequence\_random  → axi\_sequence\_base



axi\_agent\_config     → uvm\_component

axi\_agent            → uvm\_agent



##### APB Side



apb\_item\_base        → uvm\_sequence\_item

apb\_item\_mon         → apb\_item\_base



apb\_sequencer        → uvm\_sequencer

apb\_monitor          → uvm\_monitor

apb\_driver	     → uvm\_driver



apb\_agent\_config     → uvm\_component

apb\_agent            → uvm\_agent

