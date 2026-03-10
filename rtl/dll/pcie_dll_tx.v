module pcie_dll_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] tlp_in,
    input  wire        tlp_valid,
    output reg  [31:0] phy_data,
    output reg         phy_valid,
    output reg  [11:0] seq_num
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        phy_data  <= 32'd0;
        phy_valid <= 1'b0;
        seq_num   <= 12'd0;
    end else begin
        phy_valid <= tlp_valid;
        if (tlp_valid) begin
            phy_data <= tlp_in;
            seq_num  <= seq_num + 12'd1;
        end
    end
end
endmodule
