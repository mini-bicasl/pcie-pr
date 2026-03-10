module pcie_endpoint #(
    parameter DEVICE_ID = 16'h1234
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] app_tx_data,
    input  wire        app_tx_valid,
    input  wire [9:0]  serial_rx,
    input  wire        serial_rx_valid,
    input  wire        msi_irq,
    output wire [9:0]  serial_tx,
    output wire        serial_tx_valid,
    output wire [31:0] app_rx_data,
    output wire        app_rx_valid,
    output wire        link_up,
    output wire        msi_req
);
wire [31:0] tlp_tx_data;
wire        tlp_tx_valid;
wire [31:0] dll_tx_data;
wire        dll_tx_valid;
wire [31:0] phy_rx_data;
wire        phy_rx_valid;
wire [31:0] tlp_rx_data;
wire        tlp_rx_valid;

pcie_ltssm u_ltssm (
    .clk(clk),
    .rst_n(rst_n),
    .rx_detect(1'b1),
    .elec_idle(1'b0),
    .ordered_set_valid(1'b1),
    .state(),
    .link_up(link_up),
    .tx_ordered_set()
);

pcie_tl_tx u_tl_tx (
    .clk(clk), .rst_n(rst_n), .fmt_type(8'h40), .addr(32'h0),
    .payload(app_tx_data), .send(app_tx_valid), .tlp_data(tlp_tx_data), .tlp_valid(tlp_tx_valid)
);
pcie_dll_tx u_dll_tx (
    .clk(clk), .rst_n(rst_n), .tlp_in(tlp_tx_data), .tlp_valid(tlp_tx_valid),
    .phy_data(dll_tx_data), .phy_valid(dll_tx_valid), .seq_num()
);
pcie_phy_tx u_phy_tx (
    .clk(clk), .rst_n(rst_n), .dll_data(dll_tx_data), .dll_valid(dll_tx_valid),
    .serial_tx(serial_tx), .tx_valid(serial_tx_valid)
);

pcie_phy_rx u_phy_rx (
    .clk(clk), .rst_n(rst_n), .serial_rx(serial_rx), .rx_valid(serial_rx_valid),
    .dll_data(phy_rx_data), .dll_valid(phy_rx_valid), .code_err()
);
pcie_dll_rx u_dll_rx (
    .clk(clk), .rst_n(rst_n), .phy_data(phy_rx_data), .phy_valid(phy_rx_valid),
    .tlp_out(tlp_rx_data), .tlp_valid(tlp_rx_valid), .ack_out()
);
pcie_tl_rx u_tl_rx (
    .clk(clk), .rst_n(rst_n), .tlp_data(tlp_rx_data), .tlp_valid(tlp_rx_valid),
    .mem_wr(), .mem_rd(), .cfg_access(), .payload_out(app_rx_data)
);
assign app_rx_valid = tlp_rx_valid;

pcie_msi u_msi (
    .clk(clk), .rst_n(rst_n), .msi_enable(1'b1), .irq_pulse(msi_irq), .msi_req(msi_req)
);

pcie_cfg_space u_cfg (
    .clk(clk), .rst_n(rst_n), .wr_en(1'b0), .rd_en(1'b0), .addr_dw(10'd0), .wr_data(32'd0), .rd_data()
);
endmodule
