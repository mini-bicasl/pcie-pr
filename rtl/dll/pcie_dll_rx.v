module pcie_dll_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] phy_data,
    input  wire        phy_valid,
    output reg  [31:0] tlp_out,
    output reg         tlp_valid,
    output reg         ack_out
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tlp_out   <= 32'd0;
        tlp_valid <= 1'b0;
        ack_out   <= 1'b0;
    end else begin
        tlp_valid <= phy_valid;
        ack_out   <= phy_valid;
        if (phy_valid) begin
            tlp_out <= phy_data;
        end
    end
end
endmodule
