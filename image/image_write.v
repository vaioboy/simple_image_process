module image_write
#(
	parameter	WIDTH		= 768,
				HEIGHT		= 512,
				INFILE		= "output.bmp",
				BMP_HEADER_NUM	= 54
)
(
	input			HCLK			,
	input			HRESETn			,
	input			hsync			,
	input	[7:0]	DATA_WRITE_R0	,
	input	[7:0]	DATA_WRITE_G0	,
	input	[7:0]	DATA_WRITE_B0	,
	input	[7:0]	DATA_WRITE_R1	,
	input	[7:0]	DATA_WRITE_G1	,
	input	[7:0]	DATA_WRITE_B1	,
	output	reg		Write_Done
);

	parameter PIXEL_SIZE	= WIDTH*HEIGHT;
	parameter DATA_SIZE		= PIXEL_SIZE*3;

	integer bmp_header[0:BMP_HEADER_NUM-1];
	integer i, k;
	integer fd;
	
	reg	[7:0]	out_bmp[0:DATA_SIZE-1];
	
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
	
	// Windows BMP files begin with a 54-byte header: 
	// Check the website to see the value of this header: http://www.fastgraph.com/help/bmp_header_format.html
	initial begin
		bmp_header[ 0] = 66;
		bmp_header[ 1] = 77;
		bmp_header[ 2] = 54;
		bmp_header[ 3] =  0;
		bmp_header[ 4] = 18;
		bmp_header[ 5] =  0;
		bmp_header[ 6] =  0;
		bmp_header[ 7] =  0;
		bmp_header[ 8] =  0;
		bmp_header[ 9] =  0;
		bmp_header[10] = 54;
		bmp_header[11] =  0;
		bmp_header[12] =  0;
		bmp_header[13] =  0;
		bmp_header[14] = 40;
		bmp_header[15] =  0;
		bmp_header[16] =  0;
		bmp_header[17] =  0;
		bmp_header[18] =  0;
		bmp_header[19] =  3;
		bmp_header[20] =  0;
		bmp_header[21] =  0;
		bmp_header[22] =  0;
		bmp_header[23] =  2;	
		bmp_header[24] =  0;
		bmp_header[25] =  0;
		bmp_header[26] =  1;
		bmp_header[27] =  0;
		bmp_header[28] = 24;
		bmp_header[29] = 0;
		bmp_header[30] = 0;
		bmp_header[31] = 0;
		bmp_header[32] = 0;
		bmp_header[33] = 0;
		bmp_header[34] = 0;
		bmp_header[35] = 0;
		bmp_header[36] = 0;
		bmp_header[37] = 0;
		bmp_header[38] = 0;
		bmp_header[39] = 0;
		bmp_header[40] = 0;
		bmp_header[41] = 0;
		bmp_header[42] = 0;
		bmp_header[43] = 0;
		bmp_header[44] = 0;
		bmp_header[45] = 0;
		bmp_header[46] = 0;
		bmp_header[47] = 0;
		bmp_header[48] = 0;
		bmp_header[49] = 0;
		bmp_header[50] = 0;
		bmp_header[51] = 0;
		bmp_header[52] = 0;
		bmp_header[53] = 0;
	end	
	
	always @(posedge HCLK or negedge HRESETn) begin
		if(!HRESETn)
			cnt_col <= 0;
		else if(add_cnt_col) begin
			if(end_cnt_col)
				cnt_col <= 0;
			else
				cnt_col <= cnt_col + 1'd1;
		end
	end
	assign add_cnt_col = hsync;
	assign end_cnt_col = add_cnt_col && cnt_col == WIDTH/2 - 1;
	
	always @(posedge HCLK or negedge HRESETn) begin
		if(!HRESETn)
			cnt_row <= 0;
		else if(add_cnt_row) begin
			if(end_cnt_row)
				cnt_row <= 0;
			else
				cnt_row	<= cnt_row + 1'd1;
		end
	end
	assign add_cnt_row = end_cnt_col;
	assign end_cnt_row = add_cnt_row && cnt_row == HEIGHT-1;
	
	// in the order: blue, green and red
	always @(posedge HCLK or negedge HRESETn) begin
		if(!HRESETn) begin
			for(k=0;k<DATA_SIZE;k=k+1)
				out_bmp[k] <= 0;
		end
		else begin
			if(hsync) begin
				out_bmp[(WIDTH*(HEIGHT-1-cnt_row)+2*cnt_col)*3+2] <= DATA_WRITE_R0;
				out_bmp[(WIDTH*(HEIGHT-1-cnt_row)+2*cnt_col)*3+1] <= DATA_WRITE_G0;
				out_bmp[(WIDTH*(HEIGHT-1-cnt_row)+2*cnt_col)*3+0] <= DATA_WRITE_B0;
				out_bmp[(WIDTH*(HEIGHT-1-cnt_row)+2*cnt_col)*3+5] <= DATA_WRITE_R1;
				out_bmp[(WIDTH*(HEIGHT-1-cnt_row)+2*cnt_col)*3+4] <= DATA_WRITE_G1;
				out_bmp[(WIDTH*(HEIGHT-1-cnt_row)+2*cnt_col)*3+3] <= DATA_WRITE_B1;
			end
		end
	end
	
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
	assign add_cnt = hsync;
	assign end_cnt = add_cnt && cnt == PIXEL_SIZE/2 - 1;

	always @(posedge HCLK or negedge HRESETn) begin
		if(!HRESETn)
			Write_Done <= 0;
		else
			Write_Done <= end_cnt;
	end
	
	initial begin
		fd = $fopen(INFILE, "wb+");
	end
	
	always @(Write_Done) begin
		if(Write_Done) begin
			for(i = 0;i < BMP_HEADER_NUM; i= i+1)
				$fwrite(fd, "%c", bmp_header[i][7:0]);
			for(i=0;i<DATA_SIZE;i=i+6) begin
				$fwrite(fd, "%c", out_bmp[i+0][7:0]);
				$fwrite(fd, "%c", out_bmp[i+1][7:0]);
				$fwrite(fd, "%c", out_bmp[i+2][7:0]);
				$fwrite(fd, "%c", out_bmp[i+3][7:0]);
				$fwrite(fd, "%c", out_bmp[i+4][7:0]);
				$fwrite(fd, "%c", out_bmp[i+5][7:0]);
			end
		end
	end

endmodule
