module pcie_8b10b_enc (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data_in,
    input  wire       k_char_in,
    input  wire       rd_in,
    input  wire       valid_in,
    output reg  [9:0] code_out,
    output reg        rd_out,
    output reg        code_valid
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        code_out   <= 10'd0;
        rd_out     <= 1'b0;
        code_valid <= 1'b0;
    end else begin
        code_valid <= valid_in;
        if (valid_in) begin
            code_out <= {k_char_in, rd_in, data_in};
            rd_out   <= ~rd_in;
        end
    end
end
endmodule
