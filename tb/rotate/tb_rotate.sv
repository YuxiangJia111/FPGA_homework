`timescale 1ns / 1ps

module tb_rotator_axi;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter int unsigned WIDTH  = 1024;
    parameter int unsigned HEIGHT = 1024;
    parameter int unsigned P_BIT  = 24;

    // =========================================================================
    // Signals
    // =========================================================================
    logic               clk;
    logic               rst_n;

    // AXI-Stream Input
    logic [P_BIT-1:0]   in_data;
    logic               in_valid;
    logic               in_ready;

    // AXI-Stream Output
    logic [P_BIT-1:0]   out_data;
    logic               out_valid;
    logic               out_ready;

    // Queues for data management
    logic[P_BIT-1:0]   input_queue  [$];  
    logic[P_BIT-1:0]   output_queue [$];  
    logic [P_BIT-1:0]   golden_queue [$];  

    int                 error_count;

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin 
        clk = 0; 
        forever #5 clk = ~clk; // 100MHz
    end

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    rotator_axi #(
        .WIDTH (WIDTH),
        .HEIGHT(HEIGHT),
        .P_BIT (P_BIT)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_data  (in_data),
        .in_valid (in_valid),
        .in_ready (in_ready),
        .out_data (out_data),
        .out_valid(out_valid),
        .out_ready(out_ready)
    );

    // =========================================================================
    // AXI-Stream Master Driver (发送端: 带随机气泡 & 遵循握手协议)
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_valid <= 1'b0;
            in_data  <= '0;
        end else begin
            // AXI Rule: 如果 Valid 为高但 Ready 为低，必须保持 Valid 和 Data 稳定不变！
            if (in_valid && !in_ready) begin
                in_valid <= in_valid;
                in_data  <= in_data;
            end 
            // 否则 (握手成功 或 当前空闲)，可以准备发送下一个数据
            else begin
                if (input_queue.size() > 0) begin
                    // 80% 的概率发送数据，20% 的概率制造流水线气泡
                    if ($urandom_range(0, 100) < 80) begin
                        in_valid <= 1'b1;
                        in_data  <= input_queue[0]; // 填装队首数据
                        input_queue.pop_front();    // 从队列中弹出
                    end else begin
                        in_valid <= 1'b0;
                    end
                end else begin
                    in_valid <= 1'b0;
                end
            end
        end
    end

    // =========================================================================
    // AXI-Stream Slave Receiver (接收端: 带随机反压)
    // =========================================================================
    // 1. 随机生成 out_ready (模拟下游模块有时候来不及收数据，压测 DUT 的暂存防丢能力)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_ready <= 1'b0;
        end else begin
            // 80% 的概率 Ready 为高，接收数据
            out_ready <= ($urandom_range(0, 100) < 80);
        end
    end

    // 2. 握手成功时，将数据存入输出队列
    always_ff @(posedge clk) begin
        if (rst_n && out_valid && out_ready) begin
            output_queue.push_back(out_data);
        end
    end

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        rst_n       = 0;
        error_count = 0;

        repeat (10) @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset released", $time);

        // 1. 读取 input.txt
        begin
            int fd; int r, g, b;
            fd = $fopen("../../data/input.txt", "r");
            if (fd == 0) begin $display("ERROR: Cannot open data/input.txt"); $finish; end
            while (!$feof(fd)) begin
                if ($fscanf(fd, "%d %d %d", r, g, b) == 3) 
                    input_queue.push_back({r[7:0], g[7:0], b[7:0]});
            end
            $fclose(fd);
            $display("Loaded %0d pixels into input_queue", input_queue.size());
        end

        // 2. 读取 golden.txt
        begin
            int fd; int r, g, b;
            fd = $fopen("../../data/golden.txt", "r");
            if (fd == 0) begin $display("ERROR: Cannot open data/golden.txt"); $finish; end
            while (!$feof(fd)) begin
                if ($fscanf(fd, "%d %d %d", r, g, b) == 3) 
                    golden_queue.push_back({r[7:0], g[7:0], b[7:0]});
            end
            $fclose(fd);
            $display("Loaded %0d pixels into golden_queue", golden_queue.size());
        end

        repeat (5) @(posedge clk);

        // 3. 等待输入发送完毕
        wait (input_queue.size() == 0);
        @(posedge clk);
        $display("[%0t] All inputs sent to DUT. Waiting for processing...", $time);

        // 4. 等待输出完成，并设置超时保护机制
        // 由于加入了随机反压，处理时间会比理想状态长，给足超时余量
        fork
            begin
                wait (output_queue.size() == golden_queue.size());
            end
            begin
                repeat (WIDTH * HEIGHT * 10) @(posedge clk);
                $display("\n========================================");
                $display("❌ TIMEOUT: DUT is deadlocked!");
                $display("Output queue size: %0d", output_queue.size());
                $display("Expected size:     %0d", golden_queue.size());
                $display("========================================");
            end
        join_any
        disable fork;

        // 5. 数据校验与报告
        $display("\nStarting Output Verification...");
        
        if (output_queue.size() != golden_queue.size()) begin
            $display("ERROR: Size mismatch! Output=%0d, Golden=%0d", output_queue.size(), golden_queue.size());
            error_count++;
        end

        for (int i = 0; i < golden_queue.size(); i++) begin
            logic [P_BIT-1:0] expected, actual;
            expected = golden_queue[i];
            actual   = (i < output_queue.size()) ? output_queue[i] : 'x;

            if (actual !== expected) begin
                    $display("ERROR at [%0d]: Expected=(%0d,%0d,%0d), Actual=(%0d,%0d,%0d)", 
                             i, 
                             expected[23:16], expected[15:8], expected[7:0],
                             actual[23:16], actual[15:8], actual[7:0]);
                error_count++;
            end
        end

        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total outputs checked: %0d", golden_queue.size());
        $display("Errors found: %0d", error_count);

        if (error_count == 0) $display("✅ *** AXI-STREAM TEST PASSED ***");
        else $display("❌ *** TEST FAILED ***");
        $display("========================================\n");

        $finish;
    end

    // =========================================================================
    // Waveform Dumping (适配 VCS/Verdi)
    // =========================================================================
    initial begin
        $fsdbDumpfile("tb_rotator_axi.fsdb");
        $fsdbDumpvars(0, tb_rotator_axi);
        $fsdbDumpMDA(0, tb_rotator_axi);
        $fsdbDumpvars("+mda");
        $fsdbDumpvars("+all");
    end

endmodule