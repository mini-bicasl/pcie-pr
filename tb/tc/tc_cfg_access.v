module tc_cfg_access;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
reg wr_en, rd_en;
reg [9:0] addr_dw;
reg [31:0] wr_data;
reg corr_err;
reg uncorr_nf_err;
reg uncorr_fatal_err;
reg [31:0] err_header_log;
wire [31:0] rd_data;
wire err_cor_msg;
wire err_nonfatal_msg;
wire err_fatal_msg;
localparam AER_CAP_HDR_DW     = 10'h040;
localparam AER_COR_STATUS_DW  = 10'h044;
localparam AER_HEADER_LOG0_DW = 10'h048;
pcie_cfg_space dut(
    .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .rd_en(rd_en), .addr_dw(addr_dw), .wr_data(wr_data),
    .corr_err(corr_err), .uncorr_nf_err(uncorr_nf_err), .uncorr_fatal_err(uncorr_fatal_err), .err_header_log(err_header_log),
    .rd_data(rd_data), .err_cor_msg(err_cor_msg), .err_nonfatal_msg(err_nonfatal_msg), .err_fatal_msg(err_fatal_msg)
);
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_cfg_access);
    addr_dw = 10'd4;
    wr_data = 32'hCAFE_BABE;
    wr_en = 0; rd_en = 0;
    corr_err = 0;
    uncorr_nf_err = 0;
    uncorr_fatal_err = 0;
    err_header_log = 32'd0;
    #12 rst_n = 1;
    #10 wr_en = 1; #10 wr_en = 0;
    #10 rd_en = 1; #10 rd_en = 0;
    #10;
    if (rd_data !== 32'hCAFE_BABE) $fatal(1, "cfg rw failed");
    addr_dw = AER_CAP_HDR_DW;
    #10 rd_en = 1; #10 rd_en = 0;
    #10 if (rd_data[15:0] !== 16'h0001) $fatal(1, "AER capability header missing");
    err_header_log = 32'hDEAD_BEEF;
    corr_err = 1;
    #10 corr_err = 0;
    if (!err_cor_msg) $fatal(1, "correctable error message not asserted");
    addr_dw = AER_COR_STATUS_DW;
    #10 rd_en = 1; #10 rd_en = 0;
    #10 if (rd_data[0] !== 1'b1) $fatal(1, "correctable error status bit not set");
    addr_dw = AER_HEADER_LOG0_DW;
    #10 rd_en = 1; #10 rd_en = 0;
    #10 if (rd_data !== 32'hDEAD_BEEF) $fatal(1, "AER header log not captured");
    err_header_log = 32'hBAD0_F00D;
    uncorr_nf_err = 1;
    #10 uncorr_nf_err = 0;
    if (!err_nonfatal_msg) $fatal(1, "non-fatal error message not asserted");
    uncorr_fatal_err = 1;
    #10 uncorr_fatal_err = 0;
    if (!err_fatal_msg) $fatal(1, "fatal error message not asserted");
    $display("PASS: tc_cfg_access");
    $finish;
end
endmodule
