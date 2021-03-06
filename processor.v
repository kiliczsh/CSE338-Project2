module processor;
reg [31:0] pc; //32-bit prograom counter
reg clk; //clock
reg nout_status;
reg zout_status;
reg [7:0] datmem[0:31],mem[0:31]; //32-size data and instruction memory (8 bit(1 byte) for each location)
wire [31:0] 
dataa,	//Read data 1 output of Register File
datab,	//Read data 2 output of Register File
writedata,
out2,		//Output of mux with ALUSrc control-mult2
out3,		//Output of mux with MemToReg control-mult3
out4,		//Output of mux with (Branch&ALUZero) control-mult4
out5,
out6,
out7,
out8,
reg_write_data,
sum,		//ALU result
extad,	//Output of sign-extend unit
adder1out,	//Output of adder which adds PC and 4-add1
adder2out,	//Output of adder which adds PC+4 and 2 shifted sign-extend result-add2
sextad;	//Output of shift left 2 unit

wire [5:0] inst31_26;	//31-26 bits of instruction
wire [4:0] 
inst25_21,	//25-21 bits of instruction
inst20_16,	//20-16 bits of instruction
inst15_11,	//15-11 bits of instruction
out1;		//Write data input of Register File

wire [15:0] inst15_0;	//15-0 bits of instruction

wire [31:0] instruc;	//current instruction
wire [31:0] pseudo_direct_address; //Used for bz instruction
wire balrn_signal;
wire [31:0] dpack;	//Read data output of memory (data read from memory)

wire [2:0] gout;	//Output of ALU control unit

wire zout,nout,	//Zero output of ALU
pcsrc,	//Output of AND gate with Branch and ZeroOut inputs
//Control signals
regdest,alusrc,memtoreg,regwrite,memread,memwrite,branch,aluop1,aluop0,jspal_signal,blez_signal,blez_gate,bz_signal,bz_gate;

//32-size register file (32 bit(1 word) for each register)
reg [31:0] registerfile[0:31];

integer i;

// datamemory connections

always @(posedge clk)
//write data to memory
if (memwrite)
begin 
//sum stores address,datab stores the value to be written
datmem[sum[4:0]+3]=writedata[7:0];
datmem[sum[4:0]+2]=writedata[15:8];
datmem[sum[4:0]+1]=writedata[23:16];
datmem[sum[4:0]]=writedata[31:24];
end


//instruction memory
//4-byte instruction
 assign instruc={mem[pc[4:0]],mem[pc[4:0]+1],mem[pc[4:0]+2],mem[pc[4:0]+3]};
 assign inst31_26=instruc[31:26];
 assign inst25_21=instruc[25:21];
 assign inst20_16=instruc[20:16];
 assign inst15_11=instruc[15:11];
 assign inst15_0=instruc[15:0];


 assign pseudo_direct_address[31:28] = pc[31:28];
 assign pseudo_direct_address[27:2] = instruc[25:0];
 assign pseudo_direct_address[1] = 0;
 assign pseudo_direct_address[0] = 0;
 
 
// registers

assign dataa=registerfile[inst25_21];//Read register 1
assign datab=registerfile[inst20_16];//Read register 2
always @(posedge clk)
 registerfile[out1]= regwrite ? reg_write_data:registerfile[out1];//Write data to register
	
//read data from memory, sum stores address
assign dpack = (~clk) ? {datmem[sum[5:0]],datmem[sum[5:0]+1],datmem[sum[5:0]+2],datmem[sum[5:0]+3]} : dpack;

//status update nout and zout
always @(negedge clk)
begin
 nout_status = nout;
 zout_status = zout;
end



//multiplexers
//mux with RegDst control
mult2_to_1_5  mult1(out1, instruc[20:16],instruc[15:11],regdest);

//mux with ALUSrc control
mult2_to_1_32 mult2(out2, datab,extad,alusrc);

//mux with MemToReg control
mult2_to_1_32 mult3(out3, sum,dpack,memtoreg);

//mux with (Branch&ALUZero) control
mult2_to_1_32 mult4(out4, adder1out,adder2out,pcsrc);

//mux with (out3&jumpaddress) control
mult2_to_1_32 mult5(out5, out4,out3,jspal_signal);

//mux with (datab&pc+4) control
mult2_to_1_32 mult6(writedata, datab, adder1out, jspal_signal);


//mux with (address & pc+4) control
mult2_to_1_32 mult7(out6, out5,adder2out,blez_gate);

//mux with (address & pc+4) control
mult2_to_1_32 mult8(out7, out6,pseudo_direct_address,bz_gate);

//mux with (address & pc+4) control
mult2_to_1_32 mult9(out8, out7,sum,balrn_gate);

//mux with (address & pc+4) control
mult2_to_1_32 mult10(reg_write_data, out3,adder1out,balrn_gate);

// load pc
always @(negedge clk)
pc=out8;

// alu, adder and control logic connections

//ALU unit
alu32 alu1(sum,dataa,out2,zout,nout,gout);

//adder which adds PC and 4
adder add1(pc,32'h4,adder1out);

//adder which adds PC+4 and 2 shifted sign-extend result
adder add2(adder1out,sextad,adder2out);

//Control unit
control cont(instruc[31:26],balrn_gate,balrn_signal,regdest,alusrc,memtoreg,regwrite,memread,memwrite,branch,
aluop1,aluop0,jspal_signal,blez_signal,bz_signal);

//Sign extend unit
signext sext(instruc[15:0],extad);

//ALU control unit
alucont acont(aluop1,aluop0,instruc[3],instruc[2], instruc[1], instruc[0] ,gout);

//Shift-left 2 unit
shift shift2(sextad,extad);

//AND gate
assign pcsrc=branch && zout; 
assign blez_gate=blez_signal && (nout||zout);
assign bz_gate=bz_signal && zout_status;
assign balrn_signal = ( ( ~( instruc[31] | instruc[30] | instruc[29] | instruc[28] | instruc[27] | instruc[26] ) ) && ( (~instruc[5]) & instruc[4] & (~instruc[3]) & instruc[2] & instruc[1] & instruc[0] ) );
assign balrn_gate = balrn_signal && nout_status;


//initialize datamemory,instruction memory and registers
//read initial data from files given in hex
initial
begin
$readmemh("initDm.dat",datmem); //read Data Memory
$readmemh("initIM.dat",mem);//read Instruction Memory
$readmemh("initReg.dat",registerfile);//read Register File

	for(i=0; i<31; i=i+1)
	$display("Instruction Memory[%0d]= %h  ",i,mem[i],"Data Memory[%0d]= %h   ",i,datmem[i],
	"Register[%0d]= %h",i,registerfile[i]);
end

initial
begin
pc=0;
#400 $finish;
end


initial
begin
clk=0;
//40 time unit for each cycle
forever #20  clk=~clk;
end
initial 
begin
  $monitor($time,"PC %h",pc,"  SUM %h",sum,"   INST %h",instruc[31:0],
"   REGISTER %h %h %h %h ",registerfile[1],registerfile[4], registerfile[2],registerfile[1] );
end
endmodule

