module RISCV_TOP (
	//General Signals
	input wire CLK,
	input wire RSTn,

	//I-Memory Signals
	output wire I_MEM_CSN,
	input wire [31:0] I_MEM_DI,//input from IM
	output reg [11:0] I_MEM_ADDR,//in byte address

	//D-Memory Signals
	output wire D_MEM_CSN,
	input wire [31:0] D_MEM_DI,
	output wire [31:0] D_MEM_DOUT,
	output wire [11:0] D_MEM_ADDR,//in word address
	output wire D_MEM_WEN,
	output wire [3:0] D_MEM_BE,

	//RegFile Signals
	output wire RF_WE,
	output wire [4:0] RF_RA1,
	output wire [4:0] RF_RA2,
	output wire [4:0] RF_WA1,
	input wire [31:0] RF_RD1,
	input wire [31:0] RF_RD2,
	output wire [31:0] RF_WD,
	output wire HALT,                   // if set, terminate program
	output reg [31:0] NUM_INST,         // number of instruction completed
	output wire [31:0] OUTPUT_PORT      // equal RF_WD this port is used for test
	);

	assign OUTPUT_PORT = RF_WD;

	initial begin
		NUM_INST <= 0;
	end

	// TODO: implement
	
//////////////////////////////////register definition//////////////////////////////////////

	// data register
	reg [11:0] pc;
	reg [11:0] pc1;
	reg [11:0] pc2;
	wire [11:0] Added_pc;
	reg [11:0] Added_pc1;
	reg [11:0] Added_pc2;
	reg [31:0] Added_pc3;
	reg [11:0] nxt_pc;
	reg [31:0] inst;	
	reg [4:0] rd1;
	reg [4:0] rd2;
	reg [4:0] rd3;
	reg [31:0] immed;
	reg [11:0] immed1;	
	reg [31:0] A;
	reg [31:0] B;
	reg [31:0] rt1;
	reg [31:0] rt2;
	reg [31:0] result;
	reg [31:0] ALUOut;
	reg [31:0] preMEMOut;
	reg [31:0] MEMOut;
	
	// control register
	reg [1:0] PCSrc;
	reg RegWrite1;
	reg RegWrite2;
	reg RegWrite; 
	reg [2:0] ASrc;
	reg [2:0] BSrc;
	reg [1:0] rtSrc;
	reg [3:0] ALUOP;
	reg [1:0] MEMOutSrc1;
	reg [1:0] MEMOutSrc;
	reg JAL;
	reg JAL1;
	reg JALR;
	reg JALR1;
	reg Branch;
	reg MEMWrite1;
	reg MEMWrite;
	reg LW;
	reg Stall;
	reg Finish;
	reg NOP1;
	reg NOP2;
	reg NOP3;
	reg NOP;

