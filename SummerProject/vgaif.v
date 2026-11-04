/* VGAのRGB信号を出力する */

module VGAIF(
    input               PCK,
    input               RST,
    input       [9:0]   HCNT,
    input       [9:0]   VCNT,
    input       [2:0]   stage_state,    // 画面の状態 (ctl_unitから)
    input               turn,           // 0:1Pのターン(赤) 1:2Pのターン(青)
    input       [9:0]   coin_x,         // 操作中コインの左上X (表示領域の座標)
    input       [9:0]   coin_y,         // 操作中コインの左上Y (表示領域の座標)
    input       [156:0] field1,         // 1Pのコイン配置 (1:コインあり)
    input       [156:0] field2,         // 2Pのコイン配置 (1:コインあり)
    output      [3:0]   VGA_R,
    output      [3:0]   VGA_G,
    output      [3:0]   VGA_B
);

/* VGA(640×480)用パラメータ読み込み */
`include "vga_param.vh"

/* 表示領域の左上を(0,0)にした座標 */
wire [9:0] iHCNT = HCNT - HBEGIN;
wire [9:0] iVCNT = VCNT - VBEGIN;

/* RGB出力信号 */
reg [11:0] vga_rgb;

/* 画面の状態 */
localparam  SELECT = 3'b000, PLAY = 3'b001, WIN1 = 3'b010, WIN2 = 3'b011;

/* 色 (RGB 各4bit) */
localparam red = 12'hf00, blue = 12'h00f, white = 12'hfff, black = 12'h000;

/* 盤面の寸法 */
localparam LINE    = 10'd2;     // 線の太さ
localparam PITCH   = 10'd39;    // 1マスの周期 (37 + 2)
localparam BOARD_X = 10'd182;   // 盤面左上のX
localparam BOARD_Y = 10'd160;   // 盤面左上のY (上にコイン用の余白)
localparam BOARD_W = 10'd275;   // 39*7 + 2
localparam BOARD_H = 10'd236;   // 39*6 + 2
localparam COIN_D  = 10'd35;    // コイン直径

// ===========================================================
//  コインの形 (直径35pxの円)
//  lx, ly : コイン左上を(0,0)にした座標 (0〜34)
// ===========================================================
function is_coin_shape;
    input [5:0] lx, ly;
    begin
        case(ly)
            6'd0, 6'd34: is_coin_shape = (lx >= 13 && lx <= 21); // 幅9
            6'd1, 6'd33: is_coin_shape = (lx >= 10 && lx <= 24); // 幅15
            6'd2, 6'd32: is_coin_shape = (lx >= 8 && lx <= 26); // 幅19
            6'd3, 6'd31: is_coin_shape = (lx >= 7 && lx <= 27); // 幅21
            6'd4, 6'd30: is_coin_shape = (lx >= 6 && lx <= 28); // 幅23
            6'd5, 6'd29: is_coin_shape = (lx >= 5 && lx <= 29); // 幅25
            6'd6, 6'd28: is_coin_shape = (lx >= 4 && lx <= 30); // 幅27
            6'd7, 6'd27: is_coin_shape = (lx >= 3 && lx <= 31); // 幅29
            6'd8, 6'd26: is_coin_shape = (lx >= 2 && lx <= 32); // 幅31
            6'd9, 6'd25: is_coin_shape = (lx >= 2 && lx <= 32); // 幅31
            6'd10, 6'd24: is_coin_shape = (lx >= 1 && lx <= 33); // 幅33
            6'd11, 6'd23: is_coin_shape = (lx >= 1 && lx <= 33); // 幅33
            6'd12, 6'd22: is_coin_shape = (lx >= 1 && lx <= 33); // 幅33
            6'd13, 6'd21: is_coin_shape = (lx >= 0 && lx <= 34); // 幅35
            6'd14, 6'd20: is_coin_shape = (lx >= 0 && lx <= 34); // 幅35
            6'd15, 6'd19: is_coin_shape = (lx >= 0 && lx <= 34); // 幅35
            6'd16, 6'd18: is_coin_shape = (lx >= 0 && lx <= 34); // 幅35
            default:     is_coin_shape = (lx >= 0 && lx <= 34); // 幅35 (y=17)
        endcase
    end
endfunction

// ===========================================================
//  盤面の線
// ===========================================================
wire in_board = (BOARD_X <= iHCNT && iHCNT < BOARD_X + BOARD_W) &&
                (BOARD_Y <= iVCNT && iVCNT < BOARD_Y + BOARD_H);

wire [9:0] bx = iHCNT - BOARD_X;        // 盤面左上を原点にした座標
wire [9:0] by = iVCNT - BOARD_Y;

wire [9:0] col = bx / PITCH;            // 何列目か (0〜6)
wire [9:0] row = by / PITCH;            // 何行目か (0〜5)
wire [9:0] lx  = bx % PITCH;            // マス内のX (0〜38) 0,1は線
wire [9:0] ly  = by % PITCH;            // マス内のY (0〜38) 0,1は線

wire border = in_board && (lx < LINE || ly < LINE);

// ===========================================================
//  置かれたコイン (field1, field2)
//
//  field は 13列×12行 (157bit) で、画面に見える6行×7列の外側に
//  上下左右3マスずつの余白がある (4つ揃い判定用)。
//    画面の(行r, 列c) → 添え字 = (r+3)*13 + (c+3)
//    例: 左上(0,0)=42, 右上(0,6)=48, 左下(5,0)=107, 右下(5,6)=113
// ===========================================================
wire [9:0] cell_idx = (row + 10'd3) * 10'd13 + (col + 10'd3);

// マスの中(線を除く37x37)で、コイン(35x35)は1px内側に置く
wire in_cell_coin = (10'd3 <= lx && lx <= 10'd37) && (10'd3 <= ly && ly <= 10'd37);
wire [9:0] cx = lx - 10'd3;             // コイン左上を原点にした座標
wire [9:0] cy = ly - 10'd3;

wire fixed_shape = in_board && !border && in_cell_coin && is_coin_shape(cx[5:0], cy[5:0]);

wire p1_coin = fixed_shape && field1[cell_idx];
wire p2_coin = fixed_shape && field2[cell_idx];


endmodule