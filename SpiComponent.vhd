LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

--------@fun SPI Master Sender----------------
--@Generic Data_width:		发送数据宽度（注意：内部不自动生成无起始位，结束位及校验位）
--@Generic Shift_clklevel:	在clk上升沿发送还是在下降沿发送数据（0：下降沿发送，1：上升沿发送）
--@Generic Idle_State:		发送数据线空闲时，置为的状态,可为'U','Z','1','0'等。
ENTITY SPI_MASTER_SENDER IS		
GENERIC (Data_width		: NATURAL 	:= 8;
		 Idle_state		: STD_LOGIC := '1';
		 Shift_clklevel	:STD_LOGIC:= '1');
PORT (
	nRst 	:IN 	STD_LOGIC;--复位信号
	Clk		:IN 	STD_LOGIC;--inner logic work clk(state machine work clk)
	TxClk	:IN		STD_LOGIC;--Clock for send
	En   	:IN 	STD_LOGIC;	
	Wr		:IN 	STD_LOGIC;--写信号
	Data_in	:IN		STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0);--写入的数据
	Ready  	:BUFFER STD_LOGIC;--组件是否准备好发送（之前的数据发送完即准备好），高有效
	
	SDO		:OUT	STD_LOGIC;
	nCS		:OUT	STD_LOGIC;
	SCK		:BUFFER	STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_SPI_MASTER_SENDER OF SPI_MASTER_SENDER IS
TYPE State IS (Idle, Enable_nCS, Send_DataAndSCK, WaitForSendDone, DisEnable_nCS);
SIGNAL Curr_State:State;
SIGNAL Sended_count:NATURAL RANGE 0 TO 255;
SIGNAL SendStart:STD_LOGIC;
SIGNAL SendDone:STD_LOGIC;
SIGNAL EnTxClk:STD_LOGIC;
SIGNAL DataReg_Wr:STD_LOGIC;
SIGNAL Clr_ClkEdgeCount:STD_LOGIC;
SIGNAL SCK_FallEdgeCount:NATURAL RANGE 0 TO 255;
SIGNAL TxClkForSend:STD_LOGIC;
SIGNAL Data_reg:STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0);

