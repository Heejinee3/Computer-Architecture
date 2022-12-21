`timescale 1ns / 100ps

module ALU(A,B,OP,C,Cout);

	input [15:0]A;
	input [15:0]B;
	input [3:0]OP;
	output [15:0]C;
	output Cout;

	//TODO
	wire signed [15:0]A;
	wire signed [15:0]B;
	wire signed [3:0]OP;
	wire [15:0]Cadd = A+B;
	wire [15:0]Csub = A-B;
	reg signed [15:0]C;
	reg signed Cout;
	always @(*) begin
		case (OP)
			4'b0000 : {C,Cout} = {A + B, ((A[15] & B[15] & ~Cadd[15])|(~A[15] & ~B[15] & Cadd[15])) ? 1'b1 :1'b0};
			4'b0001 : {C,Cout} = {A - B, ((A[15] & ~B[15] & ~Csub[15])|(~A[15] & B[15] & Csub[15])) ? 1'b1 :1'b0};
			4'b0010 : {C,Cout} = {A & B,1'b0};
			4'b0011 : {C,Cout} = {A | B,1'b0};
			4'b0100 : {C,Cout} = {~(A & B),1'b0};
			4'b0101 : {C,Cout} = {~(A | B),1'b0};
			4'b0110 : {C,Cout} = {A ^ B,1'b0};
			4'b0111 : {C,Cout} = {A ~^ B,1'b0};|
			4'b1000 : {C,Cout} = {A,1'b0};
			4'b1001 : {C,Cout} = {~A,1'b0};
			4'b1010 : {C,Cout} = {A >> 1,1'b0};
			4'b1011 : {C,Cout} = {A >>> 1,1'b0};
			4'b1100 : {C,Cout} = {A[0],A[15:1],1'b0};
			4'b1101 : {C,Cout} = {A << 1,1'b0};
			4'b1110 : {C,Cout} = {A <<< 1,1'b0};
			4'b1111 : {C,Cout} = {A[14:0],A[15],1'b0};
			default : {C,Cout} = {A,1'b0};
		endcase
	end
	
endmodule
