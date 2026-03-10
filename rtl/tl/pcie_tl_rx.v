module pcie_tl_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] tlp_data,
    input  wire        tlp_valid,
    output reg         mem_wr,
    output reg         mem_rd,
    output reg         cfg_access,
    output reg  [31:0] payload_out
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_wr <= 1'b0;
        mem_rd <= 1'b0;
        cfg_access <= 1'b0;
        payload_out <= 32'd0;
    end else begin
        mem_wr <= 1'b0;
        mem_rd <= 1'b0;
        cfg_access <= 1'b0;
        if (tlp_valid) begin
            payload_out <= tlp_data;
            case (tlp_data[1:0])
                2'b00: mem_wr <= 1'b1;
                2'b01: mem_rd <= 1'b1;
                default: cfg_access <= 1'b1;
            endcase
        end
    end
end
endmodule