BEGIN
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			Curr_State <= Idle;
			EnTxClk <= '0';
			Ready <= '0';
			DataReg_Wr<= '0';
			SendStart <= '0';
			nCS <= '1';
			Clr_ClkEdgeCount <= '0';
		ELSIF Clk'EVENT AND Clk = '1' THEN
			CASE Curr_state IS
				WHEN Idle =>
					EnTxClk <= '0';
					IF Wr = '1' AND En = '1' THEN			----上升沿
						Ready <= '0';
						DataReg_Wr<= '1';
						SendStart <= '0';
						nCS <= '1';
						Clr_ClkEdgeCount <= '1';
						Curr_State <= Enable_nCS;
					ELSE
						Ready <= '1';
						DataReg_Wr <= '0';
						SendStart <= '0';
						nCS <= '1';
						Clr_ClkEdgeCount <= '0';
						Curr_State <= Idle;
					END IF;
				WHEN Enable_nCS =>
					Ready <= '0';
					DataReg_Wr <= '0';
					SendStart <= '0';
					EnTxClk <= '0';
					Clr_ClkEdgeCount <= '0';
					nCS <= '0';
					Curr_State <= Send_DataAndSCK;
				WHEN Send_DataAndSCK =>
					Ready <= '0';
					EnTxClk <= '1';
					DataReg_Wr <= '0';
					SendStart <= '1';
					nCS <= '0';
					Clr_ClkEdgeCount <= '0';
					Curr_State <= WaitForSendDone;
				WHEN WaitForSendDone =>
					Ready <= '0';
					EnTxClk <= '1';
					DataReg_Wr <= '0';
					SendStart <= '0';
					nCS <= '0';
					Clr_ClkEdgeCount <= '0';
					IF SendDone = '1' THEN
						Curr_State <= DisEnable_nCS;
					ELSE
						Curr_State <= WaitForSendDone;
					END IF;
				WHEN DisEnable_nCS =>
					Ready <= '0';
					DataReg_Wr <= '0';
					SendStart <= '0';
					nCS <= '1';
					EnTxClk <= '0';
					Clr_ClkEdgeCount <= '0';
					Curr_State <= Idle;
				WHEN OTHERS =>
					Curr_State <= Idle;
					EnTxClk <= '0';
					Ready <= '0';
					DataReg_Wr<= '0';
					SendStart <= '0';
					nCS <= '1';
					Clr_ClkEdgeCount <= '0';
			END CASE;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, SendDone, TxClk)
	BEGIN
		IF nRst = '0' OR SendDone = '1' THEN
			SCK <= (NOT Shift_clklevel);
			TxClkForSend <= (NOT Shift_clklevel);
		ELSIF TxClk'EVENT AND TxClk = '1' THEN
			IF EnTxClk = '1' AND SCK_FallEdgeCount < Data_Width THEN
				SCK <= NOT SCK;
			ELSE
				SCK <= (NOT Shift_clklevel);
			END IF;
			
			IF EnTxClk = '1' THEN
				TxClkForSend <= NOT TxClkForSend;
			ELSE
				TxClkForSend <= (NOT Shift_clklevel);
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, TxClkForSend)
	BEGIN
		IF nRst = '0' THEN 
			SDO <= Idle_state;
		ELSIF TxClkForSend'EVENT AND TxClkForSend = Shift_clklevel THEN
			IF SendDone = '0' THEN
				SDO <= Data_Reg(Data_Width - 1);
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, DataReg_Wr, TxClkForSend)
	BEGIN
		IF nRst = '0' THEN
			Data_Reg <= (OTHERS => Idle_state);
		ELSIF DataReg_Wr = '1' THEN
			Data_Reg <= Data_In;
		ELSIF TxClkForSend'EVENT AND TxClkForSend = Shift_clklevel THEN
			IF SendDone = '0' THEN
				Data_Reg <= Data_Reg(Data_Width-2 DOWNTO 0)&Idle_state;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, DataReg_Wr, TxClkForSend)
	BEGIN
		IF nRst = '0' OR DataReg_Wr = '1' THEN
			Sended_Count <= 0;
		ELSIF TxClkForSend'EVENT AND TxClkForSend = Shift_clklevel THEN
			IF SendDone = '0' THEN
				Sended_Count <= Sended_Count + 1;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			SendDone <= '1';
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF SendStart = '1' THEN
				SendDone <= '0';
			ELSIF Sended_Count = (Data_Width+1) THEN
				SendDone <= '1';
			ELSE
				SendDone <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clr_ClkEdgeCount, SCK)
	BEGIN
		IF nRst = '0' OR Clr_ClkEdgeCount = '1' THEN
			SCK_FallEdgeCount <= 0;
		ELSIF SCK'EVENT AND SCK = (NOT Shift_clklevel) THEN
			SCK_FallEdgeCount <= SCK_FallEdgeCount + 1;
		END IF;
	END PROCESS;
END bhv_SPI_MASTER_SENDER;


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;


--------@fun SPI Master Receiver----------------
--@Generic Data_width:		recv data width
--@Generic Shift_clklevel:	在clk上升沿recv还是在下降沿recv数据（0：recv at arise level，1：recv at rise level）
ENTITY SPI_MASTER_RECEIVER IS		
GENERIC (Data_width		: NATURAL 	:= 8;
		 Shift_clklevel:STD_LOGIC:= '1');
PORT (
	nRst  	:IN 	STD_LOGIC;
	Clk		:IN		STD_LOGIC;
	RxClk	:IN		STD_LOGIC;
	En      :IN 	STD_LOGIC;
	StartRecv:IN		STD_LOGIC;--start to recv data
	Rd		:IN		STD_LOGIC;
	Ready	:BUFFER STD_LOGIC;
	Data_out:OUT	STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0);
	
	nCS		:OUT	STD_LOGIC;
	SCK		:BUFFER	STD_LOGIC;
	SDI		:IN		STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_SPI_MASTER_RECEIVER OF SPI_MASTER_RECEIVER IS
