LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY ALTERA_MF;
USE ALTERA_MF.ALL;

ENTITY AsyncReceiver IS
GENERIC(DataWidth:NATURAL:=8);
PORT (
	nRst:IN	STD_LOGIC;
	Clk_FSM:IN	STD_LOGIC;
	Clk_Fifo:IN	STD_LOGIC;
	FreqDiv:IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
	Rxd:IN	STD_LOGIC;
	
	Fifo_Rd:IN  STD_LOGIC;
	Fifo_DataOut:OUT STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
	Fifo_Usedw:OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
	Fifo_Clr:IN STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_AsyncReceiver OF AsyncReceiver IS
COMPONENT scfifo
  GENERIC ( LPM_WIDTH: POSITIVE;
            LPM_WIDTHU: POSITIVE;
            LPM_NUMWORDS: POSITIVE;
				LPM_SHOWAHEAD:STRING);
  PORT (data   :  IN STD_LOGIC_VECTOR(LPM_WIDTH - 1 DOWNTO 0);
        clock  :  IN STD_LOGIC;
        wrreq  : 	IN std_logic;
        rdreq  :  IN std_logic;
        aclr   :  IN std_logic;
        empty  :  OUT std_logic;
        FULL   :  OUT STD_LOGIC;
        q      :  OUT STD_LOGIC_VECTOR(LPM_WIDTH - 1 DOWNTO 0);
        usedw  :  OUT STD_LOGIC_VECTOR(LPM_WIDTHU - 1 DOWNTO 0));
END COMPONENT;

SIGNAL Fifo_Full:STD_LOGIC;
SIGNAL Fifo_Wr:STD_LOGIC;
SIGNAL Fifo_DataIn:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);

CONSTANT Idle:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
CONSTANT Recving:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT WriteFifo:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
SIGNAL Curr_State:STD_LOGIC_VECTOR(1 DOWNTO 0):=Idle;

SIGNAL Reced_Count:STD_LOGIC_VECTOR(DataWidth+1 DOWNTO 0);
SIGNAL Data_Reg:STD_LOGIC_VECTOR(DataWidth+1 DOWNTO 0);
SIGNAL TimeCounter:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL WriteFifoDone:STD_LOGIC;

BEGIN
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			Curr_State <= Idle;
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '1' THEN
			CASE Curr_State IS
				WHEN Idle =>
					IF Rxd = '0' THEN
						Curr_State <= Recving;
					ELSE
						Curr_State <= Idle;
					END IF;
				WHEN Recving =>
					IF Reced_Count(DataWidth+1) = '1' THEN
						IF Data_Reg(0) = '0' THEN
							Fifo_Datain <= Data_Reg(DataWidth DOWNTO 1);
							Curr_State <= WriteFifo;
						ELSE
							Curr_State <= Idle;
						END IF;
					ELSE
						Curr_State <= Recving;
					END IF;
				WHEN WriteFifo =>
					IF WriteFifoDone = '1' THEN
						Curr_State <= Idle;
					END IF;
				WHEN OTHERS => 
					Curr_State <= Idle;
			END CASE;
		END IF;
	END PROCESS;

	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			TimeCounter <= X"01";
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
			IF Curr_State = Idle THEN
				TimeCounter <= X"01";
			ELSIF Curr_State = Recving THEN
				IF TimeCounter = FreqDiv THEN
					TimeCounter <= X"01";
				ELSE
					TimeCounter <= TimeCounter + X"01";
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			Data_Reg <= (OTHERS => '0');
			Reced_Count <= (OTHERS => '0');
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '1' THEN
			IF Curr_State = Idle THEN
				Data_Reg <= (OTHERS => '0');
				Reced_Count <= (OTHERS => '0');
			ELSIF Curr_State = Recving THEN
				IF TimeCounter(7)='0' AND TimeCounter(6 DOWNTO 0) = FreqDiv(7 DOWNTO 1) AND Reced_Count(DataWidth+1) = '0' THEN
					Reced_Count <= Reced_Count(DataWidth DOWNTO 0)&'1';
					Data_Reg(DataWidth+1) <= Rxd;
					Data_Reg(DataWidth DOWNTO 0) <= Data_Reg(DataWidth+1 DOWNTO 1);
				END IF;
			END IF;
		END IF;		
	END PROCESS;
	
	PROCESS(nRst, Clk_Fifo)
	BEGIN
		IF nRst = '0' THEN
			Fifo_Wr <= '0';
		ELSIF Clk_Fifo'EVENT AND Clk_Fifo = '0' THEN
			IF Curr_State = WriteFifo THEN
				Fifo_Wr <= '1';
			ELSE
				Fifo_Wr <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clk_Fifo)
	BEGIN
		IF Clk_Fifo'EVENT AND Clk_Fifo = '1' THEN
			WriteFifoDone <= Fifo_Wr;
		END IF;
	END PROCESS;
	
Component_AsyncRecvFifo:scfifo
GENERIC MAP (LPM_WIDTH => DataWidth,
            LPM_WIDTHU => 10,
            LPM_NUMWORDS => 1024,
				LPM_SHOWAHEAD => "ON")
PORT MAP (
		data   => Fifo_Datain(DataWidth-1 DOWNTO 0),
		clock  => Clk_Fifo,
		wrreq  => Fifo_Wr,
		rdreq  => Fifo_Rd,
		aclr   => Fifo_Clr,
		FULL   => Fifo_Full,
		q      => Fifo_DataOut,
		usedw  => Fifo_Usedw
);

END bhv_AsyncReceiver;