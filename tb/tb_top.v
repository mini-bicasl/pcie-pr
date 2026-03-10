module tb_top;
reg clk;
reg rst_n;
reg [31:0] app_tx_data;
reg app_tx_valid;
wire [31:0] app_rx_data;
wire app_rx_valid;
wire [9:0] ep_tx;
wire ep_tx_valid;
wire [9:0] ep_rx;
wire ep_rx_valid;
wire link_up;
wire msi_req;

pcie_endpoint dut (
    .clk(clk), .rst_n(rst_n), .app_tx_data(app_tx_data), .app_tx_valid(app_tx_valid),
    .serial_rx(ep_rx), .serial_rx_valid(ep_rx_valid), .msi_irq(1'b0),
    .serial_tx(ep_tx), .serial_tx_valid(ep_tx_valid), .app_rx_data(app_rx_data),
    .app_rx_valid(app_rx_valid), .link_up(link_up), .msi_req(msi_req)
);

pcie_link_model link (
    .ep_tx(ep_tx), .ep_tx_valid(ep_tx_valid), .ep_rx(ep_rx), .ep_rx_valid(ep_rx_valid), .inject_error(1'b0)
);

always #5 clk = ~clk;

initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    app_tx_data = 32'd0;
    app_tx_valid = 1'b0;
    #20;
    rst_n = 1'b1;
end
endmodule
