`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Neil Judson
// 
// Create Date: 2016/10/27 21:22:58
// Design Name: 
// Module Name: psi_operator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module psi_operator #(
	parameter SYNC_DATA_WIDTH	= 16, // <=18
	parameter RAM_ADDR_WIDTH	= 10
	)
	(
	clk			,
	reset		,
	
	i_work_ctrl_en,
	i_work_ctrl	,
	
	i_data_valid,
	i_data_i	,
	i_data_q	,
	i_data_dly_i,
	i_data_dly_q,
	i_data_dly_addr,
	
	o_psi_data_valid,
	o_psi_data_i,
	o_psi_data_q,
	
	o_self_corr_valid,
	o_self_corr_i,
	o_self_corr_q,
	o_self_corr_addr
	);
	input					clk			;
	input					reset		;
	
	input					i_work_ctrl_en;
	input					i_work_ctrl	; // 1'b0: 停止工作；1'b1: 开始工作，先进入清零状态
	
	input					i_data_valid;
	input	signed	[17:0]	i_data_i	;
	input	signed	[17:0]	i_data_q	;
	input	signed	[17:0]	i_data_dly_i;
	input	signed	[17:0]	i_data_dly_q;
	input			[15:0]	i_data_dly_addr;
	
	output					o_psi_data_valid; // 9dly
	output	signed	[37:0]	o_psi_data_i;
	output	signed	[37:0]	o_psi_data_q;
	
	output					o_self_corr_valid;
	output	signed	[35:0]	o_self_corr_i;
	output	signed	[35:0]	o_self_corr_q;
	output			[15:0]	o_self_corr_addr;
	
//================================================================================
// variable
//================================================================================
	localparam	SPRAM_ADDR_WIDTH	= 6;
	localparam	SPRAM_DATA_WIDTH	= 72;
	localparam	DATA_MUL_WIDTH		= 2*SYNC_DATA_WIDTH; // 32
	localparam	PSI_WIDTH			= 2*SYNC_DATA_WIDTH+2; // 34
	// state
	localparam	IDLE	= 2'd0,
				CLEAR	= 2'd1,
				WORK	= 2'd2;
	
	reg				[1:0]					state			;
	reg				[SPRAM_ADDR_WIDTH:0]	clear_count		;
	
	wire	signed	[17:0]					i_data_q_neg	;
	
	reg										u1_s_axis_a_tvalid	;
	reg				[47:0]					u1_s_axis_a_tdata	;
	reg				[47:0]					u1_s_axis_b_tdata	;
	wire									u1_m_axis_dout_tvalid;
	wire			[79:0]					u1_m_axis_dout_tdata;
	
	reg										u2_wea			;
	reg				[SPRAM_ADDR_WIDTH-1:0]	u2_wr_addr		;
	reg				[SPRAM_ADDR_WIDTH-1:0]	u2_rd_addr		;
	reg				[SPRAM_ADDR_WIDTH-1:0]	u2_addra		;
	reg				[SPRAM_DATA_WIDTH-1:0]	u2_dina			;
	wire			[SPRAM_DATA_WIDTH-1:0]	u2_douta		;

	wire									u3_wea			;
	wire			[SPRAM_ADDR_WIDTH-1:0]	u3_wr_addr		;
	wire			[SPRAM_ADDR_WIDTH-1:0]	u3_rd_addr		;
	wire			[SPRAM_ADDR_WIDTH-1:0]	u3_addra		;
	reg				[SPRAM_DATA_WIDTH-1:0]	u3_dina			;
	wire			[SPRAM_DATA_WIDTH-1:0]	u3_douta		;

	wire									u4_wea			;
	wire			[SPRAM_ADDR_WIDTH-1:0]	u4_wr_addr		;
	wire			[SPRAM_ADDR_WIDTH-1:0]	u4_rd_addr		;
	wire			[SPRAM_ADDR_WIDTH-1:0]	u4_addra		;
	reg				[SPRAM_DATA_WIDTH-1:0]	u4_dina			;
	wire			[SPRAM_DATA_WIDTH-1:0]	u4_douta		;
	
	reg										u1_m_axis_dout_tvalid_dly1;
	reg										u1_m_axis_dout_tvalid_dly2;
	reg		signed	[DATA_MUL_WIDTH:0]		add12_i				;
	reg		signed	[DATA_MUL_WIDTH:0]		add34_i				;
	reg		signed	[PSI_WIDTH-1:0]			add1234_i			;
	reg		signed	[DATA_MUL_WIDTH:0]		add12_q				;
	reg		signed	[DATA_MUL_WIDTH:0]		add34_q				;
	reg		signed	[PSI_WIDTH-1:0]			add1234_q			;
	
	reg				[RAM_ADDR_WIDTH-1:0]	self_corr_addr		;

//================================================================================
// state
//================================================================================
	always @(posedge clk or posedge reset) begin
		if(reset == 1'b1) begin
			state <= IDLE;
		end
		else begin
			case(state)
				IDLE: begin
					if((i_work_ctrl_en==1'b1) && (i_work_ctrl==1'b1)) begin
						state <= CLEAR;
					end
					else begin
						state <= IDLE;
					end
				end
				CLEAR: begin
					if((i_work_ctrl_en==1'b1) && (i_work_ctrl==1'b0)) begin
						state <= IDLE;
					end
					else if(clear_count >= 'd65) begin
						state <= WORK;
					end
					else begin
						state <= CLEAR;
					end
				end
				WORK: begin
					if((i_work_ctrl_en==1'b1) && (i_work_ctrl==1'b0)) begin
						state <= IDLE;
					end
					else begin
						state <= WORK;
					end
				end
				default: begin
					state <= IDLE;
				end
			endcase
		end
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset == 1'b1) begin
			clear_count <= 'd0;
		end
		else begin
			case(state)
				// IDLE: begin
				// end
				CLEAR: begin
					clear_count <= clear_count + 1'd1;
				end
				// WORK: begin
				// end
				default: begin
					clear_count <= 'd0;
				end
			endcase
		end
	end
	
//================================================================================
// complex multiply
//================================================================================
	assign i_data_q_neg = -i_data_q;
	
	always @(posedge clk or posedge reset) begin
		if(reset == 1'b1) begin
			u1_s_axis_a_tvalid	<= 1'b0;
			u1_s_axis_a_tdata	<= 48'd0;
			u1_s_axis_b_tdata	<= 48'd0;
		end
		else if((state==WORK) && (i_data_valid==1'b1)) begin
			u1_s_axis_a_tvalid	<= 1'b1;
			u1_s_axis_a_tdata	<= {{(6){i_data_q_neg[17]}},i_data_q_neg,
									{(6){i_data_i[17]}},i_data_i};
			u1_s_axis_b_tdata	<= {{(6){i_data_dly_q[17]}},i_data_dly_q,
									{(6){i_data_dly_i[17]}},i_data_dly_i};
		end
		else begin
			u1_s_axis_a_tvalid	<= 1'b0;
			u1_s_axis_a_tdata	<= u1_s_axis_a_tdata;
			u1_s_axis_b_tdata	<= u1_s_axis_b_tdata;
		end
	end
	
	complex_multiplier_18_18_ip u1_complex_multiplier_18_18_ip(
		.aclk				(clk					),	// input aclk;
		.s_axis_a_tvalid	(u1_s_axis_a_tvalid		),	// input s_axis_a_tvalid;
		.s_axis_a_tdata		(u1_s_axis_a_tdata		),	// input [47:0]s_axis_a_tdata;
		.s_axis_b_tvalid	(u1_s_axis_a_tvalid		),	// input s_axis_b_tvalid;
		.s_axis_b_tdata		(u1_s_axis_b_tdata		),	// input [47:0]s_axis_b_tdata;
		.m_axis_dout_tvalid	(u1_m_axis_dout_tvalid	),	// output m_axis_dout_tvalid; // dly6
		.m_axis_dout_tdata	(u1_m_axis_dout_tdata	)	// output [79:0]m_axis_dout_tdata; // 高位虚部，低位实部。
	);
	
//================================================================================
// 3级64深度延迟
//================================================================================
	localparam u2_rd_addr_init = 'd1;
	always @(posedge clk or posedge reset) begin
		if(reset == 1'b1) begin
			u2_wea		<= 1'b0;
			u2_wr_addr	<= 'd0;
			u2_rd_addr	<= u2_rd_addr_init;
			u2_addra	<= 'd0;
			u2_dina		<= 'd0;
		end
		else begin
			case(state)
				IDLE: begin
					u2_wea		<= 1'b0;
					u2_wr_addr	<= 'd0;
					u2_rd_addr	<= u2_rd_addr_init;
					u2_addra	<= 'd0;
					u2_dina		<= 'd0;
					u3_dina		<= 'd0;
					u4_dina		<= 'd0;
				end
				CLEAR: begin
					u2_wea		<= 1'b1;
					u2_wr_addr	<= 'd0;
					u2_rd_addr	<= u2_rd_addr_init;
					u2_addra	<= u2_addra + 1'd1;
					u2_dina		<= 'd0;
					u3_dina		<= 'd0;
					u4_dina		<= 'd0;
				end
				WORK: begin
					if(u1_m_axis_dout_tvalid == 1'b1) begin
						u2_wea		<= 1'b1;
						u2_wr_addr	<= u2_wr_addr + 1'd1;
						u2_rd_addr	<= u2_rd_addr + 1'd1;
						u2_addra	<= u2_wr_addr + 1'd1;
						u2_dina		<= {u1_m_axis_dout_tdata[40+SPRAM_DATA_WIDTH/2-1:40],
										u1_m_axis_dout_tdata[SPRAM_DATA_WIDTH/2-1:0]};
						u3_dina		<= u2_douta;
						u4_dina		<= u3_douta;
					end
					else begin
						u2_wea		<= 1'b0;
						u2_wr_addr	<= u2_wr_addr;
						u2_rd_addr	<= u2_rd_addr;
						u2_addra	<= u2_rd_addr;
						u2_dina		<= u2_dina;
						u3_dina		<= u3_dina;
						u4_dina		<= u4_dina;
					end
				end
				default: begin
					u2_wea		<= 1'b0;
					u2_wr_addr	<= 'd0;
					u2_rd_addr	<= u2_rd_addr_init;
					u2_addra	<= 'd0;
					u2_dina		<= 'd0;
					u3_dina		<= 'd0;
					u4_dina		<= 'd0;
				end
			endcase
		end
	end
	
	assign u3_wea		= u2_wea	;
	assign u3_wr_addr	= u2_wr_addr;
	assign u3_rd_addr	= u2_rd_addr;
	assign u3_addra		= u2_addra	;
	
	assign u4_wea		= u2_wea	;
	assign u4_wr_addr	= u2_wr_addr;
	assign u4_rd_addr	= u2_rd_addr;
	assign u4_addra		= u2_addra	;
	
	spram_72_64_ip u2_spram_72_64_ip (
		.clka	(clk		),	// input clka;
		.wea	(u2_wea		),	// input [0:0]wea;
		.addra	(u2_addra	),	// input [5:0]addra;
		.dina	(u2_dina	),	// input [71:0]dina;
		.douta	(u2_douta	)	// output [71:0]douta;
	);
	
	spram_72_64_ip u3_spram_72_64_ip (
		.clka	(clk		),	// input clka;
		.wea	(u3_wea		),	// input [0:0]wea;
		.addra	(u3_addra	),	// input [5:0]addra;
		.dina	(u3_dina	),	// input [71:0]dina;
		.douta	(u3_douta	)	// output [71:0]douta;
	);
	
	spram_72_64_ip u4_spram_72_64_ip (
		.clka	(clk		),	// input clka;
		.wea	(u4_wea		),	// input [0:0]wea;
		.addra	(u4_addra	),	// input [5:0]addra;
		.dina	(u4_dina	),	// input [71:0]dina;
		.douta	(u4_douta	)	// output [71:0]douta;
	);
	
//================================================================================
// exception
//================================================================================
	always @(posedge clk or posedge reset) begin
		if(reset == 1'b1) begin
			u1_m_axis_dout_tvalid_dly1 <= 1'b0;
			u1_m_axis_dout_tvalid_dly2 <= 1'b0;
		end
		else begin
			u1_m_axis_dout_tvalid_dly1 <= u1_m_axis_dout_tvalid;
			u1_m_axis_dout_tvalid_dly2 <= u1_m_axis_dout_tvalid_dly1;
		end
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset == 1'b1) begin
			add12_i <= 'd0;
			add34_i <= 'd0;
			add12_q <= 'd0;
			add34_q <= 'd0;
		end
		else if(u1_m_axis_dout_tvalid == 1'b1) begin
			add12_i <= {u1_m_axis_dout_tdata[DATA_MUL_WIDTH-1],u1_m_axis_dout_tdata[DATA_MUL_WIDTH-1:0]}
						+ {u2_douta[DATA_MUL_WIDTH-1],u2_douta[DATA_MUL_WIDTH-1:0]};
			add34_i <= {u3_douta[DATA_MUL_WIDTH-1],u3_douta[DATA_MUL_WIDTH-1:0]}
						+ {u4_douta[DATA_MUL_WIDTH-1],u4_douta[DATA_MUL_WIDTH-1:0]};
			add12_q <= {u1_m_axis_dout_tdata[40+DATA_MUL_WIDTH-1],u1_m_axis_dout_tdata[40+DATA_MUL_WIDTH-1:40]}
						+ {u2_douta[SPRAM_DATA_WIDTH/2+DATA_MUL_WIDTH-1],u2_douta[SPRAM_DATA_WIDTH/2+DATA_MUL_WIDTH-1:SPRAM_DATA_WIDTH/2]};
			add34_q <= {u3_douta[SPRAM_DATA_WIDTH/2+DATA_MUL_WIDTH-1],u3_douta[SPRAM_DATA_WIDTH/2+DATA_MUL_WIDTH-1:SPRAM_DATA_WIDTH/2]}
						+ {u4_douta[SPRAM_DATA_WIDTH/2+DATA_MUL_WIDTH-1],u4_douta[SPRAM_DATA_WIDTH/2+DATA_MUL_WIDTH-1:SPRAM_DATA_WIDTH/2]};
		end
		else begin
			add12_i <= add12_i;
			add34_i <= add34_i;
			add12_q <= add12_q;
			add34_q <= add34_q;
		end
	end
	
	always @(posedge clk or posedge reset) begin
		if(reset == 1'b1) begin
			add1234_i <= 'd0;
			add1234_q <= 'd0;
		end
		else if(u1_m_axis_dout_tvalid_dly1 == 1'b1) begin
			add1234_i <= {add12_i[DATA_MUL_WIDTH],add12_i} + {add34_i[DATA_MUL_WIDTH],add34_i};
			add1234_q <= {add12_q[DATA_MUL_WIDTH],add12_q} + {add34_q[DATA_MUL_WIDTH],add34_q};
		end
		else begin
			add1234_i <= add1234_i;
			add1234_q <= add1234_q;
		end
	end
	
	assign o_psi_data_valid	= u1_m_axis_dout_tvalid_dly2;
	assign o_psi_data_i		= {{(38-PSI_WIDTH){add1234_i[PSI_WIDTH-1]}},add1234_i};
	assign o_psi_data_q		= {{(38-PSI_WIDTH){add1234_q[PSI_WIDTH-1]}},add1234_q};
	
//================================================================================
// 
//================================================================================
	always @(posedge clk or posedge reset) begin
		if(reset == 1'b1) begin
			self_corr_addr <= 'd0;
		end
		else if(u1_m_axis_dout_tvalid == 1'b1) begin
			self_corr_addr <= i_data_dly_addr[RAM_ADDR_WIDTH-1:0] - 8'd193;
		end
		else begin
			self_corr_addr <= self_corr_addr;
		end
	end
	
	assign o_self_corr_valid	= u1_m_axis_dout_tvalid_dly1;
	assign o_self_corr_i		= u4_douta[35:0];
	assign o_self_corr_q		= u4_douta[SPRAM_DATA_WIDTH/2+35:SPRAM_DATA_WIDTH/2];
	assign o_self_corr_addr		= {{(16-RAM_ADDR_WIDTH){1'b0}},self_corr_addr};
	
endmodule
