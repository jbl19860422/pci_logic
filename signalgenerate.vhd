LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

library altera;
use altera.altera_syn_attributes.all;

LIBRARY FIFO;
USE FIFO.ALL;

USE WORK.DEFINE.ALL;

ENTITY PCI IS
PORT (  
		RST    : IN     STD_LOGIC;
		CLK    : IN     STD_LOGIC;
		IDSEL  : IN     STD_LOGIC;
		FRAME  : INOUT     STD_LOGIC; 
		AD     : INOUT  STD_LOGIC_VECTOR(31 DOWNTO 0);
		CBE    : INOUT    STD_LOGIC_VECTOR(3 DOWNTO 0);
		IRDY   : INOUT     STD_LOGIC;
		TRDY   : INOUT  STD_LOGIC; 
		DEVSEL : INOUT  STD_LOGIC;
		INTA   : OUT    STD_LOGIC;
		STOP   : INOUT    STD_LOGIC;
		PAR    : INOUT    STD_LOGIC;
		Clk_Board:IN		STD_LOGIC;
		nSERR:IN			STD_LOGIC;
		nPERR:IN			STD_LOGIC;
		nREQ:OUT			STD_LOGIC;
		nGNT:IN			STD_LOGIC;
		-------AD9642 SPI-------
		AD9642_SPI1_nCS:OUT STD_LOGIC;
		AD9642_SPI1_SDIO:INOUT STD_LOGIC;
		AD9642_SPI1_CLK:OUT STD_LOGIC;
		AD9642_C1_DCO:IN STD_LOGIC;
		AD9642_C1_D:IN STD_LOGIC_VECTOR(13 DOWNTO 0);
		
		AD9642_SPI2_nCS:OUT STD_LOGIC;
		AD9642_SPI2_SDIO:INOUT STD_LOGIC;
		AD9642_SPI2_CLK:OUT STD_LOGIC;
		AD9642_C2_DCO:IN STD_LOGIC;
		AD9642_C2_D:IN STD_LOGIC_VECTOR(13 DOWNTO 0)
);									 
END PCI;
ARCHITECTURE BEHAVE OF PCI IS
ATTRIBUTE keep:BOOLEAN;

CONSTANT IDLE_NOR:STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
CONSTANT BUSY:STD_LOGIC_VECTOR(1 DOWNTO 0):="01";
CONSTANT SDATA:STD_LOGIC_VECTOR(1 DOWNTO 0):="10";
CONSTANT TURNAROUND:STD_LOGIC_VECTOR(1 DOWNTO 0):="11";

SIGNAL STATUS: STD_LOGIC_VECTOR(1 DOWNTO 0);--STATUSSET;

SIGNAL P1,P2,P3,P4 : STD_LOGIC;
SIGNAL ADDRESS               : STD_LOGIC_VECTOR(15 DOWNTO 0);

SIGNAL 	ConfCS:STD_LOGIC;
SIGNAL	PCI_RST    : STD_LOGIC;
SIGNAL	PCI_CLK    :STD_LOGIC;
SIGNAL	PCI_IDSEL  :STD_LOGIC;
SIGNAL	PCI_FRAME  :STD_LOGIC; 
SIGNAL	PCI_AD     :STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL	PCI_CBE    :STD_LOGIC_VECTOR(3 DOWNTO 0);
SIGNAL	PCI_IRDY   :STD_LOGIC;
SIGNAL	PCI_TRDY   :STD_LOGIC; 
SIGNAL	PCI_DEVSEL :STD_LOGIC;
SIGNAL	PCI_INTA   :STD_LOGIC;
SIGNAL	PCI_STOP   :STD_LOGIC;
SIGNAL	PCI_PAR    :STD_LOGIC;
SIGNAL	PCI_Clk_Board:STD_LOGIC;
SIGNAL	PCI_nSERR:STD_LOGIC;
SIGNAL	PCI_nPERR:STD_LOGIC;
SIGNAL	PCI_nREQ:STD_LOGIC;

