LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY ALTERA_MF;
USE ALTERA_MF.ALL;
---------上升沿发，下降沿收
ENTITY MasterSyncSerial IS
PORT (
	nRst:IN		STD_LOGIC;
	En:IN			STD_LOGIC;
	Clk_FSM: IN		STD_LOGIC;
	Clk_Fifo:IN	STD_LOGIC;
	FreqDiv:IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
	-----------sender port------------
	Txd:	OUT	STD_LOGIC;
	Rxd:	IN		STD_LOGIC;
	SClk:	BUFFER	STD_LOGIC;
	-----------send Fifo port-----------
	SendFifo_Wr:IN  STD_LOGIC;
	SendFifo_Datain:IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	SendFifo_Clr:IN	STD_LOGIC;
	SendFifo_Empty:OUT STD_LOGIC;
	-----------recv fifo port-----------
	RecvFifo_Rd:IN	STD_LOGIC;
	RecvFifo_DataOut:OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
	RecvFifo_Usedw:OUT	STD_LOGIC_VECTOR(9 DOWNTO 0);
	RecvFifo_Clr:IN	STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_MasterSyncSerial OF MasterSyncSerial IS

COMPONENT scfifo
  GENERIC ( LPM_WIDTH: POSITIVE;
            LPM_WIDTHU: POSITIVE;
            LPM_NUMWORDS: POSITIVE;
				LPM_SHOWAHEAD:STRING:="OFF");
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
-------------------------发送逻辑信号---------------------------
attribute keep:boolean;
CONSTANT DataWidth:NATURAL:=8;
CONSTANT Idle:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
CONSTANT ReadFifo:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT LockFifoData:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
CONSTANT Sending:STD_LOGIC_VECTOR(1 DOWNTO 0):="11";

SIGNAL Curr_State_Send:STD_LOGIC_VECTOR(1 DOWNTO 0):=Idle;
SIGNAL Sended_Count:STD_LOGIC_VECTOR(DataWidth+2 DOWNTO 0);
SIGNAL TimeCounter:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL SendStart, SendDone:STD_LOGIC;
SIGNAL DataReg_Send:STD_LOGIC_VECTOR(DataWidth+1 DOWNTO 0);
SIGNAL SClk_Tmp:STD_LOGIC;

SIGNAL SendFifo_Rd:STD_LOGIC;
SIGNAL SendFifo_Full:STD_LOGIC;
SIGNAL SendFifo_Dataout:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
SIGNAL SendFifo_Empty_Tmp:STD_LOGIC;
SIGNAL LockedSendData:STD_LOGIC;
SIGNAL Fifo_DataReady:STD_LOGIC;

-------------------------接收逻辑信号-----------------------------
CONSTANT Recving:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT LockRecvData:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
CONSTANT WriteFifo:STD_LOGIC_VECTOR(1 DOWNTO 0):="11";
SIGNAL Curr_State_Recv:STD_LOGIC_VECTOR(1 DOWNTO 0):=Idle;

SIGNAL Reced_Count:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO  0);
SIGNAL RecvDataStart:STD_LOGIC;
SIGNAL RecvDataDone:STD_LOGIC;
SIGNAL DataReg_Recv:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
SIGNAL RxClkForRecv:STD_LOGIC;
SIGNAL DetectedHeader:STD_LOGIC;
SIGNAL RecvFifo_Wr:STD_LOGIC;
SIGNAL WriteFifoDone:STD_LOGIC;
SIGNAL RecvFifo_Datain:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
SIGNAL RecvFifo_Empty:STD_LOGIC;
SIGNAL RecvFifo_Full:STD_LOGIC;
SIGNAL WriteRecvFifoDone:STD_LOGIC;
attribute keep of SendFifo_Dataout:SIGNAL IS TRUE;
BEGIN
----------------------master send-----------------------
SendFifo:scfifo
GENERIC MAP (
	LPM_WIDTH => DataWidth,
	LPM_WIDTHU => 10,
	LPM_NUMWORDS => 1024)
PORT MAP (
  data   => SendFifo_Datain,
  clock  => Clk_Fifo,
  wrreq  => SendFifo_Wr,
  rdreq  => SendFifo_Rd,
  aclr   => SendFifo_Clr,
  empty  => SendFifo_Empty_Tmp,
  FULL   => SendFifo_Full,
  q      => SendFifo_Dataout
);
SendFifo_Empty <= SendFifo_Empty_Tmp;
----------------发送逻辑----------------
PROCESS(nRst, Clk_FSM)
BEGIN
	IF nRst = '0' THEN
		Curr_State_Send <= Idle;
	ELSIF Clk_FSM'EVENT AND Clk_FSM = '1' THEN
		CASE Curr_State_Send IS
			WHEN Idle => 
				IF SendFifo_Empty_Tmp = '0' THEN
					Curr_State_Send <= ReadFifo;
				ELSE
					Curr_State_Send <= Idle;
				END IF;
			WHEN ReadFifo =>
				IF Fifo_DataReady = '1' THEN
					Curr_State_Send <= LockFifoData;
				END IF;
			WHEN LockFifoData => 
				Curr_State_Send <= Sending;
			WHEN Sending =>
				IF Sended_Count(DataWidth+2) = '1' THEN
					Curr_State_Send <= Idle;
				END IF;
			WHEN OTHERS =>
				Curr_State_Send <= Idle;
		END CASE;
	END IF;
END PROCESS;

PROCESS(nRst, Clk_Fifo)
BEGIN
	IF nRst = '0' THEN
		SendFifo_Rd <= '0';
	ELSIF Clk_Fifo'EVENT AND Clk_Fifo = '0' THEN
		IF Curr_State_Send = ReadFifo AND SendFifo_Rd = '0' THEN
			SendFifo_Rd <= '1';
		ELSE
			SendFifo_Rd <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(Clk_Fifo)
