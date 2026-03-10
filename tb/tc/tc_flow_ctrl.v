module tc_flow_ctrl;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
wire can_send;
wire [7:0] ph, pd;
reg init_valid;
reg consume;
reg return_credit;
pcie_flow_ctrl dut(.clk(clk), .rst_n(rst_n), .init_ph(8'd2), .init_pd(8'd2), .init_valid(init_valid), .consume_ph(consume), .consume_pd(consume), .return_credit(return_credit), .avail_ph(ph), .avail_pd(pd), .can_send(can_send));
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_flow_ctrl);
    init_valid = 1'b0; consume = 1'b0; return_credit = 1'b0;
    #12 rst_n = 1; init_valid = 1; #10; init_valid = 0;
    consume = 1; #20; consume = 0;
    if (ph != 0 || pd != 0 || can_send) $fatal(1, "flow control credits mismatch");
    #10;
    if (ph != 0 || pd != 0) $fatal(1, "flow control underflowed");
    return_credit = 1'b1;
    #10;
    return_credit = 1'b0;
    if (ph != 1 || pd != 1 || !can_send) $fatal(1, "credit return not reflected");
    consume = 1'b1;
    return_credit = 1'b1;
    #10;
    consume = 1'b0; return_credit = 1'b0;
    if (ph != 1 || pd != 1) $fatal(1, "simultaneous consume/return should preserve credits");
    $display("PASS: tc_flow_ctrl");
    $finish;
end
endmodule
