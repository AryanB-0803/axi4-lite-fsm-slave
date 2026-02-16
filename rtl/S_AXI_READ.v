module s_axi_read(
    input aclk,aresetn,
    input arvalid,
    input [31:0]araddr,
    input rready,
    output arready,
    output reg [1:0]rresp,
    output reg rvalid,
    output reg [31:0]rdata
);
localparam SLVERR = 2'b10, OKAY = 2'b00;
reg [31:0]latched_addr;
reg [31:0]register_data[0:127];
reg [6:0]read_index;

//assigning arready and rvalid relationship
assign arready = ~rvalid;

always@(*) begin
    read_index = latched_addr[8:2];
    if(latched_addr[31:9] != 0) begin
        rresp = SLVERR; //if address isnt valid, read transaction shldnt be stopped but SLVERR shld be given else OKAY because read transaction successful
        rdata = 32'h0;
    end
    else begin
        rresp = OKAY;
        rdata = register_data[read_index];
    end
end
/*instead of assigning latched_addr[8:2],right shift by 2 can also be done as latched_addr >> 2 but I faced errors due to unbounded addresses being
simulated wrongly by the simulator. Thus the method of bound address by assigning the 7 bits from 8 to 2 without considering first and zeroth bits.
the >> 2 is done because each register is 32 bits i.e 4 bytes long and for safe handling, dropping last 2 bits will give proper register_data index...
ex. 0x06 = 6 decimal 0000_0110 address...drop 2 = 0000_0001 which is the right
index which register data shld access..0-3 register_data[0] 4-7 register_data[1] etc.*/

//sequential block for read transaction
always@(posedge aclk or negedge aresetn) begin  //its negedge reset because its active low reset in axi-lite
    if(!aresetn) begin//rvalid shld go to idle when reset is low
        rvalid <= 0;
        latched_addr <= 32'h0;
    end
    else begin
        if(rready && rvalid)
            rvalid <= 0;
        else if(arready && arvalid) begin
            latched_addr <= araddr;
            rvalid <= 1;
        end
    end
end
endmodule

/* --- comments ---
although stucturally my design prevents ar handshake and r handshake happening simultaneously
because of my arready and rvalid relation, rvalid is the priority state and encoding it properly
requires completing r transaction first and then going to ar handshake...thus lines 43 to 48*/
