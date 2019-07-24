LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY ALTERA_MF;
USE ALTERA_MF.ALL;

ENTITY SlaveSyncSerial IS
PORT (
	nRst:IN		STD_LOGIC;
	Clk_Fifo:IN STD_LOGIC;
	Clk_FSM:IN	STD_LOGIC;
	EnSend:IN	STD_LOGIC;
	------------Send&recv port -----------
	Rxd:IN	STD_LOGIC;
	Txd:OUT	STD_LOGIC;
	SClk:IN	STD_LOGIC;
	CheckOKPulse:OUT	STD_LOGIC;--校验正确指示脉冲
	FrmFlag:IN	STD_LOGIC;--帧定义，为0时，10个字为1帧，为1时，12个字为1帧
	-----------RecvFifo port------------
	RecvFifo_Rd:IN  STD_LOGIC;
	RecvFifo_DataOut:OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	RecvFifo_Usedw:BUFFER STD_LOGIC_VECTOR(9 DOWNTO 0);
	RecvFifo_Clr:IN	STD_LOGIC;
	-----------SendFifo Port-----------
	SendFifo_Wr:IN  STD_LOGIC;
	SendFifo_DataIn:IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	SendFifo_Clr:IN STD_LOGIC;
	SendFifo_Empty:OUT STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_SlaveSyncSerial OF SlaveSyncSerial IS

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

COMPONENT PulseTransmitter IS
GENERIC (Level:STD_LOGIC:='1');
PORT (
	nRst:IN			STD_LOGIC;
	En:IN				STD_LOGIC;
	Clk:IN			STD_LOGIC;
	Wr:IN				STD_LOGIC;
	PulseWidth:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulsePeriod:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulseCount:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	Txd:OUT			STD_LOGIC
);
END COMPONENT;

CONSTANT DataWidth:NATURAL:=8;
TYPE T_A_Data IS ARRAY(NATURAL RANGE<>) OF STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
-----------------接收信号
CONSTANT Idle:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
CONSTANT Recving:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT WriteFifo:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
CONSTANT GenCheckSum:STD_LOGIC_VECTOR(1 DOWNTO 0):="11";

SIGNAL Curr_State_Recv:STD_LOGIC_VECTOR(1 DOWNTO 0):=Idle;
SIGNAL Reced_Count:NATURAL RANGE 0 TO 15;

SIGNAL RecvDataDone:STD_LOGIC;
SIGNAL DataReg_Recv:STD_LOGIC_VECTOR(DataWidth DOWNTO 0);
SIGNAL SClk_Tmp:STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL GettedSyncHeader:STD_LOGIC;
----------------发送信号
CONSTANT ReadFifo:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT Sending:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
CONSTANT Delay:STD_LOGIC_VECTOR(1 DOWNTO 0):="11";

SIGNAL Curr_State_Send:STD_LOGIC_VECTOR(1 DOWNTO 0):=Idle;
SIGNAL Sended_Count:STD_LOGIC_VECTOR(DataWidth+1 DOWNTO 0);
SIGNAL DataReg_Send:STD_LOGIC_VECTOR(DataWidth+1 DOWNTO 0);
SIGNAL DelayCounter:STD_LOGIC_VECTOR(5 DOWNTO 0);
-------------------recv signals---------------------------
SIGNAL RecvFifo_Wr:STD_LOGIC;
SIGNAL WriteFifoDone:STD_LOGIC;
SIGNAL RecvFifo_Full:STD_LOGIC;
SIGNAL RecvFifo_Empty:STD_LOGIC;
SIGNAL RecvFifo_Datain:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
------------------send signals--------------------------------
SIGNAL SendFifo_Rd:STD_LOGIC;
SIGNAL SendFifo_Full:STD_LOGIC;
SIGNAL SendFifo_Dataout:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
SIGNAL SendFifo_Empty_Tmp:STD_LOGIC;

------------------check ok signals
SIGNAL UUT_PulseCheckOK_Wr:STD_LOGIC;
SIGNAL UUT_PulseCheckOK_Wr_Tmp:STD_LOGIC;
SIGNAL UUT_PulseCheckOK_Wr_Tmp_Reg:STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL CheckSum:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
SIGNAL CheckSumRecv:STD_LOGIC_VECTOR(DataWidth-1 DOWNTO 0);
BEGIN
-----------------------------slave recv------------------------
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			Curr_State_Recv <= Idle;
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '1' THEN
			CASE Curr_State_Recv IS
				WHEN Idle =>
					IF GettedSyncHeader = '1' THEN
						Curr_State_Recv <= Recving;
					END IF;
				WHEN Recving =>
					IF RecvDataDone = '1' THEN
						Curr_State_Recv <= WriteFifo;
					ELSE
						Curr_State_Recv <= Recving;
					END IF;
				WHEN WriteFifo =>
					IF WriteFifoDone = '1' THEN
						Curr_State_Recv <= Idle;
					ELSE
						Curr_State_Recv <= WriteFifo;
					END IF;
				WHEN OTHERS => 
					Curr_State_Recv <= Idle;
			END CASE;
		END IF;
	END PROCESS;
	--------采样SCK信号
	PROCESS(Clk_FSM)
	BEGIN
		IF Clk_FSM'EVENT AND Clk_FSM = '1' THEN
			SClk_Tmp <= SClk_Tmp(0)&SClk;
		END IF;
	END PROCESS;
	-------在SCK信号的下降沿进行移入操作
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			Reced_Count <= 0;
			GettedSyncHeader <= '0';
			RecvDataDone <= '1';
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
			IF SClk_Tmp = "10" THEN
				IF Curr_State_Recv = Idle THEN---detect header
					IF Rxd = '0' THEN
						GettedSyncHeader <= '1';
						Reced_Count <= 0;
						RecvDataDone <= '0';
					ELSE
						GettedSyncHeader <= '0';
					END IF;						
				ELSE
					GettedSyncHeader <= '0';
					DataReg_Recv(DataWidth DOWNTO 0) <= DataReg_Recv(DataWidth-1 DOWNTO 0)&Rxd;
					IF Reced_Count = DataWidth+1 THEN
						RecvDataDone <= '1';
						RecvFifo_Datain <= DataReg_Recv(DataWidth DOWNTO 1);
					ELSE
						Reced_Count <= Reced_Count+1;
						RecvDataDone <= '0';
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(nRst, Clk_Fifo)
	BEGIN
		IF nRst = '0' THEN
			RecvFifo_Wr <= '0';
		ELSIF Clk_Fifo'EVENT AND Clk_Fifo = '0' THEN
			IF Curr_State_Recv = WriteFifo THEN
				RecvFifo_Wr <= '1';
			ELSE
				RecvFifo_Wr <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk_Fifo)
	BEGIN
		IF nRst = '0' THEN
			WriteFifoDone <= '0';
		ELSIF Clk_Fifo'EVENT AND Clk_Fifo = '1' THEN
			IF RecvFifo_Wr = '1' THEN
				WriteFifoDone <= '1';
			ELSE
				WriteFifoDone <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	Component_RecvFifo:scfifo
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
	
	------------校验旁路逻辑，记录收到的数据个数，判断是否收完一帧
	PROCESS(nRst, Clk_Fifo)--记录收到的数据
	BEGIN
		IF nRst = '0' THEN
			CheckSum <= (OTHERS => '0');
		ELSIF Clk_Fifo'EVENT AND Clk_Fifo = '1' THEN
			IF RecvFifo_Usedw = "0000000000" THEN
				CheckSum <= (OTHERS => '0');
			ELSIF RecvFifo_Wr = '1' AND RecvFifo_Usedw > "0000000000" AND RecvFifo_Usedw < "0000001001" AND FrmFlag = '1' THEN--从1加到10
				CheckSum(0) <= CheckSum(0) XOR RecvFifo_Datain(0);
				CheckSum(1) <= CheckSum(1) XOR RecvFifo_Datain(1);
				CheckSum(2) <= CheckSum(2) XOR RecvFifo_Datain(2);
				CheckSum(3) <= CheckSum(3) XOR RecvFifo_Datain(3);
				CheckSum(4) <= CheckSum(4) XOR RecvFifo_Datain(4);
				CheckSum(5) <= CheckSum(5) XOR RecvFifo_Datain(5);
				CheckSum(6) <= CheckSum(6) XOR RecvFifo_Datain(6);
				CheckSum(7) <= CheckSum(7) XOR RecvFifo_Datain(7);
			ELSIF RecvFifo_Wr = '1' AND RecvFifo_Usedw > "0000000000" AND RecvFifo_Usedw < "0000000111" AND FrmFlag = '0' THEN
				CheckSum(0) <= CheckSum(0) XOR RecvFifo_Datain(0);
				CheckSum(1) <= CheckSum(1) XOR RecvFifo_Datain(1);
				CheckSum(2) <= CheckSum(2) XOR RecvFifo_Datain(2);
				CheckSum(3) <= CheckSum(3) XOR RecvFifo_Datain(3);
				CheckSum(4) <= CheckSum(4) XOR RecvFifo_Datain(4);
				CheckSum(5) <= CheckSum(5) XOR RecvFifo_Datain(5);
				CheckSum(6) <= CheckSum(6) XOR RecvFifo_Datain(6);
				CheckSum(7) <= CheckSum(7) XOR RecvFifo_Datain(7);
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clk_Fifo)
	BEGIN
		IF Clk_Fifo'EVENT AND Clk_Fifo = '1' THEN
			IF RecvFifo_Wr = '1' AND RecvFifo_Usedw = "0000001010" AND FrmFlag = '1' THEN
				CheckSumRecv <= RecvFifo_Datain;
			ELSIF RecvFifo_Wr = '1' AND RecvFifo_Usedw = "0000001000" AND FrmFlag = '0' THEN
				CheckSumRecv <= RecvFifo_Datain;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk_Fifo)
	BEGIN
		IF nRst = '0' THEN
			UUT_PulseCheckOK_Wr_Tmp <= '0';
		ELSIF Clk_Fifo'EVENT AND Clk_Fifo = '0' THEN
			IF RecvFifo_Usedw = "0000001100" AND FrmFlag = '1' THEN---收到12个数据，判断校验和是否相等
				IF CheckSum = CheckSumRecv THEN
					UUT_PulseCheckOK_Wr_Tmp <= '1';
				ELSE
					UUT_PulseCheckOK_Wr_Tmp <= '0';
				END IF;
			ELSIF RecvFifo_Usedw = "0000001010" AND FrmFlag = '0' THEN
				IF CheckSum = CheckSumRecv THEN
					UUT_PulseCheckOK_Wr_Tmp <= '1';
				ELSE
					UUT_PulseCheckOK_Wr_Tmp <= '0';
				END IF;
			ELSE
				UUT_PulseCheckOK_Wr_Tmp <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clk_Fifo)
	BEGIN
		IF Clk_Fifo'EVENT AND Clk_Fifo = '0' THEN
			UUT_PulseCheckOK_Wr_Tmp_Reg <= UUT_PulseCheckOK_Wr_Tmp_Reg(0)&UUT_PulseCheckOK_Wr_Tmp;
		END IF;
	END PROCESS;
	
	PROCESS(Clk_Fifo)
	BEGIN
		IF Clk_Fifo'EVENT AND Clk_Fifo = '1' THEN
			IF UUT_PulseCheckOK_Wr_Tmp_Reg = "01" THEN
				UUT_PulseCheckOK_Wr <= '1';
			ELSE
				UUT_PulseCheckOK_Wr <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	------------校验正确指示信号，输出1us脉冲
	UUT_PulseCheckOK:PulseTransmitter 
	PORT MAP (
		nRst => nRst,
		Clk => Clk_Fifo,--40m
		En => '1',
		Wr => UUT_PulseCheckOK_Wr,
		PulseWidth => X"00029",
		PulsePeriod => X"FFFFF",
		PulseCount => X"00001",
		Txd => CheckOKPulse
	);

	Component_SendFifo:scfifo
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
					Curr_State_Send <= Sending;
				WHEN Sending =>
					IF Sended_Count(DataWidth+1) = '1' THEN
						Curr_State_Send <= Delay;
					ELSE
						Curr_State_Send <= Sending;
					END IF;
				WHEN Delay =>
					IF DelayCounter(5) = '1' THEN
						Curr_State_Send <= Idle;
					ELSE
						Curr_State_Send <= Delay;
					END IF;
				WHEN OTHERS =>
					Curr_State_Send <= Idle;
			END CASE;
		END IF;
	END PROCESS;

	PROCESS(Clk_FSM)
	BEGIN
		IF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
			IF Curr_State_Send = Delay THEN
				DelayCounter <= DelayCounter(4 DOWNTO 0)&'1';
			ELSE
				DelayCounter <= (OTHERS => '0');
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clk_Fifo)
	BEGIN
		IF Clk_Fifo'EVENT AND Clk_Fifo = '0' THEN
			IF Curr_State_Send = ReadFifo THEN
				SendFifo_Rd <= '1';
			ELSE
				SendFifo_Rd <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk_FSM)
	BEGIN
		IF nRst = '0' THEN
			DataReg_Send <= (OTHERS => '1');
			Txd <= '1';
			Sended_Count <= (OTHERS => '0');
		ELSIF Clk_FSM'EVENT AND Clk_FSM = '0' THEN
			IF SendFifo_Rd = '1' THEN
				Sended_Count <= (OTHERS => '0');
				DataReg_Send <= '0'&SendFifo_Dataout&'1';
			ELSIF Curr_State_Send = Sending AND SClk_Tmp = "01" THEN---rising edge
				IF Sended_Count(DataWidth+1) = '0' THEN
					Txd <= DataReg_Send(DataWidth+1);
					DataReg_Send <= DataReg_Send(DataWidth DOWNTO 0)&'1';
					Sended_Count <= Sended_Count(DataWidth DOWNTO 0)&'1';
				ELSE
					Txd <= '1';
				END IF;
			END IF;
		END IF;
	END PROCESS;

END bhv_SlaveSyncSerial;