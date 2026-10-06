`timescale 1ns/1ps
// Chapter 16: Chapter-15 input system plus CH9350L USB keyboard/mouse events.
module chapter16_controller #(
    parameter integer CLK_HZ=51_200_000,
    parameter integer PS2_DEVICE_MODE=0
)(
    input wire clk,input wire rst_n,input wire keypad_valid,input wire [3:0] keypad_code,
    input wire S1_KEYA,input wire S1_KEYB,input wire S1_KEYC,input wire S1_KEYD,input wire S1_KEYP,
    input wire EC_A,input wire EC_B,input wire EC_KEY,
    inout wire PS2_CLK,inout wire PS2_DATA,
    output wire TOUCH_SCL,inout wire TOUCH_SDA,inout wire TOUCH_INT,output wire TOUCH_RST,
    input wire touch_key_press,input wire game_exit_request,
    input wire usb_event_up,input wire usb_event_down,input wire usb_event_left,input wire usb_event_right,
    input wire usb_event_ok,input wire usb_event_back,input wire usb_event_pause,
    input wire [10:0] usb_pointer_x,input wire [9:0] usb_pointer_y,input wire usb_pointer_down,input wire usb_pointer_click,
    input wire usb_pointer_activity,input wire usb_keyboard_valid,input wire [7:0] usb_keyboard_code,
    output wire event_up,output wire event_down,output wire event_left,output wire event_right,
    output wire event_ok,output wire event_back,output wire event_pause,
    output wire [2:0] ui_state,output wire [2:0] menu_sel,
    output wire [10:0] pointer_x,output wire [9:0] pointer_y,output wire pointer_down,output wire pointer_click,
    output wire [7:0] keyboard_code,output wire keyboard_extended,output wire [4:0] ec_count,
    output wire [15:0] touch_x_raw,output wire [15:0] touch_y_raw,output wire ft_flag,output wire [15:0] chip_version,
    output wire [6:0] touch_state,output wire touch_coord_valid,output wire game_exit_event,output wire usb_pointer_selected
);
    wire base_up,base_down,base_left,base_right,base_ok,base_back,base_pause;
    wire [2:0] legacy_ui_unused,legacy_menu_unused; wire legacy_paused_unused;
    wire [10:0] base_pointer_x; wire [9:0] base_pointer_y; wire base_pointer_down,base_pointer_click;
    wire [7:0] base_keyboard_code; wire base_keyboard_extended;
    chapter7_controller #(.CLK_HZ(CLK_HZ),.PS2_DEVICE_MODE(PS2_DEVICE_MODE)) u_legacy(
        .clk(clk),.rst_n(rst_n),.keypad_valid(keypad_valid),.keypad_code(keypad_code),
        .S1_KEYA(S1_KEYA),.S1_KEYB(S1_KEYB),.S1_KEYC(S1_KEYC),.S1_KEYD(S1_KEYD),.S1_KEYP(S1_KEYP),
        .EC_A(EC_A),.EC_B(EC_B),.EC_KEY(EC_KEY),.PS2_CLK(PS2_CLK),.PS2_DATA(PS2_DATA),
        .TOUCH_SCL(TOUCH_SCL),.TOUCH_SDA(TOUCH_SDA),.TOUCH_INT(TOUCH_INT),.TOUCH_RST(TOUCH_RST),
        .touch_key_press(touch_key_press),
        .event_up(base_up),.event_down(base_down),.event_left(base_left),.event_right(base_right),
        .event_ok(base_ok),.event_back(base_back),.event_pause(base_pause),
        .ui_state(legacy_ui_unused),.menu_sel(legacy_menu_unused),.paused(legacy_paused_unused),
        .pointer_x(base_pointer_x),.pointer_y(base_pointer_y),.pointer_down(base_pointer_down),.pointer_click(base_pointer_click),
        .keyboard_code(base_keyboard_code),.keyboard_extended(base_keyboard_extended),.ec_count(ec_count),
        .touch_x_raw(touch_x_raw),.touch_y_raw(touch_y_raw),.ft_flag(ft_flag),.chip_version(chip_version),
        .touch_state(touch_state),.touch_coord_valid(touch_coord_valid)
    );
    assign event_up=base_up|usb_event_up; assign event_down=base_down|usb_event_down;
    assign event_left=base_left|usb_event_left; assign event_right=base_right|usb_event_right;
    assign event_ok=base_ok|usb_event_ok; assign event_back=base_back|usb_event_back; assign event_pause=base_pause|usb_event_pause;

    reg use_usb_pointer; reg usb_kb_seen; reg [7:0] usb_last_code;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin use_usb_pointer<=0;usb_kb_seen<=0;usb_last_code<=0;end
        else begin
            if(usb_pointer_activity) use_usb_pointer<=1'b1;
            else if(base_pointer_down||base_pointer_click) use_usb_pointer<=1'b0;
            if(usb_keyboard_valid) begin usb_kb_seen<=1'b1;usb_last_code<=usb_keyboard_code;end
        end
    end
    assign usb_pointer_selected=use_usb_pointer;
    assign pointer_x=use_usb_pointer?usb_pointer_x:base_pointer_x;
    assign pointer_y=use_usb_pointer?usb_pointer_y:base_pointer_y;
    assign pointer_down=use_usb_pointer?usb_pointer_down:base_pointer_down;
    assign pointer_click=use_usb_pointer?usb_pointer_click:base_pointer_click;
    assign keyboard_code=usb_kb_seen?usb_last_code:base_keyboard_code;
    assign keyboard_extended=usb_kb_seen?1'b0:base_keyboard_extended;

    wire button_hit_unused,button_click; wire [2:0] button_index;
    touch_button_hit_1024x600 u_hit(.pointer_x(pointer_x),.pointer_y(pointer_y),.pointer_click(pointer_click),
        .button_hit(button_hit_unused),.button_click(button_click),.button_index(button_index));
    ui_fsm_chapter8 u_fsm(.clk(clk),.rst_n(rst_n),.event_up(event_up),.event_down(event_down),.event_ok(event_ok),.event_back(event_back),
        .touch_button_valid(button_click),.touch_button_index(button_index),.game_exit_request(game_exit_request),.ui_state(ui_state),.menu_sel(menu_sel));
    assign game_exit_event=event_back;
endmodule
