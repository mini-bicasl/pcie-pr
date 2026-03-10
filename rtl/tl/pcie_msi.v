module pcie_msi (
    input  wire clk,
    input  wire rst_n,
    input  wire msi_enable,
    input  wire irq_pulse,
    input  wire msix_enable,
    input  wire [10:0] msix_vector,
    input  wire msix_mask,
    input  wire intx_enable,
    input  wire intx_assert,
    input  wire intx_deassert,
    output reg  msi_req,
    output reg  msix_req,
    output reg [10:0] msix_vector_out,
    output reg [7:0] intx_msg_code,
    output reg  intx_msg_valid
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        msi_req <= 1'b0;
        msix_req <= 1'b0;
        msix_vector_out <= 11'd0;
        intx_msg_code <= 8'd0;
        intx_msg_valid <= 1'b0;
    end else begin
        msi_req <= msi_enable && irq_pulse;
        msix_req <= msix_enable && irq_pulse && !msix_mask;
        if (msix_enable && irq_pulse && !msix_mask)
            msix_vector_out <= msix_vector;
        intx_msg_valid <= 1'b0;
        if (intx_enable && intx_assert) begin
            intx_msg_code <= 8'h04;
            intx_msg_valid <= 1'b1;
        end else if (intx_enable && intx_deassert) begin
            intx_msg_code <= 8'h24;
            intx_msg_valid <= 1'b1;
        end
    end
end
endmodule
