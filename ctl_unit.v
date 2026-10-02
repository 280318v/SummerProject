module CTL_UNIT( //ゲーム全体の制御部モジュール
    input   CLK, RST,
    input[3:0] BIN   //left1_btn, down1_btn, right1_btn, dec1_btn, left2_btn, down2_btn, right2_btn, dec2_btns,
    input   KEY,
    input   [1:0] SW,
    //input   gameover_flag, gameclear_flag,
    //input   gameover2_flag, gameclear2_flag,
    //output  reg[2:0] current_mode,
    output  display_mode,
    output  reg startstop

    /*
    p1_dec:3'b000
    p1_left:3'b001
    p1_down:3'b010
    p1_right:3'b011

    p2_dec:3'b100
    p2_left:3'b101
    p2_down:3'b110
    p2_right:3'b111
    
    KEY0:1'b0
    KEY1:1'b1

    SW0:2'b01
    SW1:2'b10
    SW2:2'b11
    */
);
    always @* begin
    end
    
endmodule