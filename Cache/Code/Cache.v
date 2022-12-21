module CACHE(
	input wire CLK,
	output wire D_MEM_CSN,
	input wire [31:0] D_MEM_DI,
	output wire [31:0] D_MEM_DOUT,
	output wire [11:0] D_MEM_ADDR,
	output wire D_MEM_WEN,
	output wire [3:0] D_MEM_BE,

	input wire CACHE_CSN,
	output wire [31:0] CACHE_DI,
	input wire [31:0] CACHE_DOUT,
	input wire [11:0] CACHE_ADDR,
	input wire CACHE_WEN,
	output wire CACHE_MISS,
	output wire [31:0] hitnum,
	output wire [31:0] missnum
);

	reg		[31:0]		cacheword1[0:7];
	reg		[31:0]		cacheword2[0:7];
	reg		[31:0]		cacheword3[0:7];
	reg		[31:0]		cacheword4[0:7];
	reg		[6:0]		tag[0:7];
	reg				valid[0:7];
	wire		[2:0] 		index; 
	reg				MEMREAD;
	reg				MEMWRITE;
	reg		[11:0]		MEMADDR;
	reg		[2:0]		cycle;
	reg		[31:0]		data;
	reg		[31:0] 		HITNUM;
	reg		[31:0] 		MISSNUM;

	// MEM input and output
	assign D_MEM_BE = 4'b1111;
	assign D_MEM_CSN = CACHE_CSN || ((~MEMREAD)&& (~MEMWRITE));
	assign D_MEM_WEN = ~MEMWRITE;
	assign D_MEM_DOUT = CACHE_DOUT;
	assign D_MEM_ADDR = MEMADDR;

	// cache input and output
	assign CACHE_MISS = (~CACHE_CSN) && ((valid[index] == 1'b0) || (tag[index] != CACHE_ADDR[11:5]));
	assign CACHE_DI = data;

	// hit and miss number
	assign hitnum = HITNUM;
	assign missnum = MISSNUM;

	// valuable
	assign index = CACHE_ADDR[4:2];

	always @ (posedge CLK) begin
		if ((CACHE_CSN == 1'b0) && (CACHE_MISS == 1'b1)) cycle <= cycle + 1;
		else cycle <= 3'b0;
	end

	always @ (*) begin
		if (((cycle == 3'b100) && (CACHE_WEN == 1'b0)) || ((cycle == 3'b000) && (CACHE_MISS == 1'b0) && (CACHE_WEN == 1'b0))) MEMREAD <= 1'b0;
		else MEMREAD <= 1'b1;
	end

	always @ (*) begin
		if (((cycle == 3'b100) && (CACHE_WEN == 1'b0)) || ((cycle == 3'b000) && (CACHE_MISS == 1'b0) && (CACHE_WEN == 1'b0))) MEMWRITE <= 1'b1;
		else MEMWRITE <= 1'b0;
	end

	always @ (*) begin
		if ((cycle == 3'b000) && (CACHE_MISS == 1'b1)) MEMADDR <= {CACHE_ADDR[11:2],2'b00};
		else if ((cycle == 3'b001) && (CACHE_MISS == 1'b1)) MEMADDR <= {CACHE_ADDR[11:2],2'b01};
		else if ((cycle == 3'b010) && (CACHE_MISS == 1'b1)) MEMADDR <= {CACHE_ADDR[11:2],2'b10};
		else if ((cycle == 3'b011) && (CACHE_MISS == 1'b1)) MEMADDR <= {CACHE_ADDR[11:2],2'b11};
		else MEMADDR <= CACHE_ADDR;
	end

	// initial
	initial begin
		valid[0] <= 1'b0;
		valid[1] <= 1'b0;
		valid[2] <= 1'b0;
		valid[3] <= 1'b0;
		valid[4] <= 1'b0;
		valid[5] <= 1'b0;
		valid[6] <= 1'b0;
		valid[7] <= 1'b0;
		HITNUM <= 32'b0;
		MISSNUM <= 32'b0;
	end

	// hit and miss
	always @ (negedge CLK) begin
		if ((~CACHE_CSN) && (cycle == 3'b0) && (CACHE_MISS == 1'b1)) MISSNUM = MISSNUM + 1;
		if ((~CACHE_CSN) && (cycle == 3'b0) && (CACHE_MISS == 1'b0)) HITNUM = HITNUM + 1;
	end

	always @ (negedge CLK) begin
		// Synchronous write
		if ((~CACHE_CSN) && ((CACHE_WEN == 1'b0) || (CACHE_MISS == 1'b1))) begin
			if ((cycle == 3'b100) || ((cycle == 3'b000) && (CACHE_MISS == 1'b0) && (CACHE_WEN == 1'b0))) begin
				case (MEMADDR[1:0])
					2'b00: cacheword1[index] <= CACHE_DOUT;
					2'b01: cacheword2[index] <= CACHE_DOUT;
					2'b10: cacheword3[index] <= CACHE_DOUT;
					default: cacheword4[index] <= CACHE_DOUT;
				endcase
			end
			else begin
				case (MEMADDR[1:0])
					2'b00: cacheword1[index] <= D_MEM_DI;
					2'b01: cacheword2[index] <= D_MEM_DI;
					2'b10: cacheword3[index] <= D_MEM_DI;
					default: cacheword4[index] <= D_MEM_DI;
				endcase
			end
		end
	end

	always @ (posedge CLK) begin
		// tag and valid
		if ((~CACHE_CSN) && (((CACHE_WEN == 1'b0) && (cycle == 3'b011)) || ((CACHE_WEN == 1'b1) && (cycle == 3'b011)))) begin
			valid[index] <= 1'b1;
			tag[index] <= CACHE_ADDR[11:5];
		end
	end

	always @ (*) begin
		// Asynchronous read
		if ((~CACHE_CSN) && (CACHE_WEN == 1'b1) && (CACHE_MISS == 1'b0)) begin
			case (MEMADDR[1:0])
				2'b00: data <= cacheword1[index]; 
				2'b01: data <= cacheword2[index]; 
				2'b10: data <= cacheword3[index]; 
				default: data <= cacheword4[index]; 
			endcase
		end
	end
endmodule
