module tc_error_handling;
localparam integer TIMEOUT_WAIT_CYCLES = 270; // 256 cycles to reach timer overflow + 14-cycle margin to reliably sample timeout pulse.
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
reg req_issue;
reg [7:0] req_tag;
reg cpl_recv;
reg [7:0] cpl_tag;
reg timeout_seen;
wire timeout;
wire outstanding;
pcie_completion_tracker dut(
    .clk(clk),
    .rst_n(rst_n),
    .req_issue(req_issue),
    .req_tag(req_tag),
    .cpl_recv(cpl_recv),
    .cpl_tag(cpl_tag),
    .timeout(timeout),
    .outstanding(outstanding)
);
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_error_handling);
    req_issue = 0;
    req_tag = 8'h11;
    cpl_recv = 0;
    cpl_tag = 8'h00;
    timeout_seen = 0;
    #12 rst_n = 1;
    req_issue = 1;
    #10 req_issue = 0;
    #20;
    if (!outstanding) $fatal(1, "tracker should be outstanding");
    cpl_recv = 1;
    cpl_tag = 8'h22;
    #10 cpl_recv = 0;
    if (!outstanding) $fatal(1, "outstanding cleared for wrong completion tag");
    cpl_recv = 1;
    cpl_tag = 8'h11;
    #10 cpl_recv = 0;
    if (outstanding) $fatal(1, "outstanding did not clear for matching completion tag");
    req_issue = 1;
    #10 req_issue = 0;
    // Timer is 8-bit and timeout pulses when it reaches 8'hFF; wait longer than 256 cycles to capture the pulse.
    repeat (TIMEOUT_WAIT_CYCLES) begin
        #10;
        if (timeout) timeout_seen = 1;
    end
    if (!timeout_seen) $fatal(1, "completion timeout was not asserted");
    $display("PASS: tc_error_handling");
    $finish;
end
endmodule