//////////////////////////////////HALT and NUM_INST//////////////////////////////////////

	// state
	reg [2:0] state;

	initial begin
		state <= 0;
	end


	// HALT
	assign HALT = ((inst == 32'h00008067) && (Finish == 1'b1))? 1'b1 : 1'b0;

	// NUM_INST
	always @ (negedge CLK) begin
		if (RSTn && (state == 4) && (NOP == 1'b0)) NUM_INST <= NUM_INST + 1;
		else if (RSTn && (state == 4) && (NOP == 1'b1)) NUM_INST <= NUM_INST;
		else if (RSTn)  state <= state + 1;
		else state <= 0;
	end

//////////////////////////////////pc Maker//////////////////////////////////////

	// pc
	always @(posedge CLK) begin
		if (RSTn == 1'b0) pc <= 12'b0;
		else if (Stall == 1'b1) pc <= pc;
		else pc <= nxt_pc;
	end

	// pc pipleline register
	always @(posedge CLK) begin
		if (Stall == 1'b1) pc1 <= pc1;
		else pc1 <= pc;
	end

	always @(posedge CLK) begin
		pc2 <= pc1;
	end

	// immed pipleline register
	always @(posedge CLK) begin
		immed1 <= immed[11:0];
	end

	// Added_pc
	assign Added_pc = pc + 4;

	// Added_pc pipleline register
	always @(posedge CLK) begin
		if (Stall == 1'b1) Added_pc1 <= Added_pc1;
		else Added_pc1 <= Added_pc;
	end

	always @(posedge CLK) begin
		Added_pc2 <= Added_pc1;
	end

	always @(posedge CLK) begin
		Added_pc3 <= {{21{Added_pc2[11]}},Added_pc2[10:0]};
	end

	// PCSrc
	always @(*) begin
		if ((JAL1 == 1'b1) || ((Branch == 1'b1) && (result[0] == 1'b1))) PCSrc = 2'b01;
		else if (JALR1 == 1'b1) PCSrc = 2'b10;
		else PCSrc = 2'b00;
	end

	// nxt_pc
	always @(*) begin
		case (PCSrc)
			2'b01: nxt_pc = pc2 + immed1;
			2'b10: nxt_pc = result[11:0];
			default: nxt_pc = Added_pc;
		endcase
	end

//////////////////////////////////I Memery//////////////////////////////////////

	// I_MEM
	always @(*) I_MEM_ADDR = pc;

	assign I_MEM_CSN = ~RSTn;

	// inst
	always @(posedge CLK) begin
		if ((JAL == 1'b1) || (JALR == 1'b1) || (JAL1 == 1'b1) || (JALR1 == 1'b1) || ((Branch == 1'b1) && (result[0] == 1'b1))) begin
			inst <= 32'h00000013;
			NOP1 <= 1'b1;
		end
		else if (Stall == 1'b1) begin
			inst <= inst;
			NOP1 <= NOP1;
		end
		else begin
			inst <= I_MEM_DI;
			NOP1 <= 1'b0;
		end
	end

//////////////////////////////////General Register//////////////////////////////////////

	// RF_RA
	assign RF_RA1 = inst[19:15];

	assign RF_RA2 = inst[24:20];

	// rd pipleline register
	always @(posedge CLK) begin
		rd1 <= inst[11:7];
	end

	always @(posedge CLK) begin
		rd2 <= rd1;
	end

	always @(posedge CLK) begin
		rd3 <= rd2;
	end

	// RF_WA
	assign RF_WA1 = rd3;

	// RF_WD
	assign RF_WD = MEMOut;

	// immed
	always @(*) begin
		if (((inst[6:0] == 7'b0010011) && (inst[14:12] != 3'b101) && (inst[14:12] != 3'b001)) || (inst[6:0] == 7'b0000011) || (inst[6:0] == 7'b1100111)) 
			immed = {{21{inst[31]}},inst[30:20]};
		else if (inst[6:0] == 7'b1100011) 
			immed = {{20{inst[31]}},inst[7],inst[30:25],inst[11:8],1'b0};
		else if (inst[6:0] == 7'b0100011) 
			immed = {{21{inst[31]}},inst[30:25],inst[11:8],inst[7]};
		else if (inst[6:0] == 7'b1101111) 
			immed = {{12{inst[31]}},inst[19:12],inst[20],inst[30:21],1'b0};
		else if ((inst[6:0] == 7'b0010011) && ((inst[14:12] == 3'b101) || (inst[14:12] == 3'b001))) 
			immed = {{28{inst[24]}},inst[23:20]};
		else 
			immed = {32{1'b0}};
	end

	// RF_WE
	assign RF_WE = RegWrite;

	// RegWrite pipleline register
	always @(posedge CLK) begin
		RegWrite2 <= RegWrite1;
	end

	always @(posedge CLK) begin
		RegWrite <= RegWrite2;
	end

	// RegWrite
	always @(posedge CLK) begin
		if ((inst[6:0] == 7'b1100011) || (inst[6:0] == 7'b0100011) || ((Branch == 1'b1) && (result[0] == 1'b1)) || (Stall == 1'b1)) RegWrite1 <= 1'b0;
		else RegWrite1 <= 1'b1;
	end

	// JALR 
	always @(*) begin
		if (inst[6:0] == 7'b1100111) JALR = 1'b1;
		else JALR = 1'b0;
	end

	// JALR pipleline register
	always @(posedge CLK) begin
		if (((Branch == 1'b1) && (result[0] == 1'b1)) || (Stall == 1'b1)) JALR1 <=1'b0;
		else JALR1 <= JALR;
	end

	// JAL 
	always @(*) begin
		if (inst[6:0] == 7'b1101111) JAL = 1'b1;
		else JAL = 1'b0;
	end

	// JAL pipleline register
	always @(posedge CLK) begin
		if (((Branch == 1'b1) && (result[0] == 1'b1)) || (Stall == 1'b1)) JAL1 <=1'b0;
		else JAL1 <= JAL;
	end

	// Branch pipleline register
	always @(posedge CLK) begin
		if ((inst[6:0] == 7'b1100011) && ((Branch == 1'b0) || (result[0] == 1'b0)) && (Stall == 1'b0)) Branch <= 1'b1;
		else Branch <= 1'b0;
	end

	// LW
	always @(posedge CLK) begin
		if ((inst[6:0] == 7'b0000011) && ((Branch == 1'b0) || (result[0] == 1'b0)) && (Stall == 1'b0)) LW <= 1'b1;
		else LW <= 1'b0;
	end

	// Finish
	always @(posedge CLK) begin
		if ((inst == 32'h00c00093) && ((Branch == 1'b0) || (result[0] == 1'b0)) && (Stall == 1'b0)) Finish <= 1'b1;
		else Finish <= 1'b0;
	end

	// NOP pipeline register
	always @(posedge CLK) begin
		if (((Branch == 1'b1) && (result[0] == 1'b1)) || (Stall == 1'b1)) NOP2 <= 1'b1;
		else NOP2 <= NOP1;
	end

	always @(posedge CLK) begin
		NOP3 <= NOP2;
	end

	always @(posedge CLK) begin
		NOP <= NOP3;
	end

	// Stall
	always @(*) begin
		if ((RegWrite1 == 1'b1) && (inst[19:15] == rd1) && (inst[19:15] != 5'b00000) && (inst[6:0] != 7'b1101111) && (LW == 1'b1)) Stall = 1'b1;
		else if ((RegWrite1 == 1'b1) && (inst[24:20] == rd1) && (inst[24:20] != 5'b00000) && ((inst[6:0] == 7'b0100011) || (inst[6:0] == 7'b0110011) || (inst[6:0] == 7'b1100011)) && (LW == 1'b1)) Stall = 1'b1;
		else Stall = 1'b0;
	end
//////////////////////////////////MUX//////////////////////////////////////

	// ASrc
	always @(*) begin
		if ((RegWrite1 == 1'b1) && (inst[19:15] == rd1) && (inst[19:15] != 5'b00000) && (inst[6:0] != 7'b1101111) && (JAL1 != 1'b1) && (JALR1 != 1'b1)) ASrc = 3'b001;
		else if ((RegWrite2 == 1'b1) && (inst[19:15] == rd2) && (inst[19:15] != 5'b00000) && (inst[6:0] != 7'b1101111)) ASrc = 3'b010;
		else if ((RegWrite == 1'b1) && (inst[19:15] == rd3) && (inst[19:15] != 5'b00000) && (inst[6:0] != 7'b1101111)) ASrc = 3'b011;
		else if((RegWrite1 == 1'b1) && (inst[19:15] == rd1) && (inst[19:15] != 5'b00000) && (inst[6:0] != 7'b1101111) && ((JAL1 == 1'b1) || (JALR1 == 1'b1))) ASrc = 3'b100;
		else ASrc = 3'b000;
	end

	// BSrc
	always @(*) begin
		if ((RegWrite1 == 1'b1) && (inst[24:20] == rd1) && (inst[24:20] != 5'b00000) && ((inst[6:0] == 7'b0110011) || (inst[6:0] == 7'b1100011)) && (JAL1 != 1'b1) && (JALR1 != 1'b1)) BSrc = 3'b010;
		else if ((RegWrite2 == 1'b1) && (inst[24:20] == rd2) && (inst[24:20] != 5'b00000) && ((inst[6:0] == 7'b0110011) || (inst[6:0] == 7'b1100011))) BSrc = 3'b011;
		else if ((RegWrite == 1'b1) && (inst[24:20] == rd3) && (inst[24:20] != 5'b00000) && ((inst[6:0] == 7'b0110011) || (inst[6:0] == 7'b1100011))) BSrc = 3'b100;
		else if ((RegWrite1 == 1'b1) && (inst[24:20] == rd1) && (inst[24:20] != 5'b00000) && ((inst[6:0] == 7'b0110011) || (inst[6:0] == 7'b1100011)) && ((JAL1 == 1'b1) || (JALR1 == 1'b1))) BSrc = 3'b101;
		else if ((inst[6:0] == 7'b0110011) || (inst[6:0] == 7'b1100011)) BSrc = 3'b000;
		else BSrc = 3'b001;	
	end

	// rtSrc
	always @(*) begin
		if ((RegWrite1 == 1'b1) && (inst[24:20] == rd1) && (inst[24:20] != 5'b00000)) rtSrc = 2'b01;
		else if ((RegWrite2 == 1'b1) && (inst[24:20] == rd2) && (inst[24:20] != 5'b00000)) rtSrc = 2'b10;
		else if ((RegWrite == 1'b1) && (inst[24:20] == rd3) && (inst[24:20] != 5'b00000)) rtSrc = 2'b11;
		else rtSrc = 2'b00;	
	end

	// A
	always @(posedge CLK) begin
		case (ASrc)
			3'b000: A <= RF_RD1;		
			3'b001: A <= result;
			3'b010: A <= preMEMOut;
			3'b011: A <= MEMOut;
			default: A <= Added_pc2;
		endcase
	end

	// B
	always @(posedge CLK) begin
		case (BSrc)
			3'b000: B <= RF_RD2;	
			3'b001: B <= immed;		
			3'b010: B <= result;
			3'b011: B <= preMEMOut;
			3'b100: B <= MEMOut;
			default: B <= Added_pc2;
		endcase
	end
	
	// rt pipeline register
	always @(posedge CLK) begin
		case (rtSrc)
			2'b00: rt1 <= RF_RD2;		
			2'b01: rt1 <= result;
			2'b10: rt1 <= preMEMOut;
			default: rt1 <= MEMOut;
		endcase
	end

	always @(posedge CLK) begin
		rt2 <= rt1;
	end

//////////////////////////////////ALU//////////////////////////////////////

	// ALUOP
	always @(posedge CLK) begin
		if ((inst[6:0] == 7'b1101111) || (inst[6:0] == 7'b0000011) || (inst[6:0] == 7'b0100011) || ((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b000) && (inst[30] == 1'b0)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b000)))              
			ALUOP <= 4'b0000;
		else if ((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b000)  && (inst[30] == 1'b1))
			ALUOP <= 4'b0001;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b111)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b111))) 
			ALUOP <= 4'b0010;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b110)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b110))) 
			ALUOP <= 4'b0011;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b100)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b100))) 
			ALUOP <= 4'b0100;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b010)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b010)) || ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b100))) 
			ALUOP <= 4'b0101;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b011)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b011)) || ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b110))) 
			ALUOP <= 4'b0110;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b1)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b1)))              
			ALUOP <= 4'b0111;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b0)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b0)))              
			ALUOP <= 4'b1000;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b001)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b001)))              
			ALUOP <= 4'b1001;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b000)) 
			ALUOP <= 4'b1010;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b001)) 
			ALUOP <= 4'b1011;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b101)) 
			ALUOP <= 4'b1100;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b111)) 
			ALUOP <= 4'b1101;
		else if (inst[6:0] == 7'b1100111)
			ALUOP <= 4'b1110;
		else 
			ALUOP <= 4'b1111;
	end

	// result
	always @(*) begin
		case (ALUOP)
			4'b0000 : result = A + B;
			4'b0001 : result = A - B;
			4'b0010 : result = A & B;
			4'b0011 : result = A | B;
			4'b0100 : result = A ^ B;
			4'b0101 : result = $signed(A) < $signed(B);
			4'b0110 : result = A < B;
			4'b0111 : result = A >>> B;
			4'b1000 : result = A >> B;
			4'b1001 : result = A << B;
			4'b1010 : result = A == B;
			4'b1011 : result = A != B;
			4'b1100 : result = $signed(A) >= $signed(B);
			4'b1101 : result = A >= B;
			4'b1110 : result = (A + B) & 32'hfffffffe;
			default : result = 0;
		endcase
	end
	
	// ALUOut
	always @(posedge CLK) begin
		ALUOut <= result;
	end

//////////////////////////////////D Memory//////////////////////////////////////

	// D_MEM_ADDR
	assign D_MEM_ADDR = ALUOut[11:0];

	assign D_MEM_DOUT = rt2;

	assign D_MEM_CSN = ~RSTn;

	assign D_MEM_WEN = ~MEMWrite;

	assign D_MEM_BE = 4'b1111;

	// MemWrite
	always @(posedge CLK) begin
		if ((inst[6:0] == 7'b0100011) && ((Branch == 1'b0) || (result[0] == 1'b0)) && (Stall == 1'b0)) MEMWrite1 <= 1'b1;
		else MEMWrite1 <= 1'b0;
	end

	// MemWrite pipeline register
	always @(posedge CLK) begin
		MEMWrite <= MEMWrite1;
	end

	// MEMOutSrc
	always @(posedge CLK)begin
		if ((inst[6:0] == 7'b1101111) || (inst[6:0] == 7'b1100111)) MEMOutSrc1 <= 2'b10;
		else if (inst[6:0] == 7'b0000011) MEMOutSrc1 <= 2'b01;
		else MEMOutSrc1 <= 2'b00;
	end 

	// MEMOutSrc pipeline register
	always @(posedge CLK) begin
		MEMOutSrc <= MEMOutSrc1;
	end

	// preMEMOut
	always @(*) begin
		case (MEMOutSrc)
			2'b00: preMEMOut = ALUOut;		
			2'b01: preMEMOut = D_MEM_DI;
			default: preMEMOut = Added_pc3;
		endcase
	end

	// MEMOut
	always @(posedge CLK) begin
		MEMOut <= preMEMOut;
	end

///////////////////////////////////////////////
	
	
	
	
	




endmodule //
