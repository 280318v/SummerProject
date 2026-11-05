module GAME_CTL(CLK, RST, display_mode, BIN, coin_state, judge, turn, winner);
    input CLK, RST,
    input[2:0] display_mode, winner;
    input judge, turn;
    input[3:0] BIN; //left1_btn, down1_btn, right1_btn, dec1_btn, left2_btn, down2_btn, right2_btn, dec2_btns
    output[1:0] coin_state;
    output turn_flag;
    output [1:0]winner_flag;
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

    /*コインの状態*/
    always @* begin 
        coin_state = 2'b00;
        if (display_mode == 3'b001) begin
            if (judge)    //勝利判定中
                coin_state <= 2'b11;
            else begin
                //落下中以外に落下終了フラグのif文を追加して落下中は操作を受け付けなくした方がいいかも
                case(BIN)
                    4'b0000, 4'b1000:begin        //何もしてない状態
                        coin_state <= 2'b00;
                    end
                    4'b0011, 4'b1011:begin        //落下中
                        coin_state <= 2'b10;
                    end
                    default:begin
                        coin_state <= 2'b01; //コイン操作中
                    end
                endcase
            end
        end
    end

    /*ターンフラグ（赤が先）*/
    /*
    turn: 1'b0 赤
        　1'b1 青
    */
    always @* begin
        if(RST) begin
            turn <= 1'b0;//red
        end
        else if ((turn == 1'b0) && (judge == 1)) begin  //勝者判定を終えたらターン交代
            turn_flag   <= 1'b1;
        end
        else if((turn == 1'b1) && (judge == 1)) begin
            turn_flag <= 1'b0;
        end
    end

    /*勝者フラグ*/
    /*
    winner_flag: 2'b01 1P勝利
                 2'b10 2P勝利
    */
    always @* begin
        if(RST) begin
            winner_flag <= 2'b00;
        end
        else if (winner == 2'b01) begin
            winner_flag <= 2'b01;
        end
        else if (winner == 2'b10) begin
            winner_flag <= 2'b10;
        end
    end
endmodule