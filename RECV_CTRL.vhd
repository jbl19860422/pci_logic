LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
--���տ����߼���ʵ��FIFO�ͽ�����������
--���������յ����ݺ�ͨ����ģ�飬�Զ�����������FIFO��
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
		IF I_Receiver_Ready = '1' THEN--���������ReadyΪ1�����������������ϵ�����һ����Ч�ˣ�����дFIFO
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
		IF I_Receiver_Ready = '1' THEN--ֻҪ������׼���ã��͸���������һ�����źţ�ʹ������������ݣ����������һֱ�����ݱ��������ż����������ݡ�
			Receiver_Rd_Reg <= '1';
		ELSE
			Receiver_Rd_Reg <= '0';
		END IF;
	END IF;
END PROCESS;
O_Receiver_Rd <= Receiver_Rd_Reg;
END bhv_RECV_CTRL;