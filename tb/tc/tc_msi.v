module tc_msi;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
reg irq;
reg msi_enable;
reg msix_enable;
reg [10:0] msix_vector;
reg msix_mask;
reg intx_enable;
reg intx_assert;
reg intx_deassert;
wire req;
wire msix_req;
wire [10:0] msix_vector_out;
wire [7:0] intx_msg_code;
wire intx_msg_valid;
pcie_msi dut(
    .clk(clk), .rst_n(rst_n), .msi_enable(msi_enable), .irq_pulse(irq),
    .msix_enable(msix_enable), .msix_vector(msix_vector), .msix_mask(msix_mask),
    .intx_enable(intx_enable), .intx_assert(intx_assert), .intx_deassert(intx_deassert),
    .msi_req(req), .msix_req(msix_req), .msix_vector_out(msix_vector_out),
    .intx_msg_code(intx_msg_code), .intx_msg_valid(intx_msg_valid)
);
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_msi);
    irq = 0;
    msi_enable = 1;
    msix_enable = 0;
    msix_vector = 11'h012;
    msix_mask = 0;
    intx_enable = 0;
    intx_assert = 0;
    intx_deassert = 0;
    #12 rst_n = 1;
    #10 irq = 1;
    #10 if (!req) $fatal(1, "msi not asserted");
    irq = 0;
    #10 if (req) $fatal(1, "msi did not clear");
    msi_enable = 0;
    irq = 1;
    #10 if (req) $fatal(1, "msi asserted while disabled");
    msi_enable = 0;
    msix_enable = 1;
    irq = 1;
    #10;
    if (!msix_req || msix_vector_out !== 11'h012) $fatal(1, "msix request/vector mismatch");
    msix_mask = 1;
    #10;
    if (msix_req) $fatal(1, "msix asserted while masked");
    irq = 0;
    msix_enable = 0;
    msix_mask = 0;
    intx_enable = 1;
    intx_assert = 1;
    #10;
    intx_assert = 0;
    if (!intx_msg_valid || intx_msg_code !== 8'h04) $fatal(1, "INTx assert message mismatch");
    #10;
    intx_deassert = 1;
    #10;
    intx_deassert = 0;
    if (!intx_msg_valid || intx_msg_code !== 8'h24) $fatal(1, "INTx deassert message mismatch");
    $display("PASS: tc_msi");
    $finish;
end
endmodule
