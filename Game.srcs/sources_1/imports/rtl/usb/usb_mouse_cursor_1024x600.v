`timescale 1ns/1ps
module usb_mouse_cursor_1024x600(
    input wire clk,input wire rst_n,input wire valid,input wire [7:0] dx,input wire [7:0] dy,
    output reg [10:0] x,output reg [9:0] y
);
    wire signed [11:0] x_now = $signed({1'b0,x});
    wire signed [11:0] dx_s  = $signed({{4{dx[7]}},dx});
    wire signed [11:0] x_sum = x_now + dx_s;
    wire signed [10:0] y_now = $signed({1'b0,y});
    wire signed [10:0] dy_s  = $signed({{3{dy[7]}},dy});
    wire signed [10:0] y_sum = y_now + dy_s;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin x<=11'd512; y<=10'd300; end
        else if(valid) begin
            if(x_sum<0) x<=11'd0; else if(x_sum>1023) x<=11'd1023; else x<=x_sum[10:0];
            if(y_sum<0) y<=10'd0; else if(y_sum>599) y<=10'd599; else y<=y_sum[9:0];
        end
    end
endmodule
