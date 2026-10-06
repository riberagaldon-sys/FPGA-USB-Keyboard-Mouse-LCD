`timescale 1ns/1ps
// CH9350L lower-machine State-2 parser:
// 57 AB 01 + 8-byte BIOS keyboard report
// 57 AB 02 + 4-byte relative mouse report (Button, DX, DY, Wheel)
module ch9350_state2_parser(
    input wire clk,input wire rst_n,input wire [7:0] data,input wire valid,
    output reg keyboard_valid,output reg [7:0] kb_mod,output reg [7:0] kb_reserved,
    output reg [7:0] kb0,output reg [7:0] kb1,output reg [7:0] kb2,output reg [7:0] kb3,output reg [7:0] kb4,output reg [7:0] kb5,
    output reg mouse_valid,output reg [7:0] mouse_buttons,output reg [7:0] mouse_dx,output reg [7:0] mouse_dy,output reg [7:0] mouse_wheel,
    output reg [31:0] frame_count,output reg [15:0] sync_loss_count
);
    localparam [1:0] S57=2'd0,SAB=2'd1,SOP=2'd2,SPAY=2'd3;
    reg [1:0] state; reg [7:0] op; reg [3:0] idx,need;
    reg [7:0] p0,p1,p2,p3,p4,p5,p6;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=S57;op<=0;idx<=0;need<=0;keyboard_valid<=0;mouse_valid<=0;
            kb_mod<=0;kb_reserved<=0;kb0<=0;kb1<=0;kb2<=0;kb3<=0;kb4<=0;kb5<=0;
            mouse_buttons<=0;mouse_dx<=0;mouse_dy<=0;mouse_wheel<=0;frame_count<=0;sync_loss_count<=0;
            p0<=0;p1<=0;p2<=0;p3<=0;p4<=0;p5<=0;p6<=0;
        end else begin
            keyboard_valid<=1'b0; mouse_valid<=1'b0;
            if(valid) begin
                case(state)
                    S57: if(data==8'h57) state<=SAB;
                    SAB: begin
                        if(data==8'hAB) state<=SOP;
                        else if(data==8'h57) state<=SAB;
                        else begin state<=S57; sync_loss_count<=sync_loss_count+1'b1; end
                    end
                    SOP: begin
                        op<=data; idx<=0;
                        if(data==8'h01) begin need<=4'd8; state<=SPAY; end
                        else if(data==8'h02) begin need<=4'd4; state<=SPAY; end
                        else begin state<=S57; sync_loss_count<=sync_loss_count+1'b1; end
                    end
                    SPAY: begin
                        case(idx)
                            0:p0<=data; 1:p1<=data; 2:p2<=data; 3:p3<=data;
                            4:p4<=data; 5:p5<=data; 6:p6<=data; default:;
                        endcase
                        if(idx==need-1'b1) begin
                            frame_count<=frame_count+1'b1;
                            if(op==8'h01) begin
                                kb_mod<=p0;kb_reserved<=p1;kb0<=p2;kb1<=p3;kb2<=p4;kb3<=p5;kb4<=p6;kb5<=data;keyboard_valid<=1'b1;
                            end else if(op==8'h02) begin
                                mouse_buttons<=p0;mouse_dx<=p1;mouse_dy<=p2;mouse_wheel<=data;mouse_valid<=1'b1;
                            end
                            state<=S57; idx<=0;
                        end else idx<=idx+1'b1;
                    end
                    default: state<=S57;
                endcase
            end
        end
    end
endmodule
