/*VGAの同期信号を出力する*/

module SYNCGEN(
    input               CLK,
    input               RST,
    output  reg         PCK,
    output  reg         VGA_HS,
    output  reg         VGA_VS,
    output  reg [9:0]   HCNT,
    output  reg [9:0]   VCNT
);


/* VGA(640×480)用パラメータ読み込み */
`include "vga_param.vh"

/* システムクロックを2分周してPCKを生成 */
initial PCK = 1'b1; // 1(High)
always @( posedge CLK ) begin
    PCK <= ~PCK; // PCKを反転(~)
end

/* 水平カウンタ */
wire hcntend = (HCNT==HPERIOD-10'h001);

always @( posedge PCK ) begin
    if ( RST )
        HCNT <= 10'h000;
    else if ( hcntend )
        HCNT <= 10'h000;
    else
        HCNT <= HCNT + 10'h001;
end


/* 垂直カウンタ */
wire vcntend = (VCNT == VPERIOD - 10'h001);

always @( posedge PCK ) begin
    if ( RST )
        VCNT <= 10'h000;
    else if ( hcntend ) begin
        if ( vcntend )
            VCNT <= 10'h000;
        else
            VCNT <= VCNT + 10'h001;
    end
end

/* 同期信号 */
wire [9:0] hsstart = HFRONT - 10'h001;
wire [9:0] hsend   = HFRONT + HWIDTH - 10'h001;
wire [9:0] vsstart = VFRONT;
wire [9:0] vsend   = VFRONT + VWIDTH;

/*水平同期信号のON/OFF*/
always @( posedge PCK ) begin
    if ( RST )
        VGA_HS <= 1'b1;
    else if ( HCNT==hsstart )
        VGA_HS <= 1'b0;
    else if ( HCNT==hsend )
        VGA_HS <= 1'b1;
end

/*垂直同期信号のON/OFF*/
always @( posedge PCK ) begin
    if ( RST )
        VGA_VS <= 1'b1;
    else if ( HCNT==hsstart ) begin
        if ( VCNT==vsstart )
            VGA_VS <= 1'b0;
        else if ( VCNT==vsend )
            VGA_VS <= 1'b1;
    end
end

endmodule