module tc_flow_ctrl;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
wire can_send;
wire [7:0] ph, pd;
reg init_valid;
reg consume;
pcie_flow_ctrl dut(.clk(clk), .rst_n(rst_n), .init_ph(8'd2), .init_pd(8'd2), .init_valid(init_valid), .consume_ph(consume), .consume_pd(consume), .return_credit(1'b0), .avail_ph(ph), .avail_pd(pd), .can_send(can_send));
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_flow_ctrl);
    init_valid = 0; consume = 0;
    #12 rst_n = 1; init_valid = 1; #10; init_valid = 0;
    consume = 1; #20; consume = 0;
    if (ph != 0 || pd != 0 || can_send) $fatal(1, "flow control credits mismatch");
    $display("PASS: tc_flow_ctrl");
    $finish;
end
endmodule