ATTRIBUTE keep OF PCI_nREQ:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_RST:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_CLK:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_IDSEL:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_FRAME:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_AD:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_CBE:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_IRDY:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_TRDY:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_DEVSEL:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_INTA:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_STOP:SIGNAL IS TRUE;
ATTRIBUTE keep of PCI_PAR:SIGNAL IS TRUE;
ATTRIBUTE keep of STATUS:SIGNAL IS TRUE;
SIGNAL IDSEL_Counter:STD_LOGIC_VECTOR(7 DOWNTO 0);
ATTRIBUTE keep of IDSEL_Counter:SIGNAL IS TRUE;
ATTRIBUTE keep OF ConfCS:SIGNAL IS TRUE;
SIGNAL TRDY_Delay:STD_LOGIC;
SIGNAL RW:STD_LOGIC;
SIGNAL ParGen:STD_LOGIC;
SIGNAL ParGenData:STD_LOGIC_VECTOR(35 DOWNTO 0);
CONSTANT BaseAddr0:STD_LOGIC_VECTOR(5 DOWNTO 2):=X"4";
CONSTANT BaseAddr1:STD_LOGIC_VECTOR(5 DOWNTO 2):=X"5";
CONSTANT BaseAddr2:STD_LOGIC_VECTOR(5 DOWNTO 2):=X"6";
CONSTANT BaseAddr3:STD_LOGIC_VECTOR(5 DOWNTO 2):=X"7";
CONSTANT BaseAddr4:STD_LOGIC_VECTOR(5 DOWNTO 2):=X"8";
CONSTANT BaseAddr5:STD_LOGIC_VECTOR(5 DOWNTO 2):=X"9";
TYPE A_V32 IS ARRAY(NATURAL RANGE<>) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL	ConfReg:A_V32(15 DOWNTO 0);
SIGNAL PCI_Config_Wr:STD_LOGIC;
SIGNAL PCI_Config_WrData:STD_LOGIC_VECTOR(31 DOWNTO 0);
-----------------------Bar0 SIGNALS-------------------
SIGNAL Bar0_CS:STD_LOGIC;
SIGNAL Bar0TestReg:STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL Bar0_Wr:STD_LOGIC;
SIGNAL Bar0_WrData:STD_LOGIC_VECTOR(31 DOWNTO 0);
-----------------------Bar1 SIGNALS-------------------
SIGNAL Bar1_CS:STD_LOGIC;
SIGNAL Bar1TestReg1:STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL Bar1_Wr:STD_LOGIC;
-----------------------DMA DESC FIFO------------------
SIGNAL UUT_DmaDesc_FIFO_Rst:STD_LOGIC;
SIGNAL UUT_DmaDesc_FIFO_Din:STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL UUT_DmaDesc_FIFO_Wr:STD_LOGIC;
SIGNAL UUT_DmaDesc_FIFO_Wr_OK:STD_LOGIC;
SIGNAL UUT_DmaDesc_FIFO_Rd:STD_LOGIC;
SIGNAL UUT_DmaDesc_FIFO_DataCount:STD_LOGIC_VECTOR(9 DOWNTO 0);
SIGNAL UUT_DmaDesc_FIFO_Dout:STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL UUT_DmaDesc_FIFO_Full:STD_LOGIC;
SIGNAL UUT_DmaDesc_FIFO_Empty:STD_LOGIC;
SIGNAL DMAIntCount:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL DMAIntCount_Clr:STD_LOGIC;
SIGNAL DmaStatus:STD_LOGIC_VECTOR(7 DOWNTO 0);
--SIGNAL DmaCmd:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL DmaIntFlag:STD_LOGIC;
----------------------DMA Ctrl SIGNAL----------------
CONSTANT Idle:STD_LOGIC_VECTOR(2 DOWNTO 0):="000";
CONSTANT ReadPCIAddr:STD_LOGIC_VECTOR(2 DOWNTO 0):="001";
CONSTANT ReadTransCount:STD_LOGIC_VECTOR(2 DOWNTO 0):="010";
CONSTANT ReqPCIBus:STD_LOGIC_VECTOR(2 DOWNTO 0):="011";
CONSTANT AddrPhase:STD_LOGIC_VECTOR(2 DOWNTO 0):="100";
CONSTANT TurnAroundPhase:STD_LOGIC_VECTOR(2 DOWNTO 0):="101";
CONSTANT DataPhase:STD_LOGIC_VECTOR(2 DOWNTO 0):="110";
CONSTANT EndPhase:STD_LOGIC_VECTOR(2 DOWNTO 0):="111";

SIGNAL Curr_State_Dma:STD_LOGIC_VECTOR(2 DOWNTO 0):=Idle;
SIGNAL Dma_Start:STD_LOGIC;
SIGNAL DMA_PCIAddress:STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL DMA_Count:STD_LOGIC_VECTOR(9 DOWNTO 0);
SIGNAL DMA_Channel:STD_LOGIC;
SIGNAL DMA_Dir:STD_LOGIC;
SIGNAL DMA_Counted:STD_LOGIC_VECTOR(9 DOWNTO 0);
SIGNAL DMA_DonePCIAddress:STD_LOGIC_VECTOR(31 DOWNTO 0);-----DMA完成的PCI地址
SIGNAL DMA_DoneCount:STD_LOGIC_VECTOR(9 DOWNTO 0);
SIGNAL DevselDetect:STD_LOGIC;
SIGNAL Devsel_Counter:STD_LOGIC_VECTOR(3 DOWNTO 0);
----------------------DMA Wr/Rd FIFO--------------------
SIGNAL UUT_DmaRd_FIFO1_Rst:STD_LOGIC;
SIGNAL UUT_DmaRd_FIFO1_Wr:STD_LOGIC;
SIGNAL UUT_DmaRd_FIFO1_Rd:STD_LOGIC;
SIGNAL UUT_DmaRd_FIFO1_DataCount:STD_LOGIC_VECTOR(10 DOWNTO 0);
SIGNAL UUT_DmaRd_FIFO1_Dout:STD_LOGIC_VECTOR(13 DOWNTO 0);
SIGNAL UUT_DmaRd_FIFO1_Full:STD_LOGIC;
SIGNAL UUT_DmaRd_FIFO1_Empty:STD_LOGIC;

SIGNAL UUT_DmaRd_FIFO2_Rst:STD_LOGIC;
SIGNAL UUT_DmaRd_FIFO2_Wr:STD_LOGIC;
SIGNAL UUT_DmaRd_FIFO2_Rd:STD_LOGIC;
SIGNAL UUT_DmaRd_FIFO2_DataCount:STD_LOGIC_VECTOR(10 DOWNTO 0);
SIGNAL UUT_DmaRd_FIFO2_Dout:STD_LOGIC_VECTOR(13 DOWNTO 0);
SIGNAL UUT_DmaRd_FIFO2_Full:STD_LOGIC;
SIGNAL UUT_DmaRd_FIFO2_Empty:STD_LOGIC;

SIGNAL DmaPCIAddress_Rdy:STD_LOGIC;
SIGNAL DmaCount_Rdy:STD_LOGIC;
attribute keep of Curr_State_Dma:SIGNAL IS TRUE;
attribute keep of PCI_Config_WrData:SIGNAL IS TRUE;
--------------------INT REG--------------------
CONSTANT INT_CH1_DATA:NATURAL:=0;
CONSTANT INT_CH2_DATA:NATURAL:=1;
CONSTANT INT_CH1_DMADONE:NATURAL:=2;
CONSTANT INT_CH2_DMADONE:NATURAL:=3;

SIGNAL IntReg:STD_LOGIC_VECTOR(3 DOWNTO 0);
SIGNAL IntReg_Clr:STD_LOGIC_VECTOR(3 DOWNTO 0);
SIGNAL IntMask:STD_LOGIC_VECTOR(3 DOWNTO 0);

