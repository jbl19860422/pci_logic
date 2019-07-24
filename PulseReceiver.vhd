LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
library altera;
use altera.altera_syn_attributes.all;

ENTITY PulseReceiver IS
GENERIC (Level:STD_LOGIC:='1');
PORT (
	nRst:IN	STD_LOGIC;
	Clk:IN	STD_LOGIC;
	Rxd:IN	STD_LOGIC;
	Clr:IN	STD_LOGIC;
	PulseCount:OUT	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulseWidth:OUT	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulsePeriod_Pre:OUT	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulsePeriod_Nxt:OUT	STD_LOGIC_VECTOR(19 DOWNTO 0)
);
END ENTITY;

ARCHITECTURE bhv_PulseReceiver OF PulseReceiver IS
SIGNAL PulseCount_Reg:STD_LOGIC_VECTOR(19 DOWNTO 0);
SIGNAL PulseWidth_Reg:STD_LOGIC_VECTOR(19 DOWNTO 0);
SIGNAL PulsePeriod_PreReg:STD_LOGIC_VECTOR(19 DOWNTO 0);
SIGNAL PulsePeriod_NxtReg:STD_LOGIC_VECTOR(19 DOWNTO 0);
SIGNAL Rxd_Reg:STD_LOGIC;
SIGNAL Rxd_Tmp:STD_LOGIC_VECTOR(1 DOWNTO 0);
BEGIN

Rxd_Reg <= NOT Rxd WHEN Level = '0' ELSE Rxd;
PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		Rxd_Tmp <= "00";
	ELSIF Clk'EVENT AND Clk = '1' THEN
		Rxd_Tmp(0) <= Rxd_Reg;
		Rxd_Tmp(1) <= Rxd_Tmp(0);
	END IF;
END PROCESS;

PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		PulseWidth_Reg <= (OTHERS => '0');
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF Rxd_Tmp = "01" THEN
			PulseWidth <= PulseWidth_Reg;
			PulseWidth_Reg <= (OTHERS => '0');
		ELSIF Rxd_Tmp /= "00" AND PulseWidth_Reg /= X"FFFFF" THEN
			PulseWidth_Reg <= PulseWidth_Reg+1;
		END IF;
	END IF;
END PROCESS;

PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		PulsePeriod_NxtReg <= (OTHERS => '0');
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF Rxd_Tmp = "01" THEN
			PulsePeriod_NxtReg <= (OTHERS => '0');
		ELSIF PulsePeriod_NxtReg /= X"FFFFF" THEN
			PulsePeriod_NxtReg <= PulsePeriod_NxtReg+1;
		END IF;
	END IF;
END PROCESS;
--
PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		PulsePeriod_PreReg <= (OTHERS => '0');
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF Rxd_Tmp = "01" THEN
			PulsePeriod_PreReg <= PulsePeriod_NxtReg;
			PulsePeriod_Pre <= PulsePeriod_PreReg;
		END IF;
	END IF;
END PROCESS;

PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		PulseCount_Reg <= (OTHERS => '0');
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF Clr = '1' THEN
			PulseCount_Reg <= (OTHERS => '0');
		ELSIF Rxd_Tmp = "01" AND PulseCount_Reg /= X"FFFFF" THEN
			PulseCount_Reg <= PulseCount_Reg+1;
		END IF;
	END IF;
END PROCESS;

PROCESS(Clk)
BEGIN
	IF Clk'EVENT AND Clk = '1' THEN
		PulsePeriod_Nxt <= PulsePeriod_NxtReg;
		PulseCount <= PulseCount_Reg; 
	END IF;
END PROCESS;
END bhv_PulseReceiver;