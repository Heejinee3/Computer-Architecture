`include "vending_machine_def.v"

module vending_machine (

	clk,							// Clock signal
	reset_n,						// Reset signal (active-low)

	i_input_coin,				// coin is inserted.
	i_select_item,				// item is selected.
	i_trigger_return,			// change-return is triggered

	o_available_item,			// Sign of the item availability
	o_output_item,			// Sign of the item withdrawal
	o_return_coin,				// Sign of the coin return
	stopwatch,
	current_total,
	return_temp,
);

	// Ports Declaration
	// Do not modify the module interface
	input clk;
	input reset_n;

	input [`kNumCoins-1:0] i_input_coin;
	input [`kNumItems-1:0] i_select_item;
	input i_trigger_return;

	output reg [`kNumItems-1:0] o_available_item;
	output reg [`kNumItems-1:0] o_output_item;
	output reg [`kNumCoins-1:0] o_return_coin;

	output [3:0] stopwatch;
	output [`kTotalBits-1:0] current_total;
	output [`kTotalBits-1:0] return_temp;
	// Normally, every output is register,
	//   so that it can provide stable value to the outside.

//////////////////////////////////////////////////////////////////////	/

	//we have to return many coins
	reg [`kCoinBits-1:0] returning_coin_0;
	reg [`kCoinBits-1:0] returning_coin_1;
	reg [`kCoinBits-1:0] returning_coin_2;
	reg block_item_0;
	reg block_item_1;
	//check timeout
	reg [3:0] stopwatch;
	//when return triggered
	reg have_to_return;
	reg  [`kTotalBits-1:0] return_temp;
	reg [`kTotalBits-1:0] temp;
////////////////////////////////////////////////////////////////////////

	// Net constant values (prefix kk & CamelCase)
	// Please refer the wikepedia webpate to know the CamelCase practive of writing.
	// http://en.wikipedia.org/wiki/CamelCase
	// Do not modify the values.
	wire [31:0] kkItemPrice [`kNumItems-1:0];	// Price of each item
	wire [31:0] kkCoinValue [`kNumCoins-1:0];	// Value of each coin
	assign kkItemPrice[0] = 400;
	assign kkItemPrice[1] = 500;
	assign kkItemPrice[2] = 1000;
	assign kkItemPrice[3] = 2000;
	assign kkCoinValue[0] = 100;
	assign kkCoinValue[1] = 500;
	assign kkCoinValue[2] = 1000;


	// NOTE: integer will never be used other than special usages.
	// Only used for loop iteration.
	// You may add more integer variables for loop iteration.
	integer i, j, k,l,m,n;

	// Internal states. You may add your own net & reg variables.
	reg [`kTotalBits-1:0] current_total;
	reg [`kItemBits-1:0] num_items [`kNumItems-1:0];
	reg [`kCoinBits-1:0] num_coins [`kNumCoins-1:0];

	// Next internal states. You may add your own net and reg variables.
	reg [`kTotalBits-1:0] current_total_nxt;
	reg [`kItemBits-1:0] num_items_nxt [`kNumItems-1:0];
	reg [`kCoinBits-1:0] num_coins_nxt [`kNumCoins-1:0];

	// Variables. You may add more your own registers.
	reg [`kTotalBits-1:0] input_total, output_total, return_total_0,return_total_1,return_total_2;


	// Combinational logic for the next states
	always @(i_input_coin or o_output_item) begin
		// TODO: current_total_nxt
		// You don't have to worry about concurrent activations in each input vector (or array).

		if (i_input_coin[0]==1) begin
		current_total_nxt=current_total+100;
		num_coins_nxt[0]=num_coins[0]+1;
		end
		else if (i_input_coin[1]==1) begin
		current_total_nxt=current_total+500;
		num_coins_nxt[1]=num_coins[1]+1;
		end
		else if (i_input_coin[2]==1) begin
		current_total_nxt=current_total+1000;
		num_coins_nxt[2]=num_coins[2]+1;
		end
	

		
		if (o_output_item[0]==1) begin
		current_total_nxt=current_total-400;
		num_items_nxt[0]=num_items[0]-1;
		end
		else if (o_output_item[1]==1) begin
		current_total_nxt=current_total-500;
		num_items_nxt[1]=num_items[1]-1;
		end
		else if (o_output_item[2]==1) begin
		current_total_nxt=current_total-1000;
		num_items_nxt[2]=num_items[2]-1;
		end
		else if (o_output_item[3]==1) begin
		current_total_nxt=current_total-2000;
		num_items_nxt[3]=num_items[3]-1;
		end
		// Calculate the next current_total state. current_total_nxt =

	
	end


	// Combinational logic for the outputs
	always @(*) begin
	// TODO: o_available_item
		if (current_total>=2000) begin
			o_available_item={4'b1111};
		end
		else if (current_total>=1000) begin
			o_available_item={4'b0111};
		end
		else if (current_total>=500) begin
			o_available_item={4'b0011};
		end
		else if (current_total>=400) begin
			o_available_item={4'b0001};
		end		
		else begin
			o_available_item={4'b0000};
		end
		
		if (num_items[0]==0) begin
			o_available_item=o_available_item&4'b1110;
		end
		if (num_items[1]==0) begin
			o_available_item=o_available_item&4'b1101;
		end
		if (num_items[2]==0) begin
			o_available_item=o_available_item&4'b1011;
		end
		if (num_items[3]==0) begin
			o_available_item=o_available_item&4'b0111;
		end


	// TODO: o_output_item

		if (current_total>=400 && i_select_item[0]==1) begin
			o_output_item={4'b0001};
		end
		else if (current_total>=500 && i_select_item[1]==1) begin
			o_output_item={4'b0010};
		end
		else if (current_total>=1000 && i_select_item[2]==1) begin
			o_output_item={4'b0100};
		end
		else if (current_total>=2000 && i_select_item[3]==1) begin
			o_output_item={4'b1000};
		end	
		else begin
			o_output_item={4'b0000};
		end
	end

	// Sequential circuit to reset or update the states
	always @(posedge clk) begin
		if (!reset_n) begin
			// TODO: reset all states.
			current_total_nxt={32{1'b0}};
			for (k=0;k<3;k=k+1) begin
			num_coins_nxt[k]=5;
			end
			for (l=0;l<4;l=l+1) begin
			num_items_nxt[l]=10;
			end
			stopwatch=4'b0111;

		end
		else begin
			// TODO: update all states.
			current_total=current_total_nxt;
			begin
				for (i=0;i<4;i=i+1)
					num_items[i]=num_items_nxt[i];
			end
			begin
				for (j=0;j<3;j=j+1)
					num_coins[j]=num_coins_nxt[j];
			end
			
/////////////////////////////////////////////////////////////////////////

			// decrease stopwatch

			if (i_input_coin || i_select_item) begin
			stopwatch=4'b0111;
			end
			else if (i_trigger_return) begin
			stopwatch={4{1'b0}};
			end
			else begin
			stopwatch=stopwatch-1;
			end

			//if you have to return some coins then you have to turn on the bit
			
			if (stopwatch[3]==1||stopwatch==0) begin
				if (current_total>=1000) begin
					o_return_coin=3'b100;
					num_coins_nxt[2]=num_coins[2]-1;
					current_total_nxt=current_total-1000;
				end
				else if (current_total>=500) begin
					o_return_coin=3'b010;
					num_coins_nxt[1]=num_coins[1]-1;
					current_total_nxt=current_total-500;
				end
				else if (current_total>=100) begin
					o_return_coin=3'b001;
					num_coins_nxt[0]=num_coins[0]-1;
					current_total_nxt=current_total-100;
				end
				else begin
					stopwatch=4'b0111;
					o_return_coin=3'b000;
				end
			end

/////////////////////////////////////////////////////////////////////////
		end		   //update all state end
	end	   //always end

endmodule
