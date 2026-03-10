module tc_mem_read;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
wire mem_rd;
wire [31:0] payload;
pcie_tl_rx dut(.clk(clk), .rst_n(rst_n), .tlp_data(32'h0000_0001), .tlp_valid(1'b1), .mem_wr(), .mem_rd(mem_rd), .cfg_access(), .payload_out(payload));
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_mem_read);
    #12 rst_n = 1; #20;
    if (!mem_rd || payload !== 32'h0000_0001) $fatal(1, "mem read decode failed");
    $display("PASS: tc_mem_read");
    $finish;
end
endmodule
