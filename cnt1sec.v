module CNT1SEC( // 1Hz生成モジュール
    input CLK, RST,
    input startstop,//シンキングタイム図り始めの合図
    output EN1HZ
);

reg[25:0] cnt;

always @(posedge CLK) begin
    if(RST)
        cnt <= 26'b0;
    //合図を取り入れたif文
    /*else if(startstop == 1'b1) begin
        if(EN1HZ) begin
            cnt <= 26'b0;
        end
        else begin
            cnt <= cnt + 26'b1;
        end
    end*/
    else begin
        cnt <= 26'b0;
    end
end

assign EN1HZ = (cnt == 26'd49_999_999);

endmodule