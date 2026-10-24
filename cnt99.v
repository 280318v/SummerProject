module CNT99(CLK, RST, CLR, EN, QH, QL, CD, turn_flag);
    input CLK, RST;
    input CLR, EN;
    input turn_flag;
    output reg[3:0] QH;
    output reg[3:0] QL;
    output CD;

    /*1 DIGIT*/
    always@(posedge CLK) begin
        if(RST | CLR | turn_flag)
            QL <= 4'd0; 
        else if( EN == 1'b1 )  begin
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
        else if( (EN == 1'b1) && QL == 4'd0 )  begin
            if(QH ==4'd0)
                QH <= 4'd9;
            else
                QH <= QH - 1'b1;
        end
    end

    /*To 1second*/
    assign CD = (QH == 4'd0 && QL == 4'd0 && EN == 1'b1);

endmodule