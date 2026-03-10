module pcie_link_model (
    input  wire [9:0] ep_tx,
    input  wire       ep_tx_valid,
    output wire [9:0] ep_rx,
    output wire       ep_rx_valid,
    input  wire       inject_error
);
assign ep_rx       = inject_error ? (ep_tx ^ 10'h001) : ep_tx;
assign ep_rx_valid = ep_tx_valid;
endmodule
