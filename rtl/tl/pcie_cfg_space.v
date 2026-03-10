module pcie_cfg_space #(
    parameter DEPTH_DW = 1024
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire [9:0]  addr_dw,
    input  wire [31:0] wr_data,
    input  wire        corr_err,
    input  wire        uncorr_nf_err,
    input  wire        uncorr_fatal_err,
    input  wire [31:0] err_header_log,
    output reg  [31:0] rd_data,
    output reg         err_cor_msg,
    output reg         err_nonfatal_msg,
    output reg         err_fatal_msg
);
reg [31:0] cfg_mem [0:DEPTH_DW-1];
integer i;
localparam AER_CAP_HDR_DW      = 10'h040; // DWORD offset 0x40 (byte offset 0x100)
localparam AER_UC_STATUS_DW    = 10'h041;
localparam AER_UC_MASK_DW      = 10'h042;
localparam AER_COR_STATUS_DW   = 10'h044;
localparam AER_COR_MASK_DW     = 10'h045;
localparam AER_HEADER_LOG0_DW  = 10'h048;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < DEPTH_DW; i = i + 1) begin
            cfg_mem[i] <= 32'd0;
        end
        cfg_mem[0] <= 32'h1234_8086;
        cfg_mem[AER_CAP_HDR_DW] <= {12'h000, 4'h1, 16'h0001};
        cfg_mem[AER_UC_MASK_DW] <= 32'd0;
        cfg_mem[AER_COR_MASK_DW] <= 32'd0;
        rd_data <= 32'd0;
        err_cor_msg <= 1'b0;
        err_nonfatal_msg <= 1'b0;
        err_fatal_msg <= 1'b0;
    end else begin
        err_cor_msg <= 1'b0;
        err_nonfatal_msg <= 1'b0;
        err_fatal_msg <= 1'b0;
        if (wr_en && addr_dw < DEPTH_DW)
            cfg_mem[addr_dw] <= wr_data;
        if (rd_en && addr_dw < DEPTH_DW)
            rd_data <= cfg_mem[addr_dw];
        if (corr_err) begin
            cfg_mem[AER_COR_STATUS_DW] <= cfg_mem[AER_COR_STATUS_DW] | 32'h0000_0001;
            cfg_mem[AER_HEADER_LOG0_DW] <= err_header_log;
            if ((cfg_mem[AER_COR_MASK_DW] & 32'h0000_0001) == 32'd0)
                err_cor_msg <= 1'b1;
        end
        if (uncorr_nf_err) begin
            cfg_mem[AER_UC_STATUS_DW] <= cfg_mem[AER_UC_STATUS_DW] | 32'h0000_0002;
            cfg_mem[AER_HEADER_LOG0_DW] <= err_header_log;
            if ((cfg_mem[AER_UC_MASK_DW] & 32'h0000_0002) == 32'd0)
                err_nonfatal_msg <= 1'b1;
        end
        if (uncorr_fatal_err) begin
            cfg_mem[AER_UC_STATUS_DW] <= cfg_mem[AER_UC_STATUS_DW] | 32'h0000_0004;
            cfg_mem[AER_HEADER_LOG0_DW] <= err_header_log;
            if ((cfg_mem[AER_UC_MASK_DW] & 32'h0000_0004) == 32'd0)
                err_fatal_msg <= 1'b1;
        end
    end
end
endmodule
