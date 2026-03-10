module tc_ack_nak;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
reg [31:0] d;
wire [31:0] out;
wire valid, ack;
pcie_dll_rx dut(.clk(clk), .rst_n(rst_n), .phy_data(d), .phy_valid(1'b1), .tlp_out(out), .tlp_valid(valid), .ack_out(ack));
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_ack_nak);
    d = 32'hA5A5_5A5A;
    #12 rst_n = 1; #20;
    if (!valid || !ack || out !== d) $fatal(1, "ACK path failed");
    $display("PASS: tc_ack_nak");
    $finish;
end
endmodule
