module CNT10MS( // 落下速度・ボタン読み取り用の10msごとのパルス生成モジュール
    input CLK, RST,
    output reg tick_10ms
);

reg [18:0] count;   // 500,000 まで数えるので 19bit (2^19 = 524,288)

always @(posedge CLK) begin
    if (RST) begin
        count <= 0;
        tick_10ms <= 0;
    end
    else if (count == 500_000 - 1) begin    // 50MHz × 10ms = 500,000クロック
        count <= 0;
        tick_10ms <= 1;
    end
    else begin
        count <= count + 1;
        tick_10ms <= 0;
    end
end

endmodule