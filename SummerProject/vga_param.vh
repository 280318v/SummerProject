/* VGA(640×480)パラメータ */
localparam HPERIOD = 10'd800;
localparam HFRONT  = 10'd16;
localparam HWIDTH  = 10'd96;
localparam HBACK   = 10'd48;

localparam VPERIOD = 10'd525;
localparam VFRONT  = 10'd10;
localparam VWIDTH  = 10'd2;
localparam VBACK   = 10'd33;

/* 表示領域 (640ドット × 480ライン) */
localparam HDISP   = 10'd640;
localparam VDISP   = 10'd480;

/* 表示領域の左上にあたるカウンタ値 (フロントポーチ + 同期パルス + バックポーチ) */
localparam HBEGIN  = HFRONT + HWIDTH + HBACK;   // 160
localparam VBEGIN  = VFRONT + VWIDTH + VBACK;   // 45