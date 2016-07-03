module dual_port_bram #(
	parameter ADDR_WIDTH = 16,
	parameter DATA_WIDTH = 32,
	parameter DEFAULT_CONTENT = "video.mem"
) (
	input  wire                          clk_a,
	input  wire [(DATA_WIDTH / 8) - 1:0] we_a,
	input  wire [ADDR_WIDTH - 1:0]       addr_a,
	input  wire [DATA_WIDTH - 1:0]       write_a,
	output reg  [DATA_WIDTH - 1:0]       read_a,

	input  wire                          clk_b,
	input  wire [(DATA_WIDTH / 8) - 1:0] we_b,
	input  wire [ADDR_WIDTH - 1:0]       addr_b,
	input  wire [DATA_WIDTH - 1:0]       write_b,
	output reg  [DATA_WIDTH - 1:0]       read_b
);

reg [DATA_WIDTH - 1:0] mem [0:2 ** ADDR_WIDTH - 1];

always_ff @(posedge clk_a) begin
	read_a <= mem[addr_a];
	foreach(we_a[i]) if(we_a[i]) mem[addr_a][i*8+:8] <= write_a[i*8+:8];
end

always_ff @(posedge clk_b) begin
	read_b <= mem[addr_b];
	foreach(we_b[i]) if(we_b[i]) mem[addr_b][i*8+:8] <= write_b[i*8+:8];
end

initial $readmemh(DEFAULT_CONTENT, mem);

endmodule

module vga_controller (
	input  wire clk,
	// Reset, active high
	input  wire rst,
	output wire [7:0] red,
	output wire [7:0] green,
	output wire [7:0] blue,
	output reg hsync,
	output reg vsync,

	// External image provider
	output wire clkr,
	output wire [15:0] x,
	output wire [15:0] y,
	input  wire [23:0] color
);

parameter H_FRONT_PORCH = 16'd16;
parameter H_SYNC_PULSE  = 16'd96;
parameter H_FRAME_WIDTH = 16'd640;
parameter H_BACK_PORCH  = 16'd48;
parameter H_TOTAL_WIDTH = 16'd800;

parameter V_FRONT_PORCH = 16'd10;
parameter V_SYNC_PULSE  = 16'd2;
parameter V_FRAME_WIDTH = 16'd480;
parameter V_BACK_PORCH  = 16'd33;
parameter V_TOTAL_WIDTH = 16'd525;

reg [15:0] h_counter;
reg [15:0] v_counter;
wire en;

// Logic to update h and v counters
always @(posedge clk or posedge rst)
begin
	if (rst)
		begin
			h_counter <= 0;
			v_counter <= 0;
		end
	else
		begin
			if (h_counter == H_TOTAL_WIDTH - 1)
				begin
					h_counter <= 0;
					if (v_counter == V_TOTAL_WIDTH - 1)
						v_counter <= 0;
					else
						v_counter <= v_counter + 1;
				end
			else
				begin
					h_counter <= h_counter + 1;
				end
		end
end

// This delays the generation of hsync and vsync signals by one clock cycle
// since we need one clock cycle to get the RGB data
always @(posedge clk)
begin
	if (h_counter >= H_FRAME_WIDTH + H_FRONT_PORCH && h_counter < H_FRAME_WIDTH + H_FRONT_PORCH + H_SYNC_PULSE)
		hsync <= 1;
	else
		hsync <= 0;
end

always @(posedge clk)
begin
	if (v_counter >= V_FRAME_WIDTH + V_FRONT_PORCH && v_counter < V_FRAME_WIDTH + V_FRONT_PORCH + V_SYNC_PULSE)
		vsync <= 1;
	else
		vsync <= 0;
end

// Enable image output
assign en = h_counter < H_FRAME_WIDTH && v_counter < V_FRAME_WIDTH;

// Wire to image provider
// `en` check is not necessary as we've disabled clock when `en` is false
// but this is just an additional safe guard
assign x = en ? h_counter : 0;
assign y = en ? v_counter : 0;

// Output color if enabled
assign red = color[23:16] & {8{en}};
assign green = color[15:8] & {8{en}};
assign blue = color[7:0] & {8{en}};

// Trigger image provider only if enabled
assign clkr = clk & en;

endmodule
