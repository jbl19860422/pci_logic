LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
library altera;
use altera.altera_syn_attributes.all;

ENTITY PulseTransmitter3 IS
PORT (
	nRst:IN			STD_LOGIC;
	En1:IN			STD_LOGIC;
	En2:IN			STD_LOGIC;
	En3:IN			STD_LOGIC;
	
	AlwaysHigh1:IN	STD_LOGIC;
	AlwaysHigh2:IN	STD_LOGIC;
	AlwaysHigh3:IN	STD_LOGIC;
	
	Clk:IN			STD_LOGIC;
	Wr:IN				STD_LOGIC;
	PulseStart1:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulseEnd1:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulseStart2:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulseEnd2:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulseStart3:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulseEnd3:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulsePeriod:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	PulseCount:IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
	Txd1:OUT			STD_LOGIC;
	Txd2:OUT			STD_LOGIC;
	Txd3:OUT			STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_PulseTransmitter3 OF PulseTransmitter3 IS 
attribute keep:boolean;
SIGNAL SendDone:STD_LOGIC;
SIGNAL Count:STD_LOGIC_VECTOR(19 DOWNTO 0);
SIGNAL SendedCount_Period:STD_LOGIC_VECTOR(19 DOWNTO 0);

BEGIN

PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		Txd1 <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF AlwaysHigh1 = '1' THEN
			Txd1 <= '1';
		ELSIF SendDone = '0' AND En1 = '1' THEN
			IF Count >= PulseStart1 AND Count < PulseEnd1 THEN
				Txd1 <= '1';
			ELSE
				Txd1 <= '0';
			END IF;
		ELSE
			Txd1 <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		Txd2 <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF AlwaysHigh2 = '1' THEN
			Txd2 <= '1';
		ELSIF SendDone = '0' AND En2 = '1' THEN
			IF Count >= PulseStart2 AND Count < PulseEnd2 THEN
				Txd2 <= '1';
			ELSE
				Txd2 <= '0';
			END IF;
		ELSE
			Txd2 <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(nRst, Clk)
BEGIN
	IF nRst = '0' THEN
		Txd3 <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF AlwaysHigh3 = '1' THEN
			Txd3 <= '1';
		ELSIF SendDone = '0' AND En1 = '1' THEN
			IF Count >= PulseStart3 AND Count < PulseEnd3 THEN
				Txd3 <= '1';
			ELSE
				Txd3 <= '0';
			END IF;
		ELSE
			Txd3 <= '0';
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
		IF Wr = '1' THEN
			SendDone <= '0';
		ELSIF PulseCount = X"FFFFF" THEN
			SendDone <= '0';
		ELSIF SendedCount_Period < PulseCount THEN
			SendDone <= '0';
		ELSE
			SendDone <= '1';
		END IF;
	END IF;
END PROCESS;
END bhv_PulseTransmitter3;