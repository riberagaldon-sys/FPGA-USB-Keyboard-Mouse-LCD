`timescale 1ns/1fs

// 第17章：CH9350L USB键盘与鼠标输入——图17-1、图17-2专用。
// 工程：Game.xpr。Simulation Sources添加本文件，Top设tb_chapter17_all。
// Tcl：run 85 ms。成功打印CH17 PASS；无$finish/$stop，方便查看波形。
// 按当前Game.zip实际源码：51.2MHz、57600 8N1；Enter确认、Space暂停。
// 文档中的115200和Space确认与该版工程不符，截图分析应按实际源码填写。
// 使用工程原有UART、parser、键盘差分/映射、鼠标光标/按钮、错误计数器、
// chapter16_controller；PS2_DEVICE_MODE=0。只通过输入端口驱动，无force。
// USB事件组合连接取自top_chapter16_usb_rgb888_system，不修改设计模块。
// 覆盖的是CH9350L输出后的FPGA接收路径，不模拟USB枚举或真实板级设备。
// 图17-1(a)：首次键盘报告，范围10000~2000000ns。
// Scope=tb_chapter17_all：uart_rx_line/uart_valid/keyboard_valid/mouse_valid Binary；
// uart_byte/report_type/kb0 Hex；parser_state/payload_length/payload_index/frame_count Unsigned Decimal。
// 57 AB 01 00 00 2C 00 00 00 00 00，收齐8个载荷字节后keyboard_valid更新。
// 其余图用真实报告完成时刻放大；所有截图别名均在本模块根层。
// 图17-1(b)鼠标整帧：40370000~41600000ns，载荷01 0C F8 FF。
// mouse_valid约41584951.172ns；下一拍光标512/300->524/292、左键首次按下。
// 图17-2以Enter确认说明差分：首次9810900~9811350ns；
// 重复11720800~11721300ns；释放13630700~13631200ns。
// keyboard_valid/key_down/key_up/event_ok Binary；key_curr/key_prev/
// key_down_code/key_up_code Hex；frame_count/key_down_count/key_up_count Unsigned Decimal。
// 本地自检通过：425个UART字节、24个键盘报告、21个鼠标报告，errors=0。

module tb_chapter17_all;
    localparam integer CLK_HZ = 51_200_000;
    localparam integer BAUD = 57600;
    localparam real UART_BIT_NS = 1_000_000_000.0 / BAUD;
    reg clk = 1'b0;
    always #9.765625 clk = ~clk;
    reg rst_n = 1'b0;
    reg serial_drive = 1'b1;
    tri1 PS2_CLK, PS2_DATA, TOUCH_SDA, TOUCH_INT;
    assign PS2_DATA = serial_drive;
    wire uart_rx_line = PS2_DATA;
    wire [7:0] uart_byte;
    wire uart_valid, uart_frame_error;
    wire [15:0] uart_error_count;

    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart (
        .clk(clk), .rst_n(rst_n), .rx(uart_rx_line),
        .data_byte(uart_byte), .data_valid(uart_valid), .frame_error(uart_frame_error)
    );
    uart_error_counter u_uart_errors (
        .clk(clk), .rst_n(rst_n), .frame_error(uart_frame_error),
        .error_count(uart_error_count)
    );

    wire keyboard_valid, mouse_valid;
    wire [7:0] kb_mod, kb_reserved, kb0, kb1, kb2, kb3, kb4, kb5;
    wire [7:0] mouse_buttons, mouse_dx, mouse_dy, mouse_wheel;
    wire [31:0] frame_count;
    wire [15:0] sync_loss_count;
    ch9350_state2_parser u_parser (
        .clk(clk), .rst_n(rst_n), .data(uart_byte), .valid(uart_valid),
        .keyboard_valid(keyboard_valid), .kb_mod(kb_mod), .kb_reserved(kb_reserved),
        .kb0(kb0), .kb1(kb1), .kb2(kb2), .kb3(kb3), .kb4(kb4), .kb5(kb5),
        .mouse_valid(mouse_valid), .mouse_buttons(mouse_buttons), .mouse_dx(mouse_dx),
        .mouse_dy(mouse_dy), .mouse_wheel(mouse_wheel),
        .frame_count(frame_count), .sync_loss_count(sync_loss_count)
    );
    wire [1:0] parser_state = u_parser.state;
    wire [7:0] report_type = u_parser.op;
    wire [3:0] payload_length = u_parser.need;
    wire [3:0] payload_index = u_parser.idx;
    wire [63:0] keyboard_report = {kb5,kb4,kb3,kb2,kb1,kb0,kb_reserved,kb_mod};

    wire key_down, key_up;
    wire [7:0] key_down_code, key_up_code;
    usb_keyboard_diff u_diff (
        .clk(clk), .rst_n(rst_n), .report_valid(keyboard_valid),
        .k0(kb0), .k1(kb1), .k2(kb2), .k3(kb3), .k4(kb4), .k5(kb5),
        .key_down(key_down), .key_up(key_up),
        .key_down_code(key_down_code), .key_up_code(key_up_code)
    );
    wire [47:0] key_curr = u_diff.curr;
    wire [47:0] key_prev = u_diff.prev;
    wire [3:0] usb_action;
    usb_keyboard_adapter u_keymap (.keycode(key_down_code), .action(usb_action));
    // Same normal event connections as the actual Game top.
    wire usb_event_up = key_down && (usb_action == 4'd1);
    wire usb_event_down = key_down && (usb_action == 4'd2);
    wire usb_event_left = key_down && (usb_action == 4'd3);
    wire usb_event_right = key_down && (usb_action == 4'd4);
    wire usb_event_ok = key_down && (usb_action == 4'd5);
    wire usb_event_back = key_down && (usb_action == 4'd6);
    wire usb_event_pause = key_down && (usb_action == 4'd7);

    wire [10:0] mouse_x;
    wire [9:0] mouse_y;
    wire signed [7:0] mouse_dx_signed = mouse_dx;
    wire signed [7:0] mouse_dy_signed = mouse_dy;
    wire signed [7:0] mouse_wheel_signed = mouse_wheel;
    usb_mouse_cursor_1024x600 u_cursor (
        .clk(clk), .rst_n(rst_n), .valid(mouse_valid), .dx(mouse_dx), .dy(mouse_dy),
        .x(mouse_x), .y(mouse_y)
    );
    wire left_down, right_down, middle_down;
    usb_mouse_button_event u_buttons (
        .clk(clk), .rst_n(rst_n), .valid(mouse_valid), .buttons(mouse_buttons),
        .left_down(left_down), .right_down(right_down), .middle_down(middle_down)
    );
    wire usb_pointer_activity = mouse_valid | left_down | right_down | middle_down;
    wire event_up, event_down, event_left, event_right, event_ok, event_back, event_pause;
    wire [2:0] ui_state, menu_sel;
    wire [10:0] pointer_x;
    wire [9:0] pointer_y;
    wire pointer_down, pointer_click, usb_pointer_selected;
    wire [7:0] keyboard_code;
    wire keyboard_extended;
    wire [4:0] ec_count;
    wire [15:0] touch_x_raw, touch_y_raw, chip_version;
    wire ft_flag, touch_coord_valid, game_exit_event;
    wire [6:0] touch_state;
    wire TOUCH_SCL, TOUCH_RST;

    chapter16_controller #(.CLK_HZ(CLK_HZ), .PS2_DEVICE_MODE(0)) u_controller (
        .clk(clk), .rst_n(rst_n), .keypad_valid(1'b0), .keypad_code(4'd0),
        .S1_KEYA(1'b1), .S1_KEYB(1'b1), .S1_KEYC(1'b1), .S1_KEYD(1'b1), .S1_KEYP(1'b1),
        .EC_A(1'b1), .EC_B(1'b1), .EC_KEY(1'b1), .PS2_CLK(PS2_CLK), .PS2_DATA(PS2_DATA),
        .TOUCH_SCL(TOUCH_SCL), .TOUCH_SDA(TOUCH_SDA), .TOUCH_INT(TOUCH_INT), .TOUCH_RST(TOUCH_RST),
        .touch_key_press(1'b0), .game_exit_request(1'b0),
        .usb_event_up(usb_event_up), .usb_event_down(usb_event_down),
        .usb_event_left(usb_event_left), .usb_event_right(usb_event_right),
        .usb_event_ok(usb_event_ok | left_down), .usb_event_back(usb_event_back | right_down),
        .usb_event_pause(usb_event_pause | middle_down),
        .usb_pointer_x(mouse_x), .usb_pointer_y(mouse_y), .usb_pointer_down(mouse_buttons[0]),
        .usb_pointer_click(left_down), .usb_pointer_activity(usb_pointer_activity),
        .usb_keyboard_valid(key_down), .usb_keyboard_code(key_down_code),
        .event_up(event_up), .event_down(event_down), .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back), .event_pause(event_pause),
        .ui_state(ui_state), .menu_sel(menu_sel), .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_down(pointer_down), .pointer_click(pointer_click), .keyboard_code(keyboard_code),
        .keyboard_extended(keyboard_extended), .ec_count(ec_count), .touch_x_raw(touch_x_raw),
        .touch_y_raw(touch_y_raw), .ft_flag(ft_flag), .chip_version(chip_version),
        .touch_state(touch_state), .touch_coord_valid(touch_coord_valid),
        .game_exit_event(game_exit_event), .usb_pointer_selected(usb_pointer_selected)
    );

    integer stimulus_case = 0;
    integer error_count = 0;
    integer uart_sent_count = 0, uart_received_count = 0, uart_error_pulse_count = 0;
    integer keyboard_report_count = 0, mouse_report_count = 0;
    integer key_down_count = 0, key_up_count = 0;
    integer left_down_count = 0, right_down_count = 0, middle_down_count = 0;
    integer event_up_count = 0, event_down_count = 0, event_left_count = 0, event_right_count = 0;
    integer event_ok_count = 0, event_back_count = 0, event_pause_count = 0;
    reg suite_complete = 1'b0;
    reg [7:0] expected_uart [0:1023];
    reg [7:0] down_log [0:127], up_log [0:127];
    reg prior_uart_valid = 0, prior_keyboard_valid = 0, prior_mouse_valid = 0;
    reg prior_key_down = 0, prior_key_up = 0;

    task fail;
        input [8*160-1:0] message;
        begin
            error_count = error_count + 1;
            $display("CH17 FAIL case=%0d at %0.3f us: %0s", stimulus_case, $realtime/1000.0, message);
        end
    endtask

    always @(posedge clk) begin
        #0.001;
        if (rst_n) begin
            if (uart_valid) begin
                if (prior_uart_valid) fail("UART valid was longer than one cycle");
                if (uart_received_count >= uart_sent_count ||
                    uart_byte !== expected_uart[uart_received_count]) fail("UART byte sequence mismatch");
                uart_received_count = uart_received_count + 1;
            end
            if (uart_frame_error) uart_error_pulse_count = uart_error_pulse_count + 1;
            if (keyboard_valid) begin
                if (prior_keyboard_valid || mouse_valid) fail("keyboard report pulse width/type");
                keyboard_report_count = keyboard_report_count + 1;
                $display("CH17 keyboard case=%0d at %0.6f us keys=%h frame=%0d",
                         stimulus_case, $realtime/1000.0, key_curr, frame_count);
            end
            if (mouse_valid) begin
                if (prior_mouse_valid || keyboard_valid) fail("mouse report pulse width/type");
                mouse_report_count = mouse_report_count + 1;
                $display("CH17 mouse case=%0d at %0.6f us buttons=%h dx=%0d dy=%0d wheel=%0d",
                         stimulus_case, $realtime/1000.0, mouse_buttons,
                         mouse_dx_signed, mouse_dy_signed, mouse_wheel_signed);
            end
            if (key_down) begin
                if (prior_key_down) fail("key_down pulse width");
                down_log[key_down_count] = key_down_code;
                key_down_count = key_down_count + 1;
            end
            if (key_up) begin
                if (prior_key_up) fail("key_up pulse width");
                up_log[key_up_count] = key_up_code;
                key_up_count = key_up_count + 1;
            end
            if (left_down) left_down_count = left_down_count + 1;
            if (right_down) right_down_count = right_down_count + 1;
            if (middle_down) middle_down_count = middle_down_count + 1;
            if (event_up) event_up_count = event_up_count + 1;
            if (event_down) event_down_count = event_down_count + 1;
            if (event_left) event_left_count = event_left_count + 1;
            if (event_right) event_right_count = event_right_count + 1;
            if (event_ok) event_ok_count = event_ok_count + 1;
            if (event_back) event_back_count = event_back_count + 1;
            if (event_pause) event_pause_count = event_pause_count + 1;
            prior_uart_valid = uart_valid;
            prior_keyboard_valid = keyboard_valid;
            prior_mouse_valid = mouse_valid;
            prior_key_down = key_down;
            prior_key_up = key_up;
        end else begin
            prior_uart_valid = 0; prior_keyboard_valid = 0; prior_mouse_valid = 0;
            prior_key_down = 0; prior_key_up = 0;
        end
    end

    task wait_until_ns;
        input real target_ns;
        begin
            if ($realtime < target_ns) #(target_ns-$realtime);
        end
    endtask

    task send_uart_byte;
        input [7:0] value;
        input good_stop;
        integer bit_number;
        begin
            if (good_stop) begin
                expected_uart[uart_sent_count] = value;
                uart_sent_count = uart_sent_count + 1;
            end
            @(negedge clk);
            serial_drive = 1'b0;
            #(UART_BIT_NS);
            for (bit_number=0; bit_number<8; bit_number=bit_number+1) begin
                serial_drive = value[bit_number];
                #(UART_BIT_NS);
            end
            serial_drive = good_stop;
            #(UART_BIT_NS);
            serial_drive = 1'b1;
            if (!good_stop) #(3.0*UART_BIT_NS);
        end
    endtask

    task send_keyboard;
        input [7:0] modifier;
        input [47:0] keys;
        input [7:0] expected_down, expected_up;
        input [3:0] expected_action;
        integer kb_before, mouse_before, down_before, up_before, frame_before;
        integer eu, ed, el, er, eo, eb, ep, index;
        reg [63:0] payload;
        begin
            kb_before=keyboard_report_count; mouse_before=mouse_report_count;
            down_before=key_down_count; up_before=key_up_count; frame_before=frame_count;
            eu=event_up_count; ed=event_down_count; el=event_left_count; er=event_right_count;
            eo=event_ok_count; eb=event_back_count; ep=event_pause_count;
            payload={keys,8'h00,modifier};
            send_uart_byte(8'h57,1'b1);
            send_uart_byte(8'hAB,1'b1);
            send_uart_byte(8'h01,1'b1);
            for(index=0;index<8;index=index+1) begin
                send_uart_byte(payload[index*8 +: 8],1'b1);
                if(index<7 && keyboard_report_count!=kb_before) fail("keyboard updated before full payload");
            end
            repeat(8) @(negedge clk);
            if(keyboard_report_count!=kb_before+1 || mouse_report_count!=mouse_before ||
               frame_count!=frame_before+1) fail("keyboard report count/type");
            if(keyboard_report!==payload || key_prev!==keys) fail("keyboard payload/previous slots mismatch");
            if(expected_down!=0) begin
                if(key_down_count!=down_before+1 || down_log[down_before]!==expected_down)
                    fail("keyboard down event mismatch");
            end else if(key_down_count!=down_before) fail("repeated/empty report generated key_down");
            if(expected_up!=0) begin
                if(key_up_count!=up_before+1 || up_log[up_before]!==expected_up)
                    fail("keyboard release event mismatch");
            end else if(key_up_count!=up_before) fail("unexpected key_up");
            if(event_up_count!=eu+(expected_action==1) || event_down_count!=ed+(expected_action==2) ||
               event_left_count!=el+(expected_action==3) || event_right_count!=er+(expected_action==4) ||
               event_ok_count!=eo+(expected_action==5) || event_back_count!=eb+(expected_action==6) ||
               event_pause_count!=ep+(expected_action==7)) fail("actual controller keyboard action mismatch");
        end
    endtask

    task send_mouse;
        input [7:0] buttons, dx, dy, wheel;
        input integer expected_x, expected_y;
        input [2:0] expected_button_edges;
        integer mouse_before, kb_before, frame_before, l_before, r_before, m_before;
        integer eo,eb,ep,index;
        reg [31:0] payload;
        begin
            mouse_before=mouse_report_count; kb_before=keyboard_report_count; frame_before=frame_count;
            l_before=left_down_count; r_before=right_down_count; m_before=middle_down_count;
            eo=event_ok_count; eb=event_back_count; ep=event_pause_count;
            payload={wheel,dy,dx,buttons};
            send_uart_byte(8'h57,1'b1);
            send_uart_byte(8'hAB,1'b1);
            send_uart_byte(8'h02,1'b1);
            for(index=0;index<4;index=index+1) begin
                send_uart_byte(payload[index*8 +: 8],1'b1);
                if(index<3 && mouse_report_count!=mouse_before) fail("mouse updated before full payload");
            end
            repeat(8) @(negedge clk);
            if(mouse_report_count!=mouse_before+1 || keyboard_report_count!=kb_before ||
               frame_count!=frame_before+1) fail("mouse report count/type");
            if({mouse_wheel,mouse_dy,mouse_dx,mouse_buttons}!==payload) fail("mouse payload mismatch");
            if(mouse_x!==expected_x || mouse_y!==expected_y) fail("cursor position/clamping mismatch");
            if(!usb_pointer_selected || pointer_x!==expected_x || pointer_y!==expected_y ||
               pointer_down!==buttons[0]) fail("actual controller USB pointer route mismatch");
            if(left_down_count!=l_before+expected_button_edges[0] ||
               right_down_count!=r_before+expected_button_edges[1] ||
               middle_down_count!=m_before+expected_button_edges[2]) fail("button edge/hold mismatch");
            if(event_ok_count!=eo+expected_button_edges[0] ||
               event_back_count!=eb+expected_button_edges[1] ||
               event_pause_count!=ep+expected_button_edges[2]) fail("actual controller mouse action mismatch");
        end
    endtask

    integer before_frames, before_errors, before_reports;
    initial begin
        repeat(8) @(negedge clk);
        rst_n=1'b1;

        // Main teaching sequence: first Space, identical report, empty release.
        wait_until_ns(20000.0);
        stimulus_case=1;
        send_keyboard(0,48'h00000000002C,8'h2C,0,7);
        if(ui_state!==3'd0 || event_ok_count!=0 || event_pause_count!=1) fail("Space must pause, not confirm");
        wait_until_ns(3000000.0);
        stimulus_case=2;
        send_keyboard(0,48'h00000000002C,0,0,0);
        wait_until_ns(6000000.0);
        stimulus_case=3;
        send_keyboard(0,48'h000000000000,0,8'h2C,0);

        stimulus_case=4; send_keyboard(0,48'h000000000028,8'h28,0,5);
        if(ui_state!==3'd1) fail("Enter did not open selected menu page");
        stimulus_case=5; send_keyboard(0,48'h000000000028,0,0,0);
        stimulus_case=6; send_keyboard(0,0,0,8'h28,0);
        if(ui_state!==3'd1) fail("Enter release changed page");
        stimulus_case=7; send_keyboard(0,48'h000000000029,8'h29,0,6);
        if(ui_state!==3'd0) fail("Esc did not return home");
        stimulus_case=8; send_keyboard(0,0,0,8'h29,0);
        stimulus_case=9; send_keyboard(0,48'h000000000051,8'h51,0,2);
        if(menu_sel!==3'd1) fail("Down did not change menu selection");
        stimulus_case=10; send_keyboard(0,48'h00000000001A,8'h1A,8'h51,1);
        if(menu_sel!==3'd0) fail("W/Up did not restore menu selection");
        stimulus_case=11; send_keyboard(0,48'h000000000004,8'h04,8'h1A,3);
        stimulus_case=12; send_keyboard(0,48'h00000000004F,8'h4F,8'h04,4);
        stimulus_case=13; send_keyboard(0,0,0,8'h4F,0);

        // One new key at a time; reordering the same key set is not a new press.
        stimulus_case=14; send_keyboard(0,48'h00000000002C,8'h2C,0,7);
        stimulus_case=15; send_keyboard(0,48'h00000000282C,8'h28,0,5);
        stimulus_case=16; send_keyboard(0,48'h000000002C28,0,0,0);
        stimulus_case=17; send_keyboard(0,48'h000000000028,0,8'h2C,0);
        stimulus_case=18; send_keyboard(0,0,0,8'h28,0);
        stimulus_case=19; send_keyboard(8'h02,0,0,0,0);
        stimulus_case=20; send_keyboard(8'h00,0,0,0,0);

        stimulus_case=21; send_mouse(8'h01,8'h0C,8'hF8,8'hFF,524,292,3'b001);
        stimulus_case=22; send_mouse(8'h01,0,0,0,524,292,3'b000);
        stimulus_case=23; send_mouse(8'h00,8'hE8,8'h10,8'h01,500,308,3'b000);
        stimulus_case=24; send_mouse(8'h02,0,0,0,500,308,3'b010);
        if(ui_state!==3'd0) fail("mouse right button did not return home");
        stimulus_case=25; send_mouse(8'h00,0,0,0,500,308,3'b000);
        stimulus_case=26; send_mouse(8'h04,0,0,0,500,308,3'b100);
        stimulus_case=27; send_mouse(8'h00,0,0,0,500,308,3'b000);
        stimulus_case=28; send_mouse(0,8'h80,8'h80,0,372,180,0);
        stimulus_case=29; send_mouse(0,8'h80,8'h80,0,244,52,0);
        stimulus_case=30; send_mouse(0,8'h80,8'h80,0,116,0,0);
        stimulus_case=31; send_mouse(0,8'h80,8'h80,0,0,0,0);
        stimulus_case=32; send_mouse(0,8'h7F,8'h7F,0,127,127,0);
        stimulus_case=33; send_mouse(0,8'h7F,8'h7F,0,254,254,0);
        stimulus_case=34; send_mouse(0,8'h7F,8'h7F,0,381,381,0);
        stimulus_case=35; send_mouse(0,8'h7F,8'h7F,0,508,508,0);
        stimulus_case=36; send_mouse(0,8'h7F,8'h7F,0,635,599,0);
        stimulus_case=37; send_mouse(0,8'h7F,8'h7F,0,762,599,0);
        stimulus_case=38; send_mouse(0,8'h7F,8'h7F,0,889,599,0);
        stimulus_case=39; send_mouse(0,8'h7F,8'h7F,0,1016,599,0);
        stimulus_case=40; send_mouse(0,8'h7F,8'h7F,0,1023,599,0);

        // Noise, a bad second header byte, an unknown type and repeated 57.
        stimulus_case=41;
        before_frames=frame_count;
        send_uart_byte(0,1); send_uart_byte(8'hAB,1); send_uart_byte(8'h42,1);
        repeat(8) @(negedge clk);
        if(frame_count!=before_frames || sync_loss_count!=0) fail("idle noise created report/loss");
        stimulus_case=42;
        send_uart_byte(8'h57,1); send_uart_byte(0,1);
        repeat(8) @(negedge clk);
        if(frame_count!=before_frames || sync_loss_count!=1) fail("bad second header detection");
        send_keyboard(0,0,0,0,0);
        stimulus_case=43;
        before_frames=frame_count;
        send_uart_byte(8'h57,1); send_uart_byte(8'hAB,1); send_uart_byte(8'h7F,1);
        repeat(8) @(negedge clk);
        if(frame_count!=before_frames || sync_loss_count!=2) fail("unknown report type detection");
        send_mouse(0,0,0,0,1023,599,0);
        stimulus_case=44;
        send_uart_byte(8'h57,1);
        send_keyboard(0,0,0,0,0);
        if(sync_loss_count!=2) fail("repeated 57 prevented header synchronization");

        // Bad UART stop bit: no parser byte, exactly one error, then recovery.
        stimulus_case=45;
        before_errors=uart_error_pulse_count;
        before_reports=uart_received_count;
        before_frames=frame_count;
        send_uart_byte(8'hA6,0);
        repeat(8) @(negedge clk);
        if(uart_error_pulse_count!=before_errors+1 || uart_error_count!=1 ||
           uart_received_count!=before_reports || frame_count!=before_frames)
            fail("bad UART stop bit acceptance/error count");
        send_keyboard(0,48'h000000000028,8'h28,0,5);
        if(frame_count!=44 || keyboard_report_count!=23 || mouse_report_count!=21)
            fail("pre-reset report coverage");

        // Discard an incomplete payload by an asynchronous reset; then recover.
        stimulus_case=46;
        before_frames=frame_count;
        send_uart_byte(8'h57,1); send_uart_byte(8'hAB,1); send_uart_byte(8'h01,1);
        send_uart_byte(0,1); send_uart_byte(0,1);
        if(frame_count!=before_frames) fail("incomplete keyboard payload produced report");
        @(negedge clk); #3; rst_n=0; #0.001;
        if(frame_count!=0 || sync_loss_count!=0 || uart_error_count!=0 ||
           key_prev!=0 || keyboard_report!=0 || mouse_x!=512 || mouse_y!=300 ||
           ui_state!=0 || usb_pointer_selected!=0) fail("reset did not clear receive state");
        repeat(8) @(negedge clk);
        rst_n=1;
        stimulus_case=47;
        send_keyboard(0,48'h00000000002C,8'h2C,0,7);
        if(frame_count!=1 || sync_loss_count!=0 || uart_error_count!=0 || ui_state!=0)
            fail("post-reset recovery");

        if(keyboard_report_count!=24 || mouse_report_count!=21 || uart_error_pulse_count!=1 ||
           left_down_count!=1 || right_down_count!=1 || middle_down_count!=1 ||
           uart_received_count!=uart_sent_count) fail("final suite coverage");
        stimulus_case=48;
        suite_complete=1;
        if(error_count==0)
            $display("CH17 PASS: uart_bytes=%0d keyboard_reports=%0d mouse_reports=%0d down=%0d up=%0d buttons=%0d/%0d/%0d uart_bad_stop=%0d errors=0",
                     uart_received_count,keyboard_report_count,mouse_report_count,key_down_count,key_up_count,
                     left_down_count,right_down_count,middle_down_count,uart_error_pulse_count);
        else $display("CH17 FAIL: errors=%0d",error_count);
    end

    initial begin
        #83000000;
        if(!suite_complete) fail("suite timeout");
    end
endmodule
