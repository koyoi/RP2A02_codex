module rp2c02_minimal (
    input  wire        clk_cpu,
    input  wire        clk_ppu,
    input  wire        clk_pix,
    input  wire        rst,

    input  wire [2:0]  cpu_addr,
    input  wire [7:0]  cpu_wdata,
    input  wire        cpu_we,
    input  wire        cpu_re,
    output reg  [7:0]  cpu_rdata,

    input  wire        mapper_vertical_mirroring,
    input  wire [7:0]  chr_mem [0:8191],

    output wire        nmi,
    output wire [7:0]  video_r,
    output wire [7:0]  video_g,
    output wire [7:0]  video_b,
    output wire        video_hsync,
    output wire        video_vsync,
    output wire        video_de
);
    localparam PPUCTRL   = 3'd0;
    localparam PPUMASK   = 3'd1;
    localparam PPUSTATUS = 3'd2;
    localparam OAMADDR   = 3'd3;
    localparam OAMDATA   = 3'd4;
    localparam PPUSCROLL = 3'd5;
    localparam PPUADDR   = 3'd6;
    localparam PPUDATA   = 3'd7;

    reg [7:0] ppuctrl;
    reg [7:0] ppumask;
    reg [7:0] ppustatus;
    reg [7:0] oamaddr;
    reg [7:0] ppudata_read_buffer;
    reg [14:0] v;
    reg [14:0] t;
    reg [14:0] line_v_start;
    reg [14:0] v_next_r;
    reg [2:0] fine_x_scroll;
    reg       write_toggle;

    reg [7:0] nametable_ram [0:2047];
    reg [5:0] palette_ram   [0:31];
    reg [7:0] oam_ram       [0:255];
    reg [5:0] framebuf      [0:61439];

    reg [8:0] ppu_cycle;
    reg [8:0] ppu_scanline;
    reg [15:0] ppu_frame;

    reg [7:0] sec_y    [0:7];
    reg [7:0] sec_tile [0:7];
    reg [7:0] sec_attr [0:7];
    reg [7:0] sec_x    [0:7];
    reg [7:0] sec_idx  [0:7];
    reg [7:0] sec_lo   [0:7];
    reg [7:0] sec_hi   [0:7];
    reg [2:0] sec_count;

    reg [7:0] out_r;
    reg [7:0] out_g;
    reg [7:0] out_b;
    reg [5:0] pix_color;

    wire [9:0] sx;
    wire [9:0] sy;
    wire de;
    wire [7:0] pal_r;
    wire [7:0] pal_g;
    wire [7:0] pal_b;
    wire show_bg;
    wire show_sprites;
    wire rendering_on;

    integer i;
    integer sprite_i;
    integer slot_i;
    integer row_i;
    integer top_i;
    integer addr_i;
    integer sprite_height_i;
    integer vis_x_i;
    integer vis_y_i;
    integer scroll_x_i;
    integer scroll_y_i;
    integer global_x_i;
    integer global_y_i;
    integer nt_number_i;
    integer nt_local_x_i;
    integer nt_local_y_i;
    integer tile_x_i;
    integer tile_y_i;
    integer nt_addr_i;
    integer attr_addr_i;
    integer attr_shift_i;
    integer bg_pattern_base_i;
    integer bg_row_i;
    integer sprite_x_offset_i;
    integer sprite_bit_i;
    integer fb_index_i;
    integer sprite_base_i;
    integer sprite_tile_index_i;
    integer sprite_row_fetch_i;
    integer scanline_i;
    integer sprite_count_i;

    reg [7:0] ppu_read_data;
    reg [7:0] cpu_direct_data_r;
    reg [5:0] bg_color_idx_r;
    reg [1:0] bg_bits_r;
    reg [7:0] bg_tile_r;
    reg [7:0] bg_attr_r;
    reg [7:0] bg_lo_r;
    reg [7:0] bg_hi_r;
    reg [1:0] bg_pal_sel_r;
    reg [4:0] bg_pal_addr_r;
    reg       bg_enable_here_r;

    reg       sprite_found_r;
    reg       sprite_zero_r;
    reg       sprite_behind_r;
    reg [1:0] sprite_bits_r;
    reg [1:0] sprite_pal_sel_r;
    reg [4:0] sprite_pal_addr_r;
    reg [5:0] sprite_color_idx_r;
    reg [5:0] final_color_r;
    reg       sprite_enable_here_r;

    assign show_bg = ppumask[3];
    assign show_sprites = ppumask[4];
    assign rendering_on = show_bg | show_sprites;

    function [4:0] map_palette_addr;
        input [4:0] addr_in;
        begin
            case (addr_in)
                5'h10: map_palette_addr = 5'h00;
                5'h14: map_palette_addr = 5'h04;
                5'h18: map_palette_addr = 5'h08;
                5'h1C: map_palette_addr = 5'h0C;
                default: map_palette_addr = addr_in;
            endcase
        end
    endfunction

    function [10:0] map_nametable_addr;
        input [11:0] addr_in;
        reg [1:0] table_sel;
        reg [9:0] table_offs;
        begin
            table_sel  = addr_in[11:10];
            table_offs = addr_in[9:0];
            if (mapper_vertical_mirroring)
                map_nametable_addr = {table_sel[0], table_offs};
            else
                map_nametable_addr = {table_sel[1], table_offs};
        end
    endfunction

    function [13:0] sprite_pattern_addr;
        input [7:0] tile;
        input [7:0] attr;
        input integer row;
        integer local_row;
        integer sprite_height;
        integer bank;
        integer tile_index;
        begin
            local_row = row;
            sprite_height = ppuctrl[5] ? 16 : 8;
            if (attr[7])
                local_row = sprite_height - 1 - local_row;

            if (ppuctrl[5]) begin
                bank = tile[0] ? 14'h1000 : 14'h0000;
                tile_index = {tile[7:1], 1'b0};
                if (local_row >= 8) begin
                    tile_index = tile_index + 1;
                    local_row = local_row - 8;
                end
            end else begin
                bank = ppuctrl[3] ? 14'h1000 : 14'h0000;
                tile_index = tile;
            end

            sprite_pattern_addr = bank + (tile_index << 4) + local_row[3:0];
        end
    endfunction

    function [14:0] increment_coarse_x;
        input [14:0] addr;
        reg [14:0] next_addr;
        begin
            next_addr = addr;
            if (addr[4:0] == 5'd31) begin
                next_addr[4:0] = 5'd0;
                next_addr[10] = ~addr[10];
            end else begin
                next_addr[4:0] = addr[4:0] + 5'd1;
            end
            increment_coarse_x = next_addr;
        end
    endfunction

    function [14:0] increment_y_scroll;
        input [14:0] addr;
        reg [14:0] next_addr;
        begin
            next_addr = addr;
            if (addr[14:12] != 3'd7) begin
                next_addr[14:12] = addr[14:12] + 3'd1;
            end else begin
                next_addr[14:12] = 3'd0;
                if (addr[9:5] == 5'd29) begin
                    next_addr[9:5] = 5'd0;
                    next_addr[11] = ~addr[11];
                end else if (addr[9:5] == 5'd31) begin
                    next_addr[9:5] = 5'd0;
                end else begin
                    next_addr[9:5] = addr[9:5] + 5'd1;
                end
            end
            increment_y_scroll = next_addr;
        end
    endfunction

    function [14:0] copy_horizontal_scroll;
        input [14:0] addr;
        input [14:0] src;
        begin
            copy_horizontal_scroll = addr;
            copy_horizontal_scroll[10] = src[10];
            copy_horizontal_scroll[4:0] = src[4:0];
        end
    endfunction

    function [14:0] copy_vertical_scroll;
        input [14:0] addr;
        input [14:0] src;
        begin
            copy_vertical_scroll = addr;
            copy_vertical_scroll[14:12] = src[14:12];
            copy_vertical_scroll[11] = src[11];
            copy_vertical_scroll[9:5] = src[9:5];
        end
    endfunction

    task automatic read_ppu_space;
        input [13:0] addr_in;
        output [7:0] data_out;
        reg [10:0] mapped;
        reg [13:0] local_addr;
        begin
            if (addr_in < 14'h2000) begin
                data_out = chr_mem[addr_in];
            end else if (addr_in < 14'h3F00) begin
                local_addr = addr_in - 14'h2000;
                mapped = map_nametable_addr(local_addr[11:0]);
                data_out = nametable_ram[mapped];
            end else begin
                data_out = {2'b00, palette_ram[map_palette_addr(addr_in[4:0])]};
            end
        end
    endtask

    task automatic write_ppu_space;
        input [13:0] addr_in;
        input [7:0] data_in;
        reg [10:0] mapped;
        reg [13:0] local_addr;
        begin
            if ((addr_in >= 14'h2000) && (addr_in < 14'h3F00)) begin
                local_addr = addr_in - 14'h2000;
                mapped = map_nametable_addr(local_addr[11:0]);
                nametable_ram[mapped] <= data_in;
            end else if (addr_in >= 14'h3F00) begin
                palette_ram[map_palette_addr(addr_in[4:0])] <= data_in[5:0];
            end
        end
    endtask

    task automatic evaluate_sprites;
        input integer scanline_in;
        integer sprite_height;
        integer sprite_top;
        integer sprite_row;
        integer sprite_addr_lo;
        integer sprite_addr_hi;
        begin
            sprite_height = ppuctrl[5] ? 16 : 8;
            sprite_count_i = 0;

            for (slot_i = 0; slot_i < 8; slot_i = slot_i + 1) begin
                sec_y[slot_i]    <= 8'hFF;
                sec_tile[slot_i] <= 8'h00;
                sec_attr[slot_i] <= 8'h00;
                sec_x[slot_i]    <= 8'h00;
                sec_idx[slot_i]  <= 8'hFF;
                sec_lo[slot_i]   <= 8'h00;
                sec_hi[slot_i]   <= 8'h00;
            end

            for (sprite_i = 0; sprite_i < 64; sprite_i = sprite_i + 1) begin
                sprite_top = oam_ram[sprite_i * 4] + 1;
                if ((scanline_in >= sprite_top) && (scanline_in < (sprite_top + sprite_height))) begin
                    if (sprite_count_i < 8) begin
                        sec_y[sprite_count_i]    <= oam_ram[sprite_i * 4];
                        sec_tile[sprite_count_i] <= oam_ram[sprite_i * 4 + 1];
                        sec_attr[sprite_count_i] <= oam_ram[sprite_i * 4 + 2];
                        sec_x[sprite_count_i]    <= oam_ram[sprite_i * 4 + 3];
                        sec_idx[sprite_count_i]  <= sprite_i[7:0];

                        sprite_row = scanline_in - sprite_top;
                        sprite_addr_lo = sprite_pattern_addr(
                            oam_ram[sprite_i * 4 + 1],
                            oam_ram[sprite_i * 4 + 2],
                            sprite_row
                        );
                        sprite_addr_hi = sprite_addr_lo + 8;
                        sec_lo[sprite_count_i] <= chr_mem[sprite_addr_lo[13:0]];
                        sec_hi[sprite_count_i] <= chr_mem[sprite_addr_hi[13:0]];

                        sprite_count_i = sprite_count_i + 1;
                    end else begin
                        ppustatus[5] <= 1'b1;
                    end
                end
            end

            sec_count <= sprite_count_i[2:0];
        end
    endtask

    assign nmi = ppuctrl[7] & ppustatus[7];
    assign video_r = out_r;
    assign video_g = out_g;
    assign video_b = out_b;
    assign video_de = de;

    vga_timing_640x480 u_timing (
        .clk(clk_pix),
        .rst(rst),
        .x(sx),
        .y(sy),
        .hsync(video_hsync),
        .vsync(video_vsync),
        .de(de),
        .frame_start()
    );

    nes_palette u_palette (
        .idx(pix_color),
        .r(pal_r),
        .g(pal_g),
        .b(pal_b)
    );

    initial begin
        ppuctrl = 8'h00;
        ppumask = 8'h00;
        ppustatus = 8'h00;
        oamaddr = 8'h00;
        ppudata_read_buffer = 8'h00;
        v = 15'h0000;
        t = 15'h0000;
        line_v_start = 15'h0000;
        v_next_r = 15'h0000;
        fine_x_scroll = 3'd0;
        write_toggle = 1'b0;
        ppu_cycle = 9'd0;
        ppu_scanline = 9'd261;
        ppu_frame = 16'd0;
        out_r = 8'h00;
        out_g = 8'h00;
        out_b = 8'h00;
        pix_color = 6'h00;
        cpu_rdata = 8'h00;
        sec_count = 3'd0;

        for (i = 0; i < 2048; i = i + 1)
            nametable_ram[i] = 8'h00;
        for (i = 0; i < 32; i = i + 1)
            palette_ram[i] = 6'h00;
        for (i = 0; i < 256; i = i + 1)
            oam_ram[i] = 8'h00;
        for (i = 0; i < 61440; i = i + 1)
            framebuf[i] = 6'h00;
    end

    always @(posedge clk_cpu) begin
        if (rst) begin
            cpu_rdata <= 8'h00;
            ppuctrl <= 8'h00;
            ppumask <= 8'h00;
            oamaddr <= 8'h00;
            ppudata_read_buffer <= 8'h00;
            v <= 15'h0000;
            t <= 15'h0000;
            line_v_start <= 15'h0000;
            fine_x_scroll <= 3'd0;
            write_toggle <= 1'b0;
        end else begin
            if (cpu_we) begin
                case (cpu_addr)
                    PPUCTRL: begin
                        ppuctrl <= cpu_wdata;
                        t[10] <= cpu_wdata[0];
                        t[11] <= cpu_wdata[1];
                    end
                    PPUMASK: begin
                        ppumask <= cpu_wdata;
                    end
                    OAMADDR: begin
                        oamaddr <= cpu_wdata;
                    end
                    OAMDATA: begin
                        oam_ram[oamaddr] <= cpu_wdata;
                        oamaddr <= oamaddr + 8'd1;
                    end
                    PPUSCROLL: begin
                        if (!write_toggle) begin
                            t[4:0] <= cpu_wdata[7:3];
                            fine_x_scroll <= cpu_wdata[2:0];
                            write_toggle <= 1'b1;
                        end else begin
                            t[14:12] <= cpu_wdata[2:0];
                            t[9:5] <= cpu_wdata[7:3];
                            write_toggle <= 1'b0;
                        end
                    end
                    PPUADDR: begin
                        if (!write_toggle) begin
                            t[14] <= 1'b0;
                            t[13:8] <= cpu_wdata[5:0];
                            write_toggle <= 1'b1;
                        end else begin
                            t[7:0] <= cpu_wdata;
                            v <= {t[14:8], cpu_wdata};
                            write_toggle <= 1'b0;
                        end
                    end
                    PPUDATA: begin
                        write_ppu_space(v[13:0], cpu_wdata);
                        if (ppuctrl[2])
                            v <= v + 15'd32;
                        else
                            v <= v + 15'd1;
                    end
                    default: begin
                    end
                endcase
            end

            if (cpu_re) begin
                case (cpu_addr)
                    PPUSTATUS: begin
                        cpu_rdata <= ppustatus;
                        ppustatus[7] <= 1'b0;
                        write_toggle <= 1'b0;
                    end
                    OAMDATA: begin
                        cpu_rdata <= oam_ram[oamaddr];
                    end
                    PPUDATA: begin
                        read_ppu_space(v[13:0], cpu_direct_data_r);
                        if (v[13:0] >= 14'h3F00) begin
                            cpu_rdata <= cpu_direct_data_r;
                            ppudata_read_buffer <= cpu_direct_data_r;
                        end else begin
                            cpu_rdata <= ppudata_read_buffer;
                            ppudata_read_buffer <= cpu_direct_data_r;
                        end
                        if (ppuctrl[2])
                            v <= v + 15'd32;
                        else
                            v <= v + 15'd1;
                    end
                    default: begin
                        cpu_rdata <= 8'h00;
                    end
                endcase
            end
        end
    end

    always @(posedge clk_ppu) begin
        if (rst) begin
            ppu_cycle <= 9'd0;
            ppu_scanline <= 9'd261;
            ppu_frame <= 16'd0;
            line_v_start <= 15'h0000;
            ppustatus[7] <= 1'b0;
            ppustatus[6] <= 1'b0;
            ppustatus[5] <= 1'b0;
            sec_count <= 3'd0;
        end else begin
            v_next_r = v;

            if ((ppu_scanline == 9'd261) && (ppu_cycle == 9'd1)) begin
                ppustatus[7] <= 1'b0;
                ppustatus[6] <= 1'b0;
                ppustatus[5] <= 1'b0;
            end

            if ((ppu_scanline == 9'd241) && (ppu_cycle == 9'd1))
                ppustatus[7] <= 1'b1;

            if ((ppu_scanline < 9'd240) && (ppu_cycle == 9'd0)) begin
                line_v_start <= v;
                evaluate_sprites(ppu_scanline);
            end

            if (rendering_on &&
                (((ppu_scanline < 9'd240) && (ppu_cycle >= 9'd1) && (ppu_cycle <= 9'd256)) ||
                 ((ppu_scanline == 9'd261) && (ppu_cycle >= 9'd1) && (ppu_cycle <= 9'd256)) ||
                 ((((ppu_scanline < 9'd240) || (ppu_scanline == 9'd261))) && (ppu_cycle >= 9'd321) && (ppu_cycle <= 9'd336)))) begin
                if ((ppu_cycle[2:0] == 3'd0) && (ppu_cycle != 9'd0))
                    v_next_r = increment_coarse_x(v_next_r);
            end

            if (rendering_on &&
                (((ppu_scanline < 9'd240) || (ppu_scanline == 9'd261)) && (ppu_cycle == 9'd256)))
                v_next_r = increment_y_scroll(v_next_r);

            if (rendering_on &&
                (((ppu_scanline < 9'd240) || (ppu_scanline == 9'd261)) && (ppu_cycle == 9'd257)))
                v_next_r = copy_horizontal_scroll(v_next_r, t);

            if (rendering_on && (ppu_scanline == 9'd261) &&
                (ppu_cycle >= 9'd280) && (ppu_cycle <= 9'd304))
                v_next_r = copy_vertical_scroll(v_next_r, t);

            if ((ppu_scanline < 9'd240) && (ppu_cycle >= 9'd1) && (ppu_cycle <= 9'd256)) begin
                vis_x_i = ppu_cycle - 1;
                vis_y_i = ppu_scanline;
                scroll_x_i = {line_v_start[10], line_v_start[4:0], fine_x_scroll};
                scroll_y_i = {line_v_start[11], line_v_start[14:12], line_v_start[9:5]};

                bg_enable_here_r = ppumask[3] && (ppumask[1] || (vis_x_i >= 8));
                sprite_enable_here_r = ppumask[4] && (ppumask[2] || (vis_x_i >= 8));

                if (bg_enable_here_r) begin
                    global_x_i = scroll_x_i + vis_x_i;
                    global_y_i = scroll_y_i;

                    nt_number_i = (((global_y_i >> 8) & 1) << 1) | ((global_x_i >> 8) & 1);
                    nt_local_x_i = global_x_i & 8'hFF;
                    nt_local_y_i = global_y_i & 8'hFF;
                    tile_x_i = nt_local_x_i >> 3;
                    tile_y_i = nt_local_y_i >> 3;

                    nt_addr_i = map_nametable_addr((nt_number_i << 10) | (tile_y_i << 5) | tile_x_i);
                    bg_tile_r = nametable_ram[nt_addr_i];

                    attr_addr_i = map_nametable_addr((nt_number_i << 10) | 10'h3C0 | ((tile_y_i >> 2) << 3) | (tile_x_i >> 2));
                    bg_attr_r = nametable_ram[attr_addr_i];
                    attr_shift_i = {tile_y_i[1], tile_x_i[1]} * 2;
                    bg_pal_sel_r = (bg_attr_r >> attr_shift_i) & 2'b11;

                    bg_pattern_base_i = ppuctrl[4] ? 14'h1000 : 14'h0000;
                    bg_row_i = nt_local_y_i[2:0];
                    bg_lo_r = chr_mem[bg_pattern_base_i + (bg_tile_r << 4) + bg_row_i];
                    bg_hi_r = chr_mem[bg_pattern_base_i + (bg_tile_r << 4) + bg_row_i + 8];
                    bg_bits_r = {bg_hi_r[7 - nt_local_x_i[2:0]], bg_lo_r[7 - nt_local_x_i[2:0]]};

                    if (bg_bits_r == 2'b00)
                        bg_pal_addr_r = 5'h00;
                    else
                        bg_pal_addr_r = {1'b0, bg_pal_sel_r, bg_bits_r};
                    bg_color_idx_r = palette_ram[map_palette_addr(bg_pal_addr_r)];
                end else begin
                    bg_bits_r = 2'b00;
                    bg_color_idx_r = palette_ram[5'h00];
                end

                sprite_found_r = 1'b0;
                sprite_zero_r = 1'b0;
                sprite_behind_r = 1'b0;
                sprite_bits_r = 2'b00;
                sprite_pal_sel_r = 2'b00;
                sprite_pal_addr_r = 5'h00;
                sprite_color_idx_r = 6'h00;

                if (sprite_enable_here_r) begin
                    for (slot_i = 0; slot_i < 8; slot_i = slot_i + 1) begin
                        if (!sprite_found_r && (slot_i < sec_count)) begin
                            if ((vis_x_i >= sec_x[slot_i]) && (vis_x_i < (sec_x[slot_i] + 8))) begin
                                sprite_x_offset_i = vis_x_i - sec_x[slot_i];
                                if (sec_attr[slot_i][6])
                                    sprite_bit_i = sprite_x_offset_i;
                                else
                                    sprite_bit_i = 7 - sprite_x_offset_i;
                                sprite_bits_r = {sec_hi[slot_i][sprite_bit_i], sec_lo[slot_i][sprite_bit_i]};
                                if (sprite_bits_r != 2'b00) begin
                                    sprite_found_r = 1'b1;
                                    sprite_zero_r = (sec_idx[slot_i] == 8'd0);
                                    sprite_behind_r = sec_attr[slot_i][5];
                                    sprite_pal_sel_r = sec_attr[slot_i][1:0];
                                    sprite_pal_addr_r = {1'b1, sprite_pal_sel_r, sprite_bits_r};
                                    sprite_color_idx_r = palette_ram[map_palette_addr(sprite_pal_addr_r)];
                                end
                            end
                        end
                    end
                end

                if (sprite_zero_r && sprite_found_r && (bg_bits_r != 2'b00) && bg_enable_here_r && (vis_x_i < 255))
                    ppustatus[6] <= 1'b1;

                final_color_r = bg_color_idx_r;
                if (sprite_found_r) begin
                    if ((bg_bits_r == 2'b00) || !sprite_behind_r)
                        final_color_r = sprite_color_idx_r;
                end

                fb_index_i = vis_y_i * 256 + vis_x_i;
                framebuf[fb_index_i] <= final_color_r;
            end

            v <= v_next_r;

            if (ppu_cycle == 9'd340) begin
                ppu_cycle <= 9'd0;
                if (ppu_scanline == 9'd261) begin
                    ppu_scanline <= 9'd0;
                    ppu_frame <= ppu_frame + 16'd1;
                end else begin
                    ppu_scanline <= ppu_scanline + 9'd1;
                end
            end else begin
                ppu_cycle <= ppu_cycle + 9'd1;
            end
        end
    end

    always @(posedge clk_pix) begin
        if (rst) begin
            pix_color <= 6'h00;
            out_r <= 8'h00;
            out_g <= 8'h00;
            out_b <= 8'h00;
        end else if (!de) begin
            pix_color <= 6'h00;
            out_r <= 8'h00;
            out_g <= 8'h00;
            out_b <= 8'h00;
        end else if ((sx < 10'd256) && (sy < 10'd240)) begin
            pix_color <= framebuf[(sy * 256) + sx];
            out_r <= pal_r;
            out_g <= pal_g;
            out_b <= pal_b;
        end else begin
            pix_color <= 6'h00;
            out_r <= 8'h00;
            out_g <= 8'h00;
            out_b <= 8'h00;
        end
    end
endmodule
