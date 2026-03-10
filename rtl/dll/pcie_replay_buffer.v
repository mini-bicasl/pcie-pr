module pcie_replay_buffer #(
    parameter DEPTH = 8
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] wr_data,
    input  wire [11:0] wr_seq,
    input  wire        wr_en,
    input  wire        rd_en,
    output reg  [31:0] rd_data,
    output reg  [11:0] rd_seq,
    output wire        empty,
    output wire        full
);
reg [31:0] data_mem [0:DEPTH-1];
reg [11:0] seq_mem  [0:DEPTH-1];
reg [3:0]  wr_ptr;
reg [3:0]  rd_ptr;
reg [4:0]  count;

assign empty = (count == 0);
assign full  = (count == DEPTH);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
        count  <= 0;
        rd_data <= 32'd0;
        rd_seq  <= 12'd0;
    end else begin
        if (wr_en && !full) begin
            data_mem[wr_ptr] <= wr_data;
            seq_mem[wr_ptr]  <= wr_seq;
            wr_ptr <= wr_ptr + 1'b1;
            count <= count + 1'b1;
        end
        if (rd_en && !empty) begin
            rd_data <= data_mem[rd_ptr];
            rd_seq  <= seq_mem[rd_ptr];
            rd_ptr <= rd_ptr + 1'b1;
            count <= count - 1'b1;
        end
    end
end
endmodule
