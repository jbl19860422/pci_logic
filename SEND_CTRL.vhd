--***************************
--MODULE NAME:SEND_CTRL.vhd
--Description:���Ϳ����߼�������FIFO�ͷ�����,ֻҪFIFO�ǿգ��ҷ��������У��ͻ����FIFO���źţ����������͵����������з���;
--Version:0.1
--Author:JiangBaoLin
--Date:2014.04.19
--Update:
--Copyright 2014 by XiChenCeKong, all rights reserved.
--***************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY SEND_CTRL IS
GENERIC(Data_width:INTEGER:=8);
PORT (
  I_nRst:IN   STD_LOGIC;
  ----ʱ�Ӻ�ʹ���ź�
  I_Clk :IN   STD_LOGIC;
  I_En:IN	STD_LOGIC;
  ----��FIFO���ӵ��ź�
  O_Fifo_Rd:OUT STD_LOGIC;
  I_Fifo_Empty:IN STD_LOGIC;
  I_Fifo_DataOut:IN  STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0);
  ----�ͷ��������ӵ��ź�
  I_Sender_Ready:IN  STD_LOGIC;--������׼���÷���
  O_Sender_Wr  :OUT  STD_LOGIC;--����д�뷢����������������
  O_Sender_DataIn:OUT  STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0)--д�뷢����������
);
END ENTITY;

ARCHITECTURE bhv_SEND_CTRL OF SEND_CTRL IS
SIGNAL FifoData_Ready:STD_LOGIC;
SIGNAL Fifo_Rd_Reg:STD_LOGIC;
SIGNAL Sender_Wr_Reg:STD_LOGIC;
BEGIN
PROCESS(I_nRst, I_Clk)
BEGIN
	IF I_nRst = '0' THEN
		Fifo_Rd_Reg <= '0';
	ELSIF I_Clk'EVENT AND I_Clk = '0' THEN--�½��ط��Ͷ��ź�
		IF I_En = '1' AND FifoData_Ready = '0' AND I_Fifo_Empty = '0' THEN--ֻҪʹ�ܣ�����FIFO�����ݣ���֮ǰǰ���������������Ѿ����뷢����������һ����FIFO����
			Fifo_Rd_Reg <= '1';
		ELSE
			Fifo_Rd_Reg <= '0';
		END IF;
	END IF;
END PROCESS;
O_Fifo_Rd <= Fifo_Rd_Reg;

PROCESS(I_nRst, I_Clk)
BEGIN
	IF I_nRst = '0' THEN
		FifoData_Ready <= '0';
	ELSIF I_Clk'EVENT AND I_Clk = '1' THEN
		IF Fifo_Rd_Reg = '1' THEN--ֻҪ�������أ�FIFO���ź���Ч����ôFIFO���������ݾ��͵��˷�������������������
			FifoData_Ready <= '1';
		ELSIF Sender_Wr_Reg = '1' THEN--������ݴ����˷���������ô�����������ϵ����ݾ���Ч��
			FifoData_Ready <= '0';
		END IF;
	END IF;
END PROCESS;
O_Sender_DataIn <= I_Fifo_DataOut;

PROCESS(I_nRst, I_Clk)
BEGIN
	IF I_nRst = '0' THEN
		Sender_Wr_Reg <= '0';
	ELSIF I_Clk'EVENT AND I_Clk = '0' THEN--�½����ж�
		IF FifoData_Ready = '1' AND I_Sender_Ready = '1' THEN--���������������Ѿ���Ч��������׼���ã����������Ͳ���
			Sender_Wr_Reg <= '1';
		ELSE
			Sender_Wr_Reg <= '0';--����ȴ�
		END IF;
	END IF;
END PROCESS;
O_Sender_Wr <= Sender_Wr_Reg;

END bhv_SEND_CTRL;