SIGNAL CH1_Thres:STD_LOGIC_VECTOR(9 DOWNTO 0);
SIGNAL CH2_Thres:STD_LOGIC_VECTOR(9 DOWNTO 0);

COMPONENT scfifo
  GENERIC ( LPM_WIDTH: POSITIVE;
            LPM_WIDTHU: POSITIVE;
            LPM_NUMWORDS: POSITIVE);
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

COMPONENT SpiMaster IS
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
END COMPONENT;

---------------------------spi----------------------------
SIGNAL UUT_AD9642_SPI1_RW:STD_LOGIC;
SIGNAL UUT_AD9642_SPI1_ADDR:STD_LOGIC_VECTOR(12 DOWNTO 0);
SIGNAL UUT_AD9642_SPI1_DataSend:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL UUT_AD9642_SPI1_DataRecv:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL UUT_AD9642_SPI1_Start:STD_LOGIC;
SIGNAL CH1_EN:STD_LOGIC;

SIGNAL UUT_AD9642_SPI2_RW:STD_LOGIC;
SIGNAL UUT_AD9642_SPI2_ADDR:STD_LOGIC_VECTOR(12 DOWNTO 0);
SIGNAL UUT_AD9642_SPI2_DataSend:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL UUT_AD9642_SPI2_DataRecv:STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL UUT_AD9642_SPI2_Start:STD_LOGIC;
SIGNAL CH2_EN:STD_LOGIC;

attribute keep of ADDRESS:SIGNAL IS TRUE;

BEGIN
	PCI_RST <= RST;
	PCI_CLK <= CLK WHEN RST = '1' ELSE '0';
	PCI_IDSEL <= IDSEL WHEN RST = '1' ELSE '0';
	PCI_FRAME <= FRAME WHEN RST = '1' ELSE '0';
	PCI_AD <= AD WHEN RST = '1' ELSE (OTHERS => '0');
	PCI_CBE <= CBE WHEN RST = '1' ELSE "0000";
	PCI_IRDY <= IRDY WHEN RST = '1' ELSE '0';
	PCI_DEVSEL <= DEVSEL WHEN RST = '1' ELSE '0';
	PCI_STOP <= STOP WHEN RST = '1' ELSE '0';
	PCI_TRDY <= TRDY WHEN RST = '1' ELSE '0';
--	PCI_INTA <= INTA WHEN RST = '1' ELSE '0';
--	PROCESS(RST, Clk)
--	BEGIN
--		IF RST = '0' THEN
--			IDSEL_Counter <= (OTHERS => '0');
--		ELSIF Clk'EVENT AND Clk = '1' THEN
--			IF FRAME = '0' AND IDSEL = '1' THEN
--				IDSEL_Counter <= IDSEL_Counter + 1;
--			END IF;
--		END IF;
--	END PROCESS;
--============================= PAR CHECK =================================	   
--P1       <= AD(31) XOR AD(30) XOR AD(29) XOR AD(28) XOR
--           AD(27) XOR AD(26) XOR AD(25) XOR AD(24);
--P2       <= AD(23) XOR AD(22) XOR AD(21) XOR AD(20) XOR
--           AD(19) XOR AD(18) XOR AD(17) XOR AD(16);
--P3       <= AD(15) XOR AD(14) XOR AD(13) XOR AD(12) XOR
--           AD(11) XOR AD(10) XOR AD( 9) XOR AD( 8);
--P4       <= AD( 7) XOR AD( 6) XOR AD( 5) XOR AD( 4) XOR
--		    AD( 3) XOR AD( 2) XOR AD( 1) XOR AD( 0);
--
--PAR_TEMP <= P1 XOR P2 XOR P3 XOR P4 XOR CBE(3) XOR CBE(2) XOR CBE(1) XOR CBE(0);
--PAR      <= PAR_TEMP WHEN (ConfCS = '1' OR Bar0_CS = '1' OR Bar1_CS = '1' OR Curr_State_DMA = AddrPhase OR (Curr_State_DMA = DataPhase AND DMA_Dir = '1')) AND RW = '0' ELSE 'Z';

PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		ConfCS <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF FRAME = '0' AND STATUS = IDLE_NOR AND IDSEL = '1' AND AD(1 DOWNTO 0) = "00" AND CBE(3 DOWNTO 1) = "101" THEN
			ConfCS <= '1';
		ELSIF TRDY = '0' AND IRDY = '0' THEN
			ConfCS <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		ParGenData <= (OTHERS => '0');
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF IRDY = '0' AND TRDY = '0' THEN
			ParGenData <= AD&CBE;
		ELSIF Curr_State_DMA = AddrPhase OR (Curr_State_DMA = DataPhase AND DMA_Dir = '1') THEN
			ParGenData <= AD&CBE;
		END IF;
	END IF;
END PROCESS;

PROCESS(RST ,Clk)
BEGIN
	IF RST = '0' THEN
		ParGen <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF Curr_State_DMA = AddrPhase THEN
			ParGen <= '1';
		ELSIF STATUS = SDATA AND IRDY = '0' AND TRDY = '0' AND RW = '0' THEN
			ParGen <= '1';
		ELSIF Curr_State_DMA = DataPhase AND DMA_Dir = '1' AND IRDY = '0' AND TRDY = '0' THEN
			ParGen <= '1';
		ELSE
			ParGen <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		PAR <= 'Z';
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF ParGen = '1' THEN
			PAR <= ParGenData(0) XOR ParGenData(1) XOR ParGenData(2) XOR ParGenData(3) XOR ParGenData(4) XOR ParGenData(5)
					XOR ParGenData(6) XOR ParGenData(7) XOR ParGenData(8) XOR ParGenData(9) XOR ParGenData(10) XOR ParGenData(11)
					XOR ParGenData(12) XOR ParGenData(13) XOR ParGenData(14) XOR ParGenData(15) XOR ParGenData(16)
					XOR ParGenData(17) XOR ParGenData(18) XOR ParGenData(19) XOR ParGenData(20) XOR ParGenData(21) 
					XOR ParGenData(22) XOR ParGenData(23) XOR ParGenData(24) XOR ParGenData(25) XOR ParGenData(26)
					XOR ParGenData(27) XOR ParGenData(28) XOR ParGenData(29) XOR ParGenData(30) XOR ParGenData(31)
					XOR ParGenData(32) XOR ParGenData(33) XOR ParGenData(34) XOR ParGenData(35);
		ELSE
			PAR <= 'Z';
		END IF;
	END IF;
