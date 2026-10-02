module CNT10MS( // コインの移動速度管理モジュール
    input CLK, RST,
    input startstop,
    output reg tick_10ms //10msごとに1
);

reg[22:0] count; //quartus

always @(posedge CLK) begin
    if(RST) begin
        count <= 0;
        tick_10ms <= 0;
    end
    else if(startstop == 1'b1) begin
        if(count == 500_000 - 1) begin //0.01秒
            count <= 0;
            tick_10ms <= 1;
        end
        else begin
            count <= count + 1;
            tick_10ms <= 0;
        end
    end
    else begin
        tick_10ms <= 0;
    end
end

endmodule

//count
/*1秒（1,000ミリ秒）の 1/100 が10ミリ秒。
↓
50,000,000 / 100 = 500,000回
↓
0からカウントするため 1 を引く(500,000 - 1 = 499,999)*/

//メモ
/*reg...・wireとは違って、プログラムの処理結果や状態を一時的・恒久的に蓄えておく役割を果たす
        ・Verilogのルールとして、always ブロックや initial ブロックの内部で代入（<= や =）される変数は、
          必ず reg 型で宣言する必要がある/