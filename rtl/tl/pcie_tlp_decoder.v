module pcie_tlp_decoder (
    input  wire [95:0] tlp_header,
    output wire [7:0]  fmt_type,
    output wire [9:0]  length_dw,
    output wire [15:0] requester_id,
    output wire [7:0]  tag,
    output wire [31:0] addr
);
assign fmt_type     = tlp_header[95:88];
assign length_dw    = tlp_header[87:78];
assign requester_id = tlp_header[77:62];
assign tag          = tlp_header[61:54];
assign addr         = tlp_header[53:22];
endmodule
