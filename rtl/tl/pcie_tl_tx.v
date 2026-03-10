module pcie_tl_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  fmt_type,
    input  wire [31:0] addr,
    input  wire [31:0] payload,
    input  wire        send,
    output reg  [31:0] tlp_data,
    output reg         tlp_valid
);
wire [95:0] tlp_header;
pcie_tlp_encoder u_enc (
    .fmt_type(fmt_type),
    .length_dw(10'd1),
    .requester_id(16'h0001),
    .tag(8'h01),
    .addr(addr),
    .tlp_header(tlp_header)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tlp_data  <= 32'd0;
        tlp_valid <= 1'b0;
    end else begin
        tlp_valid <= send;
        if (send)
            tlp_data <= payload ^ tlp_header[31:0];
    end
end
endmodule
