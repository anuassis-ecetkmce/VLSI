
`ifndef AXI_TYPES_SV
`define AXI_TYPES_SV


package axi_types_pkg;

	//virtual interface type
  	typedef virtual axi_if cfs_axi_vif;


// AXI basic parameters

  parameter int AXI_ID_WIDTH    = 4;
  parameter int AXI_ADDR_WIDTH  = 32;
  parameter int AXI_DATA_WIDTH  = 32;
  parameter int AXI_STRB_WIDTH  = AXI_DATA_WIDTH / 8;

  // AXI burst types (AWBURST / ARBURST)

  typedef enum logic [1:0] {
    AXI_BURST_FIXED = 2'b00,
    AXI_BURST_INCR  = 2'b01,
    AXI_BURST_WRAP  = 2'b10
  } axi_burst_t;

  // AXI response types (BRESP / RRESP)

  typedef enum logic [1:0] {
    AXI_RESP_OKAY   = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11
  } axi_resp_t;

  // AXI transfer size (AWSIZE / ARSIZE)
  // Number of bytes per beat = 2^size

  typedef enum logic [2:0] {
    AXI_SIZE_1B   = 3'b000,
    AXI_SIZE_2B   = 3'b001,
    AXI_SIZE_4B   = 3'b010,
    AXI_SIZE_8B   = 3'b011,
    AXI_SIZE_16B  = 3'b100,
    AXI_SIZE_32B  = 3'b101,
    AXI_SIZE_64B  = 3'b110,
    AXI_SIZE_128B = 3'b111
  } axi_size_t;

  // AXI lock type (AWLOCK / ARLOCK)

  typedef enum logic {
    AXI_LOCK_NORMAL = 1'b0,
    AXI_LOCK_EXCL   = 1'b1
  } axi_lock_t;

  // AXI cache encoding (AWCACHE / ARCACHE)
  typedef enum logic [3:0] {
    AXI_CACHE_DEVICE_NONBUF = 4'b0000,
    AXI_CACHE_DEVICE_BUF    = 4'b0001,
    AXI_CACHE_NORMAL_NONBUF = 4'b0010,
    AXI_CACHE_NORMAL_BUF    = 4'b0011
  } axi_cache_t;

  // AXI protection type (AWPROT / ARPROT)


  typedef enum logic [2:0] {
    AXI_PROT_UNPRIV_SECURE_DATA   = 3'b000,
    AXI_PROT_UNPRIV_SECURE_INST   = 3'b001,
    AXI_PROT_UNPRIV_NONSEC_DATA  = 3'b010,
    AXI_PROT_UNPRIV_NONSEC_INST  = 3'b011,
    AXI_PROT_PRIV_SECURE_DATA    = 3'b100,
    AXI_PROT_PRIV_SECURE_INST    = 3'b101,
    AXI_PROT_PRIV_NONSEC_DATA    = 3'b110,
    AXI_PROT_PRIV_NONSEC_INST    = 3'b111
  } axi_prot_t;

endpackage

`endif // AXI_TYPES_SV

