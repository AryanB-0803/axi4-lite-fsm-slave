# axi4-lite-slave-verilog
AXI4-Lite slave interface in Verilog with FSM-based read/write channels

## Brief Overview
An AXI4-Lite slave/subordinate is a protocol designed by ARM under the AMBA (Advanced Microcontroller Bus Architecture) family. It has a few features such as single-outstanding write transaction and independent read and write channels. 
It is widely used in the industry and is a standard protocol for intra-system communication.
I have used a register array of 128 registers each of 32 bits i.e 128 x 32-bit register mapping.
A Moore-style FSM was used to map the working of write channel and flag-based design was chosen for read channel.
The terms master/slave are used in accordance with the legacy AXI signal naming. The newer versions use manager/subordinate.

## Read channel operation
In the read channel, there are 2 handshakes that occur - i.) the AR handshake (Address Read) and ii.) the R handshake (Read).
Firstly, the master sends a signal "arvalid" the address to be read as "araddr" signal. When the slave is ready to accept the read address, it sends a "arready" signal.
The AR handshake takes place only when both arvalid and arready are high i.e arvalid&&arready.
After the AR handshake, the read address is stored in a 32-bit register named as "latched_addr_r" in the design and the slave sends out a signal called "rvalid" to the master.
The rvalid signal is asserted by the slave in the next cycle after the AR handshake.
When the master asserts a signal "rready" signifying that it can accept the read data, the R handshake takes place and an output "rdata" is assigned the data in the register at the latched address gotten during AR handshake.
The R handshake happens only when both rvalid and rready are high i.e rvalid&&rready.

 # The response signal (rresp)
The AXI4-Lite spec demands a response signal from the slave to the master signifying the success of the read transaction.
According to the AXI4-Lite spec, there is a response signal named "rresp" which can throw one of the 2 responses which are - SLVERR (slave error) and OKAY.
OKAY signifies that the read transaction has taken place successfully. The SLVERR signifies many possible violations but the one used in the design is of the error of invalid read address.
SLVERR is encoded as 2'b10 and OKAY is encoded as 2'b00.
  # IMPORTANT
The AXI4-Lite spec specifically states that even if SLVERR is thrown, the read transaction MUST NOT be paused,stopped or aborted and it must carry out as intended but the slave has to give the response as SLVERR to the master.

## Write channel operation
In the write channel, there are 3 handshakes that occur - i.) the AW handshake (Address Write), ii.) the W handshake (Write) and iii.) the B handshake (Write response).
The design uses a 4 state FSM with states as follows - i.) idle, ii.) got_aw, iii.) got_w and iv.) resp.
Upon reset state is initialized to idle.

According to AXI4-Lite spec, one of the features supported by the protocol in the write channel is the independent nature of arrival of the write address and the write data signals. 
The AXI4-Lite design allows the write address to arrive first, the write data request to arrive first or both to arrive simultaneously.
The FSM structure explicitly allows these possibilities to occur and safely handle the requests.

If the "awvalid" signal is thrown first by the master along with the 32 bit write address data which is signified by the "awaddr" signal, the slave must throw a "awready" signal when it is ready to accept the write address.
The write address is stored in a 32-bit register named "latched_addr_w".
If both awvalid and awready are high i.e awvalid && awready then the AW handshake completes.
The transition is --> idle to got_aw iff awvalid && awready

If the "wvalid" signal is thrown first by the master along with the data to be written which is signified by the "wdata" signal, the slave must throw a "wready" signal when it is ready to accept the write data.
The write data is stored in a 32-bit register named "latched_data_w". This is done because the actual write operation occurs in the upcoming stages when both AW transaction and W transaction are completeso we have to store the wdata
temporarily in a register.
If both wvalid and wready are high i.e wvalid && wready then the W handshake completes.
The transition is --> idle to got_w iff wvalid && wready.

If both AW signals and W signals arrive together, the write address is latched in a register named "latched_addr_w" and the write data is latched in a register named "latched_data_w".
In this case, if both the AW transaction and the W transaction are complete, ONLY THEN will the write transaction occur and the latched write data is written to the register of the latched address.
The transition in this case is --> idle to resp iff AW_handshake signals && W_handshake signals.

Resp state is the final state where the actual writing of data takes place.
The "bvalid" and "bready" signals are used to signify the status of the transaction and "bresp" is the response signal thrown by the slave.

# The response signal (bresp)
The AXI4-Lite spec demands a response signal from the slave to the master signifying success of the write transaction.
According to the AXI4-Lite spec, there is a response signal named "bresp" which can throw one of the 2 responses which are - SLVERR (slave error) and OKAY.
OKAY signifies that the write transaction has taken place successfully. The SLVERR signifies many possible violations but the one used in the design is of the error of invalid write address.
SLVERR is encoded as 2'b10 and OKAY is encoded as 2'b00.
 # IMPORTANT
Like in the read channel description of the response (refer rresp), AXI4-Lite spec specifically states that even if SLVERR is thrown, the write transaction MUST NOT be paused,stopped or aborted and it must carry out as intended but
the slave has to give the response as SLVERR to the master.

The Moore-style FSM for the write channel and the respective transistions are shown below :
<p align="center">
  <img src="docs/write_fsm.svg" alt="AXI4-Lite Write Channel FSM" width="600">
</p>

## Register Map

The design implements 128 memory-mapped registers.

- Each register is 32 bits wide
- Address space size: 128 × 4 bytes = 512 bytes
- Valid address range: 0x000 to 0x1FC
- Word-aligned accesses assumed

## Design assumptions and choices

- Only single-beat transactions supported (AXI4-Lite limitation)
- No burst support
- Word-aligned accesses assumed
- No byte strobe handling (if true)
- Fully synchronous to single clock
- Active-high synchronous reset

## Notes about the flow control

AXI4-Lite supports only a single outstanding transaction per channel since it does not use transaction IDs.
To enforce this for the read channel, arready is driven using simple combinational logic in my design.
The code snippet is as follows :

  assign arready = ~rvalid
  
This makes sure that arready becomes low whenever rvalid becomes high and vice-versa. This ensures that only one outstanding read transaction requirement is met.

## VERIFICATION
The design was verified using a behavioral testbench that covers:

- Read after write
- Invalid address access
- Simultaneous AW and W arrival
- Back-to-back transactions

Tools used are - iverilog (for simulation) and GTKWave (for waveform analysis)
The waveform generated after the simulation is as shown below : 

<p align="center">
  <img src="docs/S_AXI_gtkwave_waveform.png" 
       alt="AXI4-Lite Slave GTKWave Verification Waveform" 
       width="900">
</p>

## Future Improvements
- Add byte strobes (wstrb).
- Add formal verification.
- Add parameterization for register depth. 
