module WINNER_TURN_CTL (
    input             CLK,   
    input             RST,     
    input             EN1HZ,   
    input      [7:0]  i,        
    input      [155:0] field1,
    input      [155:0] field2,
    output reg [1:0]  winner    // 01: P1, 10: P2
);

    wire valid_i =
          ((i >= 8'd42)  && (i <= 8'd48))
       || ((i >= 8'd55)  && (i <= 8'd61))
       || ((i >= 8'd68)  && (i <= 8'd74))
       || ((i >= 8'd81)  && (i <= 8'd87))
       || ((i >= 8'd94)  && (i <= 8'd100))
       || ((i >= 8'd107) && (i <= 8'd113));

    always @* begin
        winner = 2'b00;
        if (!RST && valid_i) begin
            if (field1[i] == 1'b1) begin
                // Right
                if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i+1]) &&
                         (field1[i] == field1[i+2]) &&
                         (field1[i] == field1[i+3]))
                    winner = 2'b01;

                // Left
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-1]) &&
                         (field1[i] == field1[i-2]) &&
                         (field1[i] == field1[i-3]))
                    winner = 2'b01;

                // Up
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i+13]) &&
                         (field1[i] == field1[i+26]) &&
                         (field1[i] == field1[i+39]))
                    winner = 2'b01;

                // Down
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-13]) &&
                         (field1[i] == field1[i-26]) &&
                         (field1[i] == field1[i-39]))
                    winner = 2'b01;

                // Up-right
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i+14]) &&
                         (field1[i] == field1[i+28]) &&
                         (field1[i] == field1[i+42]))
                    winner = 2'b01;

                // Down-right
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-12]) &&
                         (field1[i] == field1[i-24]) &&
                         (field1[i] == field1[i-36]))
                    winner = 2'b01;

                // Up-left
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i+12]) &&
                         (field1[i] == field1[i+24]) &&
                         (field1[i] == field1[i+36]))
                    winner = 2'b01;

                // Down-left
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-14]) &&
                         (field1[i] == field1[i-28]) &&
                         (field1[i] == field1[i-42]))
                    winner = 2'b01;

                // Horizontal: left 1 / right 2
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-1]) &&
                         (field1[i] == field1[i+1]) &&
                         (field1[i] == field1[i+2]))
                    winner = 2'b01;

                // Horizontal: left 2 / right 1
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-2]) &&
                         (field1[i] == field1[i-1]) &&
                         (field1[i] == field1[i+1]))
                    winner = 2'b01;

                // Vertical: down 1 / up 2
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-13]) &&
                         (field1[i] == field1[i+13]) &&
                         (field1[i] == field1[i+26]))
                    winner = 2'b01;

                // Vertical: down 2 / up 1
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-26]) &&
                         (field1[i] == field1[i-13]) &&
                         (field1[i] == field1[i+13]))
                    winner = 2'b01;

                // Diagonal /: down-left 1 / up-right 2
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-14]) &&
                         (field1[i] == field1[i+14]) &&
                         (field1[i] == field1[i+28]))
                    winner = 2'b01;

                // Diagonal /: down-left 2 / up-right 1
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-28]) &&
                         (field1[i] == field1[i-14]) &&
                         (field1[i] == field1[i+14]))
                    winner = 2'b01;

                // Diagonal \: down-right 1 / up-left 2
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-12]) &&
                         (field1[i] == field1[i+12]) &&
                         (field1[i] == field1[i+24]))
                    winner = 2'b01;

                // Diagonal \: down-right 2 / up-left 1
                else if ((field1[i] != 1'b0) &&
                         (field1[i] == field1[i-24]) &&
                         (field1[i] == field1[i-12]) &&
                         (field1[i] == field1[i+12]))
                    winner = 2'b01;

            end else if (field2[i] == 1'b1) begin
                // P2: check all directions relative to i
                // Right
                if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i+1]) &&
                         (field2[i] == field2[i+2]) &&
                         (field2[i] == field2[i+3]))
                    winner = 2'b10;

                // Left
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-1]) &&
                         (field2[i] == field2[i-2]) &&
                         (field2[i] == field2[i-3]))
                    winner = 2'b10;

                // Up
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i+13]) &&
                         (field2[i] == field2[i+26]) &&
                         (field2[i] == field2[i+39]))
                    winner = 2'b10;

                // Down
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-13]) &&
                         (field2[i] == field2[i-26]) &&
                         (field2[i] == field2[i-39]))
                    winner = 2'b10;

                // Up-right
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i+14]) &&
                         (field2[i] == field2[i+28]) &&
                         (field2[i] == field2[i+42]))
                    winner = 2'b10;

                // Down-right
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-12]) &&
                         (field2[i] == field2[i-24]) &&
                         (field2[i] == field2[i-36]))
                    winner = 2'b10;

                // Up-left
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i+12]) &&
                         (field2[i] == field2[i+24]) &&
                         (field2[i] == field2[i+36]))
                    winner = 2'b10;

                // Down-left
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-14]) &&
                         (field2[i] == field2[i-28]) &&
                         (field2[i] == field2[i-42]))
                    winner = 2'b10;

                // Horizontal: left 1 / right 2
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-1]) &&
                         (field2[i] == field2[i+1]) &&
                         (field2[i] == field2[i+2]))
                    winner = 2'b10;

                // Horizontal: left 2 / right 1
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-2]) &&
                         (field2[i] == field2[i-1]) &&
                         (field2[i] == field2[i+1]))
                    winner = 2'b10;

                // Vertical: down 1 / up 2
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-13]) &&
                         (field2[i] == field2[i+13]) &&
                         (field2[i] == field2[i+26]))
                    winner = 2'b10;

                // Vertical: down 2 / up 1
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-26]) &&
                         (field2[i] == field2[i-13]) &&
                         (field2[i] == field2[i+13]))
                    winner = 2'b10;

                // Diagonal /: down-left 1 / up-right 2
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-14]) &&
                         (field2[i] == field2[i+14]) &&
                         (field2[i] == field2[i+28]))
                    winner = 2'b10;

                // Diagonal /: down-left 2 / up-right 1
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-28]) &&
                         (field2[i] == field2[i-14]) &&
                         (field2[i] == field2[i+14]))
                    winner = 2'b10;

                // Diagonal \: down-right 1 / up-left 2
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-12]) &&
                         (field2[i] == field2[i+12]) &&
                         (field2[i] == field2[i+24]))
                    winner = 2'b10;

                // Diagonal \: down-right 2 / up-left 1
                else if ((field2[i] != 1'b0) &&
                         (field2[i] == field2[i-24]) &&
                         (field2[i] == field2[i-12]) &&
                         (field2[i] == field2[i+12]))
                    winner = 2'b10;

            end
        end
    end
endmodule
