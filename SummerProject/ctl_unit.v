module CTL_UNIT( //ゲーム全体の制御部モジュール
    input   CLK, RST,
    input[3:0] BIN   //left1_btn, down1_btn, right1_btn, dec1_btn, left2_btn, down2_btn, right2_btn, dec2_btns,
    input   KEY,
    input   [1:0] SW,
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
        if ((display_mode == 3'b000) && SW && (GPIO[2] || GPIO[12])) begin
            display_mode <= 3'b001;
        end
        else if ((display_mode ==  3'b001) && (winner == 1)) begin
            display_mode <= 3'b010;   
        end 
        else if ((display_mode ==  3'b001) && (winner == 2)) begin
            display_mode <= 3'b011;
        end
        else if ((display_mode <= 3'b010) && (KEY == KEY[1])) begin
            display_mode <= 3'b001;
        end
        else if ((display_mode <= 3'b010) && (KEY == KEY[0])) begin
            display_mode <= 3'b000;
        end
        else if ((display_mode <= 3'b011) && (KEY == KEY[1])) begin
            display_mode <= 3'b001;
        end
        else if ((display_mode <= 3'b011) && (KEY == KEY[0])) begin
            display_mode <= 3'b000;
        end
        else begin
            display_mode <= 3'b000;
        end
    end
    
endmodule