module S_AXI_WRITE(
    input aclk,aresetn,
    input awvalid,
    input [31:0]awaddr,
    input wvalid,
    input [31:0] wdata,
    input bready,
    output reg bvalid,
    output reg awready,
    output reg wready,
    output reg [1:0]bresp
);
reg [1:0] state,next_state;
reg [31:0]register_write[0:127];
reg [31:0]latched_addr,latched_data;
reg [6:0]write_index;
localparam idle = 2'b00, got_aw = 2'b01, got_w = 2'b10, resp = 2'b11;
localparam OKAY = 2'b00, SLVERR = 2'b10;
//the write channel uses a 4 state fsm : 1.) idle 2.) got_aw
//3.)got_w and 4.)resp...idle state is the initial state, got_aw state is
//when address handshake takes place, got_w state is when the write handshake
//takes place and finally resp state is where the writing actually happens
//with b handshake. SLVERR is thrown when the write address is out of bounds
//and OKAY when write address is in bounds. Another thing to note is that even
//when SLVERR gets thrown, the handshake SHOULD NOT halt; it must complete but
//give the SLVERR (2'b10) to the master. SLVERR and OKAY are assigned to bresp
//signal.

//error detection and response block (bresp assignment)
always@(*) begin
    write_index = latched_addr[8:2];
    if(latched_addr[31:9] != 0)
        bresp = SLVERR;
    else
        bresp = OKAY;
end

//next state assignment...starts from idle
always@(*) begin
    next_state = state;
    case(state)
        idle : begin
            if((awvalid&&awready)&&(wvalid&&wready))
                next_state = resp;
            else if(awvalid&&awready)
                next_state = got_aw;
            else if(wvalid&&wready)
                next_state = got_w;
        end
        got_aw : begin
            if(wvalid&&wready) 
                next_state = resp;
        end
        got_w : begin
            if(awvalid&&awready)
                next_state = resp;
        end
        resp : begin
            if(bvalid&&bready) 
                next_state = idle;
        end
    endcase
end

//sequential block for aw, w and b handshakes
always@(posedge aclk or negedge aresetn) begin
    if(!aresetn) begin
        state <= idle;
        awready <= 1;
        wready <= 1;
        bvalid <= 0;
        latched_addr <= 0;
        latched_data <= 0;
    end
    else begin
        state <= next_state;
        case(state)
            idle : begin                                
                if((awvalid&&awready)&&(wvalid&&wready)) begin
                    bvalid <= 1;
                    latched_addr <= awaddr;
                    latched_data <= wdata;
                    awready <= 0;
                    wready <= 0;
                end
                else if(awvalid&&awready) begin
                    latched_addr <= awaddr;
                    awready <= 0;
                end
                else if(wvalid&&wready) begin
                    latched_data <= wdata;
                    wready <= 0;
                end
            end
            got_aw : begin
                if(wvalid&&wready) begin
                    wready <= 0;
                    bvalid <= 1;
                    latched_data <= wdata;
                    awready <= 0;
                end
                else begin
                    awready <= 0;
                    wready <= 1;
                end
            end
            got_w : begin
                if(awvalid&&awready) begin
                    wready <= 0;
                    bvalid <= 1;
                    latched_addr <= awaddr;
                    awready <= 0;
                end
                else begin
                    awready <= 1;
                    wready <= 0;
                end
            end
            resp : begin
                if(bvalid&&bready) begin
                    if(latched_addr[31:9] == 0)
                        register_write[write_index] <= latched_data;
                    bvalid <= 0;
                    wready <= 1;
                    awready <= 1;
                end
                else
                    bvalid <= 1;
            end
        endcase
    end
end
endmodule
