------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-------------------------------------------------------------------------------
-- Entity:      I2cMaster
-- Author:      Jan Andersson - Gaisler Research
-- Contact:     support@gaisler.com
-- Description:
--
--         Generic interface to OpenCores I2C-master. This is a wrapper
--         that instantiates the byte- and bit-controller of the OpenCores I2C
--         master (OC core developed by Richard Herveille, richard@asics.ws).
--
-- Modifications:
--   10/2012 - Ben Reese <bareese@slac.stanford.edu>
--     Removed AMBA bus register based interfaced and replaced with generic
--     IO interface for use anywhere within a firmware design.
--     Interface based on transactions consisting of a i2c device address
--     followed by up to 4 byte-reads or 4 byte-writes.
--
--     Dynamic filter and bus speed adjustment have been left in as features,
--     though they will probably be rarely used.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY surf;
USE surf.StdRtlPkg.ALL;
USE surf.I2cPkg.ALL;

ENTITY I2cMaster IS
    GENERIC (
        TPD_G : TIME := 1 ns; -- Simulated propagation delay
        OUTPUT_EN_POLARITY_G : INTEGER RANGE 0 TO 1 := 0; -- output enable polarity
        PRESCALE_G : INTEGER RANGE 0 TO 655535 := 62;
        FILTER_G : INTEGER RANGE 2 TO 512 := 126; -- filter bit size
        DYNAMIC_FILTER_G : INTEGER RANGE 0 TO 1 := 0);
    PORT (
        clk : IN sl;
        srst : IN sl := '0';
        arst : IN sl := '0';
        -- Front End
        i2cMasterIn : IN I2cMasterInType;
        i2cMasterOut : OUT I2cMasterOutType;

        -- I2C signals
        i2ci : IN i2c_in_type;
        i2co : OUT i2c_out_type
    );
END ENTITY I2cMaster;

ARCHITECTURE rtl OF I2cMaster IS
    -----------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------
    CONSTANT TIMEOUT_C : INTEGER := (PRESCALE_G + 1) * 5 * 500;

    -----------------------------------------------------------------------------
    -- Types
    -----------------------------------------------------------------------------
    -- i2c_master_byte_ctrl IO
    TYPE ByteCtrlInType IS RECORD
        start : sl;
        stop : sl;
        read : sl;
        write : sl;
        ackIn : sl;
        din : slv(7 DOWNTO 0);
    END RECORD;

    TYPE ByteCtrlOutType IS RECORD
        cmdAck : sl;
        ackOut : sl;
        al : sl;
        busy : sl;
        dout : slv(7 DOWNTO 0);
    END RECORD;

    TYPE StateType IS (
        WAIT_TXN_REQ_S,
        ADDR_S,
        WAIT_ADDR_ACK_S,
        READ_S,
        WAIT_READ_DATA_S,
        WRITE_S,
        WAIT_WRITE_ACK_S);

    -- Module Registers
    TYPE RegType IS RECORD
        timer : INTEGER RANGE 0 TO TIMEOUT_C;
        coreRst : sl;
        byteCtrlIn : ByteCtrlInType;
        state : StateType;
        tenbit : sl;
        i2cMasterOut : I2cMasterOutType;
    END RECORD RegType;

    CONSTANT REG_INIT_C : RegType := (
        timer => 0,
        coreRst => '0',
        byteCtrlIn => (
        start => '0',
        stop => '0',
        read => '0',
        write => '0',
        ackIn => '0',
        din => (OTHERS => '0')),
        state => WAIT_TXN_REQ_S,
        tenbit => '0',
        i2cMasterOut => (
        busAck => '0',
        txnError => '0',
        wrAck => '0',
        rdValid => '0',
        rdData => (OTHERS => '0')));
    --------------------------------------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------------------------------------
    -- Register interface
    SIGNAL r : RegType := REG_INIT_C;
    SIGNAL rin : RegType;

    -- Outputs from byte_ctrl block
    SIGNAL byteCtrlOut : ByteCtrlOutType;
    SIGNAL iSclOEn : sl; -- Internal SCL output enable
    SIGNAL iSdaOEn : sl; -- Internal SDA output enablee
    SIGNAL filter : slv((FILTER_G - 1) * DYNAMIC_FILTER_G DOWNTO 0); -- filt input to byte_ctrl
    SIGNAL arstL : sl;
    SIGNAL coreRst : sl;

