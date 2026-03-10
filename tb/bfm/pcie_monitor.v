module pcie_monitor (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [9:0] link_data,
    input  wire       link_valid,
    output reg  [31:0] pkt_count
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pkt_count <= 32'd0;
    else if (link_valid)
        pkt_count <= pkt_count + 1'b1;
end
endmodule
