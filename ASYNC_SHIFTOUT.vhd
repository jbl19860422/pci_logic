LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
--实现功能：将输入的并行数据，转为串行数据发送，TxClk为其发送时钟
ENTITY ASYNC_SHIFTOUT IS
GENERIC (
	Data_Width:NATURAL:=8;
	Sync_Header:STD_LOGIC:='0'
);
PORT (
	I_nRst:IN	STD_LOGIC;
	I_Clk:IN	STD_LOGIC;
	I_TxClk:IN	STD_LOGIC;
	I_Wr:IN	STD_LOGIC;
	I_Data_In:IN	STD_LOGIC_VECTOR(Data_Width - 1  DOWNTO 0);
	
	O_Ready:OUT	STD_LOGIC;
	O_Dout:OUT	STD_LOGIC;
	O_Sending:OUT	STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_ASYNC_SHIFTOUT OF ASYNC_SHIFTOUT IS
CONSTANT Idle:STD_LOGIC_VECTOR(2 DOWNTO 0):="000";
CONSTANT StartSendData:STD_LOGIC_VECTOR(2 DOWNTO 0):="001";
CONSTANT WaitForSendDone:STD_LOGIC_VECTOR(2 DOWNTO 0):="010";
CONSTANT DelayOneClk:STD_LOGIC_VECTOR(2 DOWNTO 0):="011";
CONSTANT DelayTwoClk:STD_LOGIC_VECTOR(2 DOWNTO 0):="100";
SIGNAL SendDone:STD_LOGIC;
SIGNAL Curr_State:STD_LOGIC_VECTOR(2 DOWNTO 0):=Idle;
SIGNAL Sended_Count:NATURAL RANGE 0 TO 255;
SIGNAL Counter:NATURAL RANGE 0 TO 15;
SIGNAL Data_Reg:STD_LOGIC_VECTOR(Data_Width+1 DOWNTO 0);
BEGIN	
	PROCESS(I_nRst, I_Clk)
	BEGIN
		IF I_nRst = '0' THEN
			Curr_State <= Idle;
			O_Ready <= '0';
		ELSIF I_Clk'EVENT AND I_Clk = '1' THEN
			CASE Curr_State IS
				WHEN Idle => --空闲状态，响应外部写信号
					IF I_Wr = '1' THEN
						O_Ready <= '0';
						Curr_State <= WaitForSendDone;
					ELSE
						O_Ready <= '1';
						Curr_State <= Idle;
					END IF;
				WHEN WaitForSendDone => --等待发送完毕信号
					IF SendDone = '1' THEN
						Curr_State <= DelayOneClk;
					ELSE
						Curr_State <= WaitForSendDone;
					END IF;
				WHEN DelayOneClk => --延迟一个时钟周期
					O_Ready <= '0';
					Curr_State <= DelayTwoClk;
				WHEN DelayTwoClk =>
					O_Ready <= '0';
					Curr_State <= Idle;
				WHEN OTHERS =>
					Curr_State <= Idle;
					O_Ready <= '0';
			END CASE;
		END IF;
	END PROCESS;
	
	PROCESS(I_nRst, I_Clk)
	BEGIN
		IF I_nRst = '0' THEN
			Data_Reg <= (OTHERS => '1');
			Sended_Count <= 0;
		ELSIF I_Clk'EVENT AND I_Clk = '1' THEN
			IF I_Wr = '1' THEN
				Data_Reg <= '0'&I_Data_In&'1';
				Sended_Count <= 0;
			ELSIF Counter = 8 THEN
				Data_Reg <= Data_Reg(Data_Width DOWNTO 0)&'1';
				O_Dout <= Data_Reg(Data_Width+1);
				Sended_Count <= Sended_Count + 1;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(I_nRst, I_Wr, I_Clk)
	BEGIN
		IF I_nRst = '0' OR I_Wr = '1' THEN
			SendDone <= '0';
		ELSIF I_Clk'EVENT AND I_Clk = '0' THEN
			IF Sended_Count = Data_Width+3 THEN
				SendDone <= '1';
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(I_nRst, I_Clk)
	BEGIN
		IF I_nRst = '0' THEN
			Counter <= 1;
		ELSIF I_Clk'EVENT AND I_Clk = '1' THEN
			IF I_Wr = '1' THEN
				Counter <= 1;
			ELSIF Counter < 8 THEN
				Counter <= Counter + 1;
			ELSE
				Counter <= 1;
			END IF;
		END IF;
	END PROCESS;
END bhv_ASYNC_SHIFTOUT;
