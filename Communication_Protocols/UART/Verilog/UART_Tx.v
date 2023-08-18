/*
        *****************************************************************************************
        ****************************************LICENSE******************************************
        
        /////////////////////////////////////////////////////////////////////////////////////////
        // Company: 
        // Engineer: Khalid Sh.M. Abdelaziz 
        // 
        // Create Date: 08/17/2023 03:29:24 PM
        // Design Name: UART
        // Module Name: UART_Tx
        // Project Name: UART
        // Target Devices: ASIC desing 
        // Tool Versions: vivado 2020.1 
        // Dependencies: 
        // 
        // Revision:
        // Revision 0.01 - File Created
        // Additional Comments:
        // 
        /////////////////////////////////////////////////////////////////////////////////////////

        *****************************************************************************************
        **************************************INTODUCTION****************************************

        This is A UART Transmitter module to be used  withtin your digital BAUD_RATEin[idesign ,
        we need only to import the files to your project  just after you read this  description
        to assign all input/output ports correctly. 

        P.s. you need to include the attached file "UART_Tx_States.vh" while copying the files to 
        you  project   as  this   file  contains  the   define  statement  of the UART TX satates.

        ALSO , there is attached a simple testbench to test some functionality of the RTL.



        *****************************************************************************************
        *******************************************FRAME*****************************************

        IDLE    START                       DATA                     PARITY   STOP      IDLE
                [1bit]                 [P_data_width bits]           [1bit]  [1bit]
                ---------------------------------------------------------------------
        HIGH    | LOW  |             X  X  X  X  X  X  X  X          |  X  |  HIGH  |   HIGH
                ---------------------------------------------------------------------
                 <______________________________FRAME_______________________________>



        *****************************************************************************************
        ****************************************DESCRIPTION**************************************
        
            # parameters : 
                - CLK_freq     --> customizable ,the master  clock freq operating your TOP  design.
                - BAUD_RATE    --> customizable , the  rate  at  wich  you wish  to  transmit data.
                - P_data_width --> customizable , the size of the data to be transmitted per frame.

                - data_size_width --> don't touch , the  needed  data bits  to address  the  data frame. 
                - CLK_Ticks       --> don't touch , the ratio  between  the  master clock  and BAUD_RATE
                                      used to generate the secondary CLK (myClock) for the Transmission.

            ## ports :

                - CLK        --> input  , The  master CLK   of  the  system. 
                - RST        --> input  , The  reset  button  (Active  low).
                - PAR_EN     --> input  , The   parity  bit  (Active  high).
                - PAR_TYP    --> input  , The parity type (0->EVEN ,1->ODD).
                - P_data     --> input  , The data being transmitted(sized).
                - DATA_VALID --> input  , The enable siganl of trnasmission.


                - TX_OUT     --> output , The line date transmitted serially LSB first.
                - Busy       --> output , The signal indicating data being transmitted.

            ### internal signals :
                - current_state : signal responsiable for holding the current state for  the 
                FSM only , it has 5 possible values defined in the "UART_Tx_States.vh" file :
                                                                                                      GREY
                                                                                                    ENCODING
                        1) IDLE   : nothing happening , just the Tx waiting for DATE_VALID signal. --> 3'b000 (0)
                        2) START  : sending  the  start  bit  on  the frame to initaie the  frame. --> 3'b001 (1)
                        3) DATA   : The   main   data  is  being  transmitted  traced  by  bitIdx. --> 3'b011 (3) 
                        4) PARITY : sending the parity  to check for error , this bit is optional. --> 3'b010 (2)
                        5) STOP   : sending  the  start  bit on  the frame to terminate the frame. --> 3'b110 (6)
                
                - data_Reg : siganl responsiable for holding the data into internal register for protection.
                
                - bitIdx , Idx : two signal to tract the date being sent in the frame bit  by bit , here  we 
                                 used to counter , first  bitIdx  to  write to it  and update it with the  current
                                 bit to be sent , second Idx to  read from it  while transmittint the  current bit 
                                 on the TX_OUT , the two counters all equal all time, we assign them to each other.


                - myClcok     : The secondary clock , created  from the  master clock to match the required BAUD_RATE. 
                - CLK_Counter : A counter that is used to sample the master clock into a  new smaller secondary clock.

*/

`include "UART_Tx_States.vh"

module UART_Tx #(

    parameter CLK_freq = 100_000_000,
    parameter BAUD_RATE = 9600,
    parameter P_data_width = 8,

    parameter data_size_address = $clog2(P_data_width),  // log2(P_data_width) e.g. log2(8) = 3
    parameter CLK_Ticks = CLK_freq / BAUD_RATE  // e.g. 200_000_000 /9600 = 20_833.333 ~= 20_833

) (
    input wire CLK,
    input wire RST,
    input wire PAR_EN,
    input wire PAR_TYP,
    input wire [P_data_width-1:0] P_data,
    input wire DATA_VALID,
    output reg TX_OUT,
    output reg Busy
);

  reg [2:0] current_state = `IDLE;
  reg [P_data_width-1 : 0] data_Reg;

  reg [data_size_address-1 : 0] bitIdx;
  wire [data_size_address-1:0] Idx;

  assign Idx = bitIdx;



  integer CLK_Counter = 'b0;
  reg myClock = 'b0;

  // Generating the secondary clock 
  always @(posedge CLK) begin
    CLK_Counter <= CLK_Counter + 1;
    if (CLK_Counter < CLK_Ticks / 2) begin
      myClock <= 'b0;
    end else if (CLK_Counter < CLK_Ticks) begin
      myClock <= 'b1;
    end else begin
      CLK_Counter <= 'b0;
      myClock <= 'b0;
    end
  end


  // output logic
  always @(posedge myClock or negedge RST) begin
    if (!RST) begin
      //do nothing , the action is taken in the state logic always    
    end else begin
      case (current_state)
        `IDLE: begin
          TX_OUT   <= 'b1;
          bitIdx   <= 'b0;
          data_Reg <= 'b0;
          Busy     <= 'b0;

          if (!Busy && DATA_VALID) begin
            data_Reg <= P_data;
          end
        end

        `START: begin
          TX_OUT <= 'b0;
          Busy   <= 1;

        end

        `DATA: begin
          TX_OUT <= data_Reg[Idx];

          if (&bitIdx) begin
            bitIdx <= 'b0;
          end else begin
            bitIdx <= bitIdx + 'b1;
          end
        end

        `PARITY: begin
          if (PAR_TYP) begin
            if (^data_Reg) begin
              TX_OUT <= 'b0;
            end else begin
              TX_OUT <= 'b1;
            end
          end else begin
            if (~(^data_Reg)) begin
              TX_OUT <= 'b0;
            end else begin
              TX_OUT <= 'b1;
            end
          end
        end

        `STOP: begin
          TX_OUT <= 'b1;
        end

        default: begin
          //nothing
        end
      endcase
    end
  end


  // state logic
  always @(posedge myClock or negedge RST) begin
    if (!RST) begin
      current_state <= `IDLE;
    end else begin
      case (current_state)
        `IDLE: begin
          if (!Busy && DATA_VALID) begin
            current_state <= `START;
          end
        end

        `START: begin
          current_state <= `DATA;
        end

        `DATA: begin
          if (&bitIdx) begin
            if (PAR_EN) begin
              current_state <= `PARITY;
            end else begin
              current_state <= `STOP;
            end
          end
        end

        `PARITY: begin
          current_state <= `STOP;
        end

        `STOP: begin
          current_state <= `IDLE;
        end

        default: begin
          current_state <= `IDLE;
        end
      endcase

    end
  end

endmodule