END PROCESS;


	
--========================== PCI STATUS SWITCH ============================
PROCESS(RST,CLK)
BEGIN
  IF RST = '0' THEN
	  STATUS <= IDLE_NOR;
  ELSIF CLK'EVENT AND CLK = '1' THEN
	  CASE STATUS IS
		  WHEN IDLE_NOR =>  
				IF FRAME = '0' THEN
					STATUS <= BUSY;
			  	END IF;
         WHEN BUSY =>       
				IF ConfCS = '1' OR Bar0_CS = '1' OR Bar1_CS = '1' THEN
					STATUS <= SDATA;
				ELSIF FRAME = '1' AND IRDY = '1' THEN
					STATUS <= IDLE_NOR;
				END IF;		
         WHEN SDATA =>      
				IF IRDY = '0' AND TRDY = '0' AND FRAME = '1' THEN   									
					STATUS <= TURNAROUND;	
				END IF;
		  WHEN TURNAROUND => 
				IF FRAME = '1' THEN
					STATUS <= IDLE_NOR;
				END IF;
     END CASE;
  END IF;
END PROCESS;

--============================ PCI AD & CBE ===============================
PROCESS(RST,CLK)
BEGIN
  IF RST = '0' THEN
	  ADDRESS <= (OTHERS => '0');
  ELSIF CLK'EVENT AND CLK = '1' THEN
	  IF STATUS = IDLE_NOR AND FRAME = '0' THEN
		 ADDRESS <= AD(15 DOWNTO 0);
	  END IF;
  END IF;
END PROCESS;
	
PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		TRDY <= 'Z';
		TRDY_Delay <= '1';
	ELSIF Clk'EVENT AND Clk = '0' THEN
		ELSIF Clk'EVENT AND Clk = '0' THEN
		IF (ConfCS = '1' OR Bar0_CS = '1' OR Bar1_CS = '1') AND STATUS = SDATA THEN
			TRDY_Delay <= '0';
			TRDY <= TRDY_Delay;
		ELSE
			TRDY_Delay <= '1';
			TRDY <= 'Z';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, Clk)----������ź�
BEGIN
	IF RST = '0' THEN
		RW <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF STATUS = IDLE_NOR AND FRAME = '0' THEN
			RW <= CBE(0);
		END IF;
	END IF;
END PROCESS;
	
PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		STOP <= 'Z';
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF ConfCS = '1' OR Bar0_CS = '1' OR Bar1_CS = '1' THEN
			STOP <= '1';
		ELSE
			STOP <= 'Z';
		END IF;
	END IF;
END PROCESS;

------------------------------CONFIG R/W LOGIC--------------------------
PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		PCI_Config_Wr <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF ConfCS = '1' AND IRDY = '0' AND STATUS = SDATA AND RW = '1' THEN
			PCI_Config_Wr <= '1';
			PCI_Config_WrData <= AD;
		ELSE
			PCI_Config_Wr <= '0';
		END IF;
	END IF;
END PROCESS;
	
PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		ConfReg(0) <= X"12341103";
		ConfReg(1) <= X"00000007";---Status|Command
		ConfReg(2) <= X"00000000";---class code|revision id
		ConfReg(3) <= X"00000000";---BIST|HeaderType|LatencyTimer|CacheLine
		ConfReg(4) <= X"00000000";--BASE0
		ConfReg(5) <= X"00000001";--BASE1
		ConfReg(6) <= X"00000000";--BASE2
		ConfReg(7) <= X"00000000";--BASE3
		ConfReg(8) <= X"00000000";--BASE4
		ConfReg(9) <= X"00000000";--BASE5
		ConfReg(10) <= X"00000000";--CardBus CIS Pointer
		ConfReg(11) <= X"00000000";--SubSystem Device ID|SubSystem Vender ID
		ConfReg(12) <= X"00000000";
		ConfReg(13) <= X"00000000";
		ConfReg(14) <= X"00000000";
		ConfReg(15) <= X"00000100";
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF PCI_Config_Wr = '1' AND ConfCS = '1' THEN
			CASE ADDRESS(5 DOWNTO 2) IS
				WHEN	BaseAddr0 => 
					ConfReg(4)(31 DOWNTO 8) <= PCI_Config_WrData(31 DOWNTO 8);
					ConfReg(4)(7 DOWNTO 0) <= X"00";
				WHEN	BaseAddr1 =>
					ConfReg(5)(31 DOWNTO 16) <= X"0000";
					ConfReg(5)(15 DOWNTO 6) <= PCI_Config_WrData(15 DOWNTO 6);
					ConfReg(5)(5 DOWNTO 0) <= "000001";
				WHEN	X"1"	=>
					IF CBE(0) = '0' THEN
						ConfReg(1)(7 DOWNTO 0) <= PCI_Config_WrData(7 DOWNTO 0);
					END IF;
					
					IF CBE(1) = '0' THEN
						ConfReg(1)(15 DOWNTO 8) <= PCI_Config_WrData(15 DOWNTO 8);
					END IF;
					
					IF CBE(2) = '0' THEN
						ConfReg(1)(23 DOWNTO 16) <= PCI_Config_WrData(23 DOWNTO 16);
					END IF;
					
					IF CBE(3) = '0' THEN
						ConfReg(1)(31 DOWNTO 24) <= PCI_Config_WrData(31 DOWNTO 24);
					END IF;
				WHEN	X"3" =>
					IF CBE(0) = '0' THEN
						ConfReg(3)(7 DOWNTO 0) <= PCI_Config_WrData(7 DOWNTO 0);
					END IF;
					
					IF CBE(1) = '0' THEN
						ConfReg(3)(15 DOWNTO 8) <= PCI_Config_WrData(15 DOWNTO 8);
					END IF;
					
					IF CBE(2) = '0' THEN
						ConfReg(3)(23 DOWNTO 16) <= PCI_Config_WrData(23 DOWNTO 16);
					END IF;
					
					IF CBE(3) = '0' THEN
						ConfReg(3)(31 DOWNTO 24) <= PCI_Config_WrData(31 DOWNTO 24);
					END IF;
				WHEN X"F" =>
					IF CBE(0) = '0' THEN
						ConfReg(15)(7 DOWNTO 0) <= PCI_Config_WrData(7 DOWNTO 0);
					END IF;
					
					IF CBE(1) = '0' THEN
						ConfReg(15)(15 DOWNTO 8) <= PCI_Config_WrData(15 DOWNTO 8);
					END IF;
					
					IF CBE(2) = '0' THEN
						ConfReg(15)(23 DOWNTO 16) <= PCI_Config_WrData(23 DOWNTO 16);
					END IF;
					
					IF CBE(3) = '0' THEN
						ConfReg(15)(31 DOWNTO 24) <= PCI_Config_WrData(31 DOWNTO 24);
					END IF;
				WHEN OTHERS => 
					NULL;
			END CASE;
		END IF;
	END IF;
