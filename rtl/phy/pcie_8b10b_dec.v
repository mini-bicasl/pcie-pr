module pcie_8b10b_dec (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [9:0] code_in,
    input  wire       valid_in,
    output reg  [7:0] data_out,
    output reg        k_char_out,
    output reg        valid_out,
    output reg        code_err
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out   <= 8'd0;
        k_char_out <= 1'b0;
        valid_out  <= 1'b0;
        code_err   <= 1'b0;
    end else begin
        valid_out  <= valid_in;
        code_err   <= 1'b0;
        if (valid_in) begin
            k_char_out <= code_in[9];
            data_out   <= code_in[7:0];
        end
    end
end
endmodule
