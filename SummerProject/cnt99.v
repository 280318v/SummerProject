module COUNT99(CLK, RST, CLR, EN, QH, QL, CD, turn_flag, KEY);
    input CLK, RST;
    input CLR, EN, KEY;
    input turn_flag;
    output reg[3:0] QH;
    output reg[3:0] QL;
    //output reg turn_flag;
    output CD;

    /*1 DIGIT*/
    always@(posedge CLK) begin
        if(RST | CLR | turn_flag)
            QL <= 4'd0; 
        else if( EN )  begin
            if(QL == 4'd0)
                QL <= 4'd9;
            else
                QL <= QL - 1'b1;
        end
    end

    /*10 DIGIT*/
    always@(posedge CLK) begin
        if(RST | CLR | turn_flag)
            QH <= 4'd0;
        else if( EN && QL == 4'd0 )  begin
            if(QH ==4'd0)
                QH <= 4'd9;
            else
                QH <= QH - 1'b1;
        end
    end

    /*To 1second*/
    assign CD = (QH == 4'd0 && QL == 4'd0 && EN == 1'b1);

        //FOR TEST
    //assign turn_flag = ~KEY;
    // always @* begin
    //     if(KEY) begin
    //         turn_flag <= 1;
    //     end
    //     else begin
    //         turn_flag <= 0;
    //     end
    // end
endmodule