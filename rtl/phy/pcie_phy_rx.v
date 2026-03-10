module pcie_phy_rx #(
    parameter LINK_WIDTH = 1
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [LINK_WIDTH*10-1:0]  serial_rx,
    input  wire [LINK_WIDTH-1:0]     rx_valid,
    output wire [31:0] dll_data,
    output wire        dll_valid,
    output wire        code_err
);
wire [7:0] decoded;
wire       decoded_valid;
wire [7:0] descrambled;
wire       lane0_code_err;
pcie_8b10b_dec u_dec (
    .clk(clk), .rst_n(rst_n), .code_in(serial_rx[9:0]), .valid_in(rx_valid[0]),
    .data_out(decoded), .k_char_out(), .valid_out(decoded_valid), .code_err(lane0_code_err)
);
pcie_descrambler u_descr (
    .clk(clk), .rst_n(rst_n), .data_in(decoded), .valid_in(decoded_valid),
    .descramble_en(1'b1), .data_out(descrambled), .valid_out(dll_valid)
);
assign dll_data = {4{descrambled}};
assign code_err = lane0_code_err;
endmodule
