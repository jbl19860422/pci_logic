LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY ALTERA_MF;
USE ALTERA_MF.ALL;

ENTITY SpiMaster IS
PORT (
	nRst:IN			STD_LOGIC;
	Clk: IN 	STD_LOGIC;
	En:IN				STD_LOGIC;
	FreqDiv:IN		STD_LOGIC_VECTOR(7 DOWNTO 0);
	RW:IN				STD_LOGIC;
	ADDR:IN			STD_LOGIC_VECTOR(12 DOWNTO 0);
	DataSend:IN		STD_LOGIC_VECTOR(7 DOWNTO 0);
	DataRecv:OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
	Start:IN			STD_LOGIC;--开始执行操作
	Busy:OUT			STD_LOGIC;--是否空闲标志
	-----------spi port------------
	nCS:	OUT		STD_LOGIC;
	SDIO: INOUT		STD_LOGIC;
	SCK:	OUT		STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_SpiMaster OF SpiMaster IS

CONSTANT Idle:STD_LOGIC_VECTOR(2 DOWNTO 0):="000";
CONSTANT EnableCS:STD_LOGIC_VECTOR(2 DOWNTO 0):="001";
CONSTANT CmdPhase:STD_LOGIC_VECTOR(2 DOWNTO 0):="010";
CONSTANT DataPhase:STD_LOGIC_VECTOR(2 DOWNTO 0):="011";
CONSTANT DisableCS:STD_LOGIC_VECTOR(2 DOWNTO 0):="100";

SIGNAL Curr_State:STD_LOGIC_VECTOR(2 DOWNTO 0):=Idle;
SIGNAL Start_Reg:STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL CounterReg:STD_LOGIC_VECTOR(23 DOWNTO 0);
SIGNAL DataRecv_Reg:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL Done:STD_LOGIC;
SIGNAL SendData_Reg:STD_LOGIC_VECTOR(23 DOWNTO 0);
SIGNAL TimeCounter:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL SCK_Tmp:STD_LOGIC;
SIGNAL SCK_Tmp_Reg:STD_LOGIC_VECTOR(1 DOWNTO 0);
BEGIN
PROCESS(Clk)
BEGIN
	IF Clk'EVENT AND Clk = '0' THEN
		Start_Reg <= Start_Reg(0)&Start;
	END IF;
END PROCESS;

PROCESS(Clk)
BEGIN
	IF Clk'EVENT AND Clk = '1' THEN
		IF Curr_State = Idle THEN
			IF Start_Reg = "01" THEN
				SendData_Reg(23) <= RW;
				SendData_Reg(22) <= '0';---W1
				SendData_Reg(21) <= '0';---W0
				SendData_Reg(20 DOWNTO 8) <= ADDR;
				SendData_Reg(7 DOWNTO 0) <= DataSend;
			END IF;
		ELSIF Curr_State = CMDPhase THEN
			IF TimeCounter = X"00" THEN
				SendData_Reg <= SendData_Reg(22 DOWNTO 0)&'0';
			END IF;
		END IF;
	END IF;
END PROCESS;

PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			Curr_State <= Idle;
		ELSIF Clk'EVENT AND Clk = '1' THEN
			CASE Curr_state IS
				WHEN Idle =>
					IF Start_Reg = "01" AND En = '1' THEN			
						Curr_State <= EnableCS;
					ELSE
						Curr_State <= Idle;
					END IF;
				WHEN EnableCS =>
					Curr_State <= CmdPhase;
				WHEN CmdPhase =>
					IF CounterReg(15) = '1' THEN
						Curr_State <= DataPhase;
					ELSE
						Curr_State <= CmdPhase;
					END IF;
				WHEN DataPhase =>
					IF Done = '1' THEN
						Curr_State <= DisableCS;
					ELSE
						Curr_State <= DataPhase;
					END IF;
				WHEN DisableCS =>
					Curr_State <= Idle;
				WHEN OTHERS =>
					Curr_State <= Idle;
					nCS <= '1';
			END CASE;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			SDIO <= 'Z';
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF Curr_State = Idle THEN
				SDIO <= '0';
			ELSIF Curr_State = CmdPhase THEN
				IF TimeCounter = X"00" THEN
					SDIO <= SendData_Reg(23);
				END IF;
			ELSIF Curr_State = DataPhase THEN
				IF TimeCounter = X"00" THEN
					IF RW = '0' THEN
						SDIO <= SendData_Reg(23);
					ELSE
						SDIO <= 'Z';
					END IF;
				END IF;
			ELSE 
				SDIO <= 'Z';
			END IF;
		END IF;
	END PROCESS;

	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			CounterReg <= (OTHERS => '0');
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF Curr_State = Idle THEN
				CounterReg <= (OTHERS => '0');
			ELSIF Curr_State = CmdPhase OR Curr_State = DataPhase THEN
				IF TimeCounter = X"00" THEN
					CounterReg <= CounterReg(22 DOWNTO 0)&'1';
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clk)
	BEGIN
		IF Clk'EVENT AND Clk = '1' THEN
			SCK_Tmp_Reg <= SCK_Tmp_Reg(0)&SCK_Tmp;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			SCK_Tmp <= '0';
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF Curr_State = Idle THEN
				SCK_Tmp <= '0';
			ELSIF Curr_State = CmdPhase OR Curr_State = DataPhase THEN
				IF TimeCounter(6 DOWNTO 0) = FreqDiv(7 DOWNTO 1) OR TimeCounter = "00000000" THEN
					SCK_Tmp <= NOT SCK_Tmp;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	SCK <= SCK_Tmp;
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			DataRecv_Reg <= (OTHERS => '0');
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF SCK_Tmp_Reg = "10" AND Curr_State = DataPhase AND RW = '1' THEN
				DataRecv_Reg(7 DOWNTO 0) <= DataRecv_Reg(6 DOWNTO 0)&SDIO;
			END IF;
		END IF;
	END PROCESS;
	DataRecv <= DataRecv_Reg;
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			TimeCounter <= (OTHERS => '0');
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF Curr_State = CmdPhase OR Curr_State = DataPhase THEN
				IF TimeCounter = FreqDiv THEN
					TimeCounter <= X"00";
				ELSE
					TimeCounter <= TimeCounter + X"01";
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(nRst, Clk)
	BEGIN
		IF nRst = '0' THEN
			Done <= '0';
		ELSIF Clk'EVENT AND Clk = '0' THEN
			IF CounterReg(23) = '1' AND TimeCounter = FreqDiv THEN
				Done <= '1';
			ELSE
				Done <= '0';
			END IF;
		END IF;
	END PROCESS;
END bhv_SpiMaster;