TYPE State IS (Idle, Enable_nCS, Send_SCK_And_RecvData, WaitForRecvDone, DisEnable_nCS, WaitForReadData);
SIGNAL Curr_State, Next_State:State;
SIGNAL Reced_Count:NATURAL RANGE 0 TO 255;
SIGNAL RecvStart:STD_LOGIC;
SIGNAL RecvDone:STD_LOGIC;
SIGNAL SCK_FallEdgeCount:NATURAL RANGE 0 TO 255;
SIGNAL RxClkForRecv:STD_LOGIC;
SIGNAL Data_reg:STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0);

BEGIN
	PROCESS(nRst, Clk)
	BEGIN
	IF nRst = '0' THEN
		Ready <= '0';
		nCS <= '1';
		RecvStart <= '0';
		Curr_state <= Idle;
	ELSIF Clk'EVENT AND Clk = '1' THEN
		CASE Curr_state IS
			WHEN Idle =>
				Ready <= '0';
				nCS <= '1';
				RecvStart <= '0';
				IF StartRecv = '1' AND En = '1' THEN
					Curr_state <= Enable_nCS;
				ELSE
					Curr_state <= Idle;
				END IF;
			WHEN Enable_nCS =>
				Ready <= '0';
				nCS <= '0';
				RecvStart <= '0';
				Curr_state <= Send_SCK_And_RecvData;
			WHEN Send_SCK_And_RecvData =>
				Ready <= '0';
				nCS <= '0';
				RecvStart <= '1';
				Curr_state <= WaitForRecvDone;
			WHEN WaitForRecvDone =>
				Ready <= '0';
				nCS <= '0';
				RecvStart <= '0';
				IF RecvDone = '1' THEN
					Curr_state <= DisEnable_nCS;
				ELSE
					Curr_state <= WaitForRecvDone;
				END IF;
			WHEN DisEnable_nCS =>
				Ready <= '0';
				nCS <= '1';
				RecvStart <= '0';
				Curr_state <= WaitForReadData;
			WHEN WaitForReadData =>
				Ready <= '1';
				nCS <= '1';
				RecvStart <= '0';
				IF Rd = '1' THEN
					Curr_state <= Idle;
				ELSE
					Curr_state <= WaitForReadData;
				END IF;
			END CASE;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, RecvStart, SCK)
	BEGIN
		IF nRst = '0' OR RecvStart = '1' THEN
			SCK_FallEdgeCount <= 0;
		ELSIF SCK'EVENT AND SCK = '0' THEN
			SCK_FallEdgeCount <= SCK_FallEdgeCount + 1;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, RxClk)
	BEGIN
		IF nRst = '0' THEN
			SCK <= (NOT Shift_clklevel);
			RxClkForRecv <= (NOT Shift_clklevel);
		ELSIF RxClk'EVENT AND RxClk = '1' THEN
			IF RecvDone = '0' AND SCK_FallEdgeCount < Data_Width THEN
				SCK <= NOT SCK;
			ELSE
				SCK <= (NOT Shift_clklevel);
			END IF;
			
			IF RecvDone = '0' THEN
				RxClkForRecv <= NOT RxClkForRecv;
			ELSE
				RxClkForRecv <= (NOT Shift_clklevel);
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, RecvStart, RxClkForRecv)
	BEGIN
		IF nRst = '0' OR RecvStart = '1' THEN
			Reced_Count <= 0;
		ELSIF RxClkForRecv'EVENT AND RxClkForRecv = Shift_clklevel THEN
			IF Reced_Count < Data_Width THEN
				Reced_Count <= Reced_Count + 1;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, RxClkForRecv)
	BEGIN
		IF nRst = '0' THEN
			Data_Reg <= (OTHERS => '0');
		ELSIF RxClkForRecv'EVENT AND RxClkForRecv = Shift_clklevel THEN
			IF Reced_Count < Data_Width THEN
				Data_Reg(0) <= SDI;
				Data_Reg(Data_Width - 1 DOWNTO 1) <= Data_Reg(Data_Width - 2 DOWNTO 0);
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			RecvDone <= '0';
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF Reced_Count = Data_Width THEN
				RecvDone <= '1';
			ELSE
				RecvDone <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, RecvDone)
	BEGIN
		IF nRst = '0' THEN
			Data_Out <= (OTHERS => '0');
		ELSIF RecvDone = '1' THEN
			Data_Out <= Data_Reg;
		END IF;
	END PROCESS;
	
