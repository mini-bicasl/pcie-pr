module pcie_cfg_space #(
    parameter DEPTH_DW = 256
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire [9:0]  addr_dw,
    input  wire [31:0] wr_data,
    output reg  [31:0] rd_data
);
reg [31:0] cfg_mem [0:DEPTH_DW-1];
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < DEPTH_DW; i = i + 1) begin
            cfg_mem[i] <= 32'd0;
        end
        cfg_mem[0] <= 32'h1234_8086;
        rd_data <= 32'd0;
    end else begin
        if (wr_en && addr_dw < DEPTH_DW)
            cfg_mem[addr_dw] <= wr_data;
        if (rd_en && addr_dw < DEPTH_DW)
            rd_data <= cfg_mem[addr_dw];
    end
end
endmodule
