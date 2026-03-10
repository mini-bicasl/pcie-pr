module tc_ltssm;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
reg rx_detect;
reg elec_idle;
reg ordered_set_valid;
wire [2:0] state;
wire link_up;
wire [15:0] tx_ordered_set;
pcie_ltssm dut(
    .clk(clk),
    .rst_n(rst_n),
    .rx_detect(rx_detect),
    .elec_idle(elec_idle),
    .ordered_set_valid(ordered_set_valid),
    .state(state),
    .link_up(link_up),
    .tx_ordered_set(tx_ordered_set)
);
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_ltssm);
    rx_detect = 0;
    elec_idle = 0;
    ordered_set_valid = 0;
    #12 rst_n = 1;
    #10 rx_detect = 1;
    #10 ordered_set_valid = 1;
    #20;
    if (!link_up) $fatal(1, "LTSSM did not reach L0");
    if (state !== 3'd3 || tx_ordered_set !== 16'h0000) $fatal(1, "LTSSM L0 outputs mismatch");
    elec_idle = 1;
    #10;
    if (state !== 3'd4 || link_up) $fatal(1, "LTSSM did not enter RECOV on electrical idle");
    if (tx_ordered_set !== 16'hBEEF) $fatal(1, "LTSSM RECOV ordered set mismatch");
    elec_idle = 0;
    #10;
    if (state !== 3'd3 || !link_up) $fatal(1, "LTSSM did not return to L0 from RECOV");
    $display("PASS: tc_ltssm");
    $finish;
end
endmodule
