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

	// Only allow for NUM_INST
	always @ (negedge CLK) begin
		if (RSTn) NUM_INST <= NUM_INST + 1;
	end

	// TODO: implement

	reg [11:0] pc;
	reg [11:0] nxt_pc;
	wire [31:0] inst;
	reg [31:0] immed;
	reg JALR;
	reg JAL;
	reg Branch;
	reg [3:0] d_mem_be;
	reg d_mem_wen;
	reg [3:0] op;
	reg [2:0] reg_src;
	reg ALU_src;
	reg rf_we;
	reg [31:0] operand;
	reg [31:0] result;
	reg [31:0] load_value;
	reg [31:0] rf_wd; 

	assign I_MEM_CSN = ~RSTn;
	assign RF_RA1 = inst[19:15];
	assign RF_RA2 = inst[24:20];
	assign RF_WA1 = inst[11:7];
	assign inst = I_MEM_DI;
	assign RF_WE = rf_we;
	assign D_MEM_ADDR = result[11:0];
	assign D_MEM_DOUT = RF_RD2;
	assign D_MEM_CSN = ~RSTn;
	assign D_MEM_WEN = d_mem_wen;
	assign D_MEM_BE = d_mem_be;
	assign RF_WD = rf_wd;
	assign HALT = ((inst == 32'h00008067) && (RF_RD1 == 32'h0000000c))? 1'b1 : 1'b0;
	always @(*) begin
		I_MEM_ADDR = pc;
	end
	
	// Immediate Maker
	always @(*) begin
		if (((inst[6:0] == 7'b0010011) && (inst[14:12] != 3'b101) && (inst[14:12] != 3'b001)) || (inst[6:0] == 7'b0000011) || (inst[6:0] == 7'b1100111)) 
			immed = {{21{inst[31]}},inst[30:20]};
		else if (inst[6:0] == 7'b1100011) 
			immed = {{20{inst[31]}},inst[7],inst[30:25],inst[11:8],1'b0};
		else if (inst[6:0] == 7'b0100011) 
			immed = {{21{inst[31]}},inst[30:25],inst[11:8],inst[7]};
		else if ((inst[6:0] == 7'b0110111) || (inst[6:0] == 7'b0010111)) 
			immed = {inst[31:12],{12{1'b0}}};
		else if (inst[6:0] == 7'b1101111) 
			immed = {{12{inst[31]}},inst[19:12],inst[20],inst[30:21],1'b0};
		else if ((inst[6:0] == 7'b0010011) && ((inst[14:12] == 3'b101) || (inst[14:12] == 3'b001))) 
			immed = {{28{inst[24]}},inst[23:20]};
		else 
			immed = {32{1'b0}};
	end
		
	// PC
	always @(posedge CLK) begin
		if (RSTn == 1) pc <= nxt_pc;
		else pc <= 1'b0;
	end

	// JALR Control
	always @(*) begin
		if (inst[6:0] == 7'b1100111) JALR = 1'b1;
		else JALR = 1'b0;
	end

	// JAL Control
	always @(*) begin
		if (inst[6:0] == 7'b1101111) JAL = 1'b1;
		else JAL = 1'b0;
	end

	// Branch Control
	always @(*) begin
		if (inst[6:0] == 7'b1100011) Branch = 1'b1;
		else Branch = 1'b0;
	end

	// d_mem_be Control
	always @(*) begin
		if ((inst[6:0] == 7'b0100011) && (inst[14:12] == 3'b010)) d_mem_be = 4'b1111;
		else if ((inst[6:0] == 7'b0100011) && (inst[14:12] == 3'b001)) d_mem_be = 4'b0011;
		else if ((inst[6:0] == 7'b0100011) && (inst[14:12] == 3'b000)) d_mem_be = 4'b0001;
		else d_mem_be = 4'b0000;
	end
		

	// d_mem_wen Control
	always @(*) begin
		if (inst[6:0] == 7'b0100011) d_mem_wen = 1'b0;
		else d_mem_wen = 1'b1;
	end

	// op Control
	always @(*) begin
		if ((inst[6:0] == 7'b0000011) || (inst[6:0] == 7'b0100011) || ((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b000) && (inst[30] == 1'b0)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b000)))              
			op = 4'b0000;
		else if ((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b000)  && (inst[30] == 1'b1))
			op = 4'b0001;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b111)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b111))) 
			op = 4'b0010;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b110)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b110))) 
			op = 4'b0011;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b100)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b100))) 
			op = 4'b0100;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b010)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b010)) || ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b100))) 
			op = 4'b0101;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b011)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b011)) || ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b110))) 
			op = 4'b0110;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b1)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b1)))              
			op = 4'b0111;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b0)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b101) && (inst[30] == 1'b0)))              
			op = 4'b1000;
		else if (((inst[6:0] == 7'b0110011) && (inst[14:12] == 3'b001)) || ((inst[6:0] == 7'b0010011) && (inst[14:12] == 3'b001)))              
			op = 4'b1001;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b000)) 
			op = 4'b1010;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b001)) 
			op = 4'b1011;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b101)) 
			op = 4'b1100;
		else if ((inst[6:0] == 7'b1100011) && (inst[14:12] == 3'b111)) 
			op = 4'b1101;
		else
			op = 4'b1110;
	end

	// reg_src Control
	always @(*) begin
		if ((inst[6:0] == 7'b0110011) || (inst[6:0] == 7'b0010011)) reg_src = 3'b000;
		else if (inst[6:0] == 7'b0110111) reg_src = 3'b001;
		else if (inst[6:0] == 7'b0010111) reg_src = 3'b010;
		else if (inst[6:0] == 7'b1101111) reg_src = 3'b011;
		else if (inst[6:0] == 7'b0000011) reg_src = 3'b100;
		else  reg_src = 3'b101;
	end

	// ALU_src Control
	always @(*) begin
		if ((inst[6:0] == 7'b0110011) || (inst[6:0] == 7'b1100011)) ALU_src = 1'b1;
		else ALU_src = 1'b0;
	end

	// rf_we Control
	always @(*) begin
		if ((inst[6:0] == 7'b1100011) || (inst[6:0] == 7'b0100011)) rf_we = 1'b0;
		else rf_we = 1'b1;
	end

	// 2to1 Mux
	always @(*) begin
		if (ALU_src == 1'b1) operand = RF_RD2;
		else operand = immed;
	end
	
	// ALU
	always @(*) begin
		case (op)
			4'b0000 : result = RF_RD1 + operand;
			4'b0001 : result = RF_RD1 - operand;
			4'b0010 : result = RF_RD1 & operand;
			4'b0011 : result = RF_RD1 | operand;
			4'b0100 : result = RF_RD1 ^ operand;
			4'b0101 : result = $signed(RF_RD1) < $signed(operand);
			4'b0110 : result = RF_RD1 < operand;
			4'b0111 : result = RF_RD1 >>> operand;
			4'b1000 : result = RF_RD1 >> operand;
			4'b1001 : result = RF_RD1 << operand;
			4'b1010 : result = RF_RD1 == operand;
			4'b1011 : result = RF_RD1 != operand;
			4'b1100 : result = $signed(RF_RD1) >= $signed(operand);
			4'b1101 : result = RF_RD1 >= operand;
			default : result = 0;
		endcase
	end

	// nxt_pc Maker
	always @(*) begin
		if ((inst[6:0] == 7'b1101111) || ((inst[6:0] == 7'b1100011) && (result[0] == 1'b1))) nxt_pc = pc + immed[12:0];
		else if (inst[6:0] == 7'b1100111)  nxt_pc = (RF_RD1 + immed[12:0]) & 12'hffe;
		else nxt_pc = pc + 4;
	end

	// load_value Maker
	always @(*) begin
		case (inst[14:12])
			4'b000 : load_value = {{25{D_MEM_DI[7]}},D_MEM_DI[6:0]};
			4'b001 : load_value = {{17{D_MEM_DI[15]}},D_MEM_DI[14:0]};
			4'b010 : load_value = D_MEM_DI;
			4'b100 : load_value = {{24{1'b0}},D_MEM_DI[7:0]};
			4'b101 : load_value = {{16{1'b0}},D_MEM_DI[15:0]};
			default : load_value = D_MEM_DI;
		endcase
	end

	// 6to1 Mux
	always @(*) begin
		case (reg_src)
			4'b000 : rf_wd = result;
			4'b001 : rf_wd = immed;
			4'b010 : rf_wd = {{21{pc[11]}},pc[10:0]} + immed;
			4'b011 : rf_wd = {{21{pc[11]}},pc[10:0]} + 4;
			4'b100 : rf_wd = load_value;
			default : rf_wd = result;
		endcase
	end
	
	
		

endmodule //
