`include "parameter.v"

module image_read
#(
	parameter	WIDTH			= 768			,
				HEIGHT			= 512			,
				INFILE			= "kodim23.hex"	,
				START_UP_DELAY	= 100			,
				HSYNC_DELAY		= 160			,
				VALUE			= 100			,
				THRESHOLD		= 90			,
				SIGN			= 0
)
(
	input				HCLK		,
	input				HRESETn		,
	output				VSYNC		,
	output				HSYNC		,
	output reg	[7:0]	DATA_R0		,
	output reg	[7:0]	DATA_G0		,
	output reg	[7:0]	DATA_B0		,
	output reg	[7:0]	DATA_R1		,
	output reg	[7:0]	DATA_G1		,
	output reg	[7:0]	DATA_B1		,
	output				ctrl_done
);

//	parameter length_size	= 1179648;	// image data: 1179648 bytes: 512*768*3
	parameter PIXEL_SIZE	= WIDTH*HEIGHT;
	parameter DATA_SIZE		= PIXEL_SIZE*3;

	reg	[7:0]	total_memory[0:DATA_SIZE-1];
	
	reg	start;
	reg rst_ff0;
	reg rst_ff1;

	integer temp_bmp[0:DATA_SIZE-1];
	integer temp_r	[0:PIXEL_SIZE-1];
	integer temp_g	[0:PIXEL_SIZE-1];
	integer temp_b	[0:PIXEL_SIZE-1];
	
	integer i, j;
	
	// state machine value
	reg	[2:0]	state_c, state_n;
	
	parameter S_IDLE	= 3'd0;
	parameter S_VSYNC	= 3'd1;
	parameter S_HSYNC	= 3'd2;
	parameter S_DATA	= 3'd3;
	
	wire	idle2vsync;
	wire	vsync2hsync;
	wire	hsync2data;
	wire	data2hsync;
	wire	data2idle;
	
	reg	[31:0]	cnt	;
	wire		add_cnt;
	wire		end_cnt;
	reg [31:0]	num_cnt;
	reg	[15:0]	cnt_col;
	wire		add_cnt_col;
	wire		end_cnt_col;
	reg	[15:0]	cnt_row;
	wire		add_cnt_row;
	wire		end_cnt_row;
	
	initial begin
		$readmemh(INFILE, total_memory, 0, DATA_SIZE-1);
	end

	always @(start) begin
		if(start) begin
			for(i=0;i<DATA_SIZE;i=i+1) begin
				temp_bmp[i] = total_memory[i][7:0];
			end
			for(i=0;i<HEIGHT;i=i+1) begin
				for(j=0;j<WIDTH;j=j+1) begin
					temp_r[WIDTH*i+j] = temp_bmp[(WIDTH*i+j)*3+0];
					temp_g[WIDTH*i+j] = temp_bmp[(WIDTH*i+j)*3+1];
					temp_b[WIDTH*i+j] = temp_bmp[(WIDTH*i+j)*3+2];
				end
			end
		end
	end
	
	always @(posedge HCLK) begin
		rst_ff0 <= HRESETn;
		rst_ff1 <= rst_ff0;
	end
	
	always @(posedge HCLK) begin
		start <= (rst_ff0 == 1) && (rst_ff1 == 0);
	end
	
	// state machine block
	always @(posedge HCLK or negedge HRESETn) begin
		if(!HRESETn)
			state_c <= 0;
		else
			state_c <= state_n;
	end
	
	always @* begin
		case(state_c)
			S_IDLE:	begin
				if(idle2vsync)
					state_n = S_VSYNC;
				else
					state_n = state_c;
			end
			S_VSYNC: begin
				if(vsync2hsync)
					state_n = S_HSYNC;
				else
					state_n = state_c;
			end
			S_HSYNC: begin
				if(hsync2data)
					state_n = S_DATA;
				else
					state_n = state_c;
			end
			S_DATA: begin
				if(data2idle)
					state_n = S_IDLE;
				else if(data2hsync)
					state_n = S_HSYNC;
				else
					state_n = state_c;
			end
			default:
				state_n = S_IDLE;
		endcase
	end
	
	assign idle2vsync 	= state_c == S_IDLE		&& start;
	assign vsync2hsync 	= state_c == S_VSYNC	&& end_cnt;
	assign hsync2data 	= state_c == S_HSYNC	&& end_cnt;
	assign data2hsync	= state_c == S_DATA		&& end_cnt_col;
	assign data2idle	= state_c == S_DATA		&& end_cnt_row;
	
	always @(posedge HCLK or negedge HRESETn) begin
		if(!HRESETn)
			cnt <= 0;
		else if(add_cnt) begin
			if(end_cnt)
				cnt <= 0;
			else
				cnt <= cnt + 1'd1;
		end
	end
	assign add_cnt = state_c != S_IDLE;
	assign end_cnt = add_cnt && cnt == num_cnt-1;
	
	always @* begin
		if(state_c == S_VSYNC)
			num_cnt = START_UP_DELAY;
		else if(state_c == S_HSYNC)
			num_cnt = HSYNC_DELAY;
		else if(state_c == S_DATA)
			num_cnt = WIDTH/2;
		else
			num_cnt = 0;
	end
	
	always @(posedge HCLK or negedge HRESETn) begin
		if(!HRESETn)
			cnt_col <= 0;
		else if(add_cnt_col) begin
			if(end_cnt_col)
				cnt_col <= 0;
			else
				cnt_col <= cnt_col + 2'd2;
		end
	end
	assign add_cnt_col = state_c == S_DATA;
	assign end_cnt_col = add_cnt && cnt_col == WIDTH-2;
	
	always @(posedge HCLK or negedge HRESETn) begin
		if(!HRESETn)
			cnt_row <= 0;
		else if(add_cnt_row) begin
			if(end_cnt_row)
				cnt_row <= 0;
			else
				cnt_row <= cnt_row + 1'd1;
		end
	end
	assign add_cnt_row = end_cnt_col;
	assign end_cnt_row = add_cnt_row && cnt_row == HEIGHT-1;
	
	always @* begin
		if(state_c == S_DATA) begin
			`ifdef BRIGHTNESS_OPERATION
				if(SIGN == 1) begin
					DATA_R0 = (temp_r[WIDTH*cnt_row+cnt_col]+VALUE>255) ? 255 : temp_r[WIDTH*cnt_row+cnt_col]+VALUE;
					DATA_R1 = (temp_r[WIDTH*cnt_row+cnt_col+1]+VALUE>255) ? 255 : temp_r[WIDTH*cnt_row+cnt_col+1]+VALUE;
					DATA_G0 = (temp_g[WIDTH*cnt_row+cnt_col]+VALUE>255) ? 255 : temp_g[WIDTH*cnt_row+cnt_col]+VALUE;
					DATA_G1 = (temp_g[WIDTH*cnt_row+cnt_col+1]+VALUE>255) ? 255 : temp_g[WIDTH*cnt_row+cnt_col+1]+VALUE;
					DATA_B0 = (temp_b[WIDTH*cnt_row+cnt_col]+VALUE>255) ? 255 : temp_b[WIDTH*cnt_row+cnt_col]+VALUE;
					DATA_B1 = (temp_b[WIDTH*cnt_row+cnt_col+1]+VALUE>255) ? 255 : temp_b[WIDTH*cnt_row+cnt_col+1]+VALUE;
				end
				else begin
					DATA_R0 = (temp_r[WIDTH*cnt_row+cnt_col]-VALUE<0) ? 0 : temp_r[WIDTH*cnt_row+cnt_col]-VALUE;
					DATA_R1 = (temp_r[WIDTH*cnt_row+cnt_col+1]-VALUE<0) ? 0 : temp_r[WIDTH*cnt_row+cnt_col+1]-VALUE;
					DATA_G0 = (temp_g[WIDTH*cnt_row+cnt_col]-VALUE<0) ? 0 : temp_g[WIDTH*cnt_row+cnt_col]-VALUE;
					DATA_G1 = (temp_g[WIDTH*cnt_row+cnt_col+1]-VALUE<0) ? 0 : temp_g[WIDTH*cnt_row+cnt_col+1]-VALUE;
					DATA_B0 = (temp_b[WIDTH*cnt_row+cnt_col]-VALUE<0) ? 0 : temp_b[WIDTH*cnt_row+cnt_col]-VALUE;
					DATA_B1 = (temp_b[WIDTH*cnt_row+cnt_col+1]-VALUE<0) ? 0 : temp_b[WIDTH*cnt_row+cnt_col+1]-VALUE;				
				end
			`else
				`ifdef INVERT_OPERATION
					DATA_R0 = 255-((temp_r[WIDTH*cnt_row+cnt_col]+temp_g[WIDTH*cnt_row+cnt_col]+temp_b[WIDTH*cnt_row+cnt_col])/3);
					DATA_G0 = 255-((temp_r[WIDTH*cnt_row+cnt_col]+temp_g[WIDTH*cnt_row+cnt_col]+temp_b[WIDTH*cnt_row+cnt_col])/3);
					DATA_B0 = 255-((temp_r[WIDTH*cnt_row+cnt_col]+temp_g[WIDTH*cnt_row+cnt_col]+temp_b[WIDTH*cnt_row+cnt_col])/3);
					DATA_R1 = 255-((temp_r[WIDTH*cnt_row+cnt_col+1]+temp_g[WIDTH*cnt_row+cnt_col+1]+temp_b[WIDTH*cnt_row+cnt_col]+1)/3);
					DATA_G1 = 255-((temp_r[WIDTH*cnt_row+cnt_col+1]+temp_g[WIDTH*cnt_row+cnt_col+1]+temp_b[WIDTH*cnt_row+cnt_col]+1)/3);
					DATA_B1 = 255-((temp_r[WIDTH*cnt_row+cnt_col+1]+temp_g[WIDTH*cnt_row+cnt_col+1]+temp_b[WIDTH*cnt_row+cnt_col]+1)/3);
				`else
					`ifdef THRESHOLD_OPERATION
						DATA_R0 = ((temp_r[WIDTH*cnt_row+cnt_col]+temp_g[WIDTH*cnt_row+cnt_col]+temp_b[WIDTH*cnt_row+cnt_col])/3>THRESHOLD) ? 255 : 0;
						DATA_G0 = ((temp_r[WIDTH*cnt_row+cnt_col]+temp_g[WIDTH*cnt_row+cnt_col]+temp_b[WIDTH*cnt_row+cnt_col])/3>THRESHOLD) ? 255 : 0;
						DATA_B0 = ((temp_r[WIDTH*cnt_row+cnt_col]+temp_g[WIDTH*cnt_row+cnt_col]+temp_b[WIDTH*cnt_row+cnt_col])/3>THRESHOLD) ? 255 : 0;
						DATA_R1 = ((temp_r[WIDTH*cnt_row+cnt_col+1]+temp_g[WIDTH*cnt_row+cnt_col+1]+temp_b[WIDTH*cnt_row+cnt_col+1])/3>THRESHOLD) ? 255 : 0;
						DATA_G1 = ((temp_r[WIDTH*cnt_row+cnt_col+1]+temp_g[WIDTH*cnt_row+cnt_col+1]+temp_b[WIDTH*cnt_row+cnt_col+1])/3>THRESHOLD) ? 255 : 0;
						DATA_B1 = ((temp_r[WIDTH*cnt_row+cnt_col+1]+temp_g[WIDTH*cnt_row+cnt_col+1]+temp_b[WIDTH*cnt_row+cnt_col+1])/3>THRESHOLD) ? 255 : 0;
					`else
						DATA_R0 = temp_r[WIDTH*cnt_row+cnt_col];
						DATA_R1 = temp_r[WIDTH*cnt_row+cnt_col+1];
						DATA_G0 = temp_g[WIDTH*cnt_row+cnt_col];
						DATA_G1 = temp_g[WIDTH*cnt_row+cnt_col+1];
						DATA_B0 = temp_b[WIDTH*cnt_row+cnt_col];
						DATA_B1 = temp_b[WIDTH*cnt_row+cnt_col+1];
					`endif
				`endif
			`endif
		end
		else begin
			DATA_R0 = 0;
			DATA_R1 = 0;
			DATA_G0 = 0;
			DATA_G1 = 0;
			DATA_B0 = 0;
			DATA_B1 = 0;
		end	
	end
	
	assign ctrl_done = data2idle;
	
	assign VSYNC = state_c == S_VSYNC;
	assign HSYNC = state_c == S_DATA;
	
endmodule