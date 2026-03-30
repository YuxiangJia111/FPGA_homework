module rotator_axi #(
    parameter int unsigned WIDTH  = 1024,
    parameter int unsigned HEIGHT = 1024,
    parameter int unsigned P_BIT  = 24 
) (
    input  logic               clk,
    input  logic               rst_n,
    
    // AXI-Stream Input
    input  logic[P_BIT-1:0]   in_data,
    input  logic               in_valid,
    output logic               in_ready,

    // AXI-Stream Output
    output logic [P_BIT-1:0]   out_data,
    output logic               out_valid,
    input  logic               out_ready
);
    localparam int unsigned FRAME_SIZE      = WIDTH * HEIGHT;
    localparam int unsigned MEM_SIZE        = 2 * FRAME_SIZE; 
    localparam int unsigned AWIDTH          = $clog2(MEM_SIZE);

    logic                                     pipe_en_out;
    logic                                     rd_fire;
    logic   [$clog2(WIDTH+1)-1:0]             cntr_x_in;
    logic   [$clog2(HEIGHT+1)-1:0]            cntr_y_in;
    logic   [$clog2(HEIGHT+1)-1:0]            cntr_x_out; 
    logic   [$clog2(WIDTH+1)-1:0]             cntr_y_out; 
    logic                                     bank_wr;
    logic                                     bank_rd;
    logic   [               1:0]              bank_full; 
    logic                                     write_frame_done;
    logic                                     read_frame_done;
    logic                                     lb_we;
    logic   [        AWIDTH-1:0]              lb_waddr;
    logic   [         P_BIT-1:0]              lb_wdata;
    logic                                     lb_re;
    logic   [        AWIDTH-1:0]              lb_raddr_d0;
    logic   [         P_BIT-1:0]              lb_rdata_d1;
    logic   [        AWIDTH-1:0]              next_raddr;
    logic   [               1:0]              valid_pipe;

    assign pipe_en_out          = out_ready || !out_valid;
    assign in_ready             = !bank_full[bank_wr];

    assign write_frame_done     = in_valid && in_ready && (cntr_x_in == WIDTH - 1) && (cntr_y_in == HEIGHT - 1);
    assign read_frame_done      = rd_fire && (cntr_x_out == HEIGHT - 1) && (cntr_y_out == WIDTH - 1);
    assign lb_we                = in_valid && in_ready;
    assign lb_waddr             = bank_wr * FRAME_SIZE 
                                    + (AWIDTH'(cntr_y_in) * WIDTH)  
                                    + AWIDTH'(cntr_x_in);
    assign lb_wdata             = in_data;
    assign rd_fire              = bank_full[bank_rd] && pipe_en_out;
    assign next_raddr           = bank_rd * FRAME_SIZE 
                                    + (AWIDTH'(cntr_x_out) * WIDTH) 
                                    + (WIDTH - 1 - cntr_y_out);
    assign out_data             = lb_rdata_d1;
    assign out_valid            = valid_pipe[1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cntr_x_in <= '0;
            cntr_y_in <= '0;
            bank_wr   <= 1'b0;
        end else begin
            if (in_valid && in_ready) begin
                if (cntr_x_in == WIDTH - 1) begin
                    cntr_x_in <= '0;
                    if (cntr_y_in == HEIGHT - 1) begin
                        cntr_y_in <= '0;
                        bank_wr   <= ~bank_wr; 
                    end else begin
                        cntr_y_in <= cntr_y_in + 1;
                    end
                end else begin
                    cntr_x_in <= cntr_x_in + 1;
                end
            end
        end
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cntr_x_out <= '0;
            cntr_y_out <= '0;
            bank_rd    <= 1'b0;
        end else begin
            if (rd_fire) begin
                if (cntr_x_out == HEIGHT - 1) begin
                    cntr_x_out <= '0;
                    if (cntr_y_out == WIDTH - 1) begin
                        cntr_y_out <= '0;
                        bank_rd    <= ~bank_rd; 
                    end else begin
                        cntr_y_out <= cntr_y_out + 1;
                    end
                end else begin
                    cntr_x_out <= cntr_x_out + 1;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bank_full <= 2'b00;
        end else begin
            for (int i = 0; i < 2; i++) begin
                bank_full[i] <= (write_frame_done && bank_wr == i) ? 1'b1 :
                                (read_frame_done  && bank_rd == i) ? 1'b0 :
                                bank_full[i];
            end
        end
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lb_raddr_d0 <= '0;
            lb_re       <= 1'b0;
        end else if (pipe_en_out) begin 
            lb_raddr_d0 <= next_raddr;
            lb_re       <= rd_fire;
        end
    end

    ram #(
        .DWIDTH  (P_BIT),
        .AWIDTH  (AWIDTH),
        .MEM_SIZE(MEM_SIZE)
    ) u_frame_buf (
        .clk  (clk),
        .we   (lb_we),
        .waddr(lb_waddr),
        .wdata(lb_wdata),
        .re   (lb_re && pipe_en_out), 
        .raddr(lb_raddr_d0),
        .rdata(lb_rdata_d1)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_pipe <= 2'b00;
        else if (pipe_en_out)
            valid_pipe <= {valid_pipe[0], rd_fire};
    end


endmodule