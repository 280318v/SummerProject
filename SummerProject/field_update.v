m/*
 * field_update.v  ―  コネクトフォーのゲーム本体
 *
 * 盤面は 6行 x 7列 = 42マス。1マス1ビットで、プレイヤーごとに 42bit で覚えます。
 *   field1[idx] = 1 : プレイヤー1のコインがある
 *   field2[idx] = 1 : プレイヤー2のコインがある
 *   idx = row * 7 + col      (row: 0=一番上 〜 5=一番下 / col: 0=左 〜 6=右)
 *   ※ winner_ctl.v も同じ並びで field1/field2 を読む必要があります。
 *
 * 「盤面を突き破らない」「コインにかぶさらない」の考え方
 *   落とし始める"前"に、その列で一番下の空きマス(着地行)を計算して決めてしまいます。
 *   落下アニメは「着地行の位置まで」しか動かないので、突き破ることも、
 *   すでに置かれたコインに重なることもありません。
 *
 * 状態
 *   S_MOVE  : 上の段でコインを左右に動かして待つ (ボタン1回 = 1マス)
 *   S_FALL  : 10msごとに FALL_SPEED ピクセルずつ落下
 *   S_JUDGE : 着地後、winner_ctl の結果が出るのを少し待ってから勝敗判定
 *   S_END   : 勝敗(または引き分け)が決まったので停止
 */
module field_update #(
    parameter FALL_SPEED = 4,   // 10msごとに落ちるピクセル数 (大きいほど速い)
    parameter JUDGE_WAIT = 4    // 着地後、winner_ctl の出力を待つクロック数
)(
    input             CLK, RST,
    input             game_run,     // 1: ゲーム中 / 0: 盤面クリア (タイトル画面ができるまでは 1'b1 に固定でOK)

    input      [1:0]  dir_x,        // dir_dec から: 01=右, 11=左, 00=なし
    input             drop,         // dir_dec から: 落とす
    input             tick_10ms,    // 10msごとの信号 (落下速度用)
    input      [1:0]  winner,       // winner_ctl から: 00=なし / 01=P1の勝ち / 10=P2の勝ち

    output reg [41:0] field1,       // プレイヤー1のコイン
    output reg [41:0] field2,       // プレイヤー2のコイン
    output reg        turn,         // 手番  0=プレイヤー1 / 1=プレイヤー2
    output reg [2:0]  cur_col,      // 上の段で待っているコインの列 (0〜6)
    output reg [8:0]  fall_y,       // 落下量[px]。0 = 上の段、増えるほど下へ
    output            mv_show,      // 1: 横移動中/落下中のコインを描く
    output            game_end,     // 1: 勝負がついた
    output reg        draw_flag     // 1: 引き分け (盤面が全部埋まった)
);

localparam S_MOVE  = 2'd0,
           S_FALL  = 2'd1,
           S_JUDGE = 2'd2,
           S_END   = 2'd3;

localparam [8:0] CELL = 9'd39;      // マスの縦の間隔[px] = 線2 + 中身37 (落下距離の計算用)

reg [1:0] state;
reg [8:0] target_y;                 // 着地するまでの落下量[px]
reg [2:0] land_row;                 // 着地する行
reg [2:0] judge_cnt;
reg       tick_prev;

assign mv_show  = (state == S_MOVE) || (state == S_FALL);
assign game_end = (state == S_END);

// 10msの信号の立ち上がり (パルスでも、レベル信号でも動く)
wire tick_pulse = tick_10ms & ~tick_prev;

// どちらかのコインがあるマス
wire [41:0] occupied = field1 | field2;

// その列の一番下の空きマスを探す (7 = 列が満杯)
function [2:0] lowest_row;
    input [41:0] occ;
    input [2:0]  col;
    integer r;
    begin
        lowest_row = 3'd7;
        for (r = 0; r < 6; r = r + 1)
            if (!occ[r*7 + col]) lowest_row = r;    // 下の行ほど後で上書きされる
    end
endfunction

wire [2:0] drop_row = lowest_row(occupied, cur_col);
wire       col_full = (drop_row == 3'd7);

// 着地用のビット位置
wire [5:0]  land_idx  = land_row * 6'd7 + cur_col;
wire [41:0] land_mask = 42'd1 << land_idx;

// 次の10msでの落下量 (桁あふれ防止で10bit)
wire [9:0] fall_next = {1'b0, fall_y} + FALL_SPEED;

always @(posedge CLK) begin
    tick_prev <= tick_10ms;

    if (RST || !game_run) begin
        field1    <= 42'd0;
        field2    <= 42'd0;
        turn      <= 1'b0;
        cur_col   <= 3'd3;          // 真ん中の列からスタート
        fall_y    <= 9'd0;
        target_y  <= 9'd0;
        land_row  <= 3'd0;
        judge_cnt <= 3'd0;
        draw_flag <= 1'b0;
        state     <= S_MOVE;
    end
    else begin
        case (state)

        // ---------- 横移動して待つ ----------
        S_MOVE: begin
            if (drop) begin
                if (!col_full) begin                    // 満杯の列には落とせない
                    land_row <= drop_row;
                    target_y <= ({6'd0, drop_row} + 9'd1) * CELL;
                    fall_y   <= 9'd0;
                    state    <= S_FALL;
                end
            end
            else if (dir_x == 2'b01) begin              // 右へ
                if (cur_col < 3'd6) cur_col <= cur_col + 3'd1;
            end
            else if (dir_x == 2'b11) begin              // 左へ
                if (cur_col > 3'd0) cur_col <= cur_col - 3'd1;
            end
        end

        // ---------- 落下 (10msごとに動く) ----------
        S_FALL: begin
            if (tick_pulse) begin
                if (fall_next >= {1'b0, target_y}) begin
                    // 着地: 着地行を越えないようにぴったり止めて、盤面に記録
                    fall_y <= target_y;
                    if (!turn) field1 <= field1 | land_mask;
                    else       field2 <= field2 | land_mask;
                    judge_cnt <= 3'd0;
                    state     <= S_JUDGE;
                end
                else begin
                    fall_y <= fall_next[8:0];
                end
            end
        end

        // ---------- 勝敗判定 ----------
        S_JUDGE: begin
            if (judge_cnt < JUDGE_WAIT) begin
                judge_cnt <= judge_cnt + 3'd1;
            end
            else if (winner != 2'b00) begin
                state <= S_END;                         // 勝者あり
            end
            else if (&occupied) begin
                draw_flag <= 1'b1;                      // 全マス埋まって引き分け
                state     <= S_END;
            end
            else begin
                turn   <= ~turn;                        // 手番交代
                fall_y <= 9'd0;
                state  <= S_MOVE;
            end
        end

        // ---------- 終了 (game_run が 0 になるか RST まで停止) ----------
        S_END: begin
        end

        endcase
    end
end

endmodule
