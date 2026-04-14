Icarus Verilog 例:

iverilog -g2012 -o simv \
  rtl/vga_timing_640x480.v \
  rtl/nes_palette.v \
  rtl/rp2c02_minimal.v \
  sim/tb_rp2c02_minimal.v

vvp simv
