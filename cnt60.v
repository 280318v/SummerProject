module CNT60(CLK, RST, CLR, EN, QH, QL, turn_flag, Time, zero, timeup);
    input CLK, RST;
    input CLR, EN;
    input turn_flag, Time, SW, zero;
    output reg[3:0] QH;
    output reg[3:0] QL;
    output timeup;
    reg digit1;
    reg digit10;
    /*SET A TIME LIMIT*/
    always @* begin 
        case(SW)
            3'b001:begin        //SW1
                digit1 <= 4'd5;
                digit10 <= 4'd0;
            end
            3'b010:begin        //SW2
                digit1 <= 4'd0;
                digit10 <= 4'd1;
            end
            3'b100:begin        //SW3
                digit1 <= 4'd5;
                digit10 <= 4'd1;
            end
            default:begin
                digit1 <= 4'd0;
                digit10 <= 4'd0;
            end
        endcase
    end

    /*1の桁*/
    always@(posedge CLK) begin
        if(RST | CLR | turn_flag)
            QL <= digit1; 
        else if( EN == 1'b1)  begin
            if(QL == 4'd0)
                QL <= 4'd9;
            else
                QL <= QL - 1'b1;
        end
    end

    /*10の桁*/
    always@(posedge CLK) begin
        if(RST | CLR | turn_flag)
            QH <= digit10;
        else if( (EN == 1'b1) && (QL == 4'd0) )  begin
            if(QH ==4'd0)
                QH <= 4'd6;
            else
                QH <= QH - 1'b1;
        end
    end

    always@(posedge CLK) begin
        if(EN && (QL == 1) && (QH == 1)) begin
            timeup <= 1;
        end
    end
endmodule