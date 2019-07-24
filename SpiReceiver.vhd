LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
LIBRARY ALTERA_MF;
USE ALTERA_MF.ALL;

ENTITY SpiReceiver IS
PORT (
	nRst:IN		STD_LOGIC;
	Clk_Fifo:IN		STD_LOGIC;
	Clk_FSM:IN	STD_LOGIC;
	------------spi port -----------
	nCS:IN	STD_LOGIC;
	SDI:IN	STD_LOGIC;
	SCK:IN	STD_LOGIC;
	CheckOKPulse:IN	STD_LOGIC;
	-----------Fifo port------------
	Fifo_Rd:IN  STD_LOGIC;
	Fifo_DataOut:OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	Fifo_Usedw:OUT	STD_LOGIC_VECTOR(9 DOWNTO 0);
	Fifo_Clr:IN	STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_SpiReceiver OF SpiReceiver IS

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

CONSTANT DataWidth:NATURAL:=8;

SIGNAL Fifo_Full:STD_LOGIC;

SIGNAL Fifo_Datain:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
SIGNAL Fifo_Wr:STD_LOGIC;

CONSTANT Idle:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
CONSTANT Recving:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT LockRecvData:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
CONSTANT WriteFifo:STD_LOGIC_VECTOR(1 DOWNTO 0):="11";
SIGNAL Curr_State:STD_LOGIC_VECTOR(1 DOWNTO 0):=Idle;

SIGNAL RecvDone:STD_LOGIC;
SIGNAL SCK_Tmp:STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL Data_Reg:STD_LOGIC_VECTOR(DataWidth - 1 DOWNTO 0);
SIGNAL RecvCounter:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
SIGNAL WriteFifoDone:STD_LOGIC;
SIGNAL UUT_PulseCheckOK_Wr:STD_LOGIC;
SIGNAL CheckSum:STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			Curr_State <= Idle;
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '1' THEN
			CASE Curr_State IS
				WHEN Idle =>
					IF nCS = '0' THEN
						Curr_State <= Recving;
					ELSE
						Curr_State <= Idle;
					END IF;
				WHEN Recving =>
					IF nCS = '1' THEN
						Curr_State <= Idle;
					ELSE
						IF RecvCounter(DataWidth-1) = '1' THEN
							Curr_State <= WriteFifo;
							Fifo_Datain <= Data_Reg;
						END IF;
					END IF;
				WHEN WriteFifo =>
  					IF WriteFifoDone = '1' THEN
						Curr_State <= Recving;
					END IF;
				WHEN OTHERS =>
					Curr_State <= Idle;
			END CASE;
		END IF;
	END PROCESS;

	PROCESS(Clk_FSM)
	BEGIN
		IF Clk_FSM'EVENT AND Clk_FSM = '1' THEN
			SCK_Tmp <= SCK_Tmp(0)&SCK;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			Data_Reg <= (OTHERS => '0');
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
			IF SCK_Tmp = "10" THEN
				Data_Reg(DataWidth-1 DOWNTO 0) <= Data_Reg(DataWidth-2 DOWNTO 0)&SDI;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			RecvCounter <= (OTHERS => '0');
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
			IF Curr_State = Idle OR Curr_State = WriteFifo THEN
				RecvCounter <= (OTHERS => '0');
			ELSIF SCK_Tmp = "10" THEN
				RecvCounter <= RecvCounter(DataWidth-2 DOWNTO 0)&'1';
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
	
	UUT_RecvFifo:scfifo
	GENERIC MAP (LPM_WIDTH => DataWidth,
					LPM_WIDTHU => 10,
					LPM_NUMWORDS => 1024,
					LPM_SHOWAHEAD => "ON")
	PORT MAP (
			data   => Fifo_Datain,
			clock  => Clk_Fifo,
			wrreq  => Fifo_Wr,
			rdreq  => Fifo_Rd,
			aclr   => Fifo_Clr,
			FULL   => Fifo_Full,
			q      => Fifo_DataOut,
			usedw  => Fifo_Usedw
	);
	

END bhv_SpiReceiver;