-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- File: UART_TX.vhd
-- Author: khalid Sh.M. Abdelaziz
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
-- The provided code is an Behavioral description of a UART (Universal Asynchronous Receiver-
-- Transmitter) transmitter module in VHDL. It is intended to be used for transmitting data over 
-- a serial communication line.
-- Here's a breakdown of the code:

-- 1. Library and Use Clauses:
-- - The code includes standard logic and numeric packages from the IEEE library.

-- 2. Entity:
-- - The entity declaration defines the interface of the UART_TX module.
-- - It has four ports:
--     - `clk` (input): The clock signal for synchronization.
--     - `enable` (input): Enable signal for transmission.
--     - `data_in` (input): Data to be transmitted (8-bit).
--     - `TX` (output): Serial output line.

-- 3. Architecture:
-- - The architecture declaration defines the behavior of the UART_TX module.
-- - It includes several signals and a state type for internal operation.
-- - The `state` signal represents the current state of the transmitter.
-- - The `data_Index` signal is a counter for iterating through the data bits.
-- - The `dataReg` signal holds the data to be transmitted.
-- - The `Clk_Count` signal is a counter for determining the baud rate.

-- 4. Transmit Process:
-- - This process is sensitive to the `clk` signal.
-- - On each rising edge of the clock, it updates the transmitter state based on the current state.
-- - The process is responsible for generating the serial output (`tx`) and controlling the timing.
-- - The transmitter operates in the following states:
--     - `IDLE`: The initial state where `tx` is set to '1' and waits for the `enable` signal to become active.
--     - `START`: The start bit state where `tx` is set to '0' and prepares for data transmission.
--     - `DATA`: The data transmission state where each bit of `dataReg` is transmitted sequentially.
--     - `STOP`: The stop bit state where `tx` is set to '1' to indicate the end of the transmission.
-- - After the stop bit, it returns to the `IDLE` state.

-- Remember that this code describes only the transmitter module of a UART. To have a complete UART system, 
-- you will also need a receiver module and additional components for synchronization, data framing, 
-- and communication protocol handling.
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------


LIBRARY ieee; 
USE ieee.std_logic_1164.ALL; 
USE ieee.numeric_std.ALL; 

ENTITY UART_TX IS
    GENERIC (
        BAUD_RATE : INTEGER := 10416; -- Generic parameter for the desired baud rate (default: 10416)
        DATA_SIZE : INTEGER := 8
    );
    PORT (
        clk : IN STD_LOGIC; -- Clock input for the module
        enable : IN STD_LOGIC; -- Enable signal for transmission
        data_in : IN STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0); -- Input data to be transmitted
        TX : OUT STD_LOGIC -- Serial output
    );
END UART_TX;

ARCHITECTURE Behavioural OF UART_TX IS

    TYPE Tx_state IS (IDLE, START, DATA, STOP); -- Type declaration for the states of the UART transmitter

    SIGNAL state : Tx_state := IDLE; -- State register for the transmitter
    SIGNAL data_Index : INTEGER RANGE 0 TO DATA_SIZE-1 := 0; -- Bit counter
    SIGNAL dataReg : STD_LOGIC_VECTOR(DATA_SIZE-1 DOWNTO 0) := (OTHERS => '0'); -- Data register for the transmitted data
    SIGNAL Clk_Count : INTEGER RANGE 0 TO BAUD_RATE - 1 := 0; -- Baud rate counter

BEGIN

    Transmit : PROCESS (clk)
    BEGIN
        IF (rising_edge(clk)) THEN
            CASE state IS

                WHEN IDLE =>
                    TX <= '1'; -- Set serial output high (idle state)
                    Clk_Count <= 0; -- Reset baud rate counter
                    data_Index <= 0; -- Reset bit counter

                    IF (enable = '1') THEN
                        state <= START; -- Transition to START state if enable is high
                    END IF;

                WHEN START =>
                    TX <= '0'; -- Start bit (serial output low)
                    dataReg <= data_in; -- Load data to be transmitted
                    IF (clk_Count < BAUD_RATE - 1) THEN
                        clk_Count <= clk_Count + 1; -- Increment baud rate counter
                    ELSE
                        clk_Count <= 0;
                        state <= DATA; -- Transition to DATA state
                    END IF;

                WHEN DATA =>
                    TX <= dataReg(data_Index); -- Transmit current data bit
                    IF (clk_Count < BAUD_RATE - 1) THEN
                        clk_Count <= clk_Count + 1; -- Increment baud rate counter
                    ELSE
                        clk_Count <= 0;

                        IF (data_Index = DATA_SIZE-1) THEN
                            state <= STOP; -- Transition to STOP state after transmitting all data bits
                        ELSE
                            data_Index <= data_Index + 1; -- Increment bit counter
                        END IF;
                    END IF;

                WHEN STOP =>
                    TX <= '1'; -- Stop bit (serial output high)
                    IF (clk_Count < BAUD_RATE - 1) THEN
                        clk_Count <= clk_Count + 1; -- Increment baud rate counter
                    ELSE
                        clk_Count <= 0;
                        state <= IDLE; -- Transition to IDLE state
                    END IF;

                WHEN OTHERS =>
                    state <= IDLE; -- Default transition to IDLE state
            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE Behavioural;