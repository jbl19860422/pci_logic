LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY MASTER_SYNC_SHIFTER_OUT IS
GENERIC (
	Data_Width:NATURAL:=8;
	Sync_Header:STD_LOGIC:='1';
	ShiftOut_ClkLevel:STD_LOGIC:='1'
);
PORT (
	nRst:IN	STD_LOGIC;
	Clk:IN	STD_LOGIC;
	TxClk:IN STD_LOGIC;
	Wr:IN	STD_LOGIC;
	Data_In:IN	STD_LOGIC_VECTOR(Data_Width - 1  DOWNTO 0);
	Ready:OUT	STD_LOGIC;
	
	Txd:OUT	STD_LOGIC;
	SClk:OUT STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_MASTER_SYNC_SHIFTER_OUT OF MASTER_SYNC_SHIFTER_OUT IS
TYPE State IS (Idle, StartSendData, WaitForSendDone);
SIGNAL Curr_State:State:=Idle;
SIGNAL Sended_Count:NATURAL RANGE 0 TO 255;
SIGNAL SendStart, SendDone:STD_LOGIC;
SIGNAL DataReg_Wr:STD_LOGIC:='0';
SIGNAL Data_Reg:STD_LOGIC_VECTOR(Data_Width+1 DOWNTO 0);

BEGIN
	SClk <= TxClk;
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			Curr_State <= Idle;
			SendStart <= '0';
			DataReg_Wr <= '0';
			Ready <= '0';
		ELSIF Clk'EVENT AND Clk = '1' THEN
			CASE Curr_State IS
				WHEN Idle => 
					SendStart <= '0';
					IF Wr = '1' THEN
						DataReg_Wr <= '1';
						Ready <= '0';
						Curr_State <= StartSendData;
					ELSE
						DataReg_Wr <= '0';
						Ready <= '1';
						Curr_State <= Idle;
					END IF;
				WHEN StartSendData =>
					Ready <= '0';
					DataReg_Wr <= '0';
					SendStart <= '1';
					Curr_State <= WaitForSendDone;
				WHEN WaitForSendDone =>
					Ready <= '0';
					SendStart <= '0';
					DataReg_Wr <= '0';
					IF SendDone = '1' THEN
						Curr_State <= Idle;
					ELSE
						Curr_State <= WaitForSendDone;
					END IF;
				WHEN OTHERS =>
					Curr_State <= Idle;
					SendStart <= '0';
					DataReg_Wr <= '0';
					Ready <= '0';
			END CASE;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, DataReg_Wr, TxClk)
	BEGIN
		IF nRst = '0' THEN
			Data_Reg <= (OTHERS => (NOT Sync_Header));
		ELSIF DataReg_Wr = '1' THEN
			Data_Reg <= Sync_Header&Data_In&(NOT Sync_Header);
		ELSIF TxClk'EVENT AND TxClk = '1' THEN
			IF SendDone = '0' THEN
				Data_Reg <= Data_Reg(Data_Width DOWNTO 0)&(NOT Sync_Header);
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, SendStart, TxClk)
	BEGIN
		IF nRst = '0' OR SendStart = '1' THEN
			Sended_Count <= 0;
		ELSIF TxClk'EVENT AND TxClk = '1' THEN
			IF SendDone = '0' THEN
				Sended_Count <= Sended_Count + 1;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, SendDone, TxClk)
	BEGIN
		IF nRst = '0' OR SendDone = '1' THEN
			Txd <= NOT Sync_Header;
		ELSIF TxClk'EVENT AND TxClk = '1' THEN
			IF SendDone = '0' THEN
				Txd <= Data_Reg(Data_Width+1);
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
			ELSIF Sended_Count = Data_Width+2 THEN
				SendDone <= '1';
			ELSE
				SendDone <= '0';
			END IF;
		END IF;
	END PROCESS;
