LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY ALTERA_MF;
USE ALTERA_MF.ALL;

ENTITY AsyncSender IS
GENERIC(DataWidth:NATURAL:=8);
PORT (
	nRst:IN	STD_LOGIC;
	En:IN		STD_LOGIC;
	Clk_FSM:IN	STD_LOGIC;
	Clk_Fifo:IN STD_LOGIC;
	FreqDiv:IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
	Txd:OUT	STD_LOGIC;
	
	Fifo_Wr:IN  STD_LOGIC;
	Fifo_DataIn:IN STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
	Fifo_Clr:IN STD_LOGIC;
	Fifo_Empty:OUT	STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_AsyncSender OF AsyncSender IS

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

SIGNAL Fifo_Full:STD_LOGIC;
SIGNAL Fifo_Empty_Tmp:STD_LOGIC;
SIGNAL Fifo_Rd:STD_LOGIC;
SIGNAL Fifo_q:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);

CONSTANT Idle:STD_LOGIC_VECTOR(2 DOWNTO 0):="000";
CONSTANT ReadFifo:STD_LOGIC_VECTOR(2 DOWNTO 0):="001";
CONSTANT LockFifoData:STD_LOGIC_VECTOR(2 DOWNTO 0):="010";
CONSTANT Sending:STD_LOGIC_VECTOR(2 DOWNTO 0):="011";
CONSTANT DelayOneClk:STD_LOGIC_VECTOR(2 DOWNTO 0):="100";
CONSTANT DelayTwoClk:STD_LOGIC_VECTOR(2 DOWNTO 0):="101";

SIGNAL Curr_State:STD_LOGIC_VECTOR(2 DOWNTO 0):=Idle;

SIGNAL ReadFifoDone:STD_LOGIC;
SIGNAL SendDone:STD_LOGIC;
SIGNAL Sended_Count:STD_LOGIC_VECTOR(DataWidth+2 DOWNTO 0);
SIGNAL TimeCounter:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL Data_Reg:STD_LOGIC_VECTOR(DataWidth+1 DOWNTO 0);

BEGIN
	Component_AsyncSendFifo:scfifo
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
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '1' THEN
			CASE Curr_State IS
				WHEN Idle => --空闲状态，响应外部写信号
					IF Fifo_Empty_Tmp = '0' AND En = '1' THEN
						Curr_State <= ReadFifo;
					ELSE
						Curr_State <= Idle;
					END IF;
				WHEN ReadFifo =>
					IF ReadFifoDone = '1' THEN
						Curr_State <= LockFifoData;
					END IF;
				WHEN LockFifoData =>
					Curr_State <= Sending;
				WHEN Sending => --等待发送完毕信号
					IF Sended_Count(DataWidth+2) = '1' THEN
						Curr_State <= DelayOneClk;
					ELSE
						Curr_State <= Sending;
					END IF;
				WHEN DelayOneClk => --延迟一个时钟周期
					Curr_State <= DelayTwoClk;
				WHEN DelayTwoClk =>
					Curr_State <= Idle;
				WHEN OTHERS =>
					Curr_State <= Idle;
			END CASE;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk_Fifo)
	BEGIN
		IF nRst = '0' THEN
			Fifo_Rd <= '0';
		ELSIF Clk_Fifo'EVENT AND Clk_Fifo = '0' THEN
			IF Curr_State = ReadFifo THEN
				Fifo_Rd <= '1';
			ELSE
				Fifo_Rd <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clk_Fifo)
	BEGIN
		IF Clk_Fifo = '1' THEN
			ReadFifoDone <= Fifo_Rd;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			Data_Reg <= (OTHERS => '1');
			Sended_Count <= (OTHERS => '0');
			Txd <= '1';
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
			IF Curr_State = Idle THEN
				Txd <= '1';
				Sended_Count <= (OTHERS => '0');
			ELSIF Curr_State = LockFifoData THEN
				Data_Reg <= '1'&Fifo_q&'0';
			ELSIF TimeCounter = FreqDiv THEN---这样判断，第一个字节会延后一个周期
				Data_Reg(DataWidth+1 DOWNTO 0) <= '1'&Data_Reg(DataWidth+1 DOWNTO 1);
				Txd <= Data_Reg(0);
				Sended_Count <= Sended_Count(DataWidth+1 DOWNTO 0)&'1';
			END IF;
		END IF;
	END PROCESS;

	
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			TimeCounter <= X"01";
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
			IF Curr_State /= Sending THEN
				TimeCounter <= X"01";
			ELSIF TimeCounter = FreqDiv THEN
				TimeCounter <= X"01";
			ELSE
				TimeCounter <= TimeCounter + X"01";
			END IF;
		END IF;
	END PROCESS;

END bhv_AsyncSender;