module pcie_phy_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [9:0]  serial_rx,
    input  wire        rx_valid,
    output wire [31:0] dll_data,
    output wire        dll_valid,
    output wire        code_err
);
wire [7:0] decoded;
wire       decoded_valid;
wire [7:0] descrambled;
pcie_8b10b_dec u_dec (
    .clk(clk), .rst_n(rst_n), .code_in(serial_rx), .valid_in(rx_valid),
    .data_out(decoded), .k_char_out(), .valid_out(decoded_valid), .code_err(code_err)
);
pcie_descrambler u_descr (
    .clk(clk), .rst_n(rst_n), .data_in(decoded), .valid_in(decoded_valid),
    .descramble_en(1'b1), .data_out(descrambled), .valid_out(dll_valid)
);
assign dll_data = {4{descrambled}};
endmodule
