module ram #(
    parameter int unsigned DWIDTH   = 24,
    parameter int unsigned AWIDTH   = 17,
    parameter int unsigned MEM_SIZE = 1024*1024*2 // 2帧的双缓冲
)(
    input  logic              clk,
    input  logic              we,
    input  logic[AWIDTH-1:0] waddr,
    input  logic [DWIDTH-1:0] wdata,
    input  logic              re,
    input  logic [AWIDTH-1:0] raddr,
    output logic [DWIDTH-1:0] rdata
);

    logic[DWIDTH-1:0] mem [0:MEM_SIZE-1];

    always_ff @(posedge clk) begin
        if (we) begin
            mem[waddr]<= wdata;
        end
    end

    always_ff @(posedge clk) begin
        if (re) begin
            rdata <= mem[raddr];
        end
    end

endmodule