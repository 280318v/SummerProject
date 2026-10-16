module CTL_COIN(CLK, RST, ctl, coin_state);
    input[2:0] ctl; //仮
    output[1:0] coin_state;

    always @* begin 
        case(ctl)
            3'b001:begin        //コイン操作
                coin_state <= 2'b01;
            end
            3'b010:begin        //落下
                coin_state <= 2'b10;
            end
            3'b100:begin        //勝敗判定
                coin_state <= 2'b11;
            end
            default:begin
                coin_state <= 2'b00;
            end
        endcase
    end
endmodule