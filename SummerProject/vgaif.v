/* VGAのRGB信号を出力する */

module VGAIF(
    input            PCK, RST,

    /* 同期信号 (syncgen.v から) */
    input   [9:0]    HCNT,
    input   [9:0]    VCNT,

    /* field_update.v から */
    input   [41:0]   field1,      // プレイヤー1のコイン  idx = row*7 + col
    input   [41:0]   field2,      // プレイヤー2のコイン
    input            turn,        // 0=プレイヤー1 / 1=プレイヤー2 (動くコインの色)
    input   [2:0]    cur_col,     // 上の段で待っている列
    input   [8:0]    fall_y,      // 落下量[px]
    input            mv_show,     // 動くコインを描くか

    /* VGA出力 */
    output  [3:0]    VGA_R,
    output  [3:0]    VGA_G,
    output  [3:0]    VGA_B
);

/* VGA(640×480)用パラメータ読み込み */
`include "vga_param.vh"

/* 表示領域の左上を (0,0) とした座標 */
wire [9:0] iHCNT = HCNT - HBEGIN;
wire [9:0] iVCNT = VCNT - VBEGIN;

/* ---------------- レイアウト ---------------- */
localparam [9:0] LINE    = 10'd2;       // 線の太さ
localparam [9:0] INNER   = 10'd37;      // マスの中身
localparam [9:0] PITCH   = 10'd39;      // マスの間隔 = 線2 + 中身37
localparam [9:0] COIN_D  = 10'd35;      // コイン直径
localparam [9:0] COIN_OFF= 10'd3;       // マスの左上(線の外側)からコイン左上まで = 線2 + 隙間1
localparam [9:0] BOARD_X = 10'd182;     // 盤面の左端  ((640-275)/2 ≒ 182)
localparam [9:0] BOARD_Y = 10'd140;     // 盤面の上端  (上のコイン段 37px を含めて縦中央に配置)
localparam [9:0] BOARD_W = 10'd275;     // 39*7 + 2
localparam [9:0] BOARD_H = 10'd236;     // 39*6 + 2
localparam [9:0] LANE_Y  = BOARD_Y - INNER + 10'd1;   // 上の段にあるコインの上端 (中身37の1px内側)

/* ---------------- 色 ---------------- */
localparam [11:0] COL_BLACK = 12'h000,
                  COL_BOARD = 12'h00A,      // 盤面の青
                  COL_LINE  = 12'hFFF,      // 線 (白)
                  COL_P1    = 12'hF00,      // プレイヤー1 (赤)
                  COL_P2    = 12'hFF0;      // プレイヤー2 (黄)

/* ---------------- 円形判定 (直径35px) ----------------
 * マス内座標 lx,ly は 0〜34。中心 (17,17) からの距離^2 が 306 (=17.5^2) 以下なら円の中。
 */
function in_circle;
    input [5:0] lx, ly;
    reg   [5:0]  ax, ay;
    reg   [10:0] d2;
    begin
        ax = (lx >= 6'd17) ? (lx - 6'd17) : (6'd17 - lx);
        ay = (ly >= 6'd17) ? (ly - 6'd17) : (6'd17 - ly);
        d2 = ax * ax + ay * ay;
        in_circle = (d2 <= 11'd306);
    end
endfunction

/* ---------------- 盤面 (線・置かれたコイン) ---------------- */
wire in_board = (iHCNT >= BOARD_X) && (iHCNT < BOARD_X + BOARD_W) &&
                (iVCNT >= BOARD_Y) && (iVCNT < BOARD_Y + BOARD_H);

wire [9:0] bx = iHCNT - BOARD_X;        // 盤面内の相対座標
wire [9:0] by = iVCNT - BOARD_Y;

wire [9:0] cx = bx / PITCH;             // 列番号 (0〜7, 7は右端の線)
wire [9:0] cy = by / PITCH;             // 行番号 (0〜6, 6は下端の線)
wire [5:0] px = bx % PITCH;             // マス内の位置 (0〜38) 0,1=線 / 2=隙間 / 3〜37=コイン / 38=隙間
wire [5:0] py = by % PITCH;

wire grid_line = in_board && ((px < 6'd2) || (py < 6'd2));

// コインの外接四角形 (px,py が 3〜37 の 35x35)
wire cell_in  = in_board && (px >= 6'd3) && (px <= 6'd37) && (py >= 6'd3) && (py <= 6'd37)
                         && (cx < 10'd7) && (cy < 10'd6);
wire [5:0] lx = px - 6'd3;              // コインの中の座標 (0〜34)
wire [5:0] ly = py - 6'd3;
wire [5:0] idx = cy[2:0] * 6'd7 + cx[2:0];   // field の何ビット目か

wire coin_shape = in_circle(lx, ly);
wire placed_p1  = cell_in && coin_shape && field1[idx];
wire placed_p2  = cell_in && coin_shape && field2[idx];

/* ---------------- 横移動・落下中のコイン ---------------- */
wire [9:0] mv_x0 = BOARD_X + {7'd0, cur_col} * PITCH + COIN_OFF;   // コインの左端
wire [9:0] mv_y0 = LANE_Y + {1'b0, fall_y};                    // コインの上端

wire mv_in_x = (iHCNT >= mv_x0) && (iHCNT < mv_x0 + COIN_D);
wire mv_in_y = (iVCNT >= mv_y0) && (iVCNT < mv_y0 + COIN_D);
wire [5:0] mlx = iHCNT - mv_x0;
wire [5:0] mly = iVCNT - mv_y0;

wire mv_coin = mv_show && mv_in_x && mv_in_y && in_circle(mlx, mly);

/* ---------------- RGB出力 ---------------- */
reg [11:0] vga_rgb;

always @(posedge PCK) begin
    if (RST) begin
        vga_rgb <= COL_BLACK;
    end
    // ★ここにタイトル/勝利画面を追加 (例: else if (current_mode == TITLE) begin ... end)
    else begin
        // 優先度が高いものから上に置く
        if (grid_line)                  vga_rgb <= COL_LINE;
        else if (placed_p1)             vga_rgb <= COL_P1;
        else if (placed_p2)             vga_rgb <= COL_P2;
        else if (mv_coin)               vga_rgb <= turn ? COL_P2 : COL_P1;
        else if (in_board)              vga_rgb <= COL_BOARD;
        else                            vga_rgb <= COL_BLACK;
    end
end

assign VGA_R = vga_rgb[11:8];
assign VGA_G = vga_rgb[7:4];
assign VGA_B = vga_rgb[3:0];

endmodule
