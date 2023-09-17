-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- File: UART_TX.vhd
-- Author: khaled Abdelaziz
-- Date: 31-May-2023 
--
-- Description:
-- This VHDL code implements a UART (Universal Asynchronous Receiver-Transmitter)
-- transmitter module. It is responsible for transmitting data over a serial
-- communication line at a specified baud rate.
--
-- This code follows the behavioral approach, where the module's functionality is
-- described in terms of states and transitions.
--
-- Usage:
-- 1. Instantiate this module in your design hierarchy and connect the ports
--    appropriately.
-- 2. Provide the desired baud rate through the "BAUD_RATE" generic parameter.
-- 3. Drive the "clk" input with the system clock.
-- 4. Control the transmission by driving the "enable" input.
-- 5. Provide the data to be transmitted through the "data_in" input.
-- 6. Receive the serial output from the "TX" output.
--
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
------------------------------------------ EXPLAINATION  ----------------------------------------------
-------------------------------------------------------------------------------------------------------
-- The code you provided is an RTL (Register Transfer Level) description of a UART receiver module in VHDL 
-- The module receives serial data on the `RX` input and outputs the received data on the `DATA_OUT` signal. 
-- The `DONE` signal indicates when a complete data frame has been received.
-- Here's a breakdown of the code:

-- - The entity declaration specifies the module's name (`UART_RX`) and its ports (`clk`, `RX`, `DATA_OUT`, and `DONE`).
-- - The architecture declaration (`Behavioural`) defines the internal behavior of the module using concurrent signal 
--      assignments and a process statement.
-- - The `state_type` is defined as an enumeration type with four states: `IDLE`, `START`, `DATA`, and `STOP`. 
--      The `state` signal represents the current state of the UART receiver.
-- - Signals `DataReg`, `clk_count`, `data_index_counter`, and `isDone` are declared to store intermediate values and  
--      control the operation of the receiver.
-- - The `receiver` process is sensitive to the `clk` signal, indicating that it will execute whenever a rising edge
--      is detected on the `clk` signal.
-- - Inside the process, the behavior of the UART receiver is implemented using a case statement based on the `state` signal.
-- - In the `IDLE` state, the receiver waits for the start bit (RX = '0'). When the start bit is detected, the receiver
--      transitions to the `START` state.
-- - In the `START` state, the receiver waits for half of the bit duration (Baud_Rate / 2) to sample the data. If the 
--      sampled data is valid (RX = '0'), the receiver transitions to the `DATA` state and starts receiving the data bits.
--      Otherwise, it goes back to the `IDLE` state.
-- - In the `DATA` state, the receiver samples the data bits at each bit duration (Baud_Rate) until all 8 bits have been received.
--       The received data is stored in the `DataReg` signal.
-- - After receiving all the data bits, the receiver transitions to the `STOP` state and waits for one bit duration (Baud_Rate)
--       before going back to the `IDLE` state. The `isDone` signal is set to '1' to indicate that a complete data frame has
--       been received.
-- - The `OTHERS` clause in the case statement ensures that if the `state` signal takes any unexpected value,
--       the receiver transitions back to the `IDLE` state.
-- - Finally, the received data stored in `DataReg` is assigned to the `DATA_OUT` output signal, and the value of `isDone`
--       is assigned to the `DONE` output signal.

-- It's important to note that the code assumes a specific baud rate (`BAUD_RATE`) and uses it for timing calculations. 
-- You can provide a different value for `BAUD_RATE` when instantiating the `UART_RX` module.

-----------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
ENTITY UART_RX IS
    GENERIC (
        BAUD_RATE : INTEGER := 10416;
        DATA_SIZE : INTEGER := 8
    );

    PORT (
        clk : IN STD_LOGIC;
        RX : IN STD_LOGIC;
        DATA_OUT : OUT STD_LOGIC_VECTOR(DATA_SIZE - 1 DOWNTO 0);
        DONE : OUT STD_LOGIC
    );
END UART_RX;
ARCHITECTURE Behavioural OF UART_RX IS

    TYPE state_type IS (IDLE, START, DATA, STOP);
    SIGNAL state : state_type := IDLE;

    SIGNAL DataReg : STD_LOGIC_VECTOR(DATA_SIZE - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL clk_count : INTEGER RANGE 0 TO (Baud_Rate - 1) := 0;
    SIGNAL data_index_counter : INTEGER RANGE 0 TO DATA_SIZE - 1 := 0;
    SIGNAL isDone : STD_LOGIC := '0';

BEGIN

    receiver : PROCESS (clk)
    BEGIN
        IF (rising_edge(clk)) THEN

            CASE state IS
                WHEN IDLE =>
                    --RX <= '1';
                    clk_count <= 0;
                    data_index_counter <= 0;
                    isDone <= '0';

                    IF (RX = '0') THEN
                        state <= START;
                    END IF;
                WHEN Start =>
                    IF (clk_count = (Baud_Rate / 2) - 1) THEN
                        IF (RX = '0') THEN
                            state <= DATA;
                            clk_count <= 0;
                        ELSE
                            state <= IDLE;
                        END IF;

                    ELSE
                        clk_count <= clk_count + 1;
                    END IF;

                WHEN DATA =>

                    IF (clk_count = Baud_rate - 1) THEN
                        clk_count <= 0;
                        DataReg(data_index_counter) <= RX;
                        IF (data_index_counter = DATA_SIZE - 1) THEN
                            state <= STOP;
                        ELSE
                            data_index_counter <= data_index_counter + 1;
                        END IF;
                    ELSE
                        clk_count <= clk_count + 1;
                    END IF;

                WHEN STOP =>
                    IF (clk_count = Baud_Rate - 1) THEN
                        clk_count <= 0;
                        state <= IDLE;
                        isDone <= '1';
                    ELSE
                        clk_count <= clk_count + 1;
                    END IF;
                WHEN OTHERS =>
                    state <= IDLE;
            END CASE;
        END IF;
    END PROCESS;

    DATA_OUT <= DataReg;
    DONE <= isDone;

END ARCHITECTURE Behavioural;