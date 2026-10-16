module VGAIF(//ディスプレイ表示モジュール
    input            PCK, RST, 

    /*ctl_unitから入力されるゲームの状態の情報*/
    input       [2:0] display_mode,

    /* 同期信号 */
    input   [9:0]   HCNT,
    input   [9:0]   VCNT,
    
    //多次元配列の入出力は対応してない
    input  [9:0] stage_1, stage_2, stage_3, stage_4, stage_5, stage_6, stage_7,
                stage_8, stage_9, stage_10, stage_11, stage_12, stage_13, stage_14,
                stage_15, stage_16, stage_17, stage_18, stage_19, stage_20,
    
    input  [9:0] coin_stage_1, coin_stage_2, coin_stage_3, coin_stage_4, coin_stage_5, coin_stage_6, coin_stage_7,
                coin_stage_8, coin_stage_9, coin_stage_10, coin_stage_11, coin_stage_12, coin_stage_13, coin_stage_14,
                coin_stage_15, coin_stage_16, coin_stage_17, coin_stage_18, coin_stage_19, coin_stage_20,

    /* VGA出力 */
    output  [3:0]   VGA_R,
    output  [3:0]   VGA_G,
    output  [3:0]   VGA_B
);

/* VGA(640×480)用パラメータ読み込み */
`include "vga_param.vh"

wire signed [9:0] stage [19:0];

integer i,j;

/* 内部での参照用にカウント値を変換(表示データを用意する地点を0とする) */
wire [9:0] iHCNT = HCNT - HFRONT - HWIDTH - HBACK;
wire [9:0] iVCNT = VCNT - VFRONT - VWIDTH - VBACK;

reg [9:0] hcntreg;
reg [9:0] vcntreg;

/*カラーカウント*/
reg [2:0] color_cnt;

/* RGB出力信号作成 */
reg [11:0] vga_rgb;

localparam  TITLE = 3'b000, SELECT = 3'b001, EASY = 3'b010, NORMAL = 3'b011, HARD = 3'b100,
      GAMEOVER = 3'b101, GAMECLEAR = 3'b110;

//ゲームフィールド枠
localparam left_wall = 10'd60, right_wall = 10'd261, floar = 10'd421, roof = 10'd20;
localparam left2_wall = 10'd380, right2_wall = 10'd581, floar2 = 10'd421, roof2 = 10'd20;

// 100x80の領域に16x16のマップを描画するため、1セルは約6x5ピクセルになる
localparam CELL_H_SIZE = 10'd6; // 水平セルサイズ
localparam CELL_V_SIZE = 10'd5; // 垂直セルサイズ

localparam red = 12'hf00, orange = 12'hf80, yellow = 12'hef0, green = 12'h0f0, skyblue = 12'h0ff, purple = 12'hf0f, white = 12'hfff, black = 12'h000;
localparam brown = 12'hA74, dark_gray  = 12'h444; // 暗い灰色;
localparam red2 = 12'hA00;

//ステージ枠線信号 片面のみ

wire border = ((left_wall<=iHCNT && iHCNT<=right_wall) && (roof==iVCNT) ||
             (left_wall<=iHCNT && iHCNT<=right_wall) && (floar==iVCNT) ||
              (left_wall==iHCNT) && (roof<=iVCNT && floar>=iVCNT) ||
               (iHCNT==right_wall) && (roof<=iVCNT && floar>=iVCNT));

wire border2 = ((left2_wall<=iHCNT && iHCNT<=right2_wall) && (roof==iVCNT) ||
             (left2_wall<=iHCNT && iHCNT<=right2_wall) && (floar2==iVCNT) ||
              (left2_wall==iHCNT) && (roof2<=iVCNT && floar2>=iVCNT) ||
               (iHCNT==right2_wall) && (roof2<=iVCNT && floar2>=iVCNT));


//coin
// ===========================================================
//  コイン描画ロジック (Player1 & Player2 共通・短縮版)
// ===========================================================

// --- 1. 共通の関数と垂直座標計算 ---

// 円形(ドット絵)判定関数 (20x20マス用)
function is_coin_shape;
    input [4:0] lx, ly;
    begin
        case(ly)
            5'd0, 5'd19: is_coin_shape = (lx >= 7 && lx <= 12); // 幅6
            5'd1, 5'd18: is_coin_shape = (lx >= 5 && lx <= 14); // 幅10
            5'd2, 5'd17: is_coin_shape = (lx >= 4 && lx <= 15); // 幅12
            5'd3, 5'd16: is_coin_shape = (lx >= 3 && lx <= 16); // 幅14
            5'd4, 5'd15: is_coin_shape = (lx >= 2 && lx <= 17); // 幅16
            5'd5, 5'd6, 5'd13, 5'd14: 
                            is_coin_shape = (lx >= 1 && lx <= 18); // 幅18
            default:     is_coin_shape = (lx >= 0 && lx <= 19); // 幅20
        endcase
    end
endfunction

// 垂直方向(Y)は両プレイヤー共通 (V: 21~420)
wire coin_v_active = (iVCNT >= 10'd21 && iVCNT <= 10'd420);
wire [9:0] rel_y   = iVCNT - 10'd21;        // 相対Y座標
wire [4:0] grid_row = rel_y / 10'd20;       // 行番号 (0~19)
wire [4:0] local_y  = rel_y % 10'd20;       // マス内のY (0~19)


// --- 2. プレイヤー1 (左側: 61~260) ---
wire coin1_h_active = (iHCNT >= 10'd61 && iHCNT <= 10'd260);
wire [9:0] rel_x1   = iHCNT - 10'd61;
wire [3:0] grid_col1 = 4'd9 - (rel_x1 / 10'd20);
wire [4:0] local_x1  = rel_x1 % 10'd20;

reg [9:0] row_data1; // P1のデータ選択
always @(*) begin
    case(grid_row)
        5'd0:  row_data1 = coin_stage_1;  5'd1:  row_data1 = coin_stage_2;
        5'd2:  row_data1 = coin_stage_3;  5'd3:  row_data1 = coin_stage_4;
        5'd4:  row_data1 = coin_stage_5;  5'd5:  row_data1 = coin_stage_6;
        5'd6:  row_data1 = coin_stage_7;  5'd7:  row_data1 = coin_stage_8;
        5'd8:  row_data1 = coin_stage_9;  5'd9:  row_data1 = coin_stage_10;
        5'd10: row_data1 = coin_stage_11; 5'd11: row_data1 = coin_stage_12;
        5'd12: row_data1 = coin_stage_13; 5'd13: row_data1 = coin_stage_14;
        5'd14: row_data1 = coin_stage_15; 5'd15: row_data1 = coin_stage_16;
        5'd16: row_data1 = coin_stage_17; 5'd17: row_data1 = coin_stage_18;
        5'd18: row_data1 = coin_stage_19; 5'd19: row_data1 = coin_stage_20;
        default: row_data1 = 10'd0;
    endcase
end
    
// Player1 最終判定
wire coin = coin_v_active && coin1_h_active && row_data1[grid_col1] && is_coin_shape(local_x1, local_y);


    // --- 3. プレイヤー2 (右側: 381~580) ---
    wire coin2_h_active = (iHCNT >= 10'd381 && iHCNT <= 10'd580);
    wire [9:0] rel_x2   = iHCNT - 10'd381; // P2の開始位置オフセット
    wire [3:0] grid_col2 = 4'd9 - (rel_x2 / 10'd20);
    wire [4:0] local_x2  = rel_x2 % 10'd20;

    reg [9:0] row_data2; // P2のデータ選択
    always @(*) begin
        case(grid_row)
            5'd0:  row_data2 = coin_stage2_1;  5'd1:  row_data2 = coin_stage2_2;
            5'd2:  row_data2 = coin_stage2_3;  5'd3:  row_data2 = coin_stage2_4;
            5'd4:  row_data2 = coin_stage2_5;  5'd5:  row_data2 = coin_stage2_6;
            5'd6:  row_data2 = coin_stage2_7;  5'd7:  row_data2 = coin_stage2_8;
            5'd8:  row_data2 = coin_stage2_9;  5'd9:  row_data2 = coin_stage2_10;
            5'd10: row_data2 = coin_stage2_11; 5'd11: row_data2 = coin_stage2_12;
            5'd12: row_data2 = coin_stage2_13; 5'd13: row_data2 = coin_stage2_14;
            5'd14: row_data2 = coin_stage2_15; 5'd15: row_data2 = coin_stage2_16;
            5'd16: row_data2 = coin_stage2_17; 5'd17: row_data2 = coin_stage2_18;
            5'd18: row_data2 = coin_stage2_19; 5'd19: row_data2 = coin_stage2_20;
            default: row_data2 = 10'd0;
        endcase
    end

    // Player2 最終判定 (名前は既存コードに合わせて coin2_coin など適宜調整してください)
    // ここでは新しいコイン描画用信号として定義します
    wire coin2 = coin_v_active && coin2_h_active && row_data2[grid_col2] && is_coin_shape(local_x2, local_y);




// ===========================================================
    //  車 (Mino) 描画ロジック
    // ===========================================================

    // ドット絵定義関数: 座標(lx, ly)に応じてパーツIDを返す
    // 0:なし, 1:ボディ(黒), 2:窓(水色), 3:ライト(黄)
    function [1:0] get_car_pixel_type;
        input [4:0] lx; // 0~19
        input [4:0] ly; // 0~19
        begin
            get_car_pixel_type = 2'd0; // デフォルトは透明

            // --- 1. ボディ (黒) の基本形 ---
            // 全体を黒にする (後で削る)
            // Y=1~18, X=2~17 をベースに、中央部分(タイヤ/ミラー付近)は幅広にする
            if ((ly >= 1 && ly <= 18 && lx >= 2 && lx <= 17) || 
                (ly >= 6 && ly <= 14 && lx >= 0 && lx <= 19)) begin
                get_car_pixel_type = 2'd1;
            end

            // --- 2. 窓 (水色) ---
            // フロントガラス (上部)
            if (ly >= 4 && ly <= 7 && lx >= 5 && lx <= 14) begin
                get_car_pixel_type = 2'd2;
            end
            // リアガラス (下部)
            else if (ly >= 15 && ly <= 17 && lx >= 5 && lx <= 14) begin
                get_car_pixel_type = 2'd2;
            end
            // サイドウィンドウ (左右の細いライン)
            else if (ly >= 6 && ly <= 13 && ((lx == 2 || lx == 3) || (lx == 16 || lx == 17))) begin
                get_car_pixel_type = 2'd2;
            end

            // --- 3. ヘッドライト (黄色) ---
            // 上部の左右
            if (ly == 1 && ((lx >= 4 && lx <= 6) || (lx >= 13 && lx <= 15))) begin
                get_car_pixel_type = 2'd3;
            end

            // --- 4. 形を整える (四隅を削って丸くする) ---
            // 上端の角
            if (ly <= 1 && (lx <= 3 || lx >= 16)) get_car_pixel_type = 2'd0;
            // 下端の角
            if (ly >= 18 && (lx <= 3 || lx >= 16)) get_car_pixel_type = 2'd0;
        end
    endfunction

// --- プレイヤー1 (Left: 61~260) の車判定 ---
    wire mino1_h_active = (iHCNT >= 10'd61 && iHCNT <= 10'd260);
    wire [9:0] m_rel_x1 = iHCNT - 10'd61;
    wire [3:0] m_grid_col1 = 4'd9 - (m_rel_x1 / 10'd20);
    wire [4:0] m_local_x1  = m_rel_x1 % 10'd20;
    
    // --- プレイヤー2 (Right: 381~580) の車判定 ---
    wire mino2_h_active = (iHCNT >= 10'd381 && iHCNT <= 10'd580);
    wire [9:0] m_rel_x2 = iHCNT - 10'd381;
    wire [3:0] m_grid_col2 = 4'd9 - (m_rel_x2 / 10'd20);
    wire [4:0] m_local_x2  = m_rel_x2 % 10'd20;

    // --- 共通のY座標計算 (コインと共有可能ですが、念のため記述) ---
    wire mino_v_active = (iVCNT >= 10'd21 && iVCNT <= 10'd420);
    wire [9:0] m_rel_y = iVCNT - 10'd21;
    wire [4:0] m_grid_row = m_rel_y / 10'd20;
    wire [4:0] m_local_y  = m_rel_y % 10'd20;

    // --- データ選択 (stage / stage2 配列から) ---
    reg [9:0] current_stage_row1;
    reg [9:0] current_stage_row2;
    always @(*) begin
        case(m_grid_row)
            5'd0: begin current_stage_row1 = stage_1; current_stage_row2 = stage2_1; end
            5'd1: begin current_stage_row1 = stage_2; current_stage_row2 = stage2_2; end
            5'd2: begin current_stage_row1 = stage_3; current_stage_row2 = stage2_3; end
            5'd3: begin current_stage_row1 = stage_4; current_stage_row2 = stage2_4; end
            5'd4: begin current_stage_row1 = stage_5; current_stage_row2 = stage2_5; end
            5'd5: begin current_stage_row1 = stage_6; current_stage_row2 = stage2_6; end
            5'd6: begin current_stage_row1 = stage_7; current_stage_row2 = stage2_7; end
            5'd7: begin current_stage_row1 = stage_8; current_stage_row2 = stage2_8; end
            5'd8: begin current_stage_row1 = stage_9; current_stage_row2 = stage2_9; end
            5'd9: begin current_stage_row1 = stage_10; current_stage_row2 = stage2_10; end
            5'd10: begin current_stage_row1 = stage_11; current_stage_row2 = stage2_11; end
            5'd11: begin current_stage_row1 = stage_12; current_stage_row2 = stage2_12; end
            5'd12: begin current_stage_row1 = stage_13; current_stage_row2 = stage2_13; end
            5'd13: begin current_stage_row1 = stage_14; current_stage_row2 = stage2_14; end
            5'd14: begin current_stage_row1 = stage_15; current_stage_row2 = stage2_15; end
            5'd15: begin current_stage_row1 = stage_16; current_stage_row2 = stage2_16; end
            5'd16: begin current_stage_row1 = stage_17; current_stage_row2 = stage2_17; end
            5'd17: begin current_stage_row1 = stage_18; current_stage_row2 = stage2_18; end
            5'd18: begin current_stage_row1 = stage_19; current_stage_row2 = stage2_19; end
            5'd19: begin current_stage_row1 = stage_20; current_stage_row2 = stage2_20; end
            default: begin current_stage_row1 = 10'd0; current_stage_row2 = 10'd0; end
        endcase
    end

    // --- 最終判定: その場所に車があるか？ ---
    wire p1_car_exist = mino_v_active && mino1_h_active && current_stage_row1[m_grid_col1];
    wire p2_car_exist = mino_v_active && mino2_h_active && current_stage_row2[m_grid_col2];

    // --- 色情報の取得 ---
    // P1かP2どちらかのエリアに車があれば、そのローカル座標で色を計算
    wire [1:0] p1_part_id;
    wire [1:0] p2_part_id;

    // P1のエリア内にピクセルがあればパーツIDを取得、なければ0
    assign p1_part_id = (p1_car_exist) ? get_car_pixel_type(m_local_x1, m_local_y) : 2'd0;

    // P2のエリア内にピクセルがあればパーツIDを取得、なければ0
    assign p2_part_id = (p2_car_exist) ? get_car_pixel_type(m_local_x2, m_local_y) : 2'd0;

// ミノ表示信号  TETLIS参照
//車描画

wire mino_1  = (((stage_1[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_1[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_1[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_1[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_1[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_1[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_1[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_1[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_1[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_1[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd21<=iVCNT && iVCNT<=10'd40));  
wire mino_2  = (((stage_2[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_2[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_2[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_2[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_2[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_2[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_2[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_2[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_2[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_2[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd41<=iVCNT && iVCNT<=10'd60));  
wire mino_3  = (((stage_3[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_3[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_3[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_3[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_3[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_3[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_3[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_3[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_3[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_3[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd61<=iVCNT && iVCNT<=10'd80));  
wire mino_4  = (((stage_4[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_4[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_4[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_4[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_4[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_4[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_4[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_4[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_4[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_4[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd81<=iVCNT && iVCNT<=10'd100));  
wire mino_5  = (((stage_5[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_5[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_5[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_5[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_5[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_5[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_5[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_5[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_5[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_5[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd101<=iVCNT && iVCNT<=10'd120));  
wire mino_6  = (((stage_6[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_6[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_6[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_6[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_6[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_6[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_6[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_6[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_6[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_6[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd121<=iVCNT && iVCNT<=10'd140));  
wire mino_7  = (((stage_7[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_7[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_7[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_7[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_7[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_7[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_7[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_7[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_7[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_7[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd141<=iVCNT && iVCNT<=10'd160));  
wire mino_8  = (((stage_8[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_8[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_8[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_8[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_8[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_8[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_8[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_8[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_8[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_8[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd161<=iVCNT && iVCNT<=10'd180));  
wire mino_9  = (((stage_9[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_9[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_9[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_9[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_9[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_9[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_9[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_9[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_9[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_9[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd181<=iVCNT && iVCNT<=10'd200));  
wire mino_10  = (((stage_10[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_10[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_10[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_10[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_10[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_10[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_10[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_10[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_10[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_10[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd201<=iVCNT && iVCNT<=10'd220));  
wire mino_11  = (((stage_11[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_11[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_11[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_11[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_11[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_11[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_11[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_11[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_11[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_11[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd221<=iVCNT && iVCNT<=10'd240));  
wire mino_12  = (((stage_12[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_12[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_12[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_12[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_12[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_12[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_12[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_12[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_12[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_12[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd241<=iVCNT && iVCNT<=10'd260));  
wire mino_13  = (((stage_13[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_13[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_13[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_13[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_13[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_13[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_13[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_13[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_13[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_13[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd261<=iVCNT && iVCNT<=10'd280));  
wire mino_14  = (((stage_14[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_14[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_14[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_14[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_14[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_14[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_14[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_14[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_14[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_14[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd281<=iVCNT && iVCNT<=10'd300));  
wire mino_15  = (((stage_15[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_15[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_15[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_15[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_15[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_15[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_15[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_15[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_15[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_15[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd301<=iVCNT && iVCNT<=10'd320));  
wire mino_16  = (((stage_16[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_16[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_16[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_16[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_16[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_16[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_16[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_16[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_16[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_16[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd321<=iVCNT && iVCNT<=10'd340));  
wire mino_17  = (((stage_17[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_17[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_17[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_17[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_17[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_17[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_17[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_17[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_17[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_17[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd341<=iVCNT && iVCNT<=10'd360));  
wire mino_18  = (((stage_18[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_18[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_18[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_18[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_18[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_18[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_18[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_18[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_18[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_18[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd361<=iVCNT && iVCNT<=10'd380));  
wire mino_19  = (((stage_19[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_19[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_19[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_19[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_19[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_19[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_19[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_19[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_19[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_19[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd381<=iVCNT && iVCNT<=10'd400));  
wire mino_20  = (((stage_20[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (stage_20[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (stage_20[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (stage_20[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (stage_20[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (stage_20[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (stage_20[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (stage_20[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (stage_20[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (stage_20[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd401<=iVCNT && iVCNT<=10'd420));  

wire mino =(mino_1 || mino_2 || mino_3 || mino_4 || mino_5 || mino_6 || mino_7 || mino_8 || mino_9 || mino_10 || mino_11 || mino_12 || mino_13 || mino_14 || mino_15 || mino_16 || mino_17 || mino_18 || mino_19 || mino_20 ); 

//object
wire object_1  = (((object_stage_1[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_1[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_1[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_1[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_1[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_1[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_1[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_1[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_1[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_1[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd21<=iVCNT && iVCNT<=10'd40));  
wire object_2  = (((object_stage_2[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_2[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_2[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_2[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_2[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_2[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_2[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_2[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_2[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_2[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd41<=iVCNT && iVCNT<=10'd60));  
wire object_3  = (((object_stage_3[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_3[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_3[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_3[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_3[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_3[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_3[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_3[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_3[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_3[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd61<=iVCNT && iVCNT<=10'd80));  
wire object_4  = (((object_stage_4[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_4[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_4[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_4[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_4[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_4[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_4[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_4[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_4[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_4[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd81<=iVCNT && iVCNT<=10'd100));  
wire object_5  = (((object_stage_5[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_5[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_5[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_5[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_5[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_5[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_5[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_5[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_5[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_5[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd101<=iVCNT && iVCNT<=10'd120));  
wire object_6  = (((object_stage_6[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_6[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_6[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_6[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_6[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_6[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_6[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_6[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_6[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_6[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd121<=iVCNT && iVCNT<=10'd140));  
wire object_7  = (((object_stage_7[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_7[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_7[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_7[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_7[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_7[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_7[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_7[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_7[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_7[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd141<=iVCNT && iVCNT<=10'd160));  
wire object_8  = (((object_stage_8[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_8[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_8[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_8[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_8[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_8[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_8[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_8[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_8[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_8[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd161<=iVCNT && iVCNT<=10'd180));  
wire object_9  = (((object_stage_9[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_9[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_9[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_9[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_9[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_9[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_9[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_9[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_9[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_9[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd181<=iVCNT && iVCNT<=10'd200));  
wire object_10  = (((object_stage_10[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_10[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_10[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_10[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_10[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_10[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_10[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_10[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_10[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_10[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd201<=iVCNT && iVCNT<=10'd220));  
wire object_11  = (((object_stage_11[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_11[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_11[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_11[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_11[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_11[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_11[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_11[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_11[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_11[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd221<=iVCNT && iVCNT<=10'd240));  
wire object_12  = (((object_stage_12[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_12[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_12[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_12[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_12[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_12[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_12[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_12[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_12[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_12[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd241<=iVCNT && iVCNT<=10'd260));  
wire object_13  = (((object_stage_13[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_13[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_13[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_13[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_13[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_13[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_13[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_13[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_13[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_13[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd261<=iVCNT && iVCNT<=10'd280));  
wire object_14  = (((object_stage_14[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_14[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_14[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_14[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_14[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_14[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_14[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_14[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_14[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_14[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd281<=iVCNT && iVCNT<=10'd300));  
wire object_15  = (((object_stage_15[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_15[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_15[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_15[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_15[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_15[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_15[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_15[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_15[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_15[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd301<=iVCNT && iVCNT<=10'd320));  
wire object_16  = (((object_stage_16[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_16[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_16[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_16[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_16[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_16[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_16[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_16[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_16[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_16[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd321<=iVCNT && iVCNT<=10'd340));  
wire object_17  = (((object_stage_17[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_17[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_17[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_17[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_17[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_17[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_17[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_17[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_17[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_17[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd341<=iVCNT && iVCNT<=10'd360));  
wire object_18  = (((object_stage_18[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_18[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_18[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_18[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_18[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_18[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_18[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_18[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_18[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_18[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd361<=iVCNT && iVCNT<=10'd380));  
wire object_19  = (((object_stage_19[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_19[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_19[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_19[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_19[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_19[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_19[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_19[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_19[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_19[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd381<=iVCNT && iVCNT<=10'd400));  
wire object_20  = (((object_stage_20[9] && 10'd61<=iHCNT && iHCNT<=10'd80) || (object_stage_20[8] && 10'd81<=iHCNT && iHCNT<=10'd100) || (object_stage_20[7] && 10'd101<=iHCNT && iHCNT<=10'd120) || (object_stage_20[6] && 10'd121<=iHCNT && iHCNT<=10'd140) || (object_stage_20[5] && 10'd141<=iHCNT && iHCNT<=10'd160) || (object_stage_20[4] && 10'd161<=iHCNT && iHCNT<=10'd180) || (object_stage_20[3] && 10'd181<=iHCNT && iHCNT<=10'd200) || (object_stage_20[2] && 10'd201 <= iHCNT && iHCNT<=10'd220) || (object_stage_20[1] && 10'd221 <= iHCNT && iHCNT<=10'd240) || (object_stage_20[0] && 10'd241 <= iHCNT && iHCNT<=10'd260)) && (10'd401<=iVCNT && iVCNT<=10'd420));  

wire object =(object_1 || object_2 || object_3 || object_4 || object_5 || object_6 || object_7 || object_8 || object_9 || object_10 || object_11 || object_12 || object_13 || object_14 || object_15 || object_16 || object_17 || object_18 || object_19 || object_20 ); 

//object2
wire object2_1  = (((object_stage2_1[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_1[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_1[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_1[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_1[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_1[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_1[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_1[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_1[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_1[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd21<=iVCNT && iVCNT<=10'd40));  
wire object2_2  = (((object_stage2_2[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_2[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_2[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_2[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_2[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_2[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_2[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_2[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_2[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_2[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd41<=iVCNT && iVCNT<=10'd60));  
wire object2_3  = (((object_stage2_3[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_3[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_3[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_3[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_3[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_3[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_3[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_3[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_3[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_3[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd61<=iVCNT && iVCNT<=10'd80));  
wire object2_4  = (((object_stage2_4[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_4[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_4[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_4[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_4[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_4[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_4[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_4[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_4[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_4[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd81<=iVCNT && iVCNT<=10'd100));  
wire object2_5  = (((object_stage2_5[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_5[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_5[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_5[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_5[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_5[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_5[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_5[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_5[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_5[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd101<=iVCNT && iVCNT<=10'd120));  
wire object2_6  = (((object_stage2_6[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_6[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_6[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_6[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_6[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_6[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_6[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_6[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_6[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_6[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd121<=iVCNT && iVCNT<=10'd140));  
wire object2_7  = (((object_stage2_7[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_7[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_7[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_7[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_7[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_7[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_7[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_7[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_7[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_7[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd141<=iVCNT && iVCNT<=10'd160));  
wire object2_8  = (((object_stage2_8[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_8[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_8[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_8[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_8[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_8[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_8[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_8[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_8[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_8[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd161<=iVCNT && iVCNT<=10'd180));  
wire object2_9  = (((object_stage2_9[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_9[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_9[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_9[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_9[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_9[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_9[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_9[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_9[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_9[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd181<=iVCNT && iVCNT<=10'd200));  
wire object2_10  = (((object_stage2_10[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_10[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_10[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_10[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_10[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_10[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_10[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_10[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_10[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_10[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd201<=iVCNT && iVCNT<=10'd220));  
wire object2_11  = (((object_stage2_11[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_11[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_11[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_11[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_11[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_11[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_11[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_11[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_11[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_11[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd221<=iVCNT && iVCNT<=10'd240));  
wire object2_12  = (((object_stage2_12[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_12[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_12[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_12[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_12[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_12[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_12[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_12[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_12[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_12[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd241<=iVCNT && iVCNT<=10'd260));  
wire object2_13  = (((object_stage2_13[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_13[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_13[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_13[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_13[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_13[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_13[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_13[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_13[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_13[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd261<=iVCNT && iVCNT<=10'd280));  
wire object2_14  = (((object_stage2_14[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_14[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_14[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_14[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_14[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_14[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_14[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_14[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_14[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_14[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd281<=iVCNT && iVCNT<=10'd300));  
wire object2_15  = (((object_stage2_15[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_15[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_15[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_15[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_15[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_15[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_15[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_15[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_15[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_15[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd301<=iVCNT && iVCNT<=10'd320));  
wire object2_16  = (((object_stage2_16[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_16[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_16[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_16[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_16[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_16[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_16[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_16[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_16[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_16[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd321<=iVCNT && iVCNT<=10'd340));  
wire object2_17  = (((object_stage2_17[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_17[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_17[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_17[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_17[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_17[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_17[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_17[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_17[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_17[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd341<=iVCNT && iVCNT<=10'd360));  
wire object2_18  = (((object_stage2_18[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_18[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_18[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_18[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_18[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_18[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_18[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_18[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_18[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_18[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd361<=iVCNT && iVCNT<=10'd380));  
wire object2_19  = (((object_stage2_19[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_19[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_19[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_19[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_19[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_19[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_19[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_19[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_19[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_19[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd381<=iVCNT && iVCNT<=10'd400));  
wire object2_20  = (((object_stage2_20[9] && 10'd381<=iHCNT && iHCNT<=10'd400) || (object_stage2_20[8] && 10'd401<=iHCNT && iHCNT<=10'd420) || (object_stage2_20[7] && 10'd421<=iHCNT && iHCNT<=10'd440) || (object_stage2_20[6] && 10'd441<=iHCNT && iHCNT<=10'd460) || (object_stage2_20[5] && 10'd461<=iHCNT && iHCNT<=10'd480) || (object_stage2_20[4] && 10'd481<=iHCNT && iHCNT<=10'd500) || (object_stage2_20[3] && 10'd501<=iHCNT && iHCNT<=10'd520) || (object_stage2_20[2] && 10'd521 <= iHCNT && iHCNT<=10'd540) || (object_stage2_20[1] && 10'd541 <= iHCNT && iHCNT<=10'd560) || (object_stage2_20[0] && 10'd561 <= iHCNT && iHCNT<=10'd580)) && (10'd401<=iVCNT && iVCNT<=10'd420));

wire object2 =(object2_1 || object2_2 || object2_3 || object2_4 || object2_5 || object2_6 || object2_7 || object2_8 || object2_9 || object2_10 || object2_11 || object2_12 || object2_13 || object2_14 || object2_15 || object2_16 || object2_17 || object2_18 || object2_19 || object2_20 ); 

//iHCNT = 水平　iVCNT = 垂直
wire C1_TITLE = (((10'd221<=iHCNT && iHCNT<=10'd270) && ((10'd81<=iVCNT && iVCNT<=10'd100)||(10'd161<=iVCNT && iVCNT<=10'd180))) 
            || ((10'd221<=iHCNT && iHCNT<=10'd240) && (10'd91<=iVCNT && iVCNT<=10'd160))); // C

wire A1_TITLE = (((10'd311<=iHCNT && iHCNT<=10'd340) && (10'd81<=iVCNT && iVCNT<=10'd100)) 
            || (((10'd291<=iHCNT && iHCNT<=10'd310)||(10'd341<=iHCNT && iHCNT<=10'd360)) && ((10'd101<=iVCNT && iVCNT<=10'd120)||(10'd141<=iVCNT && iVCNT<=10'd180))) 
            || ((10'd291<=iHCNT && iHCNT<=10'd360)&&(10'd120<=iVCNT && iVCNT<=10'd140))); // A

wire R1_TITLE = (((10'd381<=iHCNT && iHCNT<=10'd440) && ((10'd81<=iVCNT && iVCNT<=10'd100) || (10'd121<=iVCNT && iVCNT<=10'd140))) 
            || (((10'd381<=iHCNT && iHCNT<=10'd400) || (10'd421<=iHCNT && iHCNT<=10'd440)) && ((10'd101<=iVCNT && iVCNT<=10'd120) || (10'd161<=iVCNT && iVCNT<=10'd180))) 
            || ((10'd381<=iHCNT && iHCNT<=10'd420) && (10'd141<=iVCNT && iVCNT<=10'd160))); //R

wire R2_TITLE = (((10'd181<=iHCNT && iHCNT<=10'd240) && ((10'd201<=iVCNT && iVCNT<=10'd220) || (10'd241<=iVCNT && iVCNT<=10'd260))) 
            || (((10'd181<=iHCNT && iHCNT<=10'd200) || (10'd221<=iHCNT && iHCNT<=10'd240)) && ((10'd221<=iVCNT && iVCNT<=10'd240) || (10'd281<=iVCNT && iVCNT<=10'd300))) 
            || ((10'd181<=iHCNT && iHCNT<=10'd220) && (10'd261<=iVCNT && iVCNT<=10'd280))); //R

wire A2_TITLE = (((10'd281<=iHCNT && iHCNT<=10'd310) && (10'd201<=iVCNT && iVCNT<=10'd220)) 
            || (((10'd261<=iHCNT && iHCNT<=10'd280)||(10'd311<=iHCNT && iHCNT<=10'd330)) && ((10'd221<=iVCNT && iVCNT<=10'd240)||(10'd261<=iVCNT && iVCNT<=10'd300))) 
            || ((10'd261<=iHCNT && iHCNT<=10'd330)&&(10'd241<=iVCNT && iVCNT<=10'd260))); // A

wire C2_TITLE = (((10'd351<=iHCNT && iHCNT<=10'd410) && ((10'd201<=iVCNT && iVCNT<=10'd220)||(10'd281<=iVCNT && iVCNT<=10'd300))) 
            || ((10'd351<=iHCNT && iHCNT<=10'd370) && (10'd221<=iVCNT && iVCNT<=10'd280)));

wire E1_TITLE = (((10'd431<=iHCNT && iHCNT<=10'd480) && ((10'd201<=iVCNT && iVCNT<=10'd220) || (10'd241<=iVCNT && iVCNT<=10'd261) || (10'd281<=iVCNT && iVCNT<=10'd300))) 
            || (10'd431<=iHCNT && iHCNT<=10'd450) && ((10'd221<=iVCNT && iVCNT<=10'd240)||(10'd261<=iVCNT && iVCNT<=10'd280)));//オレンジf80

//SELECT画面表示信号
wire S1_SELECT = (((10'd101<=iHCNT && iHCNT<=10'd160) && ((10'd81<=iVCNT && iVCNT<=10'd100) || (10'd121<=iVCNT && iVCNT<=10'd140) || (10'd161 <= iVCNT && iVCNT <= 10'd180))) 
            || ((10'd101<=iHCNT && iHCNT<=10'd120) && (10'd81<=iVCNT && iVCNT<=10'd120))
            || ((10'd141<=iHCNT && iHCNT<=10'd160) && (10'd141<=iVCNT && iVCNT<=10'd160))); // S

wire E1_SELECT = (((10'd181<=iHCNT && iHCNT<=10'd230) && ((10'd81<=iVCNT && iVCNT<=10'd100) || (10'd121<=iVCNT && iVCNT<=10'd140) || (10'd161<=iVCNT && iVCNT<=10'd180))) 
            || (10'd181<=iHCNT && iHCNT<=10'd200) && ((10'd101<=iVCNT && iVCNT<=10'd120)||(10'd141<=iVCNT && iVCNT<=10'd160)));//オレンジf80

wire L1_SELECT = (((10'd251<=iHCNT && iHCNT<=10'd270)&&(10'd81<=iVCNT && iVCNT<=10'd180)) 
            || ((10'd251<=iHCNT && iHCNT<=10'd300)&&(10'd161<=iVCNT && iVCNT<=10'd180))); // L

wire E2_SELECT = (((10'd321<=iHCNT && iHCNT<=10'd370)&&((10'd81<=iVCNT && iVCNT<=10'd100)||(10'd121<=iVCNT && iVCNT<=10'd140)||(10'd161<=iVCNT && iVCNT<=10'd180))) 
            ||((10'd321<=iHCNT && iHCNT<=10'd340)&&((10'd101<=iVCNT && iVCNT<=10'd120)||(10'd141<=iVCNT && iVCNT<=10'd160))));

wire C1_SELECT = (((10'd391<=iHCNT && iHCNT<=10'd440) && ((10'd81<=iVCNT && iVCNT<=10'd100)||(10'd161<=iVCNT && iVCNT<=10'd180))) 
            || ((10'd391<=iHCNT && iHCNT<=10'd410) && (10'd91<=iVCNT && iVCNT<=10'd160)));

wire T1_SELECT = (((10'd461<=iHCNT && iHCNT<=10'd520) && (10'd81<=iVCNT && iVCNT<=10'd100)) 
            || ((10'd481<=iHCNT && iHCNT<=10'd500) && (10'd101<=iVCNT && iVCNT<=10'd180)));//赤 f00 

//EASY画面表示
wire S1_SW1 = (((10'd111<=iHCNT && iHCNT<=10'd130) && ((10'd201<=iVCNT && iVCNT<=10'd210) || (10'd221<=iVCNT && iVCNT<=10'd230) || (10'd241 <= iVCNT && iVCNT <= 10'd250))) 
            || ((10'd111<=iHCNT && iHCNT<=10'd120) && (10'd201<=iVCNT && iVCNT<=10'd220))
            || ((10'd121<=iHCNT && iHCNT<=10'd130) && (10'd231<=iVCNT && iVCNT<=10'd240)));

wire W1_SW1 = ((((10'd151<=iHCNT && iHCNT<=10'd160) || (10'd171<=iHCNT && iHCNT<=10'd180) || (10'd191<=iHCNT && iHCNT<=10'd200)) && (10'd201<=iVCNT && iVCNT<= 10'd225))
            || (((10'd161<=iHCNT && iHCNT<=10'd170) || (10'd181<=iHCNT && iHCNT<=10'd190)) && (10'd226<=iVCNT && iVCNT<=10'd250)));

wire SW1_SW1 = (((10'd211<=iHCNT && iHCNT<=10'd220) && (10'd201<=iVCNT && iVCNT<=10'd250)));

wire C1_EASY = (((10'd231<=iHCNT && iHCNT<=10'd240) && ((10'd201<= iVCNT && iVCNT<=10'd215) || (10'd236<=iVCNT && iVCNT<=10'd250))));

wire E_EASY = (((10'd251<=iHCNT && iHCNT<=10'd280)&&((10'd201<=iVCNT && iVCNT<=10'd210)||(10'd221<=iVCNT && iVCNT<=10'd230)||(10'd241<=iVCNT && iVCNT<=10'd250))) 
            ||((10'd251<=iHCNT && iHCNT<=10'd260)&&((10'd211<=iVCNT && iVCNT<=10'd220)||(10'd231<=iVCNT && iVCNT<=10'd240))));

wire A_EASY = (((10'd301<=iHCNT && iHCNT<=10'd310) && (10'd201<=iVCNT && iVCNT<=10'd210)) 
            || (((10'd291<=iHCNT && iHCNT<=10'd300)||(10'd311<=iHCNT && iHCNT<=10'd320)) && ((10'd211<=iVCNT && iVCNT<=10'd220)||(10'd231<=iVCNT && iVCNT<=10'd250))) 
            || ((10'd291<=iHCNT && iHCNT<=10'd320)&&(10'd221<=iVCNT && iVCNT<=10'd230)));

wire S_EASY = (((10'd331<=iHCNT && iHCNT<=10'd350) && ((10'd201<=iVCNT && iVCNT<=10'd210) || (10'd221<=iVCNT && iVCNT<=10'd230) || (10'd241 <= iVCNT && iVCNT <= 10'd250))) 
            || ((10'd331<=iHCNT && iHCNT<=10'd340) && (10'd201<=iVCNT && iVCNT<=10'd220))
            || ((10'd341<=iHCNT && iHCNT<=10'd350) && (10'd231<=iVCNT && iVCNT<=10'd240)));

wire Y_EASY = ((((10'd361<=iHCNT && iHCNT<=10'd370) || (10'd381<=iHCNT && iHCNT <= 10'd390)) && (10'd201<=iVCNT && iVCNT<=10'd225))
            || ((10'd371<=iHCNT && iHCNT<=10'd380) && (10'd226<=iVCNT && iVCNT<=10'd250)));

//NORMAL画面表示
wire S2_SW2 = (((10'd111<=iHCNT && iHCNT<=10'd130) && ((10'd261<=iVCNT && iVCNT<=10'd270) || (10'd281<=iVCNT && iVCNT<=10'd290) || (10'd301 <= iVCNT && iVCNT <= 10'd310))) 
            || ((10'd111<=iHCNT && iHCNT<=10'd120) && (10'd261<=iVCNT && iVCNT<=10'd280))
            || ((10'd121<=iHCNT && iHCNT<=10'd130) && (10'd291<=iVCNT && iVCNT<=10'd300)));

wire W2_SW2 = ((((10'd151<=iHCNT && iHCNT<=10'd160) || (10'd171<=iHCNT && iHCNT<=10'd180) || (10'd191<=iHCNT && iHCNT<=10'd200)) && (10'd261<=iVCNT && iVCNT<= 10'd285))
            || (((10'd161<=iHCNT && iHCNT<=10'd170) || (10'd181<=iHCNT && iHCNT<=10'd190)) && (10'd286<=iVCNT && iVCNT<=10'd310)));

wire SW2_SW2 = (((10'd211<=iHCNT && iHCNT<=10'd230) && ((10'd261<=iVCNT && iVCNT<=10'd270) || (10'd281<=iVCNT && iVCNT<=10'd290) || (10'd301 <= iVCNT && iVCNT <= 10'd310))) 
            || ((10'd221<=iHCNT && iHCNT<=10'd230) && (10'd261<=iVCNT && iVCNT<=10'd280))
            || ((10'd211<=iHCNT && iHCNT<=10'd220) && (10'd291<=iVCNT && iVCNT<=10'd300)));

wire C2_NORMAL = (((10'd241<=iHCNT && iHCNT<=10'd250) && ((10'd261<= iVCNT && iVCNT<=10'd275) || (10'd296<=iVCNT && iVCNT<=10'd310))));

wire N_NORMAL = ((((10'd261<=iHCNT && iHCNT<=10'd270) || (10'd291<=iHCNT && iHCNT<=10'd300)) && (10'd261<=iVCNT && iVCNT<=10'd310))
            || ((10'd271<=iHCNT && iHCNT<=10'd280) && (10'd261<=iVCNT && iVCNT<=10'd285))
            || ((10'd281<=iHCNT && iHCNT<=10'd290) && (10'd286<=iVCNT && iVCNT<=10'd310)));

wire O_NORMAL = (((10'd331<=iHCNT && iHCNT<=10'd340) && ((10'd261<=iVCNT && iVCNT<=10'd270) || (10'd301<=iVCNT && iVCNT<=10'd310)))
            || (((10'd321<=iHCNT && iHCNT<=10'd330) || (10'd341<=iHCNT && iHCNT<=10'd350)) && ((10'd271<=iVCNT && iVCNT<=10'd280) || (10'd291<=iVCNT && iVCNT<=10'd300)))
            || (((10'd311<=iHCNT && iHCNT<=10'd320) || (10'd351<=iHCNT && iHCNT<=10'd360)) && (10'd281<=iVCNT && iVCNT<=10'd290)));

wire R_NORMAL = (((10'd371<=iHCNT && iHCNT<=10'd400) && ((10'd261<=iVCNT && iVCNT<=10'd270) || (10'd281<=iVCNT && iVCNT<=10'd290))) 
            || (((10'd371<=iHCNT && iHCNT<=10'd380) || (10'd391<=iHCNT && iHCNT<=10'd400)) && ((10'd271<=iVCNT && iVCNT<=10'd280) || (10'd301<=iVCNT && iVCNT<=10'd310))) 
            || ((10'd371<=iHCNT && iHCNT<=10'd390) && (10'd291<=iVCNT && iVCNT<=10'd300)));

wire M_NORMAL = ((((10'd411<=iHCNT && iHCNT<=10'd420)||(10'd451<=iHCNT && iHCNT<=10'd460))&&((10'd261<=iVCNT && iVCNT<=10'd270)||(10'd291<=iVCNT && iVCNT<=10'd310))) 
            || (((10'd411<=iHCNT && iHCNT<=10'd430)||(10'd441<=iHCNT && iHCNT<=10'd460))&&(10'd271<=iVCNT && iVCNT<=10'd280)) 
            || (((10'd411<=iHCNT && iHCNT<=10'd420)||(10'd431<=iHCNT && iHCNT<=10'd440)||(10'd451<=iHCNT && iHCNT<=10'd460))&&(10'd281<=iVCNT && iVCNT<=10'd290)));

wire A_NORMAL = (((10'd481<=iHCNT && iHCNT<=10'd490) && (10'd261<=iVCNT && iVCNT<=10'd270)) 
            || (((10'd471<=iHCNT && iHCNT<=10'd480)||(10'd491<=iHCNT && iHCNT<=10'd500)) && ((10'd271<=iVCNT && iVCNT<=10'd280)||(10'd291<=iVCNT && iVCNT<=10'd310))) 
            || ((10'd471<=iHCNT && iHCNT<=10'd500)&&(10'd281<=iVCNT && iVCNT<=10'd290)));

wire L_NORMAL = (((10'd511<=iHCNT && iHCNT<=10'd520)&&(10'd261<=iVCNT && iVCNT<=10'd310)) 
            || ((10'd511<=iHCNT && iHCNT<=10'd530)&&(10'd300<=iVCNT && iVCNT<=10'd310))); // L

//HARD画面表示
wire S3_SW3 = (((10'd111<=iHCNT && iHCNT<=10'd130) && ((10'd321<=iVCNT && iVCNT<=10'd330) || (10'd341<=iVCNT && iVCNT<=10'd350) || (10'd361 <= iVCNT && iVCNT <= 10'd370))) 
            || ((10'd111<=iHCNT && iHCNT<=10'd120) && (10'd321<=iVCNT && iVCNT<=10'd340))
            || ((10'd121<=iHCNT && iHCNT<=10'd130) && (10'd351<=iVCNT && iVCNT<=10'd360)));

wire W3_SW3 = ((((10'd151<=iHCNT && iHCNT<=10'd160) || (10'd171<=iHCNT && iHCNT<=10'd180) || (10'd191<=iHCNT && iHCNT<=10'd200)) && (10'd321<=iVCNT && iVCNT<= 10'd345))
            || (((10'd161<=iHCNT && iHCNT<=10'd170) || (10'd181<=iHCNT && iHCNT<=10'd190)) && (10'd346<=iVCNT && iVCNT<=10'd370)));

wire SW3_SW3 = (((10'd211<=iHCNT && iHCNT<=10'd240)&&((10'd321<=iVCNT && iVCNT<=10'd330)||(10'd341<=iVCNT && iVCNT<=10'd350)||(10'd361<=iVCNT && iVCNT<=10'd370))) 
            ||((10'd231<=iHCNT && iHCNT<=10'd240)&&((10'd331<=iVCNT && iVCNT<=10'd340)||(10'd351<=iVCNT && iVCNT<=10'd360)))); 

wire C3_HARD = (((10'd251<=iHCNT && iHCNT<=10'd260) && ((10'd321<= iVCNT && iVCNT<=10'd345) || (10'd356<=iVCNT && iVCNT<=10'd370))));

wire H_HARD = ((((10'd271<=iHCNT && iHCNT<=10'd280) || (10'd291<=iHCNT && iHCNT<=10'd300)) && (10'd321<=iVCNT && iVCNT<=10'd370))
            || ((10'd281<=iHCNT && iHCNT<=10'd290) && (10'd341<=iVCNT && iVCNT<=10'd350)));

wire A_HARD = (((10'd321<=iHCNT && iHCNT<=10'd330) && (10'd321<=iVCNT && iVCNT<=10'd330)) 
            || (((10'd311<=iHCNT && iHCNT<=10'd320)||(10'd331<=iHCNT && iHCNT<=10'd340)) && ((10'd331<=iVCNT && iVCNT<=10'd340)||(10'd351<=iVCNT && iVCNT<=10'd370))) 
            || ((10'd311<=iHCNT && iHCNT<=10'd340)&&(10'd341<=iVCNT && iVCNT<=10'd350)));

wire R_HARD = (((10'd351<=iHCNT && iHCNT<=10'd380) && ((10'd321<=iVCNT && iVCNT<=10'd330) || (10'd341<=iVCNT && iVCNT<=10'd350))) 
            || (((10'd351<=iHCNT && iHCNT<=10'd360) || (10'd371<=iHCNT && iHCNT<=10'd380)) && ((10'd331<=iVCNT && iVCNT<=10'd340) || (10'd361<=iVCNT && iVCNT<=10'd370))) 
            || ((10'd351<=iHCNT && iHCNT<=10'd370) && (10'd351<=iVCNT && iVCNT<=10'd360)));

wire D_HARD = (((10'd391<=iHCNT && iHCNT<=10'd400) && (10'd321<=iVCNT && iVCNT<=10'd370))
            || ((10'd401<=iHCNT && iHCNT<=10'd410) && ((10'd321<=iVCNT && iVCNT<=10'd330) || (10'd361<=iVCNT && iVCNT<=10'd370)))
            || ((10'd411<=iHCNT && iHCNT<=10'd420) && (10'd331<=iVCNT && iVCNT<=10'd361)));

//GAMEOVER画面表示信号
wire G1_OVER = (((10'd236<=iHCNT && iHCNT<=10'd265) && ((10'd81<=iVCNT && iVCNT<=10'd90)||(10'd120<=iVCNT && iVCNT<=10'd130))) 
            || ((10'd226<=iHCNT && iHCNT<=10'd235) && (10'd91<=iVCNT && iVCNT<=10'd100)) 
            || (((10'd226<=iHCNT && iHCNT<=10'd235) || (10'd246<=iHCNT && iHCNT<=10'd265)) && (10'd101<=iVCNT && iVCNT<=10'd110)) 
            || (((10'd226<=iHCNT && iHCNT<=10'd235) || (10'd256<=iHCNT && iHCNT<=10'd265))&&((10'd111<=iVCNT && iVCNT<=10'd120))));                       

wire A1_OVER = (((10'd286<=iHCNT && iHCNT<=10'd305) && (10'd81<=iVCNT && iVCNT<=10'd90)) 
            || (((10'd276<=iHCNT && iHCNT<=10'd285) || (10'd306<=iHCNT && iHCNT<=10'd315)) && ((10'd91<=iVCNT && iVCNT<=10'd110)||(10'd121<=iVCNT && iVCNT<=10'd130))) 
            || ((10'd276<=iHCNT && iHCNT<=10'd315) && (10'd111<=iVCNT && iVCNT<=10'd120)));

wire M1_OVER = ((((10'd326<=iHCNT && iHCNT<=10'd335)||(10'd366<=iHCNT && iHCNT<=10'd375))&&((10'd81<=iVCNT && iVCNT<=10'd90)||(10'd111<=iVCNT && iVCNT<=10'd130))) 
            || (((10'd326<=iHCNT && iHCNT<=10'd345)||(10'd356<=iHCNT && iHCNT<=10'd375))&&(10'd91<=iVCNT && iVCNT<=10'd100)) 
            || (((10'd326<=iHCNT && iHCNT<=10'd335)||(10'd346<=iHCNT && iHCNT<=10'd355)||(10'd366<=iHCNT && iHCNT<=10'd375))&&(10'd101<=iVCNT && iVCNT<=10'd110)));

wire E2_OVER = (((10'd386<=iHCNT && iHCNT<=10'd425)&&((10'd81<=iVCNT && iVCNT<=10'd90)||(10'd101<=iVCNT && iVCNT<=10'd110)||(10'd121<=iVCNT && iVCNT<=10'd130))) 
            || ((10'd386<=iHCNT && iHCNT<=10'd395)&&((10'd91<=iVCNT && iVCNT<=10'd100)||(10'd111<=iVCNT && iVCNT<=10'd120))));

wire O1_OVER = (((10'd236<=iHCNT && iHCNT<=10'd255)&&((10'd161<=iVCNT && iVCNT<=10'd170)||(10'd201<=iVCNT && iVCNT<=10'd210)))
            || (((10'd226<=iHCNT && iHCNT<=10'd235)||(10'd256<=iHCNT && iHCNT<=10'd265))&&(10'd171<=iVCNT && iVCNT<=10'd200)));

wire V1_OVER = ((((10'd276<=iHCNT && iHCNT<=10'd285)||(10'd316<=iHCNT && iHCNT<=10'd325))&&(10'd161<=iVCNT && iVCNT<=10'd190))
            || (((10'd286<=iHCNT && iHCNT<=10'd295)||(10'd306<=iHCNT && iHCNT<=10'd315))&&(10'd191<=iVCNT && iVCNT<=10'd200))
            || ((10'd296<=iHCNT && iHCNT<=10'd305)&&(10'd201<=iVCNT && iVCNT<=10'd210)));

wire E3_OVER = (((10'd336<=iHCNT && iHCNT<=10'd375)&&((10'd161<=iVCNT && iVCNT<=10'd170)||(10'd181<=iVCNT && iVCNT<=10'd190)||(10'd201<=iVCNT && iVCNT<=10'd210)))
            || ((10'd336<=iHCNT && iHCNT<=10'd345)&&((10'd171<=iVCNT && iVCNT<=10'd180)||(10'd191<=iVCNT && iVCNT<=10'd200))));

wire R2_OVER = (((10'd386<=iHCNT && iHCNT<=10'd415) && ((10'd161<=iVCNT && iVCNT<=10'd170) || (10'd181<=iVCNT && iVCNT<=10'd190))) 
            || (((10'd386<=iHCNT && iHCNT<=10'd395) || (10'd406<=iHCNT && iHCNT<=10'd415)) && ((10'd171<=iVCNT && iVCNT<=10'd180) || (10'd201<=iVCNT && iVCNT<=10'd210))) 
            || ((10'd386<=iHCNT && iHCNT<=10'd405) && (10'd191<=iVCNT && iVCNT<=10'd200)));

//GAMECLEAR画面表示信号
wire G1_CLEAR = (((10'd236<=iHCNT && iHCNT<=10'd265) && ((10'd81<=iVCNT && iVCNT<=10'd90)||(10'd120<=iVCNT && iVCNT<=10'd130))) 
            || ((10'd226<=iHCNT && iHCNT<=10'd235) && (10'd91<=iVCNT && iVCNT<=10'd100)) 
            || (((10'd226<=iHCNT && iHCNT<=10'd235) || (10'd246<=iHCNT && iHCNT<=10'd265)) && (10'd101<=iVCNT && iVCNT<=10'd110)) 
            || (((10'd226<=iHCNT && iHCNT<=10'd235) || (10'd256<=iHCNT && iHCNT<=10'd265))&&((10'd111<=iVCNT && iVCNT<=10'd120))));                       

wire A1_CLEAR = (((10'd286<=iHCNT && iHCNT<=10'd305) && (10'd81<=iVCNT && iVCNT<=10'd90)) 
            || (((10'd276<=iHCNT && iHCNT<=10'd285) || (10'd306<=iHCNT && iHCNT<=10'd315)) && ((10'd91<=iVCNT && iVCNT<=10'd110)||(10'd121<=iVCNT && iVCNT<=10'd130))) 
            || ((10'd276<=iHCNT && iHCNT<=10'd315) && (10'd111<=iVCNT && iVCNT<=10'd120)));

wire M1_CLEAR = ((((10'd326<=iHCNT && iHCNT<=10'd335)||(10'd366<=iHCNT && iHCNT<=10'd375))&&((10'd81<=iVCNT && iVCNT<=10'd90)||(10'd111<=iVCNT && iVCNT<=10'd130))) 
            || (((10'd326<=iHCNT && iHCNT<=10'd345)||(10'd356<=iHCNT && iHCNT<=10'd375))&&(10'd91<=iVCNT && iVCNT<=10'd100)) 
            || (((10'd326<=iHCNT && iHCNT<=10'd335)||(10'd346<=iHCNT && iHCNT<=10'd355)||(10'd366<=iHCNT && iHCNT<=10'd375))&&(10'd101<=iVCNT && iVCNT<=10'd110)));

wire E2_CLEAR = (((10'd386<=iHCNT && iHCNT<=10'd425)&&((10'd81<=iVCNT && iVCNT<=10'd90)||(10'd101<=iVCNT && iVCNT<=10'd110)||(10'd121<=iVCNT && iVCNT<=10'd130))) 
            || ((10'd386<=iHCNT && iHCNT<=10'd395)&&((10'd91<=iVCNT && iVCNT<=10'd100)||(10'd111<=iVCNT && iVCNT<=10'd120))));

wire C1_CLEAR = (((10'd226<=iHCNT && iHCNT<=10'd265)&&((10'd161<=iVCNT && iVCNT<=10'd170)||(10'd201<=iVCNT && iVCNT<=10'd210))) 
            || ((10'd226<=iHCNT && iHCNT<=10'd235)&&(10'd171<=iVCNT && iVCNT<=10'd200))); // C

wire L1_CLEAR = (((10'd276<=iHCNT && iHCNT<=10'd285)&&(10'd161<=iVCNT && iVCNT<=10'd210)) 
            || ((10'd276<=iHCNT && iHCNT<=10'd315)&&(10'd201<=iVCNT && iVCNT<=10'd210))); // L

wire E3_CLEAR = (((10'd326<=iHCNT && iHCNT<=10'd365)&&((10'd161<=iVCNT && iVCNT<=10'd170)||(10'd181<=iVCNT && iVCNT<=10'd190)||(10'd201<=iVCNT && iVCNT<=10'd210))) 
            ||((10'd326<=iHCNT && iHCNT<=10'd335)&&((10'd171<=iVCNT && iVCNT<=10'd180)||(10'd191<=iVCNT && iVCNT<=10'd200))));

wire A2_CLEAR = (((10'd386<=iHCNT && iHCNT<=10'd405)&&(10'd161<=iVCNT && iVCNT<=10'd170)) 
            || (((10'd376<=iHCNT && iHCNT<=10'd385)||(10'd406<=iHCNT && iHCNT<=10'd415))&&((10'd171<=iVCNT && iVCNT<=10'd190) || (10'd201<=iVCNT && iVCNT<=10'd210)))
            || ((10'd376<=iHCNT && iHCNT<=10'd415) && (10'd191<=iVCNT && iVCNT<=10'd200)));

wire R2_CLEAR = (((10'd426<=iHCNT && iHCNT<=10'd455) && ((10'd161<=iVCNT && iVCNT<=10'd170) || (10'd181<=iVCNT && iVCNT<=10'd190))) 
            || (((10'd426<=iHCNT && iHCNT<=10'd435) || (10'd446<=iHCNT && iHCNT<=10'd455)) && ((10'd171<=iVCNT && iVCNT<=10'd180) || (10'd201<=iVCNT && iVCNT<=10'd210))) 
            || ((10'd426<=iHCNT && iHCNT<=10'd445) && (10'd191<=iVCNT && iVCNT<=10'd200)));


always @(posedge PCK) begin
    if(RST)begin
        vga_rgb = black;
    end
    else if (current_mode == TITLE)begin //TITLE画面表示
        if(C1_TITLE)
            vga_rgb <= red;
        else if(A1_TITLE)
            vga_rgb <= orange;
        else if(R1_TITLE)
            vga_rgb <= yellow;
        else if(R2_TITLE)
            vga_rgb <= green;
        else if(A2_TITLE)
            vga_rgb <= skyblue;
        else if(C2_TITLE)
            vga_rgb <= purple;
        else if(E1_TITLE)
            vga_rgb <= red;
        else    
            vga_rgb <= black;
    end
    else if (current_mode == SELECT)begin //SELECT画面表示

        if(S1_SELECT)
               vga_rgb <= red;
        else if(E1_SELECT)
            vga_rgb <= orange;
        else if(L1_SELECT)
            vga_rgb <= yellow;
        else if(E2_SELECT)
            vga_rgb <= green;
        else if(C1_SELECT)
            vga_rgb <= skyblue;
        else if(T1_SELECT)
            vga_rgb <= purple;
        else if(S1_SW1 || W1_SW1 || SW1_SW1 || C1_EASY || E_EASY || A_EASY || S_EASY || Y_EASY) begin
            vga_rgb <= orange;
        end
        else if(S2_SW2 || W2_SW2 || SW2_SW2 || C2_NORMAL || N_NORMAL || O_NORMAL || R_NORMAL || M_NORMAL || A_NORMAL || L_NORMAL)begin
            vga_rgb <= skyblue; 
        end
        else if(S3_SW3 || W3_SW3 || SW3_SW3 || C3_HARD || H_HARD || A_HARD || R_HARD || D_HARD)begin
            vga_rgb <= red;
        end
        else    
            vga_rgb <= black;   

    end
    
    // ロードマップの描画
    //優先度が高いものから上に置いていく
    else if (current_mode == EASY && ((((left_wall <= iHCNT && iHCNT <= right_wall) || (left2_wall <= iHCNT && iHCNT <= right2_wall)) && (roof <= iVCNT && iVCNT <= floar))
         || p1_part_id != 0 || p2_part_id != 0 || coin || coin2 || border || border2)) begin 
        
        // 車の描画 (IDによって色を変える)
        if (p1_part_id == 2'd1)      vga_rgb <= red2;    // ボディ
        else if (p1_part_id == 2'd2) vga_rgb <= skyblue;  // 窓
        else if (p1_part_id == 2'd3) vga_rgb <= yellow;   // ライト

        else if (p2_part_id == 2'd1) vga_rgb <= black;    // ボディ
        else if (p2_part_id == 2'd2) vga_rgb <= skyblue;  // 窓
        else if (p2_part_id == 2'd3) vga_rgb <= yellow;   // ライト

        else if(coin || coin2)      vga_rgb <= yellow;
        else if(border || border2)  vga_rgb <= white;
        else vga_rgb <= dark_gray;
    end

    else if (current_mode == NORMAL && ((((left_wall <= iHCNT && iHCNT <= right_wall) || (left2_wall <= iHCNT && iHCNT <= right2_wall)) && (roof <= iVCNT && iVCNT <= floar))
         || p1_part_id != 0 || p2_part_id != 0 || coin || coin2 || border || border2)) begin

        if (p1_part_id == 2'd1)      vga_rgb <= red2;    // ボディ
        else if (p1_part_id == 2'd2) vga_rgb <= skyblue;  // 窓
        else if (p1_part_id == 2'd3) vga_rgb <= yellow;   // ライト

        else if (p2_part_id == 2'd1) vga_rgb <= black;    // ボディ
        else if (p2_part_id == 2'd2) vga_rgb <= skyblue;  // 窓
        else if (p2_part_id == 2'd3) vga_rgb <= yellow;   // ライト
        
        else if(coin || coin2)      vga_rgb <= yellow;
        else if(object || object2)  vga_rgb <= brown;
        else if(border || border2)  vga_rgb <= white;
        else vga_rgb <= dark_gray;
    end

    else if (current_mode == HARD && ((((left_wall <= iHCNT && iHCNT <= right_wall) || (left2_wall <= iHCNT && iHCNT <= right2_wall)) && (roof <= iVCNT && iVCNT <= floar))
         || p1_part_id != 0 || p2_part_id != 0 || coin || coin2 || border || border2)) begin

        if (p1_part_id == 2'd1)      vga_rgb <= red2;    // ボディ
        else if (p1_part_id == 2'd2) vga_rgb <= skyblue;  // 窓
        else if (p1_part_id == 2'd3) vga_rgb <= yellow;   // ライト

        else if (p2_part_id == 2'd1) vga_rgb <= black;    // ボディ
        else if (p2_part_id == 2'd2) vga_rgb <= skyblue;  // 窓
        else if (p2_part_id == 2'd3) vga_rgb <= yellow;   // ライト

        else if(object || object2)  vga_rgb <= brown;
        else if(coin || coin2)      vga_rgb <= yellow;
        else if(border || border2)  vga_rgb <= purple;
        else vga_rgb <= dark_gray;
    end
    

    else if (current_mode == GAMEOVER)begin //GAMEOVER画面表示
        if(G1_OVER)
            vga_rgb <= red;
        else if(A1_OVER)
            vga_rgb <= orange;
        else if(M1_OVER)
            vga_rgb <= yellow;
        else if(E2_OVER)
            vga_rgb <= green;
        else if(O1_OVER)
            vga_rgb <= yellow;
        else if(V1_OVER)
            vga_rgb <= green;
        else if(E3_OVER)
            vga_rgb <= skyblue;
        else if(R2_OVER)
            vga_rgb <= purple;
        else    
            vga_rgb <= black;
    end
    else if (current_mode == GAMECLEAR)begin //GAMECLEAR画面表示

        if(G1_CLEAR)
            vga_rgb <= red;
        else if(A1_CLEAR)
            vga_rgb <= orange;
        else if(M1_CLEAR)
            vga_rgb <= yellow;
        else if(E2_CLEAR)
            vga_rgb <= green;
        else if(C1_CLEAR)
            vga_rgb <= skyblue;
        else if(L1_CLEAR)
            vga_rgb <= purple;
        else if(E3_CLEAR)
            vga_rgb <= orange;
        else if(A2_CLEAR)
            vga_rgb <= red;
        else if(R2_CLEAR)
            vga_rgb <= yellow;
        else    
            vga_rgb <= black;
    end
    else
        vga_rgb <= black; 

end

assign VGA_R = vga_rgb[11:8];
assign VGA_G = vga_rgb[7:4];
assign VGA_B = vga_rgb[3:0];

endmodule