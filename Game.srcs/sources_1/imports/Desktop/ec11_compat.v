`timescale 1ns/1ps

// EC11 rotary encoder decoder
// Fixed version:
// 1. Uses full quadrature transition table
// 2. Rejects illegal jumps caused by switch bounce
// 3. Direction is determined from A/B phase order
// 4. Outputs one pulse per detent

module ec11_compat #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer LOCKOUT_MS = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire ec_a,
    input  wire ec_b,
    output reg  step_pulse,
    output reg  step_dir
);

    (* ASYNC_REG = "TRUE" *) reg [1:0] a_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] b_sync;

    reg [1:0] last_ab;
    reg signed [2:0] count;

    wire [1:0] ab = {a_sync[1], b_sync[1]};

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            a_sync <= 2'b11;
            b_sync <= 2'b11;
        end else begin
            a_sync <= {a_sync[0], ec_a};
            b_sync <= {b_sync[0], ec_b};
        end
    end


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            last_ab    <= 2'b11;
            count      <= 3'sd0;
            step_pulse <= 1'b0;
            step_dir   <= 1'b0;
        end else begin
            step_pulse <= 1'b0;

            if(ab != last_ab) begin

                case({last_ab,ab})

                    // clockwise:
                    // 11 -> 10 -> 00 -> 01 -> 11
                    4'b1110,
                    4'b1000,
                    4'b0001,
                    4'b0111: begin
                        count <= count + 1;
                    end

                    // counter clockwise:
                    // 11 -> 01 -> 00 -> 10 -> 11
                    4'b1101,
                    4'b0100,
                    4'b0010,
                    4'b1011: begin
                        count <= count - 1;
                    end

                    default: begin
                        count <= 0;
                    end
                endcase

                last_ab <= ab;


                if(count >= 3) begin
                    step_pulse <= 1'b1;
                    step_dir   <= 1'b1;
                    count      <= 0;
                end
                else if(count <= -3) begin
                    step_pulse <= 1'b1;
                    step_dir   <= 1'b0;
                    count      <= 0;
                end
            end
        end
    end

endmodule