BEGIN
	IF Clk_Fifo'EVENT AND Clk_Fifo = '1' THEN
		Fifo_DataReady <= SendFifo_Rd;
	END IF;
END PROCESS;

PROCESS(nRst, Clk_FSM)
BEGIN
	IF nRst = '0' THEN
		DataReg_Send <= (OTHERS => '1');
		Txd <= '1'; 
		Sended_Count <= (OTHERS => '0');
	ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
		IF Curr_State_Send = LockFifoData THEN
			DataReg_Send <= '0'&SendFifo_Dataout&'1';
			Sended_Count <= (OTHERS => '0');
			Txd <= '1';
		ELSIF Curr_State_Send = Sending THEN
			IF TimeCounter = FreqDiv THEN
				Sended_Count <= Sended_Count(DataWidth+1 DOWNTO 0)&'1';
				DataReg_Send <= DataReg_Send(DataWidth DOWNTO 0)&'1';
				Txd <= DataReg_Send(DataWidth+1);
			END IF;
		ELSE
			Txd <= '1';
		END IF;
	END IF;
END PROCESS;

PROCESS(nRst,Clk_FSM)
BEGIN
	IF nRst = '0' THEN
		TimeCounter <= FreqDiv;
		SClk_Tmp <= '0';
	ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
		IF TimeCounter = FreqDiv THEN
			TimeCounter <= X"01";
		ELSE
			TimeCounter <= TimeCounter + X"01";
		END IF;

		IF TimeCounter = FreqDiv OR (TimeCounter(7) = '0' AND TimeCounter(6 DOWNTO 0) = FreqDiv(7 DOWNTO 1)) THEN
			SClk_Tmp <= NOT SClk_Tmp;
		END IF;
	END IF;
END PROCESS;

SClk <= SClk_Tmp WHEN En = '1' ELSE '0';
-----------------------接收逻辑-------------------------------
PROCESS(nRst, Clk_FSM)
BEGIN
	IF nRst = '0' THEN
		Curr_State_Recv <= Idle;
	ELSIF Clk_FSM'EVENT AND Clk_FSM = '1' THEN
		CASE Curr_State_Recv IS
			WHEN Idle =>
				IF DetectedHeader = '1' THEN
					Curr_State_Recv <= Recving;
				ELSE     
					Curr_State_Recv <= Idle;
				END IF;
			WHEN Recving =>     
				IF Reced_Count(DataWidth-1) = '1' THEN
					Curr_State_Recv <= WriteFifo;
					RecvFifo_Datain <= DataReg_Recv;
				ELSE
					Curr_State_Recv <= Recving;
				END IF;
			WHEN WriteFifo =>
				IF WriteRecvFifoDone = '1' THEN
					Curr_State_Recv <= Idle;
				END IF;
			WHEN OTHERS =>
				Curr_State_Recv <= Idle;
		END CASE;
	END IF;
END PROCESS;
--
PROCESS(nRst, Clk_FSM)
BEGIN
	IF nRst = '0' THEN
		DetectedHeader <= '0';
	ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
		IF TimeCounter = 5 AND Rxd = '0' THEN--下降沿，收到低电平
			DetectedHeader <= '1';
		ELSE
			DetectedHeader <= '0';
		END IF;
	END IF;		
END PROCESS;
--
PROCESS(nRst, Clk_FSM)
BEGIN
	IF nRst = '0' THEN
		DataReg_Recv <= (OTHERS => '0');
		Reced_Count <= (OTHERS => '0');
	ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
		IF Curr_State_Recv = Recving THEN
			IF TimeCounter = 5 AND Reced_Count(DataWidth-1) = '0' THEN
				DataReg_Recv(DataWidth-1 DOWNTO 0) <= DataReg_Recv(DataWidth-2 DOWNTO 0)&Rxd;
				Reced_Count <= Reced_Count(DataWidth-2 DOWNTO 0)&'1';
			END IF;
		ELSE
			Reced_Count <= (OTHERS => '0');
		END IF;
	END IF;		
END PROCESS;

PROCESS(nRst, Clk_Fifo)
BEGIN
	IF nRst = '0' THEN
		RecvFifo_Wr <= '0';
	ELSIF Clk_Fifo'EVENT AND Clk_Fifo = '0' THEN
		IF Curr_State_Recv = WriteFifo AND RecvFifo_Wr = '0' THEN
			RecvFifo_Wr <= '1';
		ELSE
			RecvFifo_Wr <= '0';
		END IF;
	END IF;	
END PROCESS;

PROCESS(Clk_Fifo)
BEGIN
	IF Clk_Fifo'EVENT AND Clk_Fifo = '1' THEN
		WriteRecvFifoDone <= RecvFifo_Wr;
	END IF;
END PROCESS;
--
-------------------------master recv---------------------------
RecvFifo:scfifo
GENERIC MAP (LPM_WIDTH => DataWidth,
            LPM_WIDTHU => 10,
            LPM_NUMWORDS => 1024,
				LPM_SHOWAHEAD => "ON")
PORT MAP (data   => RecvFifo_Datain(DataWidth-1 DOWNTO 0),
		clock  => Clk_Fifo,
		wrreq  => RecvFifo_Wr,
		rdreq  => RecvFifo_Rd,
		aclr   => RecvFifo_Clr,
		empty  => RecvFifo_Empty,
		FULL   => RecvFifo_Full,
		q      => RecvFifo_DataOut,
		usedw  => RecvFifo_Usedw
);

END bhv_MasterSyncSerial;