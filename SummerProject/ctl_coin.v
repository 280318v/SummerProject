module CTL_COIN(CLK, RST, display_mode, BIN, coin_state, judge);
    input[2:0] display_mode; //仮
    input judge;
    input[3:0] BIN; //left1_btn, down1_btn, right1_btn, dec1_btn, left2_btn, down2_btn, right2_btn, dec2_btns,
    output[1:0] coin_state;
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
    */
    always @* begin 
        if (display_mode == 3'b01) begin
            if (judge)    //勝利判定中
                coin_stage <= 2'b11;
            else begin
                case(BIN) begin
                    4'b0000:begin        //何もしてない状態
                        coin_state <= 2'b00;
                    end
                    4'b1000:begin       //何もしてない状態
                        coin_state <= 2'b00;
                    end
                    4'b0011:begin        //落下中
                        coin_state <= 2'b10;
                    end
                    4'b1011:begin        //落下中
                        coin_state <= 2'b10;
                    end
                    default:begin
                        coin_state <= 2'b01; //コイン操作中
                    end
                end
            end
        end
    end
endmodule