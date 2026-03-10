module pcie_flow_ctrl (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] init_ph,
    input  wire [7:0] init_pd,
    input  wire       init_valid,
    input  wire       consume_ph,
    input  wire       consume_pd,
    input  wire       return_credit,
    output reg  [7:0] avail_ph,
    output reg  [7:0] avail_pd,
    output wire       can_send
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        avail_ph <= 8'd0;
        avail_pd <= 8'd0;
    end else begin
        if (init_valid) begin
            avail_ph <= init_ph;
            avail_pd <= init_pd;
        end else begin
            if (consume_ph && avail_ph != 0) avail_ph <= avail_ph - 1'b1;
            if (consume_pd && avail_pd != 0) avail_pd <= avail_pd - 1'b1;
            if (return_credit) begin
                avail_ph <= avail_ph + 1'b1;
                avail_pd <= avail_pd + 1'b1;
            end
        end
    end
end
assign can_send = (avail_ph != 0) && (avail_pd != 0);
endmodule
