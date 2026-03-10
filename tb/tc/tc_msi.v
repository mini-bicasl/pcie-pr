module tc_msi;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
reg irq;
wire req;
pcie_msi dut(.clk(clk), .rst_n(rst_n), .msi_enable(1'b1), .irq_pulse(irq), .msi_req(req));
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_msi);
    irq = 0;
    #12 rst_n = 1;
    #10 irq = 1;
    #10 if (!req) $fatal(1, "msi not asserted");
    irq = 0;
    #10 if (req) $fatal(1, "msi did not clear");
    $display("PASS: tc_msi");
    $finish;
end
endmodule