BEGIN

    arstL <= NOT arst;

    coreRst <= r.coreRst OR srst;
    -- Byte Controller from OpenCores I2C master,
    -- by Richard Herveille (richard@asics.ws). The asynchronous
    -- reset is tied to '1'. Only the synchronous reset is used.
    -- OC I2C logic has active high reset.
    byte_ctrl : i2c_master_byte_ctrl
    GENERIC MAP(
        filter => FILTER_G,
        dynfilt => DYNAMIC_FILTER_G)
    PORT MAP(
        clk => clk,
        rst => coreRst,
        nReset => arstL,
        ena => i2cMasterIn.enable,
        clk_cnt => slv(to_unsigned(PRESCALE_G, 16)),
        start => r.byteCtrlIn.start,
        stop => r.byteCtrlIn.stop,
        read => r.byteCtrlIn.read,
        write => r.byteCtrlIn.write,
        ack_in => r.byteCtrlIn.ackIn,
        din => r.byteCtrlIn.din,
        filt => filter,
        cmd_ack => byteCtrlOut.cmdAck,
        ack_out => byteCtrlOut.ackOut,
        i2c_busy => byteCtrlOut.busy,
        i2c_al => byteCtrlOut.al,
        dout => byteCtrlOut.dout,
        scl_i => i2ci.scl,
        scl_o => i2co.scl,
        scl_oen => iscloen,
        sda_i => i2ci.sda,
        sda_o => i2co.sda,
        sda_oen => isdaoen);

    i2co.enable <= i2cMasterIn.enable;

    -- Fix output enable polarity
    soepol0 : IF OUTPUT_EN_POLARITY_G = 0 GENERATE
        i2co.scloen <= iscloen;
        i2co.sdaoen <= isdaoen;
    END GENERATE soepol0;
    soepol1 : IF OUTPUT_EN_POLARITY_G /= 0 GENERATE
        i2co.scloen <= NOT iscloen;
        i2co.sdaoen <= NOT isdaoen;
    END GENERATE soepol1;
    comb : PROCESS (r, byteCtrlOut, i2cMasterIn, srst)
        VARIABLE v : RegType;
        VARIABLE indexVar : INTEGER;
    BEGIN -- process comb
        v := r;

        -- Pulsed
        v.coreRst := '0';

        -- byteCtrl commands default to zero
        -- unless overridden in a state below
        v.byteCtrlIn.start := '0';
        v.byteCtrlIn.stop := '0';
        v.byteCtrlIn.read := '0';
        v.byteCtrlIn.write := '0';
        v.byteCtrlIn.ackIn := '0';

        v.i2cMasterOut.wrAck := '0'; -- pulsed
        v.i2cMasterOut.busAck := '0'; -- pulsed

        IF (i2cMasterIn.rdAck = '1') THEN
            v.i2cMasterOut.rdValid := '0';
            v.i2cMasterOut.rdData := (OTHERS => '0');
            v.i2cMasterOut.txnError := '0';
        END IF;

        v.timer := 0;

        CASE (r.state) IS
            WHEN WAIT_TXN_REQ_S =>
                -- Reset front end outputs
                -- If new request and any previous rdData has been acked.
                IF (i2cMasterIn.txnReq = '1') AND (r.i2cMasterOut.rdValid = '0') AND (r.i2cMasterOut.busAck = '0') THEN
                    v.state := ADDR_S;
                    v.tenbit := i2cMasterIn.tenbit;
                END IF;

            WHEN ADDR_S =>
                v.byteCtrlIn.start := '1';
                v.byteCtrlIn.write := '1';
                IF (r.tenbit = '0') THEN
                    IF (i2cMasterIn.tenbit = '0') THEN
                        -- Send normal 7 bit address
                        v.byteCtrlIn.din(7 DOWNTO 1) := i2cMasterIn.addr(6 DOWNTO 0);
                        v.byteCtrlIn.din(0) := NOT i2cMasterIn.op;
                    ELSE
                        -- Send second half of 10 bit address
                        v.byteCtrlIn.din := i2cMasterIn.addr(7 DOWNTO 0);
                    END IF;
                ELSE
                    -- Send first half of 10 bit address
                    v.byteCtrlIn.din(7 DOWNTO 3) := "00000";
                    v.byteCtrlIn.din(2 DOWNTO 1) := i2cMasterIn.addr(9 DOWNTO 8);
                    v.byteCtrlIn.din(0) := NOT i2cMasterIn.op;
                END IF;
                v.state := WAIT_ADDR_ACK_S;
            WHEN WAIT_ADDR_ACK_S =>
                v.timer := r.timer + 1;

                IF (byteCtrlOut.cmdAck = '1') THEN -- Master sent the command
                    IF (byteCtrlOut.ackOut = '0') THEN -- Slave ack'd the transfer
                        IF (r.tenbit = '1') THEN -- Must send second half of addr if tenbit set
                            v.tenbit := '0';
                            v.state := ADDR_S;
                        ELSE
                            -- Do read or write depending on op
                            IF (i2cMasterIn.op = '0') THEN
                                v.state := READ_S;
                            ELSE
                                v.state := WRITE_S;
                            END IF;
                        END IF;
                    ELSE
                        -- Slave did not ack the transfer, fail the txn
                        v.i2cMasterOut.txnError := '1';
                        v.i2cMasterOut.rdValid := '1';
                        v.i2cMasterOut.rdData := I2C_INVALID_ADDR_ERROR_C;
                        v.state := WAIT_TXN_REQ_S;
                    END IF;
                    IF (r.tenbit = '0') AND (i2cMasterIn.busReq = '1') THEN
                        v.i2cMasterOut.busAck := '1';
                        v.state := WAIT_TXN_REQ_S;
                    END IF;
                END IF;
            WHEN READ_S =>
                IF (r.i2cMasterOut.rdValid = '0') THEN -- Previous byte has been ack'd
                    v.byteCtrlIn.read := '1';
                    -- If last byte of txn send nack.
                    -- Send stop on last byte if enabled (else repeated start will occur on next txn).
                    v.byteCtrlIn.ackIn := NOT i2cMasterIn.txnReq;
                    v.byteCtrlIn.stop := NOT i2cMasterIn.txnReq AND i2cMasterIn.stop;
                    v.state := WAIT_READ_DATA_S;
                END IF;
            WHEN WAIT_READ_DATA_S =>
                v.timer := r.timer + 1;

                v.byteCtrlIn.stop := r.byteCtrlIn.stop; -- Hold stop or it wont get seen
                v.byteCtrlIn.ackIn := r.byteCtrlIn.ackIn; -- This too
                IF (byteCtrlOut.cmdAck = '1') THEN -- Master sent the command
                    v.byteCtrlIn.stop := '0'; -- Drop stop asap or it will be repeated
                    v.byteCtrlIn.ackIn := '0';
                    v.i2cMasterOut.rdData := byteCtrlOut.dout;
                    v.i2cMasterOut.rdValid := '1';
                    IF (i2cMasterIn.txnReq = '0') THEN -- Last byte of txn
                        v.i2cMasterOut.txnError := '0'; -- Necessary? Should already be 0
                        v.state := WAIT_TXN_REQ_S;
                    ELSE
                        -- If not last byte, read another.
                        v.state := READ_S;
                    END IF;
                END IF;

            WHEN WRITE_S =>
                -- Write the next byte
                IF (i2cMasterIn.wrValid = '1' AND r.i2cMasterOut.wrAck = '0') THEN
                    v.byteCtrlIn.write := '1';
                    -- Send stop on last byte if enabled (else repeated start will occur on next txn).
                    v.byteCtrlIn.stop := NOT i2cMasterIn.txnReq AND i2cMasterIn.stop;
                    v.byteCtrlIn.din := i2cMasterIn.wrData;
                    v.state := WAIT_WRITE_ACK_S;
                END IF;

            WHEN WAIT_WRITE_ACK_S =>
                v.timer := r.timer + 1;

                v.byteCtrlIn.stop := r.byteCtrlIn.stop;
                IF (byteCtrlOut.cmdAck = '1') THEN -- Master sent the command
                    IF (byteCtrlOut.ackOut = '0') THEN -- Slave ack'd the transfer
                        v.byteCtrlIn.stop := '0';
                        v.i2cMasterOut.wrAck := '1'; -- Pass wr ack to front end
                        IF (i2cMasterIn.txnReq = '0') THEN -- Last byte of txn
                            v.i2cMasterOut.txnError := '0'; -- Necessary, should already be 0?
                            v.state := WAIT_TXN_REQ_S;
                        ELSE
                            -- If not last byte, write nother
                            v.state := WRITE_S;
                        END IF;
                    ELSE
                        -- Slave did not ack the transfer, fail the txn
                        v.i2cMasterOut.txnError := '1';
                        v.i2cMasterOut.rdValid := '1';
                        v.i2cMasterOut.rdData := I2C_WRITE_ACK_ERROR_C;
                        v.state := WAIT_TXN_REQ_S;
                    END IF;
                END IF;

            WHEN OTHERS => v.state := WAIT_TXN_REQ_S;
        END CASE;

        -- Must always monitor for arbitration loss
        IF (byteCtrlOut.al = '1') THEN
            -- Return error back to next layer
            v.state := WAIT_TXN_REQ_S;
            v.i2cMasterOut.txnError := '1';
            v.i2cMasterOut.rdValid := '1';
            v.i2cMasterOut.rdData := I2C_ARBITRATION_LOST_ERROR_C;
        END IF;

        -- Always monitor for timeouts.
        IF (r.timer = TIMEOUT_C) THEN
            -- Return error back to next layer
            v.state := WAIT_TXN_REQ_S;
            v.i2cMasterOut.txnError := '1';
            v.i2cMasterOut.rdValid := '1';
            v.i2cMasterOut.rdData := I2C_TIMEOUT_ERROR_C;
            v.timer := 0;
            v.coreRst := '1';
        END IF;

        ------------------------------------------------------------------------------------------------
        -- Synchronous Reset
        ------------------------------------------------------------------------------------------------
        IF (srst = '1') THEN
            v := REG_INIT_C;
            v.coreRst := r.coreRst; -- Remove srst from coreRst path
        END IF;

        ------------------------------------------------------------------------------------------------
        -- Signal Assignments
        ------------------------------------------------------------------------------------------------
        -- Update registers
        rin <= v;

        -- Assign outputs
        i2cMasterOut <= r.i2cMasterOut;

    END PROCESS comb;
    filter <= i2cMasterIn.filter WHEN DYNAMIC_FILTER_G = 1 ELSE
        (OTHERS => '0');

    reg : PROCESS (clk, arst)
    BEGIN
        IF (arst = '1') THEN
            r <= REG_INIT_C AFTER TPD_G;
        ELSIF rising_edge(clk) THEN
            r <= rin AFTER TPD_G;
        END IF;
    END PROCESS reg;
END ARCHITECTURE rtl;