module COUNT60(CLK, RST, CLR, EN, QH, QL, SW, turn_flag, Time, KEY);
    input CLK, RST;
    input CLR, EN, KEY;
    input Time;
    input[2:0] SW;
    output reg[3:0] QH;
    output reg[3:0] QL;
    output wire turn_flag;
    reg[3:0] digit1;
    reg[3:0] digit10;
    /*SET A TIME LIMIT*/
    always @* begin 
        case(SW)
            3'b001:begin        //SW0
                digit1 <= 4'd5;
                digit10 <= 4'd0;
            end
            3'b010:begin        //SW1
                digit1 <= 4'd0;
                digit10 <= 4'd1;
            end
            3'b100:begin        //SW2
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
        else if( EN && (QH != 4'd0 || QL != 4'd0) )  begin
            if(QL == 4'd0)
                if(SW == 3'b100 || SW == 3'b010)
                    QL <= 4'd9;
                else begin
                    QL <= (digit1 - 1);
                end
            else
                QL <= QL - 1'b1;
        end
    end

    /*10の桁*/
    always@(posedge CLK) begin
        if(RST | CLR | turn_flag)
            QH <= digit10;
        //else if( EN && (QH != 4'd0 || QL != 4'd0) )  begin
        else if(EN && QL == 4'd0 && (QH != 4'd0 || QL != 4'd0)) begin
            if(QH == 4'd0)
                QH <= digit10;
            else
                QH <= QH - 1'b1;
        end
    end

    //FOR TEST
    assign turn_flag = ~KEY;
    // always @* begin
    //     if(KEY) begin
    //         turn_flag <= 1;
    //     end
    //     else begin
    //         turn_flag <= 0;
    //     end
    // end
endmodule