END PROCESS;
----------------------------------config end
PROCESS(Clk)
BEGIN
	IF Clk'EVENT AND Clk = '0' THEN
		IF RW = '0' AND ConfCS = '1' THEN
			AD <= ConfReg(conv_integer(ADDRESS(5 DOWNTO 2)));
		ELSIF RW = '0' AND Bar0_CS = '1' THEN
			CASE ADDRESS(7 DOWNTO 2) IS
				WHEN "000000" =>
					AD <= X"000000"&UUT_AD9642_SPI1_DataRecv;
				WHEN "000001" =>
					AD <= X"000000"&UUT_AD9642_SPI2_DataRecv;
				WHEN "000010" =>--8
					AD <= X"0000000"&IntReg;
				WHEN "000011" =>--C
					AD <= X"0000000"&IntMask;
				WHEN "000101" =>--14
					AD <= X"0000000"&"000"&Dma_Start;
				WHEN "000110" =>--18
					AD <= DMA_DonePCIAddress;
				WHEN "000111" =>--1C
					AD <= X"00000"&"00"&DMA_DoneCount;
				WHEN "001000" =>--20
					AD <= X"0000000"&"000"&CH1_EN;
				WHEN "001001" =>--24
					AD <= X"0000000"&"000"&CH2_EN;
				WHEN "001010" =>--28
					AD <= X"00000"&"0"&UUT_DmaRd_FIFO1_DataCount;
				WHEN "001011" =>--2C
					AD <= X"00000"&"0"&UUT_DmaRd_FIFO1_DataCount;
				WHEN "001100" =>--30
					AD <= X"00000"&"00"&CH1_Thres;
				WHEN "001110" =>--34
					AD <= X"00000"&"00"&CH2_Thres;
--				WHEN "001100" =>--30
--					AD <= X"000000"&DMAIntCount;
--				WHEN "001101" =>--34
--					AD <= X"000000"&DMAStatus;
--				WHEN "001111" =>--3C
--					AD <= X"000000"&DMACmd;
				WHEN OTHERS =>
					AD <= X"00000000";
			END CASE;
		ELSIF RW = '0' AND Bar1_CS = '1' THEN
			CASE ADDRESS(5 DOWNTO 2) IS
				WHEN "0000" =>
					AD <= Bar1TestReg1;
				WHEN OTHERS =>
					AD <= X"00000000";
			END CASE;
		ELSIF Curr_State_DMA = AddrPhase THEN
			AD <= DMA_PCIAddress;
		ELSIF Curr_State_DMA = DataPhase AND DMA_Dir = '1' THEN
			AD <= X"0000"&"00"&UUT_DmaRd_FIFO1_Dout;
		ELSE
			AD <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";
		END IF;
	END IF;
END PROCESS;
------------------------CONFIG R/W LOGIC END--------------------------------
------------------------BAR0 R/W LOGIC-------------------------------------
PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		Bar0_CS <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF STATUS = IDLE_NOR AND FRAME = '0' AND AD(31 DOWNTO 8) = ConfReg(4)(31 DOWNTO 8) AND CBE(3 DOWNTO 1) = "011" THEN
			Bar0_CS <= '1';
		ELSIF IRDY = '0' AND TRDY = '0' THEN
			Bar0_CS <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		Bar0_Wr <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF Bar0_CS = '1' AND IRDY = '0' AND STATUS = SDATA AND RW = '1' THEN
			Bar0_Wr <= '1';
			Bar0_WrData <= AD;
		ELSE
			Bar0_Wr <= '0';
		END IF;
	END IF;
