module tc_scrambler;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
reg [7:0] data_in;
wire [7:0] scr_out, descr_out;
wire v1, v2;
pcie_scrambler u1(.clk(clk), .rst_n(rst_n), .data_in(data_in), .valid_in(1'b1), .scramble_en(1'b1), .data_out(scr_out), .valid_out(v1));
pcie_descrambler u2(.clk(clk), .rst_n(rst_n), .data_in(scr_out), .valid_in(v1), .descramble_en(1'b1), .data_out(descr_out), .valid_out(v2));
initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_scrambler);
    #12 rst_n = 1; data_in = 8'hC3; #20;
    if (!v2 || descr_out !== 8'hC3) $fatal(1, "scrambler roundtrip failed");
    $display("PASS: tc_scrambler");
    $finish;
end
endmodule