END bhv_SPI_MASTER_RECEIVER;



--------@fun SPI Slave Sender----------------
--@Generic Data_width:		发送数据宽度（注意：内部不自动生成无起始位，结束位及校验位）
--@Generic Shift_clklevel:	在clk上升沿发送还是在下降沿发送数据（0：下降沿发送，1：上升沿发送）
--@Generic Idle_State:		发送数据线空闲时，置为的状态,可为'U','Z','1','0'等。
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
ENTITY SPI_SLAVE_SENDER IS		
GENERIC (Data_width		: NATURAL	:= 8;
		Idle_state		: STD_LOGIC := '1';
		Shift_clklevel:STD_LOGIC:= '1');
PORT (
	nRst 	:IN 	STD_LOGIC;--复位信号
	Clk		:IN 	STD_LOGIC;--inner logic work clk(state machine work clk)
	En   	:IN 	STD_LOGIC;
	Wr		:IN 	STD_LOGIC;--写信号
	Data_in	:IN		STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0);--写入的数据
	Ready  	:BUFFER STD_LOGIC;--组件是否准备好发送（之前的数据发送完即准备好），高有效
	
	SDO		:OUT	STD_LOGIC;
	nCS		:IN	STD_LOGIC;
	SCK		:IN	STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_SPI_SLAVE_SENDER OF SPI_SLAVE_SENDER IS
CONSTANT Idle:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
CONSTANT WaitForValidCS:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT WaitForSendDone:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
CONSTANT Delay:STD_LOGIC_VECTOR(1 DOWNTO 0):="11";
SIGNAL Curr_State:STD_LOGIC_VECTOR(1 DOWNTO 0):=Idle;
SIGNAL Data_Reg:STD_LOGIC_VECTOR(Data_Width - 1 DOWNTO 0);
SIGNAL SCK_Pre:STD_LOGIC;
SIGNAL DelayCounter:NATURAL RANGE 0 TO 15;
SIGNAL SCK_Tmp:STD_LOGIC_VECTOR(1 DOWNTO 0);
BEGIN
PROCESS(nRst, Clk)-----主要用于保证nCS必须拉低，否则下次发送将无法写入，产生错误；
	BEGIN
		IF nRst = '0' THEN
			Curr_State <= Idle;
			Ready <= '0';
		ELSIF Clk'EVENT AND Clk = '1' THEN
			CASE Curr_State IS
				WHEN Idle =>
					IF Wr = '1' AND En = '1' THEN
						Ready <= '0';
						Curr_State <= WaitForValidCS;
					ELSE
						Ready <= '1';
						Curr_State <= Idle;
					END IF;
				WHEN WaitForValidCS =>
					IF nCS = '0' THEN
						Curr_State <= WaitForSendDone;
					ELSE
						Curr_State <= WaitForValidCS;
					END IF;
				WHEN WaitForSendDone =>
					IF nCS = '1' THEN
						Ready <= '1';
						Curr_State <= Delay;
					ELSE
						Ready <= '0';
						Curr_State <= WaitForSendDone;
					END IF;
				WHEN Delay =>
					IF DelayCounter = 2 THEN
						Curr_State <= Idle;
					ELSE
						Curr_State <= Delay;
					END IF;
				WHEN OTHERS =>
					Curr_State <= Idle;
					Ready <= '0';
			END CASE;
		END IF;
	END PROCESS;
	
	PROCESS(Clk)
	BEGIN
		IF Clk'EVENT AND Clk = '0' THEN
			IF Curr_State = Delay THEN
				DelayCounter <= DelayCounter + 1;
			ELSE
				DelayCounter <= 0;
			END IF;
		END IF;
	END PROCESS;
	
