/*
 * dir_dec.v  ―  手番のプレイヤーのボタンを「方向」の信号に変換する
 *
 * 先輩の car_control.v と同じ「ボタン → case で方向を決める → 出力」という形です。
 *
 * ボタンの読み取り(同期化・チャタリング除去・「押した瞬間の1パルス」)は
 * BTN_IN.v がすでにやってくれているので、このモジュールでは行いません。
 *   入力 : BTN_IN の出力 BOUT から取り出した、押した瞬間に1クロックだけ1になる信号
 *   出力 : field_update.v へ渡す方向 (これも1クロックだけ)
 *
 * 2人分のボタンを受け取って、手番(turn)のプレイヤーのボタンだけを使います。
 * 手番でない人がボタンを押しても、何も起きません。
 *
 * 出力の約束 (先輩の car_control.v と同じ)
 *   out_x = 2'b01 : 右へ +1
 *   out_x = 2'b11 : 左へ -1
 *   out_x = 2'b00 : 何もしない (左右を同時に押したときも何もしない)
 *   out_drop = 1  : 「落とす」
 */
module dir_dec( //方向の決定モジュール
    input            CLK, RST,
    input            turn,                      // 手番 (field_update から)  0=P1 / 1=P2

    /* BTN_IN の出力 BOUT から (押した瞬間に1クロックだけ1) */
    input            p1_left, p1_right, p1_drop,
    input            p2_left, p2_right, p2_drop,

    output reg [1:0] out_x,                     // x = {+1, -1}
    output reg       out_drop
);

//手番のプレイヤーのボタンだけを選ぶ
wire left_btn  = turn ? p2_left  : p1_left;
wire right_btn = turn ? p2_right : p1_right;
wire drop_btn  = turn ? p2_drop  : p1_drop;

//出力方向を定義  ({left, right} の組み合わせ)
localparam STOP  = 2'b00;
localparam LEFT  = 2'b10;
localparam RIGHT = 2'b01;

reg [1:0] state;

//ボタン入力から方向を決定する
always @(*) begin
    case({left_btn, right_btn})
        2'b10:   state = LEFT;
        2'b01:   state = RIGHT;
        default: state = STOP;      //何も押していない / 左右同時押し
    endcase
end

//出力 (1マス移動の合図)
always @(posedge CLK) begin
    if(RST) begin
        out_x    <= 2'b00;
        out_drop <= 1'b0;
    end
    else begin
        case(state)
            LEFT:    out_x <= 2'b11; // x - 1
            RIGHT:   out_x <= 2'b01; // x + 1
            default: out_x <= 2'b00; // ボタン何も押してないとき
        endcase
        out_drop <= drop_btn;
    end
end

endmodule