ファミコンの GPU(PPU) である RP2C02 を Verilog/SystemVerilog で実装します。

現状の `rp2c02_minimal` には次を含めています。

- BG 描画
- OAM / sprite 描画
- `PPUSTATUS` の sprite 0 hit / overflow
- `v/t/x/w` ベースのスクロールレジスタ書き込み
- 外部 CHR-ROM 相当の `chr_mem[0:8191]` 接続
- CPU / PPU / VGA の分離クロック

Icarus Verilog 例:

```sh
iverilog -g2012 -o simv \
  rtl/vga_timing_640x480.v \
  rtl/nes_palette.v \
  rtl/rp2c02_minimal.v \
  sim/tb_rp2c02_minimal.v

vvp simv
```
