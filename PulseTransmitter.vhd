LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
library altera;
use altera.altera_syn_attributes.all;

ENTITY PulseTransmitter IS
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
END ENTITY;

ARCHITECTURE bhv_PulseTransmitter OF PulseTransmitter IS 
SIGNAL SendDone:STD_LOGIC;
SIGNAL Count:STD_LOGIC_VECTOR(19 DOWNTO 0);
SIGNAL SendedCount_Period:STD_LOGIC_VECTOR(19 DOWNTO 0);
SIGNAL Txd_Tmp:STD_LOGIC;
BEGIN

PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		Txd_Tmp <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF SendDone = '0' THEN
			IF PulseWidth = X"FFFFF" THEN
				Txd_Tmp <= '1';
			ELSIF Count < PulseWidth AND Count > 0 THEN
				Txd_Tmp <= '1';
			ELSE
				Txd_Tmp <= '0';
			END IF;
		ELSE
			Txd_Tmp <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		Count <= (OTHERS => '0');
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF Wr = '1' THEN
			Count <= (OTHERS => '0');
		ELSIF SendDone = '0' THEN
			IF Count = PulsePeriod THEN
				Count <= (OTHERS => '0');	
			ELSE
				Count <= Count+1;
			END IF;
		ELSE
			Count <= (OTHERS => '0');
		END IF;
	END IF;
END PROCESS;

PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		SendedCount_Period <= (OTHERS => '0');
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF Wr = '1' THEN
			SendedCount_Period <= (OTHERS => '0');
		ELSIF Count = PulsePeriod THEN
			IF SendedCount_Period /= X"FFFFF" THEN
				SendedCount_Period <= SendedCount_Period+1;
			END IF;
		END IF;
	END IF;
END PROCESS;

PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN	
		SendDone <= '1';
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF Wr = '1' AND En = '1' THEN
			SendDone <= '0';
		ELSIF En = '0' THEN
			SendDone <= '1';
		ELSIF PulseCount = X"FFFFF" THEN
			SendDone <= '0';
		ELSIF SendedCount_Period < PulseCount THEN
			SendDone <= '0';
		ELSE
			SendDone <= '1';
		END IF;
	END IF;
END PROCESS;

Txd <= NOT Txd_Tmp WHEN Level = '0' ELSE Txd_Tmp;

END bhv_PulseTransmitter;