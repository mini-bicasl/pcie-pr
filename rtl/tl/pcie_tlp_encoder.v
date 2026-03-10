module pcie_tlp_encoder (
    input  wire [7:0]  fmt_type,
    input  wire [9:0]  length_dw,
    input  wire [15:0] requester_id,
    input  wire [7:0]  tag,
    input  wire [31:0] addr,
    output wire [95:0] tlp_header
);
assign tlp_header = {fmt_type, length_dw, requester_id, tag, addr, 22'd0};
endmodule
