`timescale 1ns/1psinput

module UART_Tx_tb();

    parameter CLK_freq = 200_000_000;
    parameter BAUD_RATE_tb = 9600;
    parameter P_data_width_tb = 8;

    parameter data_size_address_tb = $clog2(P_data_width_tb);  // log2(P_data_width) 
    parameter CLK_Ticks_tb = CLK_freq/BAUD_RATE_tb; // e.g. 200_000_000 /9600 = 20_833.333 ~= 20_833

    reg CLK_tb;
    // reg RST_tb; 
    reg PAR_TYP_tb;
    reg PAR_EN_tb;
    reg [P_data_width_tb-1:0] P_data_tb;
    reg DATA_VALID_tb;
    wire TX_OUT_tb;
    wire Busy_tb;


    
  ////////////////////////////////////////////////////////
  ////////////////// initial block /////////////////////// 
  ////////////////////////////////////////////////////////


  initial begin

    // Save Waveform
    $dumpfile("UART_Tx.vcd");
    $dumpvars;


    // initialization
    initialize();

    #CLK_Ticks_tb;
    P_data_tb = 'hA5;

    #CLK_Ticks_tb;

    #CLK_Ticks_tb;
    DATA_VALID_tb = 'b1;


  end


  task initialize;
    begin
      CLK_tb = 'b0;
      DATA_VALID_tb = 'b0;
      P_data_tb = 'b0; 
      PAR_EN_tb = 'b0;
      PAR_TYP_tb = 'b0; //EVEN parity
    end  
  endtask


  

  ////////////////////////////////////////////////////////
  ////////////////// Clock Generator  ////////////////////
  ////////////////////////////////////////////////////////

  parameter CLK_period = 1/(CLK_freq); //master clock 
  
  
  always #(CLK_period / 2) CLK_tb = ~CLK_tb;



  ////////////////////////////////////////////////////////
  /////////////////// DUT Instantation ///////////////////
  ////////////////////////////////////////////////////////
  UART_Tx #(
    .P_data_width(P_data_width_tb),
    .data_size_address(data_size_address),
    .BAUD_RATE(BAUD_RATE_tb)
  )
  DUT (

    .CLK(CLK_tb),
    //.RST(RST_tb). 
    .PAR_EN(PAR_EN_tb),
    .PAR_TYP(PAR_TYP_tb),
    .P_data(P_data_tb),
    .DATA_VALID(DATA_VALID_tb),
    .TX_OUT(TX_OUT_tb),
    .Busy(Busy_tb)
  );
endmodule