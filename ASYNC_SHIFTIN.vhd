--实现功能：将输入的串行数据，转为并行数据，RxClk为两倍于发送时钟的时钟信号
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY ASYNC_SHIFTIN IS
GENERIC (
	Data_Width:NATURAL:=8;
	Sync_Header:STD_LOGIC:='1'
);
PORT (
	I_nRst:IN	STD_LOGIC;
	I_Clk:IN	STD_LOGIC;
	I_RxClk:IN	STD_LOGIC;	---twice of txclk
	I_Din:IN	STD_LOGIC;
	I_Rd:IN	STD_LOGIC;
	
	O_Ready:OUT	STD_LOGIC;
	O_Data_Out:OUT	STD_LOGIC_VECTOR(Data_Width - 1  DOWNTO 0)
);
END ENTITY;

ARCHITECTURE bhv_ASYNC_SHIFTIN OF ASYNC_SHIFTIN IS
CONSTANT Idle:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
CONSTANT StartRecv:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT Recving:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
CONSTANT WaitForRead:STD_LOGIC_VECTOR(1 DOWNTO 0):="11";

SIGNAL Curr_State:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
SIGNAL Reced_Count:NATURAL RANGE 0 TO 255;
SIGNAL EnRxClk:STD_LOGIC;
SIGNAL RecvDataDone:STD_LOGIC;
SIGNAL Data_Reg:STD_LOGIC_VECTOR(Data_Width+1 DOWNTO 0);
SIGNAL RxClkForRecv:STD_LOGIC;
SIGNAL Counter:NATURAL RANGE 0 TO 15;
BEGIN
	PROCESS(I_nRst, I_Clk)
	BEGIN
		IF I_nRst = '0' THEN
			Curr_State <= Idle;
			O_Ready <= '0';
		ELSIF I_Clk'EVENT AND I_Clk = '1' THEN
			CASE Curr_State IS
				WHEN Idle =>
					O_Ready <= '0';
					IF I_Din = Sync_Header THEN
						Curr_State <= Recving;
					ELSE
						Curr_State <= Idle;
					END IF;
				WHEN StartRecv =>
					O_Ready <= '0';
					Curr_State <= Recving;
				WHEN Recving =>
					IF RecvDataDone = '1' THEN
						IF Data_Reg(Data_Width+1) = '0' THEN
							O_Ready <= '0';
							Curr_State <= WaitForRead;
						ELSE
							O_Ready <= '0';
							Curr_State <= Idle;
						END IF;
					ELSE
						O_Ready <= '0';
						Curr_State <= Recving;
					END IF;
				WHEN WaitForRead =>
					IF I_Rd = '1' THEN
						O_Ready <= '0';
						Curr_State <= Idle;
					ELSE
						O_Ready <= '1';
						Curr_State <= WaitForRead;
					END IF;
				WHEN OTHERS => 
					Curr_State <= Idle;
					O_Ready <= '0';
			END CASE;
		END IF;
	END PROCESS;

	PROCESS(I_nRst, Curr_State, I_Clk, I_Din)
	BEGIN
		IF I_nRst = '0' OR (I_Din = '0' AND Curr_State = Idle) THEN
			Counter <= 1;
		ELSIF I_Clk'EVENT AND I_Clk = '0' THEN
			IF Curr_State = Recving THEN
				IF Counter /= 8 THEN
					Counter <= Counter + 1;
				ELSE
					Counter <= 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(I_nRst, Curr_State, I_Din, I_Clk)
	BEGIN
		IF I_nRst = '0' OR (I_Din = '0' AND Curr_State = Idle) THEN
			Data_Reg <= (OTHERS => '0');
			Reced_Count <= 0;
			RecvDataDone <= '0';
		ELSIF I_Clk'EVENT AND I_Clk = '1' THEN
			IF Counter = 4 AND RecvDataDone = '0' THEN
				Reced_Count <= Reced_Count + 1;
				Data_Reg(0) <= I_Din;
				Data_Reg(Data_Width+1 DOWNTO 1) <= Data_Reg(Data_Width DOWNTO 0);
			END IF;
			
			IF Reced_Count >= Data_Width + 2 THEN
				RecvDataDone <= '1';
			END IF;
		END IF;		
	END PROCESS;
	
	PROCESS(I_nRst, I_Clk)
	BEGIN
		IF I_nRst = '0' THEN
			O_Data_Out <= (OTHERS => '0');
		ELSIF I_Clk'EVENT AND I_Clk = '0' THEN
			IF RecvDataDone = '1' THEN
				O_Data_Out <= Data_Reg(Data_Width DOWNTO 1);
			END IF;
		END IF;
	END PROCESS;
END bhv_ASYNC_SHIFTIN;