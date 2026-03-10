module tc_cfg_access;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
reg wr_en, rd_en;
wire [31:0] rd_data;
pcie_cfg_space dut(.clk(clk), .rst_n(rst_n), .wr_en(wr_en), .rd_en(rd_en), .addr_dw(10'd4), .wr_data(32'hCAFE_BABE), .rd_data(rd_data));
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_cfg_access);
    wr_en = 0; rd_en = 0;
    #12 rst_n = 1;
    #10 wr_en = 1; #10 wr_en = 0;
    #10 rd_en = 1; #10 rd_en = 0;
    #10;
    if (rd_data !== 32'hCAFE_BABE) $fatal(1, "cfg rw failed");
    $display("PASS: tc_cfg_access");
    $finish;
end
endmodule
