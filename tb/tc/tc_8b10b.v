module tc_8b10b;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
reg [7:0] data_in;
wire [9:0] code;
wire [7:0] data_out;
wire valid_enc, valid_dec;

pcie_8b10b_enc enc(.clk(clk), .rst_n(rst_n), .data_in(data_in), .k_char_in(1'b0), .rd_in(1'b0), .valid_in(1'b1), .code_out(code), .rd_out(), .code_valid(valid_enc));
pcie_8b10b_dec dec(.clk(clk), .rst_n(rst_n), .code_in(code), .valid_in(valid_enc), .data_out(data_out), .k_char_out(), .valid_out(valid_dec), .code_err());

initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_8b10b);
    #12 rst_n = 1;
    data_in = 8'h5A;
    #20;
    if (!valid_dec || data_out !== 8'h5A) $fatal(1, "8b10b loopback failed");
    $display("PASS: tc_8b10b");
    $finish;
end
endmodule
