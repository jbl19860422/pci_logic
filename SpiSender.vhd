LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY ALTERA_MF;
USE ALTERA_MF.ALL;

ENTITY SpiSender IS
PORT (
	nRst:IN		STD_LOGIC;
	Clk_FSM: IN STD_LOGIC;
	Clk_Fifo:STD_LOGIC;
	En:IN			STD_LOGIC;
	FreqDiv:IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
	-----------spi port------------
	nCS:	OUT	STD_LOGIC;
	SDO:OUT	STD_LOGIC;
	SCK:	OUT	STD_LOGIC;
	-----------Fifo port-----------
	Fifo_Wr:IN  STD_LOGIC;
	Fifo_Datain:IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	Fifo_Clr:IN	STD_LOGIC;
	Fifo_Empty:OUT	STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_SpiSender OF SpiSender IS
COMPONENT scfifo
  GENERIC ( LPM_WIDTH: POSITIVE;
            LPM_WIDTHU: POSITIVE;
            LPM_NUMWORDS: POSITIVE);
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
SIGNAL Fifo_Rd:STD_LOGIC;
SIGNAL Fifo_q:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
SIGNAL Fifo_Empty_Tmp:STD_LOGIC;

CONSTANT Idle:STD_LOGIC_VECTOR(2 DOWNTO 0):="000";
CONSTANT ReadFifo:STD_LOGIC_VECTOR(2 DOWNTO 0):="001";
CONSTANT LockFifoData:STD_LOGIC_VECTOR(2 DOWNTO 0):="010";
CONSTANT Enable_nCS:STD_LOGIC_VECTOR(2 DOWNTO 0):="011";
CONSTANT Sending:STD_LOGIC_VECTOR(2 DOWNTO 0):="100";
CONSTANT Disable_nCS:STD_LOGIC_VECTOR(2 DOWNTO 0):="101";

SIGNAL Curr_State:STD_LOGIC_VECTOR(2 DOWNTO 0):=Idle;
SIGNAL Sended_count:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
SIGNAL SendDone:STD_LOGIC;
SIGNAL Data_reg:STD_LOGIC_VECTOR(DataWidth - 1 DOWNTO 0);
SIGNAL Fifo_DataReady:STD_LOGIC;
SIGNAL Fifo_Rd_Delay:STD_LOGIC;
SIGNAL TimeCounter:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL SCK_Tmp:STD_LOGIC;
attribute keep:boolean;
attribute keep of Fifo_q:SIGNAL IS TRUE;
BEGIN

Component_SendFifo:scfifo
GENERIC MAP (
	LPM_WIDTH => DataWidth,
	LPM_WIDTHU => 10,
	LPM_NUMWORDS => 1024)
PORT MAP (
  data   => Fifo_Datain,
  clock  => Clk_Fifo,
  wrreq  => Fifo_Wr,
  rdreq  => Fifo_Rd,
  aclr   => Fifo_Clr,
  empty  => Fifo_Empty_Tmp,
  FULL   => Fifo_Full,
  q      => Fifo_q
);
Fifo_Empty <= Fifo_Empty_Tmp;

PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			Curr_State <= Idle;
			nCS <= '1';
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '1' THEN
			CASE Curr_state IS
				WHEN Idle =>
					nCS <= '1';
					IF Fifo_Empty_Tmp = '0' AND En = '1' THEN			----上升沿
						nCS <= '0';
						Curr_State <= ReadFifo;
					ELSE
						Curr_State <= Idle;
					END IF;
				WHEN ReadFifo =>
					IF Fifo_DataReady = '1' THEN
						Curr_State <= LockFifoData;
					ELSE
						Curr_State <= ReadFifo;
					END IF;
				WHEN LockFifoData =>
					Curr_State <= Enable_nCS;
				WHEN Enable_nCS =>
					nCS <= '0';
					Curr_State <= Sending;
				WHEN Sending =>
					IF SendDone = '1' THEN
						IF Fifo_Empty_Tmp = '0' THEN--如果FIFO非空，说明一帧还未发完，nCS信号仍然为低
							Curr_State <= Idle;
						ELSE
							Curr_State <= Disable_nCS;
						END IF;
					ELSE
						Curr_State <= Sending;
					END IF;
				WHEN Disable_nCS =>
					nCS <= '1';
					Curr_State <= Idle;
				WHEN OTHERS =>
					Curr_State <= Idle;
					nCS <= '1';
			END CASE;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk_Fifo)
	BEGIN
		IF nRst = '0' THEN
			Fifo_Rd <= '0';
		ELSIF Clk_Fifo'EVENT AND Clk_Fifo = '0' THEN
			IF Curr_State = ReadFifo AND Fifo_Rd = '0' THEN
				Fifo_Rd <= '1';
			ELSE
				Fifo_Rd <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clk_Fifo)
	BEGIN
		IF Clk_Fifo'EVENT AND Clk_Fifo = '1' THEN
			Fifo_DataReady <= Fifo_Rd;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			Data_Reg <= (OTHERS => '0');
			Sended_Count <= (OTHERS => '0');
			SDO <= '0';
			SCK_Tmp <= '0';
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
			IF Curr_State = Idle THEN
				SDO <= '0';
				SCK_Tmp <= '0';
				Sended_Count <= (OTHERS => '0');
			ELSIF Curr_State = LockFifoData THEN
				Data_Reg <= Fifo_q;
			ELSIF Curr_State = Sending THEN
				IF TimeCounter = "00000000" THEN
					Data_Reg <= Data_Reg(DataWidth-2 DOWNTO 0)&'0';
					SDO <= Data_Reg(DataWidth-1);
					Sended_Count <= Sended_count(DataWidth-2 DOWNTO 0)&'1';
				END IF;
				IF TimeCounter(6 DOWNTO 0) = FreqDiv(7 DOWNTO 1) OR TimeCounter = "00000000" THEN
					SCK_Tmp <= NOT SCK_Tmp;
				END IF;
				IF TimeCounter = FreqDiv THEN
					TimeCounter <= "00000000";
				ELSE
					TimeCounter <= TimeCounter + "00000000";
				END IF;
			END IF;
		END IF;
	END PROCESS;
	SCK <= SCK_Tmp;
--	
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			SendDone <= '0';
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
			IF Sended_count(DataWidth-1) = '1' AND TimeCounter = FreqDiv THEN
				SendDone <= '1';
			ELSE
				SendDone <= '0';
			END IF;
		END IF;
	END PROCESS;
END bhv_SpiSender;