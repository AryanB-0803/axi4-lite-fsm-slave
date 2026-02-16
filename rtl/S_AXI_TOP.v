module S_AXI_TOP(
    input aclk,aresetn,
    input awvalid,
    input [31:0]awaddr,
    input wvalid,
    input [31:0] wdata,
    input bready,
    input arvalid,
    input [31:0]araddr,
    input rready,
    output reg awready,
    output reg wready,
    output reg bvalid,
    output reg [1:0]bresp,
    output arready,
    output reg [1:0]rresp,
    output reg rvalid,
    output reg [31:0]rdata
);
reg [1:0] state,next_state;
reg [6:0] read_index,write_index;
//this register is common for both write and read channels...these will be
//used as a common register array from which both handshakes can occur as in
//axi4-lite they operate as parallel blocks rather than interconnected ones 
reg [31:0]register_array[0:127];
reg [31:0]latched_addr_w,latched_data;
reg [31:0] latched_addr_r;
localparam SLVERR = 2'b10, OKAY = 2'b00;
//state encoding for my write channel
localparam idle = 2'b00, got_aw = 2'b01, got_w = 2'b10, resp = 2'b11;

//---READ CHANNEL--- 
//assigning arready and rvalid relationship
assign arready = ~rvalid;

always@(*) begin
    read_index = latched_addr_r[8:2];
    if(latched_addr_r[31:9] != 0)  begin
        rresp = SLVERR; //if address isnt valid, read transaction shldnt be stopped but SLVERR shld be given else OKAY because read transaction successful
        rdata = 32'h0;
    end
    else begin
        rresp = OKAY;
        rdata = register_array[read_index];
    end
end
//using latched_addr >> 2 is also an option but got a few errors during simulation
//which results in wrong error flags being thrown...this happened because the
//out of bound addresses werent being handled correctly by the simulator.
/*the >> 2 is done because each register is 32 bits i.e 4 bytes long and for safe handling,
dropping last 2 bits will give proper register_data index...ex 0x06 = 6 decimal 0000_0110 address...drop 2 = 0000_0001 which is the right
index which register data shld access..0-3 register_data[0] 4-7 register_data[1] etc.*/

//sequential block for read transaction
always@(posedge aclk or negedge aresetn) begin  //its negedge reset because its active low reset in axi-lite
    if(!aresetn) begin//rvalid shld go to idle when reset is low
        rvalid <= 0;
        latched_addr_r <= 32'h0;
    end
    else begin
        if(rready && rvalid)
            rvalid <= 0;
        else if(arready && arvalid) begin
            latched_addr_r <= araddr;
            rvalid <= 1;
        end
    end
end


//--WRITE CHANNEL---
//have used fsm approach for write channel as its cleaner...4 states are
//defined as idle, got_aw (got write address), got_w (got data) and resp(state
//where writing happens under the condition of bvalid&&bready) 
always@(*) begin
    write_index = latched_addr_w[8:2];
    if((latched_addr_w[31:9] != 0))
        bresp = SLVERR;
    else
        bresp = OKAY;
end

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

always@(posedge aclk or negedge aresetn) begin
    if(!aresetn) begin
        state <= idle;
        awready <= 1;
        wready <= 1;
        bvalid <= 0;
        latched_addr_w <= 32'h0;
        latched_data <= 32'h0;
    end
    else begin
        state <= next_state;
        case(state)
            idle : begin                                
                if((awvalid&&awready)&&(wvalid&&wready)) begin
                    bvalid <= 1;
                    latched_addr_w <= awaddr;
                    latched_data <= wdata;
                    awready <= 0;
                    wready <= 0;
                end
                else if(awvalid&&awready) begin
                    latched_addr_w <= awaddr;
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
                    latched_addr_w <= awaddr;
                    awready <= 0;
                end
                else begin
                    awready <= 1;
                    wready <= 0;
                end
            end
            resp : begin
                if(bvalid&&bready) begin
                    if((latched_addr_w[31:9] == 0)) 
                    register_array[write_index] <= latched_data;
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
