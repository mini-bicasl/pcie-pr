module tc_mem_write;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
wire [31:0] tlp;
wire valid;
pcie_tl_tx dut(.clk(clk), .rst_n(rst_n), .fmt_type(8'h00), .addr(32'h1000), .payload(32'hDEAD_BEEF), .send(1'b1), .tlp_data(tlp), .tlp_valid(valid));
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_mem_write);
    #12 rst_n = 1; #20;
    if (!valid) $fatal(1, "mem write TLP not produced");
    $display("PASS: tc_mem_write");
    $finish;
end
endmodule
