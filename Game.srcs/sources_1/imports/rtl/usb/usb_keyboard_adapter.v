`timescale 1ns/1ps
module usb_keyboard_adapter(input wire [7:0] keycode,output reg [3:0] action);
    // 0 none, 1 up, 2 down, 3 left, 4 right, 5 ok, 6 back, 7 pause
    always @(*) begin
        action=4'd0;
        case(keycode)
            8'h1A,8'h52: action=4'd1; // W / Up
            8'h16,8'h51: action=4'd2; // S / Down
            8'h04,8'h50: action=4'd3; // A / Left
            8'h07,8'h4F: action=4'd4; // D / Right
            8'h28: action=4'd5;       // Enter
            8'h29: action=4'd6;       // Esc
            8'h2C: action=4'd7;       // Space
            default: action=4'd0;
        endcase
    end
endmodule
