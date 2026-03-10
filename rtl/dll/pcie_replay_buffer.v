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
localparam PTR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1;
localparam CNT_W = $clog2(DEPTH + 1);

reg [31:0] data_mem [0:DEPTH-1];
reg [11:0] seq_mem  [0:DEPTH-1];
reg [PTR_W-1:0] wr_ptr;
reg [PTR_W-1:0] rd_ptr;
reg [CNT_W-1:0] count;

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
            wr_ptr <= (wr_ptr == DEPTH-1) ? {PTR_W{1'b0}} : (wr_ptr + {{(PTR_W-1){1'b0}}, 1'b1});
        end
        if (rd_en && !empty) begin
            rd_data <= data_mem[rd_ptr];
            rd_seq  <= seq_mem[rd_ptr];
            rd_ptr <= (rd_ptr == DEPTH-1) ? {PTR_W{1'b0}} : (rd_ptr + {{(PTR_W-1){1'b0}}, 1'b1});
        end
        case ({wr_en && !full, rd_en && !empty})
            2'b10: count <= count + {{(CNT_W-1){1'b0}}, 1'b1};
            2'b01: count <= count - {{(CNT_W-1){1'b0}}, 1'b1};
            default: count <= count;
        endcase
    end
end
endmodule
