module simple_dualport_ram #(
    parameter AW = 10,
    parameter DW = 8,
    parameter INIT_FILE = ""
) (
    input  wire             clka,
    input  wire             wea,
    input  wire [AW-1:0]    addra,
    input  wire [DW-1:0]    dina,
    output reg  [DW-1:0]    douta,

    input  wire             clkb,
    input  wire             web,
    input  wire [AW-1:0]    addrb,
    input  wire [DW-1:0]    dinb,
    output reg  [DW-1:0]    doutb
);
    reg [DW-1:0] mem [0:(1<<AW)-1];
    integer i;
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end else begin
            for (i = 0; i < (1<<AW); i = i + 1)
                mem[i] = {DW{1'b0}};
        end
    end

    always @(posedge clka) begin
        if (wea)
            mem[addra] <= dina;
        douta <= mem[addra];
    end

    always @(posedge clkb) begin
        if (web)
            mem[addrb] <= dinb;
        doutb <= mem[addrb];
    end
endmodule