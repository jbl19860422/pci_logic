LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
--接收控制逻辑，实现FIFO和接收器的连接
--当接收器收到数据后，通过该模块，自动将数据输入FIFO中
ENTITY RECV_CTRL IS
GENERIC(Data_width:NATURAL:=8);
PORT (
  I_nRst:IN   STD_LOGIC;
  I_Clk :IN   STD_LOGIC;
  ----connect with shifter_in
  I_Receiver_Ready:IN    STD_LOGIC;
  O_Receiver_Rd  : OUT  STD_LOGIC;
  I_Receiver_DataOut:IN  STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0);
  ----connect with fifo 
  O_Fifo_Wr:OUT  STD_LOGIC;
  O_Fifo_Datain:OUT  STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0);
  I_Fifo_Full:IN STD_LOGIC
);
END ENTITY;

ARCHITECTURE bhv_RECV_CTRL OF RECV_CTRL IS
SIGNAL ReceiverData_Ready:STD_LOGIC;
SIGNAL Receiver_Rd_Reg:STD_LOGIC;
BEGIN

PROCESS(I_nRst, I_Clk)
BEGIN
	IF I_nRst = '0' THEN
		O_Fifo_Wr <= '0';
	ELSIF I_Clk'EVENT AND I_Clk = '0' THEN
		IF I_Receiver_Ready = '1' THEN--如果接收器Ready为1（接收器数据总线上的数据一定有效了），则写FIFO
			IF I_Fifo_Full = '0' THEN
				O_Fifo_Wr <= '1';
			ELSE
				O_Fifo_Wr <= '0';
			END IF;
		ELSE
			O_Fifo_Wr <= '0';
		END IF;
	END IF;
END PROCESS;
O_Fifo_Datain <= I_Receiver_DataOut;

PROCESS(I_nRst, I_Clk)
BEGIN
	IF I_nRst = '0' THEN
		Receiver_Rd_Reg <= '0';
	ELSIF I_Clk'EVENT AND I_Clk = '0' THEN
		IF I_Receiver_Ready = '1' THEN--只要接收器准备好，就给接收器发一个读信号，使其继续接收数据，否则接收器一直等数据被读出，才继续接收数据。
			Receiver_Rd_Reg <= '1';
		ELSE
			Receiver_Rd_Reg <= '0';
		END IF;
	END IF;
END PROCESS;
O_Receiver_Rd <= Receiver_Rd_Reg;
END bhv_RECV_CTRL;