module pcie_crc16 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] data_in,
    input  wire        data_valid,
    input  wire        init,
    output reg  [15:0] crc_out
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        crc_out <= 16'hFFFF;
    end else if (init) begin
        crc_out <= 16'hFFFF;
    end else if (data_valid) begin
        crc_out <= {crc_out[14:0], 1'b0} ^ data_in ^ 16'h1021;
    end
end
endmodule
