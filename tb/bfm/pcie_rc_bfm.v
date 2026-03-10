module pcie_rc_bfm (
    input  wire clk,
    input  wire rst_n,
    output reg  [31:0] tx_data,
    output reg         tx_valid,
    input  wire [31:0] rx_data,
    input  wire        rx_valid
);
task send_dw(input [31:0] data);
begin
    @(posedge clk);
    tx_data  <= data;
    tx_valid <= 1'b1;
    @(posedge clk);
    tx_valid <= 1'b0;
end
endtask

initial begin
    tx_data  = 32'd0;
    tx_valid = 1'b0;
end
endmodule
