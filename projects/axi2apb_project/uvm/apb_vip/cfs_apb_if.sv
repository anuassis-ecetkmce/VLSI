`ifndef CFS_APB_IF_SV
	`define CFS_APB_IF_SV

	`ifndef CFS_APB_MAX_DATA_WIDTH
		`define CFS_APB_MAX_DATA_WIDTH 32
	`endif

	`ifndef CFS_APB_MAX_ADDR_WIDTH
		`define CFS_APB_MAX_ADDR_WIDTH 16
	`endif

	interface cfs_apb_if(input pclk);

      logic preset_n;
      logic psel;
      logic penable;
      logic pwrite;
      logic pready;
      logic pslverr;
      
      logic [`CFS_APB_MAX_ADDR_WIDTH-1:0] paddr;
      logic [`CFS_APB_MAX_DATA_WIDTH-1:0] pwdata;
      logic [`CFS_APB_MAX_DATA_WIDTH-1:0] prdata;
      
	endinterface


`endif