END bhv_MASTER_SYNC_SHIFTER_OUT;


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
ENTITY SLAVE_SYNC_SHIFTER_OUT IS
GENERIC (
	Data_Width:NATURAL:=8;
	Sync_Header:STD_LOGIC:='1';
	ShiftOut_ClkLevel:STD_LOGIC:='1'
);
PORT (
	nRst:IN	STD_LOGIC;
	Clk:IN	STD_LOGIC;
	Wr:IN	STD_LOGIC;
	Data_In:IN	STD_LOGIC_VECTOR(Data_Width - 1  DOWNTO 0);
	Ready:OUT	STD_LOGIC;
	
	Txd:OUT	STD_LOGIC;
	SClk:IN STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_SLAVE_SYNC_SHIFTER_OUT OF SLAVE_SYNC_SHIFTER_OUT IS
--TYPE State IS (Idle, StartSendData, WaitForSendDone);
CONSTANT Idle:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
CONSTANT StartSendData:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT WaitForSendDone:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
CONSTANT Delay:STD_LOGIC_VECTOR(1 DOWNTO 0):="11";

SIGNAL Curr_State:STD_LOGIC_VECTOR(1 DOWNTO 0):=Idle;
SIGNAL Sended_Count:NATURAL RANGE 0 TO 255;
SIGNAL SendStart, SendDone:STD_LOGIC;
SIGNAL DataReg_Wr:STD_LOGIC:='0';
SIGNAL Data_Reg:STD_LOGIC_VECTOR(Data_Width+1 DOWNTO 0);
SIGNAL SClk_Pre:STD_LOGIC;
SIGNAL DelayCounter:NATURAL RANGE 0 TO 15;
BEGIN
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			Curr_State <= Idle;
			Ready <= '0';
		ELSIF Clk'EVENT AND Clk = '1' THEN
			CASE Curr_State IS
				WHEN Idle => 
					IF SendDone = '0' THEN
						Ready <= '0';
						Curr_State <= StartSendData;
					ELSE
						Ready <= '1';
						Curr_State <= Idle;
					END IF;
				WHEN StartSendData =>
					Ready <= '0';
					Curr_State <= WaitForSendDone;
				WHEN WaitForSendDone =>
					Ready <= '0';
					IF SendDone = '1' THEN
						Curr_State <= Delay;
					ELSE
						Curr_State <= WaitForSendDone;
					END IF;
				WHEN Delay =>
					IF DelayCounter = 5 THEN
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
	
	PROCESS(Clk)
	BEGIN
		IF Clk'EVENT AND Clk = '1' THEN
			SClk_Pre <= SClk;
		END IF;
	END PROCESS;
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
--			SClk_Pre <= '0';
			Data_Reg <= (OTHERS => NOT Sync_Header);
			SendDone <= '1';
			Txd <= NOT Sync_Header;
		ELSIF Clk'EVENT AND Clk = '0' THEN
--			SClk_Pre <= SClk;
			IF Curr_State = Idle AND Wr = '1' THEN-----new data to send
				Sended_Count <= 0;
				Data_Reg <= Sync_Header&Data_In&(NOT Sync_Header);
				SendDone <= '0';
			ELSIF SClk_Pre = '0' AND SClk = '1' THEN---rising edge
				IF SendDone = '0' THEN
					Txd <= Data_Reg(Data_Width+1);
					Data_Reg <= Data_Reg(Data_Width DOWNTO 0)&(NOT Sync_Header);
					Sended_Count <= Sended_Count + 1;
					IF Sended_Count = Data_Width + 1 THEN
						SendDone <= '1';
					END IF;
				ELSE
					Txd <= NOT Sync_Header;
				END IF;
			END IF;
		END IF;
	END PROCESS;
END bhv_SLAVE_SYNC_SHIFTER_OUT;


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
ENTITY MASTER_SYNC_SHIFTER_IN IS
GENERIC (
	Data_Width:NATURAL:=8;
	Sync_Header:STD_LOGIC:='1';
	ShifterIn_Clk:STD_LOGIC:='0'
);
PORT (
	nRst:IN	STD_LOGIC;
	Clk:IN	STD_LOGIC;
	RxClk:IN	STD_LOGIC;
	Ready:OUT	STD_LOGIC;
	Rd:IN	STD_LOGIC;
	Data_Out:OUT	STD_LOGIC_VECTOR(Data_Width - 1  DOWNTO 0);
	
	SClk:OUT STD_LOGIC;
	Rxd:IN	STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_MASTER_SYNC_SHIFTER_IN OF MASTER_SYNC_SHIFTER_IN IS
TYPE State IS (Idle, Recving, WaitForRead);
SIGNAL Curr_State, Next_State:State:=Idle;
SIGNAL Reced_Count:NATURAL RANGE 0 TO 255;
SIGNAL RecvDataStart:STD_LOGIC;
SIGNAL RecvDataDone:STD_LOGIC;
SIGNAL Data_Reg:STD_LOGIC_VECTOR(Data_Width DOWNTO 0);
SIGNAL RxClkForRecv:STD_LOGIC;
SIGNAL DetectedHeader:STD_LOGIC;
BEGIN
	SClk <= RxClk;
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			Curr_State <= Idle;
			RecvDataStart <= '0';
			Ready <= '0';
		ELSIF Clk'EVENT AND Clk = '1' THEN
			CASE Curr_State IS
				WHEN Idle =>
					Ready <= '0';
					IF DetectedHeader = '1' THEN
						RecvDataStart <= '1';
						Curr_State <= Recving;
					ELSE
						RecvDataStart <= '0';
						Curr_State <= Idle;
					END IF;
				WHEN Recving =>
					RecvDataStart <= '0';
					IF RecvDataDone = '1' THEN
						Ready <= '1';
						Curr_State <= WaitForRead;
					ELSE
						Ready <= '0';
						Curr_State <= Recving;
					END IF;
				WHEN WaitForRead =>
					RecvDataStart <= '0';
					IF Rd = '1' THEN
						Ready <= '0';
						Curr_State <= Idle;
					ELSE
						Ready <= '1';
						Curr_State <= WaitForRead;
					END IF;
				WHEN OTHERS =>
					Curr_State <= Idle;
					RecvDataStart <= '0';
					Ready <= '0';
			END CASE;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, RxClk)
	BEGIN
		IF nRst = '0' THEN
			DetectedHeader <= '0';
		ELSIF RxClk'EVENT AND RxClk = ShifterIn_Clk THEN
			IF Rxd = Sync_Header THEN
				DetectedHeader <= '1';
			ELSE
				DetectedHeader <= '0';
			END IF;
		END IF;		
	END PROCESS;
	
	PROCESS(nRst, RecvDataStart, RxClk)
	BEGIN
		IF nRst = '0' AND RecvDataStart = '1' THEN
			Data_Reg <= (OTHERS => '0');
		ELSIF RxClk'EVENT AND RxClk = ShifterIn_Clk THEN
			IF RecvDataDone = '0' THEN
				Data_Reg(0) <= Rxd;
				Data_Reg(Data_Width DOWNTO 1) <= Data_Reg(Data_Width-1 DOWNTO 0);
			END IF;
		END IF;		
	END PROCESS;
	
	PROCESS(nRst, RecvDataStart, RxClk)
	BEGIN
		IF nRst = '0' OR RecvDataStart = '1' THEN
			Reced_Count <= 0;
		ELSIF RxClk'EVENT AND RxClk = ShifterIn_Clk THEN
			IF RecvDataDone = '0' THEN
				Reced_Count <= Reced_Count + 1;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			RecvDataDone <= '1';
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF RecvDataStart = '1' THEN
				RecvDataDone <= '0';
			ELSIF Reced_Count = Data_Width+1 THEN
				RecvDataDone <= '1';
			ELSE
				RecvDataDone <= '0';
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, RecvDataDone)
	BEGIN
		IF nRst = '0' THEN
			Data_Out <= (OTHERS => '0');
		ELSIF RecvDataDone = '1' THEN
			Data_Out <= Data_Reg(Data_Width DOWNTO 1);
		END IF;
	END PROCESS;
