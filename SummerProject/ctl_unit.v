module CTL_UNIT( //ゲーム全体の制御部モジュール
    input   CLK, RST,
    input[3:0] BIN   //left1_btn, down1_btn, right1_btn, dec1_btn, left2_btn, down2_btn, right2_btn, dec2_btns,
    input   [1:0]KEY,
    input   [1:0] SW,
    input [1:0] winner,
    //input   gameover_flag, gameclear_flag,
    //input   gameover2_flag, gameclear2_flag,
    //output  reg[2:0] current_mode,
    output  [2:0]display_mode,
    //output  reg startstop

    /*
    p1_no_input:4'b0000
    p1_dec:4'b0001
    p1_left:4'b0010
    p1_down:4'b0011
    p1_right:4'b0100

    p2_no_input:4'b1000
    p2_dec:4'b1001
    p2_left:4'b1010
    p2_down:4'b1011
    p2_right:4'b1100

    KEY0:1'b0
    KEY1:1'b1

    SW0:2'b01
    SW1:2'b10
    SW2:2'b11
    */
);

/*
3’b000: タイトルセレクト画面
3’b001:対戦画面
3’b010:対戦結果画面1P
3’b011:対戦結果画面2P
*/
    always @* begin
        if (RST) begin
            display_mode <= 3'b000;
        end else begin
            case (display_mode)
                3'b000: begin
                    if (SW != 2'b00 && ((BIN == 4'b0001) || (BIN == 4'b1001)))
                        display_mode <= 3'b001;
                end
                3'b001: begin
                    if(winner == 2'b01)
                        display_mode <= 3'b010;
                    else if(winner == 2'b10)
                        display_mode <= 3'b011;
                end
                3'b010, 3'b011: begin
                    if(KEY[1])
                        display_mode <= 3'b001;
                    else if(KEY[0])
                        display_mode <= 3'b010;
                end
                default: display_mode <= 3'b000;
            endcase
        end
    end
    
endmodule