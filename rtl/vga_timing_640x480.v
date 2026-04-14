module vga_timing_640x480 (
    input  wire clk,
    input  wire rst,
    output reg  [9:0] x,
    output reg  [9:0] y,
    output reg  hsync,
    output reg  vsync,
    output reg  de,
    output wire frame_start
);
    localparam H_ACTIVE = 640;
    localparam H_FP     = 16;
    localparam H_SYNC   = 96;
    localparam H_BP     = 48;
    localparam H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;

    localparam V_ACTIVE = 480;
    localparam V_FP     = 10;
    localparam V_SYNC   = 2;
    localparam V_BP     = 33;
    localparam V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;

    assign frame_start = (x == 10'd0) && (y == 10'd0);

    always @(posedge clk) begin
        if (rst) begin
            x <= 10'd0;
            y <= 10'd0;
        end else if (x == H_TOTAL - 1) begin
            x <= 10'd0;
            if (y == V_TOTAL - 1)
                y <= 10'd0;
            else
                y <= y + 10'd1;
        end else begin
            x <= x + 10'd1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
            de <= 1'b0;
        end else begin
            hsync <= ~((x >= H_ACTIVE + H_FP) && (x < H_ACTIVE + H_FP + H_SYNC));
            vsync <= ~((y >= V_ACTIVE + V_FP) && (y < V_ACTIVE + V_FP + V_SYNC));
            de <= (x < H_ACTIVE) && (y < V_ACTIVE);
        end
    end
endmodule
