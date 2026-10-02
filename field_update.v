module FIELD_UPDATE( //ゲーム本体モジュール 未完成
    input   CLK, RST,
    input   [1:0]   coin_move_x,
    input   [1:0]   coin_move_y,
    input   tick_10ms,
    input   reg thinking_flag,

    output  [9:0] stage_1, stage_2, stage_3, stage_4,stage_5, stage_6, stage_7,stage_8, stage_9, stage_10,
            stage_11, stage_12, stage_13, stage_14, stage_15, stage_16, stage_17, stage_18, stage_19, stage_20,

    output  [9:0] coin_stage_1, coin_stage_2, coin_stage_3, coin_stage_4,coin_stage_5, coin_stage_6, coin_stage_7,coin_stage_8, coin_stage_9, coin_stage_10,
            coin_stage_11, coin_stage_12, coin_stage_13, coin_stage_14, coin_stage_15, coin_stage_16, coin_stage_17, coin_stage_18, coin_stage_19, coin_stage_20,

    output wire [156:0] field1,
    output wire [156:0] field2,
    output reg  [1:0] coinnumber, //コインの種類\

);

reg [15:0] stage [25:0];
reg [15:0] coin_stage [25:0];

endmodule