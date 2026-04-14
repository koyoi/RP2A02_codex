`timescale 1ns/1ps
        .video_b(video_b),
        .video_hsync(video_hsync),
        .video_vsync(video_vsync),
        .video_de(video_de)
    );

    // 25MHz approx
    always #20 clk = ~clk;

    task cpu_write;
        input [2:0] a;
        input [7:0] d;
        begin
            @(posedge clk);
            cpu_addr  <= a;
            cpu_wdata <= d;
            cpu_we    <= 1'b1;
            @(posedge clk);
            cpu_we    <= 1'b0;
        end
    endtask

    task cpu_read;
        input [2:0] a;
        begin
            @(posedge clk);
            cpu_addr <= a;
            cpu_re   <= 1'b1;
            @(posedge clk);
            cpu_re   <= 1'b0;
        end
    endtask

    integer fp;
    integer x;
    integer y;
    integer frame_count;

    initial begin
        fp = $fopen("frame0.ppm", "w");
        if (fp == 0) begin
            $display("failed to open output file");
            $finish;
        end

        // reset
        repeat (10) @(posedge clk);
        rst <= 1'b0;

        // enable NMI and BG
        cpu_write(3'd0, 8'b1000_0000); // PPUCTRL NMI enable
        cpu_write(3'd1, 8'b0000_1000); // PPUMASK show bg

        // optional: modify scroll
        cpu_write(3'd5, 8'd0);
        cpu_write(3'd5, 8'd0);

        // dump first visible frame as 640x480 PPM
        @(negedge rst);
        wait (dut.u_timing.frame_start == 1'b1);
        @(posedge clk);

        $fwrite(fp, "P3\n640 480\n255\n");
        frame_count = 0;
        x = 0;
        y = 0;

        while (y < 480) begin
            @(posedge clk);
            if (video_de) begin
                $fwrite(fp, "%0d %0d %0d\n", video_r, video_g, video_b);
                if (x == 639) begin
                    x = 0;
                    y = y + 1;
                end else begin
                    x = x + 1;
                end
            end
        end

        $fclose(fp);
        $display("PPM frame dumped to frame0.ppm");
        repeat (1000) @(posedge clk);
        $finish;
    end
endmodule