END PROCESS;
----------------------BAR0 R/W LOGIC END---------------------------------
----------------------BAR0 WRITE LOGIC-----------------------------------
PROCESS(RST, Clk)---------------REGISTER WRITE
BEGIN
	IF RST = '0' THEN
		Bar0TestReg <= (OTHERS => '0');
		IntReg_Clr <= (OTHERS => '0');
		IntMask <= (OTHERS => '0');
		Dma_Start <= '0';
		CH1_EN <= '0';
		CH2_EN <= '0';
		UUT_AD9642_SPI1_Start <= '0';
		UUT_AD9642_SPI2_Start <= '0';
		UUT_DmaDesc_FIFO_Rst <= '0';
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF Bar0_CS = '1' AND Bar0_Wr = '1' THEN
			CASE ADDRESS(7 DOWNTO 2) IS
				WHEN "000000" =>--0
					UUT_AD9642_SPI1_RW <= AD(23);
					UUT_AD9642_SPI1_ADDR <= AD(20 DOWNTO 8);
					UUT_AD9642_SPI1_DataSend <= AD(7 DOWNTO 0);
					UUT_AD9642_SPI1_Start <= '1';
				WHEN "000001" =>--4
					UUT_AD9642_SPI2_RW <= AD(23);
					UUT_AD9642_SPI2_ADDR <= AD(20 DOWNTO 8);
					UUT_AD9642_SPI2_DataSend <= AD(7 DOWNTO 0);
					UUT_AD9642_SPI2_Start <= '1';
				WHEN "000010" =>--8
					IntReg_Clr <= AD(3 DOWNTO 0);
				WHEN "000011" =>--C
					IntMask <= AD(3 DOWNTO 0);
				WHEN "000101" =>--14
					Dma_Start <= AD(0);
				WHEN "001100" =>--30
					CH1_EN <= AD(0);
				WHEN "001101" =>--34
					CH2_EN <= AD(0);
				WHEN "010000" =>--40
					UUT_DmaDesc_FIFO_Rst <= '0';
				WHEN OTHERS => NULL;
			END CASE;
		ELSE
			UUT_AD9642_SPI1_Start <= '0';
			UUT_AD9642_SPI2_Start <= '0';
			IntReg_Clr <= (OTHERS => '0');
			UUT_DmaDesc_FIFO_Rst <= '0';
		END IF;
	END IF;
END PROCESS;

--PROCESS(RST, Clk)--------------FIFO WRITE
--BEGIN
--	IF RST = '0' THEN
--		DMAIntCount_Clr <= '0';
--	ELSIF Clk'EVENT AND Clk = '0' THEN
--		IF Bar0_Wr = '1' AND ADDRESS(7 DOWNTO 2) = "001011" THEN--2c
--			DMAIntCount_Clr <= '1';
--		ELSE
--			DMAIntCount_Clr <= '0';
--		END IF;
--	END IF;
--END PROCESS;

----------------------------BAR1 R/W LOGIC-------------------------
PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		Bar1_CS <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF STATUS = IDLE_NOR AND FRAME = '0' AND AD(31 DOWNTO 6) = ConfReg(5)(31 DOWNTO 6) AND CBE(3 DOWNTO 1) = "001" THEN
			Bar1_CS <= '1';
		ELSIF IRDY = '0' AND TRDY = '0' THEN
			Bar1_CS <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		Bar1_Wr <= '0';
	ELSIF Clk'EVENT AND Clk = '1' THEN
		IF Bar1_CS = '1' AND IRDY = '0' AND STATUS = SDATA AND RW = '1' THEN
			Bar1_Wr <= '1';
		ELSE
			Bar1_Wr <= '0';
		END IF;
	END IF;
END PROCESS;
PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		Bar1TestReg1 <= (OTHERS => '0');
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF Bar1_CS = '1' AND Bar1_Wr = '1' THEN
			CASE ADDRESS(5 DOWNTO 2) IS
				WHEN "0000" =>
					Bar1TestReg1 <= AD;
				WHEN OTHERS => NULL;
			END CASE;
		END IF;
	END IF;
END PROCESS;
---------------------------DMA DESCRIPTOR FIFO------------------
UUT_DmaDesc_FIFO:scfifo
GENERIC MAP (
	LPM_WIDTH => 32,
	LPM_WIDTHU => 10,
	LPM_NUMWORDS => 1024)
PORT MAP (
  clock  => Clk,
  aclr   => UUT_DmaDesc_FIFO_Rst,
  data   => Bar0_WrData,
  wrreq  => UUT_DmaDesc_FIFO_Wr,
  rdreq  => UUT_DmaDesc_FIFO_Rd,
  empty  => UUT_DmaDesc_FIFO_Empty,
  FULL   => UUT_DmaDesc_FIFO_Full,
  q      => UUT_DmaDesc_FIFO_Dout,
  usedw 	=> UUT_DmaDesc_FIFO_DataCount
);

