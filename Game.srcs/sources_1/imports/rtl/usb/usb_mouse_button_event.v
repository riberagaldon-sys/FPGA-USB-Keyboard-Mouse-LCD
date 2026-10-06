`timescale 1ns/1ps
module usb_mouse_button_event(
    input wire clk,input wire rst_n,input wire valid,input wire [7:0] buttons,
    output reg left_down,output reg right_down,output reg middle_down
);
    reg [7:0] prev;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin prev<=0;left_down<=0;right_down<=0;middle_down<=0;end
        else begin
            left_down<=0;right_down<=0;middle_down<=0;
            if(valid) begin
                left_down<=buttons[0]&~prev[0];right_down<=buttons[1]&~prev[1];middle_down<=buttons[2]&~prev[2];prev<=buttons;
            end
        end
    end
endmodule
