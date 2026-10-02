
//変更の確認！！！できてるかーー？？？

module COONECT_FOR (
    // クロック、リセット
    input CLK, SW9,

    // ボタン
    input [12:0] nBIN, //SW(0~2), KEY(3~13)

    // 7セグ
    output [7:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    
    // VGA
    output [3:0] VGA_R, VGA_G, VGA_B,
    // output       VGA_HS, VGA_VS
    output       VGA_HS, VGA_VS,

    // LED
    output [7:0] LEDR
);

//スイッチ入力,チャタリング回路の接続
//wire [12:0] BOUT;
wire   sw0, sw1, sw2;
wire   key0, key1; 
wire   p1_dec, p1_right, p1_down, p1_left;
wire   p2_dec, p2_right, p2_down, p2_left;

BTN_IN btn_in( .CLK(CLK), .RST(SW9), .nBIN(nBIN), 
    .BOUT({p1_left, p1_down, p1_right, p1_dec,
    p2_left, p2_down, p2_right, p2_dec, 
    key1, key0,
    sw2, sw1, sw0}), 
	 .LEDR(LEDR[7:0])
);

// 1Hz生成器の接続
wire EN1HZ;
//wire startstop;

//CNT1SEC cnt1sec( .CLK(CLK), .RST(SW9), .startstop(startstop),  .EN1HZ(EN1HZ));

//0.02秒生成器の接続
//wire tick_20ms;

//CNT20MS cnt20ms( .CLK(CLK), .RST(SW9), .startstop(startstop), .tick_20ms(tick_20ms));

//0.05秒生成器の接続
CNT1SEC cnt1sec( .CLK(CLK), .RST(SW9), .startstop(startstop),  .EN1HZ(EN1HZ));

wire tick_10ms;

CNT10MS cnt10ms( .CLK(CLK), .RST(SW9), .startstop(startstop), .tick_10ms(tick_10ms));

CNT99 cnt99( .CLK(CLK), .RST(SW9), CLR, EN, QH, QL, CD, turn_flag);

CNT60 cnt60( .CLK(CLK), .RST(SW9), CLR, EN, QH, QL, turn_flag, Time, zero, timeup);

//車制御の接続
wire [1:0] coin1_move_x, coin1_move_y;
wire [1:0] coin2_move_x, coin2_move_y;


DIR_DEC player1( .CLK(CLK), .RST(SW9), .SW({sw2, sw1, sw0})
    .down_btn(p1_down), .left_btn(p1_left), .right_btn(p1_right),
    .out_x(coin1_move_x), .out_y(coin1_move_y)
);

DIR_DEC player2( .CLK(CLK), .RST(SW9), .SW({sw2, sw1, sw0})
    .down_btn(p2_down), .left_btn(p2_left), .right_btn(p2_right),
    .out_x(coin2_move_x), .out_y(coin2_move_y)
);



CTL_UNIT ctl_unit( .CLK(CLK), .RST(SW9), .KEY({key1, key0}), .SW({sw2, sw1, sw0}),
    .left1_btn(p1_left), .down1_btn(p1_down), .right1_btn(p1_right), .dec1_btn(p1_dec),
    .left2_btn(p2_left), .down2_btn(p2_down), .right2_btn(p2_right), .dec2_btn(p2_dec),
    //.gameover_flag(gameover_flag), .gameclear_flag(gameclear_flag), 
    //.gameover2_flag(gameover2_flag), .gameclear2_flag(gameclear2_flag),
    //.current_mode(current_mode),
    .display_mode(display_mode),
    .startstop(startstop)
);

CTL_COIN ctl_coin( .CLK(CKL), .RST(SW9), ctl, coin_state);

//フィールド更新の接続
wire [9:0] SCORE1;
wire [9:0] SCORE2;

wire [9:0]  stage_1, stage_2, stage_3, stage_4,stage_5, stage_6, stage_7,stage_8, stage_9, stage_10,
    stage_11, stage_12, stage_13, stage_14, stage_15, stage_16, stage_17, stage_18, stage_19, stage_20;
wire [9:0] coin_stage_1, coin_stage_2, coin_stage_3, coin_stage_4,coin_stage_5, coin_stage_6, coin_stage_7,coin_stage_8, coin_stage_9, coin_stage_10,
    coin_stage_11, coin_stage_12, coin_stage_13, coin_stage_14, coin_stage_15, coin_stage_16, coin_stage_17, coin_stage_18, coin_stage_19, coin_stage_20;

wire [156:0] field1;
wire [156:0] field2;

FIELD_UPDATE field_update( .CLK(CLK), .RST(SW9),
    .coin1_move_x(coin1_move_x), .coin1_move_y(coin1_move_y),
    .coin2_move_x(coin2_move_x), .coin2_move_y(coin2_move_y),
    .tick_10ms(tick_10ms),
    .thinking_flag(thinking_flag)
    
    .stage_1(stage_1), 
    .stage_2(stage_2), 
    .stage_3(stage_3),
    .stage_4(stage_4), 
    .stage_5(stage_5),
    .stage_6(stage_6), 
    .stage_7(stage_7),
    .stage_8(stage_8), 
    .stage_9(stage_9), 
    .stage_10(stage_10), 
    .stage_11(stage_11),
    .stage_12(stage_12),
    .stage_13(stage_13),
    .stage_14(stage_14), 
    .stage_15(stage_15), 
    .stage_16(stage_16), 
    .stage_17(stage_17),
    .stage_18(stage_18),
    .stage_19(stage_19),
    .stage_20(stage_20),

    .coin_stage_1(coin_stage_1), 
    .coin_stage_2(coin_stage_2), 
    .coin_stage_3(coin_stage_3),
    .coin_stage_4(coin_stage_4), 
    .coin_stage_5(coin_stage_5),
    .coin_stage_6(coin_stage_6), 
    .coin_stage_7(coin_stage_7),
    .coin_stage_8(coin_stage_8), 
    .coin_stage_9(coin_stage_9), 
    .coin_stage_10(coin_stage_10), 
    .coin_stage_11(coin_stage_11),
    .coin_stage_12(coin_stage_12),
    .coin_stage_13(coin_stage_13),
    .coin_stage_14(coin_stage_14), 
    .coin_stage_15(coin_stage_15), 
    .coin_stage_16(coin_stage_16), 
    .coin_stage_17(coin_stage_17),
    .coin_stage_18(coin_stage_18),
    .coin_stage_19(coin_stage_19),
    .coin_stage_20(coin_stage_20),

    .filed1(filed1),
    .filed2(filed2),
    .turn(coinnumber),
);

GAME_CTL game_ctl( .CLK(CLK), .RST(SW9),);

WINNER_TURN_CTL winner_turn_ctl( .CLK(CLK), .RST(SW9),
    .EN1HZ(EN1HZ),
    .turn(turn),
    .field1(field1),
    .field2(field2),
    
    .stage_1(stage_1), 
    .stage_2(stage_2), 
    .stage_3(stage_3),
    .stage_4(stage_4), 
    .stage_5(stage_5),
    .stage_6(stage_6), 
    .stage_7(stage_7),
    .stage_8(stage_8), 
    .stage_9(stage_9), 
    .stage_10(stage_10), 
    .stage_11(stage_11),
    .stage_12(stage_12),
    .stage_13(stage_13),
    .stage_14(stage_14), 
    .stage_15(stage_15), 
    .stage_16(stage_16), 
    .stage_17(stage_17),
    .stage_18(stage_18),
    .stage_19(stage_19),
    .stage_20(stage_20),

    .coin_stage_1(coin_stage_1), 
    .coin_stage_2(coin_stage_2), 
    .coin_stage_3(coin_stage_3),
    .coin_stage_4(coin_stage_4), 
    .coin_stage_5(coin_stage_5),
    .coin_stage_6(coin_stage_6), 
    .coin_stage_7(coin_stage_7),
    .coin_stage_8(coin_stage_8), 
    .coin_stage_9(coin_stage_9), 
    .coin_stage_10(coin_stage_10), 
    .coin_stage_11(coin_stage_11),
    .coin_stage_12(coin_stage_12),
    .coin_stage_13(coin_stage_13),
    .coin_stage_14(coin_stage_14), 
    .coin_stage_15(coin_stage_15), 
    .coin_stage_16(coin_stage_16), 
    .coin_stage_17(coin_stage_17),
    .coin_stage_18(coin_stage_18),
    .coin_stage_19(coin_stage_19),
    .coin_stage_20(coin_stage_20),

    //output
    .stage_1(stage_1), 
    .stage_2(stage_2), 
    .stage_3(stage_3),
    .stage_4(stage_4), 
    .stage_5(stage_5),
    .stage_6(stage_6), 
    .stage_7(stage_7),
    .stage_8(stage_8), 
    .stage_9(stage_9), 
    .stage_10(stage_10), 
    .stage_11(stage_11),
    .stage_12(stage_12),
    .stage_13(stage_13),
    .stage_14(stage_14), 
    .stage_15(stage_15), 
    .stage_16(stage_16), 
    .stage_17(stage_17),
    .stage_18(stage_18),
    .stage_19(stage_19),
    .stage_20(stage_20),

    .coin_stage_1(coin_stage_1), 
    .coin_stage_2(coin_stage_2), 
    .coin_stage_3(coin_stage_3),
    .coin_stage_4(coin_stage_4), 
    .coin_stage_5(coin_stage_5),
    .coin_stage_6(coin_stage_6), 
    .coin_stage_7(coin_stage_7),
    .coin_stage_8(coin_stage_8), 
    .coin_stage_9(coin_stage_9), 
    .coin_stage_10(coin_stage_10), 
    .coin_stage_11(coin_stage_11),
    .coin_stage_12(coin_stage_12),
    .coin_stage_13(coin_stage_13),
    .coin_stage_14(coin_stage_14), 
    .coin_stage_15(coin_stage_15), 
    .coin_stage_16(coin_stage_16), 
    .coin_stage_17(coin_stage_17),
    .coin_stage_18(coin_stage_18),
    .coin_stage_19(coin_stage_19),
    .coin_stage_20(coin_stage_20),

    .gamefinish(gamefinish)
);

// 7セグの接続
SEG7DEC d0(.DIN(QL2), .nHEX(HEX0));
SEG7DEC d1(.DIN(QM2), .nHEX(HEX1));
SEG7DEC d2(.DIN(QH2), .nHEX(HEX2));

SEG7DEC d3(.DIN(QL), .nHEX(HEX3));
SEG7DEC d4(.DIN(QM), .nHEX(HEX4));
SEG7DEC d5(.DIN(QH), .nHEX(HEX5));

// syncgenの接続
wire PCK;
wire [9:0] HCNT, VCNT;
SYNCGEN syncgen ( 
    .CLK(CLK),
    .RST(SW9),
    .PCK(PCK),
    .VGA_HS (VGA_HS),
    .VGA_VS (VGA_VS),
    .HCNT(HCNT),
    .VCNT(VCNT)
);

// vgaifの接続
VGAIF v0 (
    .PCK(PCK),
    .RST(SW9),
    .gamefinish(gamefinish),
    
    .stage_1(stage_1), 
    .stage_2(stage_2), 
    .stage_3(stage_3),
    .stage_4(stage_4), 
    .stage_5(stage_5), 
    .stage_6(stage_6), 
    .stage_7(stage_7),
    .stage_8(stage_8), 
    .stage_9(stage_9), 
    .stage_10(stage_10), 
    .stage_11(stage_11),
    .stage_12(stage_12), 
    .stage_13(stage_13),
    .stage_14(stage_14),
    .stage_15(stage_15), 
    .stage_16(stage_16),
    .stage_17(stage_17),
    .stage_18(stage_18),
    .stage_19(stage_19),
    .stage_20(stage_20),
    
    //.stage_out(stage_out),
    .coin_stage_1(coin_stage_1), 
    .coin_stage_2(coin_stage_2), 
    .coin_stage_3(coin_stage_3),
    .coin_stage_4(coin_stage_4), 
    .coin_stage_5(coin_stage_5), 
    .coin_stage_6(coin_stage_6), 
    .coin_stage_7(coin_stage_7),
    .coin_stage_8(coin_stage_8), 
    .coin_stage_9(coin_stage_9), 
    .coin_stage_10(coin_stage_10), 
    .coin_stage_11(coin_stage_11),
    .coin_stage_12(coin_stage_12), 
    .coin_stage_13(coin_stage_13),
    .coin_stage_14(coin_stage_14),
    .coin_stage_15(coin_stage_15), 
    .coin_stage_16(coin_stage_16),
    .coin_stage_17(coin_stage_17),
    .coin_stage_18(coin_stage_18),
    .coin_stage_19(coin_stage_19),
    .coin_stage_20(coin_stage_20),

    .display_mode(display_mode),
    
    //output
    .HCNT(HCNT),
    .VCNT(VCNT),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B)
);

endmodule