---------------------------DMA LOGIC----------------------------
PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		Curr_State_Dma <= Idle;
	ELSIF Clk'EVENT AND Clk = '1' THEN
		CASE Curr_State_DMA IS
			WHEN Idle =>
				IF Dma_Start = '1' AND UUT_DmaDesc_FIFO_Empty = '0' AND UUT_DmaDesc_FIFO_DataCount(0) = '0' THEN
					Curr_State_DMA <= ReadPCIAddr;
				END IF;
			WHEN ReadPCIAddr =>
				IF DmaPCIAddress_Rdy = '1' THEN
					Curr_State_DMA <= ReadTransCount;
				END IF;
			WHEN ReadTransCount =>
				IF DmaCount_Rdy = '1' THEN
					Curr_State_DMA <= ReqPCIBus;
				END IF;
			WHEN ReqPCIBus =>
				IF nGNT = '0' AND FRAME = '1' AND IRDY = '1' THEN
					Curr_State_DMA <= AddrPhase;
				END IF;
			WHEN AddrPhase =>
				IF DMA_Dir = '0' THEN
					Curr_State_DMA <= DataPhase;
				ELSE
					Curr_State_DMA <= TurnAroundPhase;
				END IF;
			WHEN TurnAroundPhase =>
				Curr_State_DMA <= DataPhase;
			WHEN DataPhase =>
				IF STOP = '0' OR Devsel_Counter = 6 OR DMA_Count = 0 THEN  -----
					Curr_State_DMA <= EndPhase;
				END IF;
			WHEN EndPhase =>
				IF DMA_Count /= 0 THEN
					Curr_State_DMA <= ReqPCIBus;
				ELSE
					Curr_State_DMA <= Idle;
				END IF;
			WHEN OTHERS => NULL;
		END CASE;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		UUT_DmaDesc_FIFO_Rd <= '0';
	ELSIF CLK'EVENT AND CLK = '0' THEN
		IF Curr_State_DMA = ReadPCIAddr AND UUT_DmaDesc_FIFO_Rd = '0' THEN
			UUT_DmaDesc_FIFO_Rd <= '1';
		ELSIF Curr_State_DMA = ReadTransCount AND UUT_DmaDesc_FIFO_Rd = '0' THEN
			UUT_DmaDesc_FIFO_Rd <= '1';
		ELSE
			UUT_DmaDesc_FIFO_Rd <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		DmaPCIAddress_Rdy <= '0';
	ELSIF CLK'EVENT AND CLK = '0' THEN
		IF Curr_State_DMA = ReadPCIAddr AND UUT_DmaDesc_FIFO_Rd = '1' THEN
			DmaPCIAddress_Rdy <= '1';
		ELSE
			DmaPCIAddress_Rdy <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		DmaCount_Rdy <= '0';
	ELSIF CLK'EVENT AND CLK = '0' THEN
		IF Curr_State_DMA = ReadTransCount AND UUT_DmaDesc_FIFO_Rd = '1' THEN
			DmaCount_Rdy <= '1';
		ELSE
			DmaCount_Rdy <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		nREQ <= 'Z';
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF Curr_State_DMA = ReqPCIBus THEN
			nREQ <= '0';
			PCI_nREQ <= '0';
		ELSE
			nREQ <= '1';
			PCI_nREQ <= '1';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		FRAME <= 'Z';
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF Curr_State_DMA = AddrPhase THEN
			FRAME <= '0';
		ELSIF Curr_State_DMA = DataPhase THEN
			IF DMA_Count = 1 THEN
				FRAME <= '1';
			ELSE
				FRAME <= '0';
			END IF;
		ELSIF Curr_State_DMA = EndPhase THEN
			FRAME <= '1';
		ELSE
			FRAME <= 'Z';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		IRDY <= 'Z';
	ELSIF CLK'EVENT AND CLK = '0' THEN
		IF Curr_State_DMA = DataPhase AND DevselDetect = '1' THEN
			IRDY <= '0';
		ELSIF Curr_State_DMA = EndPhase THEN
			IRDY <= '1';
		ELSE
			IRDY <= 'Z';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		CBE <= "ZZZZ";
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF Curr_State_DMA = AddrPhase THEN
			CBE <= "011"&DMA_Dir;
		ELSIF Curr_State_DMA = DataPhase THEN
			CBE <= "0000";
		ELSE
			CBE <= "ZZZZ";
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, Clk)
BEGIN
	IF RST = '0' THEN
		DEVSEL <= 'Z';
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF (ConfCS = '1' OR Bar0_CS = '1' OR Bar1_CS = '1') AND STATUS = SDATA THEN
			DEVSEL <= '0';
		ELSE 
			DEVSEL <= 'Z';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		Devsel_Counter <= (OTHERS => '0');
	ELSIF CLK'EVENT AND CLk = '1' THEN
		IF Curr_State_DMA = AddrPhase THEN
			Devsel_Counter <= (OTHERS => '0');
			DevselDetect <= '0';
		ELSIF Curr_State_DMA = DataPhase THEN
			IF DEVSEL = '0' THEN
				DevselDetect <= '1';
			ELSIF DevselDetect = '0' THEN
				Devsel_Counter <= Devsel_Counter + 1;
			END IF;
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		DMA_Count <= (OTHERS => '0');
		DMA_Channel <= '0';
	ELSIF CLK'EVENT AND CLK = '1' THEN
		IF DmaCount_Rdy = '1' AND Curr_State_DMA = ReadTransCount THEN
			DMA_Channel <= UUT_DmaDesc_FIFO_Dout(31);--第31位表示通道，目前支持两通道
			DMA_Count <= UUT_DmaDesc_FIFO_Dout(9 DOWNTO 0);
			DMA_DoneCount <= UUT_DmaDesc_FIFO_Dout(9 DOWNTO 0);
		ELSIF Curr_State_DMA = DataPhase THEN
			IF TRDY = '0' AND IRDY = '0' THEN
				DMA_Count <= DMA_Count - 1;
			END IF;
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		DMA_PCIAddress <= (OTHERS => '0');
		DMA_Dir <= '0';
	ELSIF CLK'EVENT AND CLK = '1' THEN
		IF DmaPCIAddress_Rdy = '1' AND Curr_State_DMA = ReadPCIAddr THEN
			DMA_PCIAddress <= UUT_DmaDesc_FIFO_Dout(31 DOWNTO 2)&"00";
			DMA_DonePCIAddress <= UUT_DmaDesc_FIFO_Dout(31 DOWNTO 2)&"00";
			DMA_Dir <= UUT_DMADesc_FIFO_Dout(0);
			DMAIntFlag <= UUT_DMADesc_FIFO_Dout(1);
		ELSIF Curr_State_DMA = DataPhase THEN
			IF IRDY = '0' AND TRDY = '0' THEN
				DMA_PCIAddress(31 DOWNTO 2) <= DMA_PCIAddress(31 DOWNTO 2) + 1;
			END IF;
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		UUT_DmaRd_FIFO1_Rd <= '0';
	ELSIF CLK'EVENT AND Clk = '0' THEN
		IF Curr_State_DMA = DataPhase AND DMA_Dir = '1' AND TRDY = '0' AND DMA_Channel = '0' THEN
			UUT_DmaRd_FIFO1_Rd <= '1';
		ELSE
			UUT_DmaRd_FIFO1_Rd <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		UUT_DmaRd_FIFO2_Rd <= '0';
	ELSIF CLK'EVENT AND Clk = '0' THEN
		IF Curr_State_DMA = DataPhase AND DMA_Dir = '1' AND TRDY = '0' AND DMA_Channel = '1' THEN
			UUT_DmaRd_FIFO2_Rd <= '1';
		ELSE
			UUT_DmaRd_FIFO2_Rd <= '0';
		END IF;
	END IF;
END PROCESS;

