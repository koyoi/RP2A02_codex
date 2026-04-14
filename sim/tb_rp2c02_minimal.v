`timescale 1ns/1ps

module tb_rp2c02_minimal;
    reg clk_cpu = 1'b0;
    reg clk_ppu = 1'b0;
    reg clk_pix = 1'b0;
    reg rst = 1'b1;

    reg [2:0] cpu_addr = 3'd0;
    reg [7:0] cpu_wdata = 8'h00;
    reg cpu_we = 1'b0;
    reg cpu_re = 1'b0;
    wire [7:0] cpu_rdata;

    reg mapper_vertical_mirroring = 1'b1;
    reg [7:0] chr_mem [0:8191];

    wire nmi;
    wire [7:0] video_r;
    wire [7:0] video_g;
    wire [7:0] video_b;
    wire video_hsync;
    wire video_vsync;
    wire video_de;

    integer fp;
    integer x;
    integer y;
    integer i;

    rp2c02_minimal dut (
        .clk_cpu(clk_cpu),
        .clk_ppu(clk_ppu),
        .clk_pix(clk_pix),
        .rst(rst),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_we(cpu_we),
        .cpu_re(cpu_re),
        .cpu_rdata(cpu_rdata),
        .mapper_vertical_mirroring(mapper_vertical_mirroring),
        .chr_mem(chr_mem),
        .nmi(nmi),
        .video_r(video_r),
        .video_g(video_g),
        .video_b(video_b),
        .video_hsync(video_hsync),
        .video_vsync(video_vsync),
        .video_de(video_de)
    );

    always #50 clk_cpu = ~clk_cpu;
    always #18 clk_ppu = ~clk_ppu;
    always #20 clk_pix = ~clk_pix;

    task cpu_write;
        input [2:0] addr;
        input [7:0] data;
        begin
            @(posedge clk_cpu);
            cpu_addr <= addr;
            cpu_wdata <= data;
            cpu_we <= 1'b1;
            @(posedge clk_cpu);
            cpu_we <= 1'b0;
        end
    endtask

    task cpu_read;
        input [2:0] addr;
        begin
            @(posedge clk_cpu);
            cpu_addr <= addr;
            cpu_re <= 1'b1;
            @(posedge clk_cpu);
            cpu_re <= 1'b0;
        end
    endtask

    initial begin
        for (i = 0; i < 8192; i = i + 1)
            chr_mem[i] = 8'h00;

        // Tile 1: dense background pixels.
        chr_mem[16 + 0] = 8'b11111111;
        chr_mem[16 + 1] = 8'b10000001;
        chr_mem[16 + 2] = 8'b10111101;
        chr_mem[16 + 3] = 8'b10100101;
        chr_mem[16 + 4] = 8'b10111101;
        chr_mem[16 + 5] = 8'b10000001;
        chr_mem[16 + 6] = 8'b11111111;
        chr_mem[16 + 7] = 8'b00000000;
        chr_mem[24 + 0] = 8'b00000000;
        chr_mem[24 + 1] = 8'b01111110;
        chr_mem[24 + 2] = 8'b01000010;
        chr_mem[24 + 3] = 8'b01011010;
        chr_mem[24 + 4] = 8'b01000010;
        chr_mem[24 + 5] = 8'b01111110;
        chr_mem[24 + 6] = 8'b00000000;
        chr_mem[24 + 7] = 8'b00000000;

        // Tile 2: sprite cross for sprite 0 hit.
        chr_mem[32 + 0] = 8'b00011000;
        chr_mem[32 + 1] = 8'b00111100;
        chr_mem[32 + 2] = 8'b01111110;
        chr_mem[32 + 3] = 8'b11111111;
        chr_mem[32 + 4] = 8'b11111111;
        chr_mem[32 + 5] = 8'b01111110;
        chr_mem[32 + 6] = 8'b00111100;
        chr_mem[32 + 7] = 8'b00011000;
        chr_mem[40 + 0] = 8'b00000000;
        chr_mem[40 + 1] = 8'b00011000;
        chr_mem[40 + 2] = 8'b00111100;
        chr_mem[40 + 3] = 8'b01111110;
        chr_mem[40 + 4] = 8'b01111110;
        chr_mem[40 + 5] = 8'b00111100;
        chr_mem[40 + 6] = 8'b00011000;
        chr_mem[40 + 7] = 8'b00000000;

        // Tile 3: overflow filler sprite.
        for (i = 0; i < 8; i = i + 1) begin
            chr_mem[48 + i] = 8'hFF;
            chr_mem[56 + i] = 8'h00;
        end
    end

    initial begin
        fp = $fopen("frame0.ppm", "w");
        if (fp == 0) begin
            $display("failed to open frame0.ppm");
            $finish;
        end

        repeat (10) @(posedge clk_cpu);
        rst <= 1'b0;

        // Build a checkerboard nametable directly.
        for (i = 0; i < 960; i = i + 1)
            dut.nametable_ram[i] = (i[0]) ? 8'd1 : 8'd0;
        for (i = 960; i < 1024; i = i + 1)
            dut.nametable_ram[i] = 8'h55;

        dut.palette_ram[5'h00] = 6'h0F;
        dut.palette_ram[5'h01] = 6'h21;
        dut.palette_ram[5'h02] = 6'h27;
        dut.palette_ram[5'h03] = 6'h30;
        dut.palette_ram[5'h11] = 6'h16;
        dut.palette_ram[5'h12] = 6'h2A;
        dut.palette_ram[5'h13] = 6'h20;

        // Sprite 0 overlaps background to trigger sprite 0 hit.
        cpu_write(3'd3, 8'd0);
        cpu_write(3'd4, 8'd39);
        cpu_write(3'd4, 8'd2);
        cpu_write(3'd4, 8'b0000_0000);
        cpu_write(3'd4, 8'd40);

        // Nine sprites on one scanline to trigger overflow.
        for (i = 1; i < 10; i = i + 1) begin
            cpu_write(3'd4, 8'd79);
            cpu_write(3'd4, 8'd3);
            cpu_write(3'd4, 8'b0000_0000);
            cpu_write(3'd4, i * 8);
        end

        cpu_write(3'd0, 8'b1000_0000);
        cpu_write(3'd1, 8'b0001_1110);
        cpu_write(3'd5, 8'd4);
        cpu_write(3'd5, 8'd8);

        wait (dut.ppu_scanline == 9'd120 && dut.ppu_cycle == 9'd10);
        cpu_read(3'd2);
        @(posedge clk_cpu);
        $display("PPUSTATUS midway = %02x (expect sprite0hit/overflow set)", cpu_rdata);

        wait (dut.u_timing.frame_start == 1'b1);
        @(posedge clk_pix);

        $fwrite(fp, "P3\n640 480\n255\n");
        x = 0;
        y = 0;
        while (y < 480) begin
            @(posedge clk_pix);
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
        $display("frame dumped to frame0.ppm");
        repeat (100) @(posedge clk_cpu);
        $finish;
    end
endmodule
