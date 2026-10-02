module DIR_DEC( //コインの制御モジュール
    input CLK, RST,
    input[2:0] BIN, //down_btn, left_btn, right_btn,
    input[1:0] stage_state,
    input  [2:0] SW,
    input  EN1HZ,
    output reg signed[1:0] out_x, //x = {+1, -1}
    output reg signed[1:0] out_y  //y = {+1, -1}
);
/*
p1_left:3'b001
p1_down:3'b010
p1_right:3'b011

p2_left:3'b101
p2_down:3'b110
p2_right:3'b111
*/
    always @* begin
        if(stage_state == 2'b01) begin //対戦画面
            case(BIN) begin
                //1P
                3'b001:begin
                    out_x <= -2'b01;
                end
                3'b010:begin
                    out_y <= -2'b01;
                end
                3'b011:begin
                    out_x <= 2'b01;
                end
                //2P
                3'b101:begin
                    out_x <= -2'b11;
                end
                3'b110:begin
                    out_y <= -2'b11;
                end
                3'b111:begin
                    out_x <= 2'b11;
                end
                default:begin
                    out_x <= 2'b0;
                    out_y <= 2'b0;
                end
            end
        end
    end
endmodule