`timescale 1ns/1ps
module uart_rx #(
    parameter integer CLK_HZ = 40_000_000,
    parameter integer BAUD   = 115200
)(
    input  wire clk, input wire rst_n, input wire rx,
    output reg [7:0] data_byte, output reg data_valid, output reg frame_error
);
    localparam integer CLKS_PER_BIT = (CLK_HZ + BAUD/2) / BAUD;
    localparam integer HALF_BIT = CLKS_PER_BIT/2;
    localparam [1:0] IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;
    reg rx_m, rx_s, rx_d;
    reg [15:0] clk_cnt;
    reg [3:0] bit_idx;
    reg [7:0] shift;
    reg [1:0] state;
    always @(posedge clk) begin rx_m<=rx; rx_s<=rx_m; rx_d<=rx_s; end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin state<=IDLE; clk_cnt<=0; bit_idx<=0; shift<=0; data_byte<=0; data_valid<=0; frame_error<=0; end
        else begin
            data_valid<=1'b0; frame_error<=1'b0;
            case(state)
                IDLE: begin clk_cnt<=0; bit_idx<=0; if(!rx_d) state<=START; end
                START: if(clk_cnt==HALF_BIT-1) begin clk_cnt<=0; if(!rx_d) state<=DATA; else state<=IDLE; end else clk_cnt<=clk_cnt+1'b1;
                DATA: if(clk_cnt==CLKS_PER_BIT-1) begin
                    clk_cnt<=0; shift[bit_idx]<=rx_d;
                    if(bit_idx==7) begin bit_idx<=0; state<=STOP; end else bit_idx<=bit_idx+1'b1;
                end else clk_cnt<=clk_cnt+1'b1;
                STOP: if(clk_cnt==CLKS_PER_BIT-1) begin
                    clk_cnt<=0; data_byte<=shift;
                    if(rx_d) data_valid<=1'b1; else frame_error<=1'b1;
                    state<=IDLE;
                end else clk_cnt<=clk_cnt+1'b1;
                default: state<=IDLE;
            endcase
        end
    end
endmodule
