module tc_ltssm;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
wire [2:0] state;
wire link_up;
pcie_ltssm dut(.clk(clk), .rst_n(rst_n), .rx_detect(1'b1), .elec_idle(1'b0), .ordered_set_valid(1'b1), .state(state), .link_up(link_up), .tx_ordered_set());
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_ltssm);
    #12 rst_n = 1; #40;
    if (!link_up) $fatal(1, "LTSSM did not reach L0");
    $display("PASS: tc_ltssm");
    $finish;
end
endmodule
