module pcie_msi (
    input  wire clk,
    input  wire rst_n,
    input  wire msi_enable,
    input  wire irq_pulse,
    output reg  msi_req
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        msi_req <= 1'b0;
    else
        msi_req <= msi_enable && irq_pulse;
end
endmodule
