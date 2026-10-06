`timescale 1ns/1ps
module uart_error_counter(input wire clk,input wire rst_n,input wire frame_error,output reg [15:0] error_count);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) error_count<=16'd0; else if(frame_error) error_count<=error_count+1'b1;
    end
endmodule