--PROCESS(RST, CLK)
--BEGIN
--	IF RST = '0' THEN
--		DMAIntCount <= (OTHERS => '0');
--	ELSIF CLK'EVENT AND CLK = '0' THEN
--		IF DMAIntCount_Clr = '1' THEN
--			DMAIntCount <= (OTHERS => '0');
--		ELSIF DMAIntFlag = '1' AND Curr_State_DMA = EndPhase AND DMA_Count = 0 AND DMAIntFlag = '1' THEN
--			DMAIntCount <= DMAIntCount + 1;
--		END IF;
--	END IF;
--END PROCESS;
------------------------------中断状态产生---------------------------
PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		IntReg(INT_CH1_DATA) <= '0';
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF UUT_DmaRd_FIFO1_DataCount >= CH1_Thres THEN
			IntReg(INT_CH1_DATA) <= '1';
		ELSE
			IntReg(INT_CH1_DATA) <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		IntReg(INT_CH2_DATA) <= '0';
	ELSIF Clk'EVENT AND Clk = '0' THEN
		IF UUT_DmaRd_FIFO2_DataCount >= CH2_Thres THEN
			IntReg(INT_CH2_DATA) <= '1';
		ELSE
			IntReg(INT_CH2_DATA) <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		IntReg(INT_CH1_DMADONE) <= '0';
	ELSIF CLK'EVENT AND CLK = '0' THEN
		IF IntReg_Clr(INT_CH1_DMADONE) = '1' THEN
			IntReg(INT_CH1_DMADONE) <= '0';
		ELSIF DMAIntFlag = '1' AND Curr_State_DMA = EndPhase AND DMA_Count = 0 AND DMAIntFlag = '1' AND DMA_Channel = '0' THEN
			IntReg(INT_CH1_DMADONE) <= '1';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		IntReg(INT_CH2_DMADONE) <= '0';
	ELSIF CLK'EVENT AND CLK = '0' THEN
		IF IntReg_Clr(INT_CH2_DMADONE) = '1' THEN
			IntReg(INT_CH2_DMADONE) <= '0';
		ELSIF DMAIntFlag = '1' AND Curr_State_DMA = EndPhase AND DMA_Count = 0 AND DMAIntFlag = '1' AND DMA_Channel = '1' THEN
			IntReg(INT_CH2_DMADONE) <= '1';
		END IF;
	END IF;
END PROCESS;

PROCESS(RST, CLK)
BEGIN
	IF RST = '0' THEN
		INTA <= 'Z';
	ELSIF CLK'EVENT AND CLK = '1' THEN
		IF (IntMask(0) AND IntReg(0))= '1' OR (IntMask(1) AND IntReg(1)) = '1' OR (IntMask(2) AND IntReg(2))= '1' OR (IntMask(3) AND IntReg(3)) = '1' THEN--you can add other interrupt here
			INTA <= '0';
		ELSE
			INTA <= 'Z';
		END IF;
	END IF;
END PROCESS;

------------------------------中断状态结束---------------------------
UUT_AD9642_SPI1:SpiMaster
PORT MAP(
	nRst => RST,
	Clk => Clk,
	En => '1',
	FreqDiv => X"10",
	RW => UUT_AD9642_SPI1_RW,
	ADDR => UUT_AD9642_SPI1_ADDR,
	DataSend => UUT_AD9642_SPI1_DataSend,
	DataRecv => UUT_AD9642_SPI1_DataRecv,
	Start => UUT_AD9642_SPI1_Start,
	-----------spi port------------
	nCS => AD9642_SPI1_nCS,
	SDIO => AD9642_SPI1_SDIO,
	SCK => AD9642_SPI1_CLK
);

UUT_AD9642_SPI2:SpiMaster
PORT MAP(
	nRst => RST,
	Clk => Clk,
	En => '1',
	FreqDiv => X"10",
	RW => UUT_AD9642_SPI2_RW,
	ADDR => UUT_AD9642_SPI2_ADDR,
	DataSend => UUT_AD9642_SPI2_DataSend,
	DataRecv => UUT_AD9642_SPI2_DataRecv,
	Start => UUT_AD9642_SPI2_Start,
	-----------spi port------------
	nCS => AD9642_SPI2_nCS,
	SDIO => AD9642_SPI2_SDIO,
	SCK => AD9642_SPI2_CLK
);

-------AD1 数据存储FIFO --------------------
UUT_DmaRd_FIFO1_Wr <= AD9642_C1_DCO AND CH1_EN;
UUT_DmaRd_FIFO1:scfifo
GENERIC MAP (
	LPM_WIDTH => 14,
	LPM_WIDTHU => 11,
	LPM_NUMWORDS => 2048)
PORT MAP (
  data   => AD9642_C1_D,
  clock  => Clk,
  wrreq  => UUT_DmaRd_FIFO1_Wr,
  rdreq  => UUT_DmaRd_FIFO1_Rd,
  aclr   => UUT_DmaRd_FIFO1_Rst,
  empty  => UUT_DmaRd_FIFO1_Empty,
  FULL   => UUT_DmaRd_FIFO1_Full,
  q      => UUT_DmaRd_FIFO1_Dout,
  usedw 	=> UUT_DmaRd_FIFO1_DataCount
);
-------AD2 数据存储FIFO --------------------
UUT_DmaRd_FIFO2_Wr <= AD9642_C2_DCO AND CH2_EN;
UUT_DmaRd_FIFO2:scfifo
GENERIC MAP (
	LPM_WIDTH => 14,
	LPM_WIDTHU => 11,
	LPM_NUMWORDS => 2048)
PORT MAP (
  data   => AD9642_C2_D,
  clock  => Clk,
  wrreq  => UUT_DmaRd_FIFO2_Wr,
  rdreq  => UUT_DmaRd_FIFO2_Rd,
  aclr   => UUT_DmaRd_FIFO2_Rst,
  empty  => UUT_DmaRd_FIFO2_Empty,
  FULL   => UUT_DmaRd_FIFO2_Full,
  q      => UUT_DmaRd_FIFO2_Dout,
  usedw 	=> UUT_DmaRd_FIFO2_DataCount
);


END BEHAVE;