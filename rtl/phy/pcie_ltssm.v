module pcie_ltssm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_detect,
    input  wire       elec_idle,
    input  wire       ordered_set_valid,
    output reg  [2:0] state,
    output reg        link_up,
    output reg [15:0] tx_ordered_set
);
localparam S_DETECT  = 3'd0;
localparam S_POLLING = 3'd1;
localparam S_CONFIG  = 3'd2;
localparam S_L0      = 3'd3;
localparam S_RECOV   = 3'd4;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_DETECT;
    end else begin
        case (state)
            S_DETECT:  if (rx_detect) state <= S_POLLING;
            S_POLLING: if (ordered_set_valid) state <= S_CONFIG;
            S_CONFIG:  if (ordered_set_valid) state <= S_L0;
            S_L0:      if (elec_idle) state <= S_RECOV;
            S_RECOV:   if (!elec_idle) state <= S_L0;
            default:   state <= S_DETECT;
        endcase
    end
end

always @(*) begin
    link_up = (state == S_L0);
    case (state)
        S_DETECT:  tx_ordered_set = 16'hD15C;
        S_POLLING: tx_ordered_set = 16'hF1F1;
        S_CONFIG:  tx_ordered_set = 16'hC0DE;
        S_L0:      tx_ordered_set = 16'h0000;
        default:   tx_ordered_set = 16'hBEEF;
    endcase
end
endmodule
