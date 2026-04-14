module rp2c02_minimal (
        end else begin
            if (sx == 10'd0 && sy == 10'd240)
                ppustatus[7] <= 1'b1;
            if (sx == 10'd0 && sy == 10'd0)
                ppustatus[7] <= 1'b0;
        end
    end

    // ------------------------------------------------------------
    // Background fetch / pixel generation
    // ------------------------------------------------------------
    wire nes_area = (sx < 10'd256) && (sy < 10'd240) && de;

    reg [7:0] tile_id;
    reg [7:0] attr_byte;
    reg [7:0] pat_lo;
    reg [7:0] pat_hi;
    reg [1:0] attr_sel;
    reg [1:0] px_bits;
    reg [4:0] pal_index;
    reg [5:0] nes_color_idx;

    reg [7:0] out_r, out_g, out_b;
    assign video_r = out_r;
    assign video_g = out_g;
    assign video_b = out_b;

    wire [8:0] scx = sx[8:0] + scroll_x;
    wire [8:0] scy = sy[8:0] + scroll_y;
    wire [4:0] nt_x = scx[8:3];
    wire [4:0] nt_y = scy[8:3];
    wire [2:0] in_x = scx[2:0];
    wire [2:0] in_y = scy[2:0];

    wire [9:0] nt_index = nt_y * 10'd32 + nt_x;
    wire [5:0] at_index = (nt_y >> 2) * 6'd8 + (nt_x >> 2);

    wire [13:0] pat_base = bg_pat_sel ? 14'h1000 : 14'h0000;
    wire [13:0] pat_addr_lo = pat_base + {tile_id, 4'b0000} + in_y;
    wire [13:0] pat_addr_hi = pat_base + {tile_id, 4'b0000} + in_y + 14'd8;

    wire [1:0] quadrant = {nt_y[1], nt_x[1]};

    wire [7:0] nt_data_now   = vram[nt_index[10:0]];
    wire [7:0] attr_data_now = vram[11'd960 + at_index];
    wire [7:0] pat_lo_now    = chr[pat_addr_lo];
    wire [7:0] pat_hi_now    = chr[pat_addr_hi];

    wire [1:0] attr_q_sel = (quadrant == 2'b00) ? attr_data_now[1:0] :
                            (quadrant == 2'b01) ? attr_data_now[3:2] :
                            (quadrant == 2'b10) ? attr_data_now[5:4] :
                                                   attr_data_now[7:6];

    wire [1:0] pat_px = {pat_hi_now[7 - in_x], pat_lo_now[7 - in_x]};
    wire [4:0] pal_addr = (pat_px == 2'b00) ? 5'd0 : {1'b0, attr_q_sel, pat_px};
    wire [5:0] color_now = pal_ram[map_pal_addr(pal_addr)];

    wire [7:0] pal_r, pal_g, pal_b;
    nes_palette u_pal (
        .idx(color_now),
        .r(pal_r), .g(pal_g), .b(pal_b)
    );

    always @(posedge clk_pix) begin
        if (rst) begin
            out_r <= 8'h00;
            out_g <= 8'h00;
            out_b <= 8'h00;
        end else begin
            if (!de) begin
                out_r <= 8'h00;
                out_g <= 8'h00;
                out_b <= 8'h00;
            end else if (nes_area && show_bg) begin
                out_r <= pal_r;
                out_g <= pal_g;
                out_b <= pal_b;
            end else begin
                out_r <= 8'h00;
                out_g <= 8'h00;
                out_b <= 8'h00;
            end
        end
    end
endmodule