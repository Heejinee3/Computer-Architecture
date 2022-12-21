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
	output wire HALT,
	output reg [31:0] NUM_INST,
	output wire [31:0] OUTPUT_PORT
	);

	// TODO: implement multi-cycle CPU

	reg [11:0] pc;
	reg [11:0] nxt_pc;
	reg PCWrite;
	reg PCWriteCond;
	reg [31:0] result;
	reg [2:0] state;
	reg [2:0] nxt_state;
	reg [31:0] inst;	
	reg I_MemRead;
	reg [31:0] immed;
	reg RegWrite;
	reg [31:0] A;
	reg [31:0] B;
	reg ALUSrcA;
	reg [1:0] ALUSrcB;
	reg [31:0] ALUA;
	reg [31:0] ALUB;
	reg [3:0] ALUOP;
	reg [31:0] ALUOut;
	reg PCSrc;
	reg D_MemRead;
	reg D_MemWrite;
	reg [31:0] MDR;
	reg [1:0] MemtoReg;

	always @(*) I_MEM_ADDR = pc;
	assign I_MEM_CSN = (~RSTn) || (~I_MemRead);
	always @(*) inst = I_MEM_DI;
	assign RF_RA1 = inst[19:15];
	assign RF_RA2 = inst[24:20];
	assign RF_WA1 = inst[11:7];
	assign RF_WE = RegWrite;
	assign D_MEM_ADDR = ALUOut[11:0];
	assign D_MEM_DOUT = B;
	assign D_MEM_CSN = (~RSTn) || ((~D_MemRead) && (~D_MemWrite));
	assign D_MEM_WEN = ~D_MemWrite;
	assign D_MEM_BE = 4'b1111;
	always @(*) MDR = D_MEM_DI;

	always @(posedge CLK) begin
		A <= RF_RD1;
		B <= RF_RD2;
		ALUOut <= result;
	end


	assign OUTPUT_PORT = (inst[6:0] == 7'b1100011)? result : ((inst[6:0] == 7'b0100011)? ALUOut : RF_WD);
	assign HALT = ((inst == 32'h00008067) && (RF_RD1 == 32'h0000000c))? 1'b1 : 1'b0;
	initial begin
		NUM_INST <= 0;
	end
	always @ (negedge CLK) begin
		if ((RSTn) && ((((inst[6:0] == 7'b0000011) || (inst[6:0] == 7'b0110011) ||  (inst[6:0] == 7'b0010011) || (inst[6:0] == 7'b1101111) || (inst[6:0] == 7'b1100111)) && (state == 3'b100)) || ((inst[6:0] == 7'b0100011) && (state == 3'b011)) || ((inst[6:0] == 7'b1100011) && (state == 3'b010)))) NUM_INST <= NUM_INST + 1;
	end
	
	// PC
	always @(posedge CLK) begin
		if ((PCWrite == 1) || ((result[0] == 1) && (PCWriteCond == 1))) pc <= nxt_pc; 
		else pc <= pc;
	end

	// STATE
	always @(posedge CLK) state <= nxt_state;

	// NEXT STATE
	always @(*) begin
		if ((RSTn == 0) || ((inst[6:0] == 7'b1100011) && (state == 3'b010)) || ((inst[6:0] == 7'b0100011) && (state == 3'b011)) || (state == 3'b100)) nxt_state = 3'b000;
		else if ((state == 3'b010) && ((inst[6:0] == 7'b1100111) || (inst[6:0] == 7'b1101111) || (inst[6:0] == 7'b0010011) || (inst[6:0] == 7'b0110011))) nxt_state = 3'b100;
		else nxt_state = state+1;
	end

	// PC WRITE CONDITION
	always @(*) begin
		if ((state == 3'b010) && (inst[6:0] == 7'b1100011)) PCWriteCond = 1'b1;
		else PCWriteCond = 1'b0;
	end

	// PC WRITE
	always @(*) begin
		if ((state == 3'b000) || ((state == 3'b010) && (inst[6:0] == 7'b1101111)) || ((state == 3'b100) && (inst[6:0] == 7'b1100111))) PCWrite = 1'b1;
		else PCWrite = 1'b0;
	end

	// I MEM READ
	always @(*) begin
		if (state == 3'b000) I_MemRead = 1'b1;
		else I_MemRead = 1'b0;
	end
	
	// IMMEDIATE
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

	// REG WRITE
	always @(*) begin
		if (state == 3'b100) RegWrite = 1'b1;
		else RegWrite = 1'b0;
	end

	// ALU A
	always @(*) begin
		case (ALUSrcA)
			1'b0: ALUA = {{21{pc[11]}},pc[10:0]};
			default: ALUA = A;
		endcase
	end

	// ALU B
	always @(*) begin
		case (ALUSrcB)
			2'b00: ALUB = B;
			2'b01: ALUB = 4;
			2'b11: ALUB = 0;
			default: ALUB = immed;
		endcase
	end

	// ALU SOURCE A
	always @(*) begin
		if ((state == 3'b000) || (state == 3'b001) || ((state == 3'b010) && (inst[6:0] == 7'b1101111))) ALUSrcA = 1'b0;
		else ALUSrcA = 1'b1;
	end

	// ALU SOURCE B
	always @(*) begin
		if (state == 3'b000) ALUSrcB = 2'b01;
		else if ((state == 3'b010) && ((inst[6:0] == 7'b0110011) || (inst[6:0] == 7'b1100011))) ALUSrcB = 2'b00;
 		else if ((state == 3'b010) && (inst[6:0] == 7'b1101111)) ALUSrcB = 2'b11;
		else ALUSrcB = 2'b10;
	end

	//ALU
	always @(*) begin
		case (ALUOP)
			4'b0000 : result = ALUA + ALUB;
			4'b0001 : result = ALUA - ALUB;
			4'b0010 : result = ALUA & ALUB;
			4'b0011 : result = ALUA | ALUB;
			4'b0100 : result = ALUA ^ ALUB;
			4'b0101 : result = $signed(ALUA) < $signed(ALUB);
			4'b0110 : result = ALUA < ALUB;
			4'b0111 : result = ALUA >>> ALUB;
			4'b1000 : result = ALUA >> ALUB;
			4'b1001 : result = ALUA << ALUB;
			4'b1010 : result = ALUA == ALUB;
			4'b1011 : result = ALUA != ALUB;
			4'b1100 : result = $signed(ALUA) >= $signed(ALUB);
			4'b1101 : result = ALUA >= ALUB;
			4'b1110 : result = ALUA + ALUB -4;
			4'b1111 : result = (ALUA + ALUB) & 32'hfffffffe;
			default : result = 0;
		endcase
	end

	// ALUOP
	always @(*) begin
		if (state == 3'b001)
			ALUOP = 4'b1110;
		else if ((state == 3'b010) && (inst[6:0] == 7'b1100111))
			ALUOP = 4'b1111;
		else if ((state != 3'b010) || (inst[6:0] == 7'b1101111) || (inst[6:0] == 7'b0000011) || (inst[6:0] == 7'b0100011))
			ALUOP = 4'b0000;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b000) && (inst[30] == 1'b0)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b000)))              
			ALUOP = 4'b0000;
		else if ((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b000)  && (inst[30] == 1'b1))
			ALUOP = 4'b0001;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b111)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b111))) 
			ALUOP = 4'b0010;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b110)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b110))) 
			ALUOP = 4'b0011;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b100)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b100))) 
			ALUOP = 4'b0100;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b010)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b010)) || ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b100))) 
			ALUOP = 4'b0101;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b011)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b011)) || ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b110))) 
			ALUOP = 4'b0110;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b1)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b1)))              
			ALUOP = 4'b0111;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b0)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b0)))              
			ALUOP = 4'b1000;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b001)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b001)))              
			ALUOP = 4'b1001;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b000)) 
			ALUOP = 4'b1010;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b001)) 
			ALUOP = 4'b1011;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b101)) 
			ALUOP = 4'b1100;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b111)) 
			ALUOP = 4'b1101;
	end

	// PC SOURCE
	always @(*) begin
		if (state == 3'b000) PCSrc = 1'b0;
		else PCSrc = 1'b1;
	end

	// NEXT PC
	always @(*) begin
		if (RSTn == 1'b0) nxt_pc = 0;
		else if (PCSrc == 1'b0) nxt_pc = result[11:0];
		else nxt_pc = ALUOut[11:0];
	end

	// D MEM READ
	always @(*) begin
		if ((state == 3'b011) && (inst[6:0] == 7'b0000011)) D_MemRead = 1'b1;
		else D_MemRead = 1'b0;
	end

	// D MEM WRITE
	always @(*) begin
		if ((state == 3'b011) && (inst[6:0] == 7'b0100011)) D_MemWrite = 1'b1;
		else D_MemWrite = 1'b0;
	end

	// RF_WD
	assign RF_WD = (MemtoReg == 2'b00)? ALUOut : ((MemtoReg == 2'b01)? MDR : pc );
	
	// MEM TO REG
	always @(*) begin
		if ((state == 3'b100) && (inst[6:0] == 7'b0000011)) MemtoReg = 2'b01;
		else if ((state == 3'b100) && (inst[6:0] == 7'b1100111)) MemtoReg = 2'b10;
		else MemtoReg = 2'b00;
	end



endmodule //
