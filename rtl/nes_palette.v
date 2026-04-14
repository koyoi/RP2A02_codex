module nes_palette (
    input  wire [5:0] idx,
    output reg  [7:0] r,
    output reg  [7:0] g,
    output reg  [7:0] b
);
    always @(*) begin
        case (idx)
            6'h00: begin r=8'h54; g=8'h54; b=8'h54; end
            6'h01: begin r=8'h00; g=8'h1E; b=8'h74; end
            6'h02: begin r=8'h08; g=8'h10; b=8'h90; end
            6'h03: begin r=8'h30; g=8'h00; b=8'h88; end
            6'h04: begin r=8'h44; g=8'h00; b=8'h64; end
            6'h05: begin r=8'h5C; g=8'h00; b=8'h30; end
            6'h06: begin r=8'h54; g=8'h04; b=8'h00; end
            6'h07: begin r=8'h3C; g=8'h18; b=8'h00; end
            6'h08: begin r=8'h20; g=8'h2A; b=8'h00; end
            6'h09: begin r=8'h08; g=8'h3A; b=8'h00; end
            6'h0A: begin r=8'h00; g=8'h40; b=8'h00; end
            6'h0B: begin r=8'h00; g=8'h3C; b=8'h00; end
            6'h0C: begin r=8'h00; g=8'h32; b=8'h3C; end
            6'h0D: begin r=8'h00; g=8'h00; b=8'h00; end
            6'h0E: begin r=8'h00; g=8'h00; b=8'h00; end
            6'h0F: begin r=8'h00; g=8'h00; b=8'h00; end

            6'h10: begin r=8'h98; g=8'h96; b=8'h98; end
            6'h11: begin r=8'h08; g=8'h4C; b=8'hC4; end
            6'h12: begin r=8'h30; g=8'h32; b=8'hEC; end
            6'h13: begin r=8'h5C; g=8'h1E; b=8'hE4; end
            6'h14: begin r=8'h88; g=8'h14; b=8'hB0; end
            6'h15: begin r=8'hA0; g=8'h14; b=8'h64; end
            6'h16: begin r=8'h98; g=8'h22; b=8'h20; end
            6'h17: begin r=8'h78; g=8'h3C; b=8'h00; end
            6'h18: begin r=8'h54; g=8'h5A; b=8'h00; end
            6'h19: begin r=8'h28; g=8'h72; b=8'h00; end
            6'h1A: begin r=8'h08; g=8'h7C; b=8'h00; end
            6'h1B: begin r=8'h00; g=8'h76; b=8'h28; end
            6'h1C: begin r=8'h00; g=8'h66; b=8'h78; end
            6'h1D: begin r=8'h00; g=8'h00; b=8'h00; end
            6'h1E: begin r=8'h00; g=8'h00; b=8'h00; end
            6'h1F: begin r=8'h00; g=8'h00; b=8'h00; end

            6'h20: begin r=8'hEC; g=8'hEE; b=8'hEC; end
            6'h21: begin r=8'h4C; g=8'h9A; b=8'hEC; end
            6'h22: begin r=8'h78; g=8'h7C; b=8'hEC; end
            6'h23: begin r=8'hB0; g=8'h62; b=8'hEC; end
            6'h24: begin r=8'hE4; g=8'h54; b=8'hEC; end
            6'h25: begin r=8'hEC; g=8'h58; b=8'hB4; end
            6'h26: begin r=8'hEC; g=8'h6A; b=8'h64; end
            6'h27: begin r=8'hD4; g=8'h88; b=8'h20; end
            6'h28: begin r=8'hA0; g=8'hAA; b=8'h00; end
            6'h29: begin r=8'h74; g=8'hC4; b=8'h00; end
            6'h2A: begin r=8'h4C; g=8'hD0; b=8'h20; end
            6'h2B: begin r=8'h38; g=8'hCC; b=8'h6C; end
            6'h2C: begin r=8'h38; g=8'hB4; b=8'hCC; end
            6'h2D: begin r=8'h3C; g=8'h3C; b=8'h3C; end
            6'h2E: begin r=8'h00; g=8'h00; b=8'h00; end
            6'h2F: begin r=8'h00; g=8'h00; b=8'h00; end

            6'h30: begin r=8'hEC; g=8'hEE; b=8'hEC; end
            6'h31: begin r=8'hA8; g=8'hCC; b=8'hEC; end
            6'h32: begin r=8'hBC; g=8'hBC; b=8'hEC; end
            6'h33: begin r=8'hD4; g=8'hB2; b=8'hEC; end
            6'h34: begin r=8'hEC; g=8'hAE; b=8'hEC; end
            6'h35: begin r=8'hEC; g=8'hAE; b=8'hD4; end
            6'h36: begin r=8'hEC; g=8'hB4; b=8'hB0; end
            6'h37: begin r=8'hE4; g=8'hC4; b=8'h90; end
            6'h38: begin r=8'hCC; g=8'hD2; b=8'h78; end
            6'h39: begin r=8'hB4; g=8'hDE; b=8'h78; end
            6'h3A: begin r=8'hA8; g=8'hE2; b=8'h90; end
            6'h3B: begin r=8'h98; g=8'hE2; b=8'hB4; end
            6'h3C: begin r=8'hA0; g=8'hD6; b=8'hE4; end
            6'h3D: begin r=8'hA0; g=8'hA2; b=8'hA0; end
            6'h3E: begin r=8'h00; g=8'h00; b=8'h00; end
            default: begin r=8'h00; g=8'h00; b=8'h00; end
        endcase
    end
endmodule