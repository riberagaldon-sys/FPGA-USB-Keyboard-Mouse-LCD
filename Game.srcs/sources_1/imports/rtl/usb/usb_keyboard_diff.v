`timescale 1ns/1ps
module usb_keyboard_diff(
    input wire clk,input wire rst_n,input wire report_valid,
    input wire [7:0] k0,input wire [7:0] k1,input wire [7:0] k2,input wire [7:0] k3,input wire [7:0] k4,input wire [7:0] k5,
    output reg key_down,output reg key_up,output reg [7:0] key_down_code,output reg [7:0] key_up_code
);
    reg [47:0] prev; wire [47:0] curr={k5,k4,k3,k2,k1,k0};
    function [7:0] getk; input [47:0] l; input integer n; begin
        case(n) 0:getk=l[7:0];1:getk=l[15:8];2:getk=l[23:16];3:getk=l[31:24];4:getk=l[39:32];default:getk=l[47:40];endcase
    end endfunction
    function in6; input [7:0] k; input [47:0] l; begin
        in6=(k!=0)&&((k==l[7:0])||(k==l[15:8])||(k==l[23:16])||(k==l[31:24])||(k==l[39:32])||(k==l[47:40]));
    end endfunction
    integer i; reg [7:0] dcode,ucode; reg dfound,ufound;
    always @(*) begin
        dcode=0;ucode=0;dfound=0;ufound=0;
        for(i=0;i<6;i=i+1) begin
            if(!dfound && getk(curr,i)!=0 && !in6(getk(curr,i),prev)) begin dcode=getk(curr,i);dfound=1;end
            if(!ufound && getk(prev,i)!=0 && !in6(getk(prev,i),curr)) begin ucode=getk(prev,i);ufound=1;end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin prev<=0;key_down<=0;key_up<=0;key_down_code<=0;key_up_code<=0;end
        else begin
            key_down<=0;key_up<=0;
            if(report_valid) begin
                if(dfound) begin key_down<=1;key_down_code<=dcode;end
                if(ufound) begin key_up<=1;key_up_code<=ucode;end
                prev<=curr;
            end
        end
    end
endmodule