END bhv_MASTER_SYNC_SHIFTER_IN;


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
ENTITY SLAVE_SYNC_SHIFTER_IN IS
GENERIC (
	Data_Width:NATURAL:=8;
	Sync_Header:STD_LOGIC:='1';
	ShifterIn_Clk:STD_LOGIC:='0'
);
PORT (
	nRst:IN	STD_LOGIC;
	Clk:IN	STD_LOGIC;
	Ready:OUT	STD_LOGIC;
	Rd:IN	STD_LOGIC;
	Data_Out:OUT	STD_LOGIC_VECTOR(Data_Width - 1  DOWNTO 0);
	
	SClk:IN STD_LOGIC;
	Rxd:IN	STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_SLAVE_SYNC_SHIFTER_IN OF SLAVE_SYNC_SHIFTER_IN IS
--TYPE State IS (Idle, Recving, WaitForRead);
CONSTANT Idle:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
CONSTANT Recving:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT WaitForRead:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
SIGNAL Curr_State:STD_LOGIC_VECTOR(1 DOWNTO 0):=Idle;
SIGNAL Reced_Count:NATURAL RANGE 0 TO 255;

--SIGNAL RecvDataStart:STD_LOGIC;
SIGNAL RecvDataDone:STD_LOGIC;
SIGNAL Data_Reg:STD_LOGIC_VECTOR(Data_Width DOWNTO 0);
SIGNAL SClk_Pre:STD_LOGIC;
SIGNAL GettedSyncHeader:STD_LOGIC;
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
					IF GettedSyncHeader = '1' THEN
						Curr_State <= Recving;
					END IF;
				WHEN Recving =>
					IF RecvDataDone = '1' THEN
						Ready <= '1';
						Curr_State <= WaitForRead;
					ELSE
						Ready <= '0';
						Curr_State <= Recving;
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
			SClk_Pre <= SClk;
		END IF;
	END PROCESS;
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			--SClk_Tmp <= (OTHERS => '0');
			Reced_Count <= 0;
			GettedSyncHeader <= '0';
			RecvDataDone <= '1';
		ELSIF Clk'EVENT AND Clk = '0' THEN
			--SClk_Tmp <= SClk_Tmp(0)&SClk;
			IF SClk_Pre = '1' AND SClk = '0' THEN---------arising edge
				IF Curr_State = Idle THEN---detect header
					IF Rxd = '0' THEN
						GettedSyncHeader <= '1';
						Reced_Count <= 0;
						RecvDataDone <= '0';
					ELSE
						GettedSyncHeader <= '0';
					END IF;						
				ELSE
					GettedSyncHeader <= '0';
					Data_Reg(Data_Width DOWNTO 0) <= Data_Reg(Data_Width-1 DOWNTO 0)&Rxd;
					IF Reced_Count = Data_Width+1 THEN
						RecvDataDone <= '1';
						Data_Out <= Data_Reg(Data_Width DOWNTO 1);
					ELSE
						Reced_Count <= Reced_Count+1;
						RecvDataDone <= '0';
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;

END bhv_SLAVE_SYNC_SHIFTER_IN;

