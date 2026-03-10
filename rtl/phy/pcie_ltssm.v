module pcie_ltssm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_detect,
    input  wire       elec_idle,
    input  wire       ordered_set_valid,
    input  wire       aspm_l0s_en,
    input  wire       idle_to_l0s,
    input  wire       pm_enter_l1,
    input  wire       pm_exit,
    output reg  [2:0] state,
    output reg        link_up,
    output reg [15:0] tx_ordered_set,
    output reg        in_l0s,
    output reg        in_l1
);
localparam S_DETECT  = 3'd0;
localparam S_POLLING = 3'd1;
localparam S_CONFIG  = 3'd2;
localparam S_L0      = 3'd3;
localparam S_RECOV   = 3'd4;
localparam S_L0S     = 3'd5;
localparam S_L1      = 3'd6;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_DETECT;
    end else begin
        case (state)
            S_DETECT:  if (rx_detect) state <= S_POLLING;
            S_POLLING: if (ordered_set_valid) state <= S_CONFIG;
            S_CONFIG:  if (ordered_set_valid) state <= S_L0;
            S_L0: begin
                if (pm_enter_l1) state <= S_L1;
                else if (aspm_l0s_en && idle_to_l0s) state <= S_L0S;
                else if (elec_idle) state <= S_RECOV;
            end
            S_RECOV:   if (!elec_idle) state <= S_L0;
            S_L0S: begin
                if (pm_enter_l1) state <= S_L1;
                else if (ordered_set_valid) state <= S_L0;
            end
            S_L1: if (pm_exit) state <= S_RECOV;
            default:   state <= S_DETECT;
        endcase
    end
end

always @(*) begin
    link_up = (state == S_L0) || (state == S_L0S);
    in_l0s = (state == S_L0S);
    in_l1 = (state == S_L1);
    case (state)
        S_DETECT:  tx_ordered_set = 16'hD15C;
        S_POLLING: tx_ordered_set = 16'hF1F1;
        S_CONFIG:  tx_ordered_set = 16'hC0DE;
        S_L0:      tx_ordered_set = 16'h0000;
        S_L0S:     tx_ordered_set = 16'hF7F7;
        S_L1:      tx_ordered_set = 16'h1111;
        default:   tx_ordered_set = 16'hBEEF;
    endcase
end
endmodule
