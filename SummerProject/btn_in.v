module BTN_IN(
    //一人プレイ
    input CLK, RST,
    input       [12:0] nBIN, //4botton*2,SW0,1,2,KEY0,1
    output reg  [12:0] BOUT, //4botton*2,SW0,1,2, KEY0,1
    output [7:0] LEDR
    /*LEDR
    「現在プレイヤーがスイッチやボタンを押しているかどうか」
    を実機の赤色LEDを点滅させて目視確認（デバッグ）するための出力*/
);

    /*50MHzを1,250,000分周して40Hzを作る*/
    /*en40hzはシステムクロック1周期分のバルスで40Hz*/
    reg[20:0] cnt;
    wire en40hz = (cnt==1250000 - 1);////ボタン入力を40Hzでチェックする, wireなので0に戻すコードは不要
    //wire en40hz = (cnt == 5 - 1); //カウントを表すために-1する．

    always @( posedge CLK ) begin
        if(RST)
            cnt <= 21'b0;
        else if(en40hz)
            cnt <= 21'b0;
        else
            cnt <= cnt + 21'b1;
    end

    /*ボタン入力をFF2個で受けることでCLKを受けたときに信号を出力（同期）できる*/
    /*ボタン入力が13bitなのでFFも13bit*/
    reg[12:0] ff1, ff2;

    always @( posedge CLK ) begin
        if ( RST ) begin
            ff2 <= 13'b0;
            ff1 <= 13'b0;
        end
        else if ( en40hz ) begin
            ff2 <= ff1;  //ひとつ前の値をFF2に取り込む
            ff1 <= nBIN; //nBINの現在の値をFF1に取り込む
        end
    end

    /*ボタンを押すと0なので，立下りを検出*/
    wire[12:0] temp = (~ff1 & ff2) & {13{en40hz}}; //前回押してないけど今回は押された

    /*念のためFFで受ける*/
    always @(posedge CLK) begin
        if(RST)
            BOUT <= 13'b0;
        else
            BOUT <= temp; //BOUT[12:5], SW[2:0], KEY[1:0]
    end

    assign LEDR[7:0] = temp[12:5];
endmodule