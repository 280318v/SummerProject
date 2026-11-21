/* VGAのRGB信号を出力する */

module VGAIF(
    input            PCK, RST,
     input   [2:0]    display_mode, // 画面切替

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
                  COL_RED   = 12'hF00,
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

/* ----------------タイトル画面画面 ----------------
 * 基準：VGA有効画面 640×480、左上 (0,0)
 * 黒枠、赤い文字、黒背景で描画する。（黒枠は背景と同色のため見えない）
 * TIME_SELECT_MODE は CTL_UNIT の実際のモード値に合わせて変更する。
 */
localparam [2:0] TIME_SELECT_MODE = 3'd0;
localparam [9:0] FRAME_L = 10'd8,
                 FRAME_R = 10'd614,
                 FRAME_T = 10'd32,
                 FRAME_B = 10'd448;
localparam [9:0] TITLE_X = 10'd176,
                 TITLE_Y = 10'd53;   // 12文字×(6ドット×4倍)=288px
localparam [9:0] HEAD_X  = 10'd140,
                 HEAD_Y  = 10'd226;  // 20文字×(6ドット×3倍)=360px
localparam [9:0] OPT0_X  = 10'd153,
                 OPT1_X  = 10'd270,
                 OPT2_X  = 10'd389,
                 OPT_Y   = 10'd314;  // 文字の縦横2倍

wire video_active = (iHCNT < 10'd640) && (iVCNT < 10'd480);
wire frame_pixel =
     (((iHCNT == FRAME_L) || (iHCNT == FRAME_R)) &&
      (iVCNT >= FRAME_T) && (iVCNT <= FRAME_B)) ||
     (((iVCNT == FRAME_T) || (iVCNT == FRAME_B)) &&
      (iHCNT >= FRAME_L) && (iHCNT <= FRAME_R));

// 5×7ビットマップの任意の1行を返す。MSBが左端の点。
function [4:0] font_row;
    input [7:0] code;
    input [2:0] row_no;
    reg [34:0] bitmap;
    begin
        case (code)
            "C": bitmap = {5'b01111, 5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b01111};
            "F": bitmap = {5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b10000};
            "S": bitmap = {5'b01111, 5'b10000, 5'b10000, 5'b01110, 5'b00001, 5'b00001, 5'b11110};
            "T": bitmap = {5'b11111, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100};
            "W": bitmap = {5'b10001, 5'b10001, 5'b10001, 5'b10101, 5'b10101, 5'b10101, 5'b01010};
            "c": bitmap = {5'b00000, 5'b01111, 5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b01111};
            "e": bitmap = {5'b00000, 5'b01110, 5'b10001, 5'b11111, 5'b10000, 5'b10001, 5'b01110};
            "g": bitmap = {5'b00000, 5'b01111, 5'b10001, 5'b10001, 5'b01111, 5'b00001, 5'b01110};
            "h": bitmap = {5'b10000, 5'b10000, 5'b11110, 5'b10001, 5'b10001, 5'b10001, 5'b10001};
            "i": bitmap = {5'b00100, 5'b00000, 5'b01100, 5'b00100, 5'b00100, 5'b00100, 5'b01110};
            "k": bitmap = {5'b10000, 5'b10001, 5'b10010, 5'b11100, 5'b10010, 5'b10001, 5'b10001};
            "l": bitmap = {5'b01100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b01110};
            "m": bitmap = {5'b00000, 5'b11010, 5'b10101, 5'b10101, 5'b10101, 5'b10101, 5'b10101};
            "n": bitmap = {5'b00000, 5'b11110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001};
            "o": bitmap = {5'b00000, 5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110};
            "r": bitmap = {5'b00000, 5'b10110, 5'b11001, 5'b10000, 5'b10000, 5'b10000, 5'b10000};
            "s": bitmap = {5'b00000, 5'b01111, 5'b10000, 5'b01110, 5'b00001, 5'b00001, 5'b11110};
            "t": bitmap = {5'b00100, 5'b00100, 5'b11111, 5'b00100, 5'b00100, 5'b00100, 5'b00011};
            "u": bitmap = {5'b00000, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10011, 5'b01101};
            "0": bitmap = {5'b01110, 5'b10001, 5'b10011, 5'b10101, 5'b11001, 5'b10001, 5'b01110};
            "1": bitmap = {5'b00100, 5'b01100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b01110};
            "2": bitmap = {5'b01110, 5'b10001, 5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b11111};
            "5": bitmap = {5'b11111, 5'b10000, 5'b11110, 5'b00001, 5'b00001, 5'b10001, 5'b01110};
            ":": bitmap = {5'b00000, 5'b00100, 5'b00100, 5'b00000, 5'b00100, 5'b00100, 5'b00000};
            " ": bitmap = {5'b00000, 5'b00000, 5'b00000, 5'b00000, 5'b00000, 5'b00000, 5'b00000};
            default: bitmap = {7{5'b00000}};
        endcase
        case (row_no)
            3'd0: font_row = bitmap[34:30];
            3'd1: font_row = bitmap[29:25];
            3'd2: font_row = bitmap[24:20];
            3'd3: font_row = bitmap[19:15];
            3'd4: font_row = bitmap[14:10];
            3'd5: font_row = bitmap[9:5];
            3'd6: font_row = bitmap[4:0];
            default: font_row = 5'b00000;
        endcase
    end
endfunction

// 文字位置をASCIIに変換（ROM相当）
function [7:0] title_char;
    input [4:0] n;
    begin
        case (n)
            5'd0: title_char = "C";
            5'd1: title_char = "o";
            5'd2: title_char = "n";
            5'd3: title_char = "n";
            5'd4: title_char = "e";
            5'd5: title_char = "c";
            5'd6: title_char = "t";
            5'd7: title_char = " ";
            5'd8: title_char = "F";
            5'd9: title_char = "o";
            5'd10: title_char = "u";
            5'd11: title_char = "r";
            default: title_char = " ";
        endcase
    end
endfunction

function [7:0] head_char;
    input [4:0] n;
    begin
        case (n)
            5'd0: head_char = "S";
            5'd1: head_char = "e";
            5'd2: head_char = "l";
            5'd3: head_char = "e";
            5'd4: head_char = "c";
            5'd5: head_char = "t";
            5'd6: head_char = " ";
            5'd7: head_char = "T";
            5'd8: head_char = "h";
            5'd9: head_char = "i";
            5'd10: head_char = "n";
            5'd11: head_char = "k";
            5'd12: head_char = "i";
            5'd13: head_char = "n";
            5'd14: head_char = "g";
            5'd15: head_char = " ";
            5'd16: head_char = "T";
            5'd17: head_char = "i";
            5'd18: head_char = "m";
            5'd19: head_char = "e";
            default: head_char = " ";
        endcase
    end
endfunction

// num = 0:SW0 : 5s / 1:SW1 : 10s / 2:SW2 : 15s
function [7:0] option_char;
    input [1:0] num;
    input [3:0] n;
    begin
        case (n)
            4'd0: option_char = "S";
            4'd1: option_char = "W";
            4'd2: option_char = (num == 2'd0) ? "0" :
                                 (num == 2'd1) ? "1" : "2";
            4'd3: option_char = " ";
            4'd4: option_char = ":";
            4'd5: option_char = " ";
            4'd6: option_char = (num == 2'd0) ? "5" : "1";
            4'd7: option_char = (num == 2'd0) ? "s" :
                                 (num == 2'd1) ? "0" : "5";
            4'd8: option_char = (num == 2'd0) ? " " : "s";
            default: option_char = " ";
        endcase
    end
endfunction

// タイトル：横縦4倍、6ドットピッチ、12文字
wire title_area = (iHCNT >= TITLE_X) && (iHCNT < TITLE_X + 10'd288) &&
                  (iVCNT >= TITLE_Y) && (iVCNT < TITLE_Y + 10'd28);
wire [9:0] title_xunit = (iHCNT - TITLE_X) >> 2;
wire [4:0] title_index = title_xunit / 10'd6;
wire [2:0] title_px = title_xunit % 10'd6;
wire [2:0] title_py = (iVCNT - TITLE_Y) >> 2;
wire [4:0] title_mask = font_row(title_char(title_index), title_py);
wire title_pixel = title_area && (title_px < 3'd5) &&
                   title_mask[3'd4 - title_px];

// 見出し：横縦3倍、20文字
wire head_area = (iHCNT >= HEAD_X) && (iHCNT < HEAD_X + 10'd360) &&
                 (iVCNT >= HEAD_Y) && (iVCNT < HEAD_Y + 10'd21);
wire [9:0] head_xunit = (iHCNT - HEAD_X) / 10'd3;
wire [4:0] head_index = head_xunit / 10'd6;
wire [2:0] head_px = head_xunit % 10'd6;
wire [2:0] head_py = (iVCNT - HEAD_Y) / 10'd3;
wire [4:0] head_mask = font_row(head_char(head_index), head_py);
wire head_pixel = head_area && (head_px < 3'd5) &&
                  head_mask[3'd4 - head_px];

// 選択肢：横縦2倍、同じ文字ROMを3か所で利用
wire opt0_area = (iHCNT >= OPT0_X) && (iHCNT < OPT0_X + 10'd96) &&
                 (iVCNT >= OPT_Y) && (iVCNT < OPT_Y + 10'd14);
wire opt1_area = (iHCNT >= OPT1_X) && (iHCNT < OPT1_X + 10'd108) &&
                 (iVCNT >= OPT_Y) && (iVCNT < OPT_Y + 10'd14);
wire opt2_area = (iHCNT >= OPT2_X) && (iHCNT < OPT2_X + 10'd108) &&
                 (iVCNT >= OPT_Y) && (iVCNT < OPT_Y + 10'd14);

wire [9:0] opt0_unit = (iHCNT - OPT0_X) >> 1;
wire [9:0] opt1_unit = (iHCNT - OPT1_X) >> 1;
wire [9:0] opt2_unit = (iHCNT - OPT2_X) >> 1;
wire [3:0] opt0_index = opt0_unit / 10'd6;
wire [3:0] opt1_index = opt1_unit / 10'd6;
wire [3:0] opt2_index = opt2_unit / 10'd6;
wire [2:0] opt0_px = opt0_unit % 10'd6;
wire [2:0] opt1_px = opt1_unit % 10'd6;
wire [2:0] opt2_px = opt2_unit % 10'd6;
wire [2:0] opt_py = (iVCNT - OPT_Y) >> 1;
wire [4:0] opt0_mask = font_row(option_char(2'd0, opt0_index), opt_py);
wire [4:0] opt1_mask = font_row(option_char(2'd1, opt1_index), opt_py);
wire [4:0] opt2_mask = font_row(option_char(2'd2, opt2_index), opt_py);
wire option_pixel =
    (opt0_area && (opt0_px < 3'd5) && opt0_mask[3'd4 - opt0_px]) ||
    (opt1_area && (opt1_px < 3'd5) && opt1_mask[3'd4 - opt1_px]) ||
    (opt2_area && (opt2_px < 3'd5) && opt2_mask[3'd4 - opt2_px]);


/* ---------------- RGB出力 ---------------- */
reg [11:0] vga_rgb;

always @(posedge PCK) begin
    if (RST) begin
        vga_rgb <= COL_BLACK;
    end
    // ★ここにタイトル/勝利画面を追加 (例: else if (current_mode == TITLE) begin ... end)
    else if(!video_active) begin
        vga_rgb <= COL_BLACK;  //表示領域外は黒
    end
    else if(display_mode == TIME_SELECT_MODE) begin
        //時間選択画面は文字は赤、枠とその他画素は黒
        if (title_pixel || head_pixel || option_pixel)
            vga_rgb <= COL_RED;
        else if(frame_pixel)
            vga_rgb <= COL_BLACK;
        else
            vga_rgb <= COL_BLACK;
    end
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