--	PROCESS(Clk)
--	BEGIN
--		IF Clk'EVENT AND Clk = '0' THEN
--			SCK_Pre <= SCK;
--		END IF;
--	END PROCESS;
	PROCESS(Clk)
	BEGIN
		IF Clk'EVENT AND Clk = '0' THEN
			SCK_Tmp <= SCK_Tmp(0)&SCK;
		END IF;
	END PROCESS;
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			Data_Reg <= (OTHERS => '0');
		ELSIF Clk'EVENT AND Clk = '1' THEN
--			SCK_Pre <= SCK;
--			IF SCK_Pre = '0' AND SCK = '1' THEN
			IF SCK_Tmp = "01" THEN
				SDO <= Data_Reg(Data_Width - 1);
				Data_Reg <= Data_Reg(Data_Width - 2 DOWNTO 0)&Idle_state;
			ELSIF Wr = '1' AND EN = '1' THEN
				Data_Reg <= Data_In;
			END IF;
		END IF;
	END PROCESS;
END bhv_SPI_SLAVE_SENDER;


--------@fun spi slave receiver----------------
--@Generic Data_width:		接收数据宽度
--@Generic Shift_clklevel:	接收时钟
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY SPI_SLAVE_RECEIVER IS
GENERIC (Data_width		: NATURAL 	:= 8;
		 Shift_clklevel:STD_LOGIC:='1');
PORT (
	nRst  	:IN 	STD_LOGIC;
	Clk		:IN	STD_LOGIC;---至少是SCK的4倍
	En      :IN 	STD_LOGIC;
	Rd		:IN		STD_LOGIC;
	Ready	:OUT	STD_LOGIC;
	Data_out:OUT	STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0);
	
	nCS		:IN		STD_LOGIC;
	SCK		:IN 	STD_LOGIC;
	SDI		:IN		STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_SPI_SLAVE_RECEIVER OF SPI_SLAVE_RECEIVER IS

CONSTANT Idle:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
CONSTANT Recving:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT WaitForRead:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
SIGNAL Curr_State:STD_LOGIC_VECTOR(1 DOWNTO 0):=Idle;
SIGNAL RecvDone:STD_LOGIC;
SIGNAL SCK_Pre:STD_LOGIC;
SIGNAL Data_Reg:STD_LOGIC_VECTOR(Data_Width - 1 DOWNTO 0);
SIGNAL Counter:NATURAL RANGE 0 TO 31;
BEGIN
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			Curr_State <= Idle;
			Ready <= '0';
		ELSIF Clk'EVENT AND Clk = '1' THEN
			CASE Curr_State IS
				WHEN Idle =>
					Ready <= '0';
					IF nCS = '0' AND En = '1' THEN
						Curr_State <= Recving;
					ELSE
						Curr_State <= Idle;
					END IF;
				WHEN Recving =>
					IF nCS = '0' THEN
						Curr_State <= Recving;
					ELSE
						IF Counter = Data_width THEN
							Curr_State <= WaitForRead;
						ELSE
							Curr_State <= Idle;
						END IF;
					END IF;
				WHEN WaitForRead =>
					IF Rd = '1' THEN
						Ready <= '0';
						Curr_State <= Idle;
					ELSE
						Ready <= '1';
						Curr_State <= WaitForRead;
					END IF;
				WHEN OTHERS =>
					Curr_State <= Idle;
					Ready <= '0';
			END CASE;
		END IF;
	END PROCESS;

	PROCESS(Clk)
	BEGIN
		IF Clk'EVENT AND Clk = '1' THEN
			SCK_Pre <= SCK;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			Data_Reg <= (OTHERS => '0');
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF SCK_Pre = '1' AND SCK = '0' THEN
				Data_Reg(Data_Width-1 DOWNTO 0) <= Data_Reg(Data_Width-2 DOWNTO 0)&SDI;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			Counter <= 0;
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF Curr_State = Idle THEN
				Counter <= 0;
			ELSIF SCK_Pre = '1' AND SCK = '0' THEN
				Counter <= Counter + 1;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clk)
	BEGIN 
		IF Clk'EVENT AND Clk = '1' THEN
			Data_Out <= Data_Reg;
		END IF;
	END PROCESS;
	
END bhv_SPI_SLAVE_RECEIVER;