`timescale 1ns / 1ps

module uart_top
#(
  parameter clk_freq = 1000000,
  parameter baud_rate = 9600
)
(
  input clk, rst,
  input rx,
  input [7:0] dintx,
  input newd,
  output tx,
  output [7:0] doutrx,
  output donetx,
  output donerx
);

  uarttx 
  #(.clk_freq(clk_freq), .baud_rate(baud_rate)) 
  utx (
    .clk(clk),
    .rst(rst),
    .newd(newd),
    .tx_data(dintx),
    .tx(tx),
    .donetx(donetx)
  );

  uartrx 
  #(.clk_freq(clk_freq), .baud_rate(baud_rate))
  rtx (
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .done(donerx),
    .rxdata(doutrx)
  );

endmodule

//////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module uarttx
#(
  parameter clk_freq = 1000000,
  parameter baud_rate = 9600
)
(
  input clk, rst,
  input newd,
  input [7:0] tx_data,
  output reg tx,
  output reg donetx
);

  localparam clkcount = (clk_freq / baud_rate);

  integer count = 0;
  integer counts = 0;

  reg uclk = 0;

  enum bit [1:0] {idle = 2'b00, start = 2'b01, transfer = 2'b10, send_parity = 2'b11} state;

  // UART Clock Generator
  always @(posedge clk) begin
    if (count < clkcount / 2)
      count <= count + 1;
    else begin
      count <= 0;
      uclk <= ~uclk;
    end
  end

  reg [7:0] din;
  reg parity = 0;  // store odd parity

  // FSM for UART Transmit
  always @(posedge uclk) begin
    if (rst) begin
      state <= idle;
    end
    else begin
      case (state)

        // Detect new data and start transmission
        idle: begin
          counts <= 0;
          tx <= 1'b1;
          donetx <= 1'b0;

          if (newd) begin
            state <= transfer;
            din <= tx_data;
            tx <= 1'b0;
            parity <= ~^tx_data;  // odd parity
          end
          else
            state <= idle;
        end

        // Transmit data bits
        transfer: begin
          if (counts <= 7) begin
            counts <= counts + 1;
            tx <= din[counts];
            state <= transfer;
          end
          else begin
            counts <= 0;
            tx <= parity;
            state <= send_parity;
          end
        end

        // Send parity and return to idle
        send_parity: begin
          tx <= 1'b1;
          state <= idle;
          donetx <= 1'b1;
        end

        default: state <= idle;

      endcase
    end
  end

endmodule

////////////////////////////////////////////////////////////////////

module uartrx
#(
  parameter clk_freq = 1000000,
  parameter baud_rate = 9600
)
(
  input clk,
  input rst,
  input rx,
  output reg done,
  output reg [7:0] rxdata
);

  localparam clkcount = (clk_freq / baud_rate);

  integer count = 0;
  integer counts = 0;

  reg uclk = 0;

  enum bit [1:0] {idle = 2'b00, start = 2'b01} state;

  // UART Clock Generator
  always @(posedge clk) begin
    if (count < clkcount / 2)
      count <= count + 1;
    else begin
      count <= 0;
      uclk <= ~uclk;
    end
  end

  // FSM for UART Receive
  always @(posedge uclk) begin
    if (rst) begin
      rxdata <= 8'h00;
      counts <= 0;
      done <= 1'b0;
    end
    else begin
      case (state)

        idle: begin
          rxdata <= 8'h00;
          counts <= 0;
          done <= 1'b0;
          if (rx == 1'b0)
            state <= start;
          else
            state <= idle;
        end

        start: begin
          if (counts <= 7) begin
            counts <= counts + 1;
            rxdata <= {rx, rxdata[7:1]};
          end
          else begin
            counts <= 0;
            done <= 1'b1;
            state <= idle;
          end
        end

        default: state <= idle;

      endcase
    end
  end

endmodule

///////////////////////////////////////////////////////////////////

interface uart_if;
  logic clk;
  logic uclktx;
  logic uclkrx;
  logic rst;
  logic rx;
  logic [7:0] dintx;
  logic newd;
  logic tx;
  logic [7:0] doutrx;
  logic donetx;
  logic donerx;
endinterface
