module BTN_IN(
    input CLK, RST,
    input       [12:0] nBIN, //4botton*2,SW0,1,2,KEY0,1
    output reg  [12:0] BOUT, //4botton*2,SW0,1,2, KEY0,1
    output [7:0] LEDR
);
    reg[20:0] cnt;
    wire en40hz = (cnt==1250000 - 1);

    always @( posedge CLK ) begin
        if(RST)
            cnt <= 21'b0;
        else if(en40hz)
            cnt <= 21'b0;
        else
            cnt <= cnt + 21'b1;
    end

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
       // 押している間だけ点灯 (押すと0なので ~ で反転)
       assign LEDR[7:0] = ~ff1[12:5];
endmodule