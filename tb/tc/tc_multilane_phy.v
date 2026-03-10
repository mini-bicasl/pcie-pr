module tc_multilane_phy;
reg clk = 0; always #5 clk = ~clk;
reg rst_n = 0;
reg [31:0] dll_data;
reg dll_valid;
wire [39:0] serial_tx;
wire tx_valid;
wire [31:0] dll_data_rx;
wire dll_valid_rx;
wire code_err;
reg seen_valid;

pcie_phy_tx #(.LINK_WIDTH(4)) tx_dut (
    .clk(clk), .rst_n(rst_n), .dll_data(dll_data), .dll_valid(dll_valid),
    .serial_tx(serial_tx), .tx_valid(tx_valid)
);

pcie_phy_rx #(.LINK_WIDTH(4)) rx_dut (
    .clk(clk), .rst_n(rst_n), .serial_rx(serial_tx), .rx_valid({4{tx_valid}}),
    .dll_data(dll_data_rx), .dll_valid(dll_valid_rx), .code_err(code_err)
);

initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tc_multilane_phy);
    dll_data = 32'h0000_00A5;
    dll_valid = 0;
    seen_valid = 0;
    #12 rst_n = 1;
    #10 dll_valid = 1;
    #10 dll_valid = 0;
    repeat (6) begin
        #10;
        if (dll_valid_rx) seen_valid = 1;
    end
    if (serial_tx[9:0] !== serial_tx[19:10] ||
        serial_tx[9:0] !== serial_tx[29:20] ||
        serial_tx[9:0] !== serial_tx[39:30]) begin
        $fatal(1, "lane symbols mismatch");
    end
    if (!seen_valid || code_err) $fatal(1, "multilane rx output invalid");
    if (dll_data_rx[7:0] !== 8'hA5) $fatal(1, "multilane rx payload mismatch");
    $display("PASS: tc_multilane_phy");
    $finish;
end
endmodule
