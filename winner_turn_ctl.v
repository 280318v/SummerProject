module WINNER_TURN_CTL( //ゲーム本体モジュール 未完成
    input   CLK, RST,
    input   EN1HZ,
    input   turn,
    input [7:0] i; //コイン落下位置
    input wire [156:0] field1,
    input wire [156:0] field2,

    input  [9:0] stage_1, stage_2, stage_3, stage_4,stage_5, stage_6, stage_7,stage_8, stage_9, stage_10,
            stage_11, stage_12, stage_13, stage_14, stage_15, stage_16, stage_17, stage_18, stage_19, stage_20,

    input  [9:0] coin_stage_1, coin_stage_2, coin_stage_3, coin_stage_4,coin_stage_5, coin_stage_6, coin_stage_7,coin_stage_8, coin_stage_9, coin_stage_10,
            coin_stage_11, coin_stage_12, coin_stage_13, coin_stage_14, coin_stage_15, coin_stage_16, coin_stage_17, coin_stage_18, coin_stage_19, coin_stage_20,

    output  [9:0] stage_1, stage_2, stage_3, stage_4,stage_5, stage_6, stage_7,stage_8, stage_9, stage_10,
            stage_11, stage_12, stage_13, stage_14, stage_15, stage_16, stage_17, stage_18, stage_19, stage_20,

    output  [9:0] coin_stage_1, coin_stage_2, coin_stage_3, coin_stage_4,coin_stage_5, coin_stage_6, coin_stage_7,coin_stage_8, coin_stage_9, coin_stage_10,
            coin_stage_11, coin_stage_12, coin_stage_13, coin_stage_14, coin_stage_15, coin_stage_16, coin_stage_17, coin_stage_18, coin_stage_19, coin_stage_20,

    output reg gamefinish_flag​
);

        reg [15:0] stage [25:0];
        reg [15:0] coin_stage [25:0];
        
        always @* begin
                /*1P*/
                //右判定
                if((field1[i] != 2'b0) && (field1[i] == field1[i+1]) && (field1[i] == field1[i+2]) && (field1[i] == field1[i+3])) begin
                        gamefinish_flag = 1'b1;
                end

                //左判定
                else if((field1[i] != 2'b0) && (field1[i] == field1[i-1]) && (field1[i] == field1[i-2]) && (field1[i] == field1[i-3])) begin
                        gamefinish_flag = 1'b1;
                end

                //上判定
                else if((field1[i] != 2'b0) && (field1[i] == field1[i+13]) && (field1[i] == field1[i+26]) && (field1[i] == field1[i+39])) begin
                        gamefinish_flag = 1'b1;
                end

                //下判定
                else if((field1[i] != 2'b0) && (field1[i] == field1[i-13]) && (field1[i] == field1[i-26]) && (field1[i] == field1[i-39])) begin
                        gamefinish_flag = 1'b1;
                end

                //右斜め上
                else if((field1[i] != 2'b0) && (field1[i] == field1[i+14]) && (field1[i] == field1[i+28]) && (field1[i] == field1[i+42])) begin
                        gamefinish_flag = 1'b1;
                end

                //右斜め下
                else if((field1[i] != 2'b0) && (field1[i] == field1[i-14]) && (field1[i] == field1[i-24]) && (field1[i] == field1[i-36])) begin
                        gamefinish_flag = 1'b1;
                end

                //左斜め上
                else if((field1[i] != 2'b0) && (field1[i] == field1[i+12]) && (field1[i] == field1[i+24]) && (field1[i] == field1[i+36])) begin
                        gamefinish_flag = 1'b1;
                end
                //左斜め下
                else if((field1[i] != 2'b0) && (field1[i] == field1[i-14]) && (field1[i] == field1[i-28]) && (field1[i] == field1[i-42])) begin
                        gamefinish_flag = 1'b1;
                end

                else begin
                        gamefinish_flag = 1'b0;
                end

                /*2P*/
                //右判定
                if((field2[i] != 2'b0) && (field2[i] == field2[i+1]) && (field2[i] == field2[i+2]) && (field2[i] == field2[i+3])) begin
                        gamefinish_flag = 1'b1;
                end

                //左判定
                else if((field2[i] != 2'b0) && (field2[i] == field2[i-1]) && (field2[i] == field2[i-2]) && (field2[i] == field2[i-3])) begin
                        gamefinish_flag = 1'b1;
                end

                //上判定
                else if((field2[i] != 2'b0) && (field2[i] == field2[i+13]) && (field2[i] == field2[i+26]) && (field2[i] == field2[i+39])) begin
                        gamefinish_flag = 1'b1;
                end

                //下判定
                else if((field2[i] != 2'b0) && (field2[i] == field2[i-13]) && (field2[i] == field2[i-26]) && (field2[i] == field2[i-39])) begin
                        gamefinish_flag = 1'b1;
                end

                //右斜め上
                else if((field2[i] != 2'b0) && (field2[i] == field2[i+14]) && (field2[i] == field2[i+28]) && (field2[i] == field2[i+42])) begin
                        gamefinish_flag = 1'b1;
                end

                //右斜め下
                else if((field2[i] != 2'b0) && (field2[i] == field2[i-14]) && (field2[i] == field2[i-24]) && (field2[i] == field2[i-36])) begin
                        gamefinish_flag = 1'b1;
                end

                //左斜め上
                else if((field2[i] != 2'b0) && (field2[i] == field2[i+12]) && (field2[i] == field2[i+24]) && (field2[i] == field2[i+36])) begin
                        gamefinish_flag = 1'b1;
                end
                //左斜め下
                else if((field2[i] != 2'b0) && (field2[i] == field2[i-14]) && (field2[i] == field2[i-28]) && (field2[i] == field2[i-42])) begin
                        gamefinish_flag = 1'b1;
                end
                else begin
                        gamefinish_flag = 1'b0;
                end
        end

endmodule