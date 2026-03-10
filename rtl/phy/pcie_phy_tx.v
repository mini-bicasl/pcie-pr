module pcie_phy_tx #(
    parameter LINK_WIDTH = 1
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] dll_data,
    input  wire        dll_valid,
    output wire [LINK_WIDTH*10-1:0]  serial_tx,
    output wire        tx_valid
);
wire [7:0] scrambled;
wire       scrambled_valid;
wire [9:0] serial_tx_lane0;
pcie_scrambler u_scr (
    .clk(clk), .rst_n(rst_n), .data_in(dll_data[7:0]), .valid_in(dll_valid),
    .scramble_en(1'b1), .data_out(scrambled), .valid_out(scrambled_valid)
);
pcie_8b10b_enc u_enc (
    .clk(clk), .rst_n(rst_n), .data_in(scrambled), .k_char_in(1'b0), .rd_in(1'b0),
    .valid_in(scrambled_valid), .code_out(serial_tx_lane0), .rd_out(), .code_valid(tx_valid)
);
genvar lane;
generate
    for (lane = 0; lane < LINK_WIDTH; lane = lane + 1) begin : g_lane_copy
        assign serial_tx[(lane*10)+:10] = serial_tx_lane0;
    end
endgenerate
endmodule
