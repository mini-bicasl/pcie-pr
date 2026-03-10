module pcie_completion_tracker (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       req_issue,
    input  wire [7:0] req_tag,
    input  wire       cpl_recv,
    input  wire [7:0] cpl_tag,
    output reg        timeout,
    output reg        outstanding
);
reg [7:0] tag_reg;
reg [7:0] timer;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tag_reg      <= 8'd0;
        timer        <= 8'd0;
        outstanding  <= 1'b0;
        timeout      <= 1'b0;
    end else begin
        timeout <= 1'b0;
        if (req_issue) begin
            tag_reg <= req_tag;
            timer <= 8'd0;
            outstanding <= 1'b1;
        end else if (outstanding && cpl_recv && (cpl_tag == tag_reg)) begin
            outstanding <= 1'b0;
        end else if (outstanding) begin
            timer <= timer + 1'b1;
            if (timer == 8'hFF) timeout <= 1'b1;
        end
    end
end
endmodule
