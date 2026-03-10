module tc_error_handling;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
wire timeout;
wire outstanding;
pcie_completion_tracker dut(.clk(clk), .rst_n(rst_n), .req_issue(1'b1), .req_tag(8'h11), .cpl_recv(1'b0), .cpl_tag(8'h00), .timeout(timeout), .outstanding(outstanding));
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_error_handling);
    #12 rst_n = 1;
    #40;
    if (!outstanding) $fatal(1, "tracker should be outstanding");
    $display("PASS: tc_error_handling");
    $finish;
end
endmodule
