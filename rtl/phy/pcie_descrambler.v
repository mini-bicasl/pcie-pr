module pcie_descrambler (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data_in,
    input  wire       valid_in,
    input  wire       descramble_en,
    output reg  [7:0] data_out,
    output reg        valid_out
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out  <= 8'd0;
        valid_out <= 1'b0;
    end else begin
        valid_out <= valid_in;
        data_out  <= descramble_en ? (data_in ^ 8'hA5) : data_in;
    end
end
endmodule
