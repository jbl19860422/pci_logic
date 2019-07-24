--***************************
--MODULE NAME:SEND_CTRL.vhd
--Description:发送控制逻辑，连接FIFO和发送器,只要FIFO非空，且发送器空闲，就会产生FIFO读信号，并将数据送到发送器进行发送;
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
  ----时钟和使能信号
  I_Clk :IN   STD_LOGIC;
  I_En:IN	STD_LOGIC;
  ----和FIFO连接的信号
  O_Fifo_Rd:OUT STD_LOGIC;
  I_Fifo_Empty:IN STD_LOGIC;
  I_Fifo_DataOut:IN  STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0);
  ----和发送器连接的信号
  I_Sender_Ready:IN  STD_LOGIC;--发送器准备好发送
  O_Sender_Wr  :OUT  STD_LOGIC;--数据写入发送器，并启动发送
  O_Sender_DataIn:OUT  STD_LOGIC_VECTOR(Data_width - 1 DOWNTO 0)--写入发送器的数据
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
	ELSIF I_Clk'EVENT AND I_Clk = '0' THEN--下降沿发送读信号
		IF I_En = '1' AND FifoData_Ready = '0' AND I_Fifo_Empty = '0' THEN--只要使能，并且FIFO有数据，且之前前给发送器的数据已经打入发送器就启动一个读FIFO操作
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
		IF Fifo_Rd_Reg = '1' THEN--只要在上升沿，FIFO读信号有效，那么FIFO读出的数据就送到了发送器的数据总线上了
			FifoData_Ready <= '1';
		ELSIF Sender_Wr_Reg = '1' THEN--如果数据打入了发送器，那么该数据总线上的数据就无效了
			FifoData_Ready <= '0';
		END IF;
	END IF;
END PROCESS;
O_Sender_DataIn <= I_Fifo_DataOut;

PROCESS(I_nRst, I_Clk)
BEGIN
	IF I_nRst = '0' THEN
		Sender_Wr_Reg <= '0';
	ELSIF I_Clk'EVENT AND I_Clk = '0' THEN--下降沿判断
		IF FifoData_Ready = '1' AND I_Sender_Ready = '1' THEN--数据总线上数据已经有效，发送器准备好，则启动发送操作
			Sender_Wr_Reg <= '1';
		ELSE
			Sender_Wr_Reg <= '0';--否则等待
		END IF;
	END IF;
END PROCESS;
O_Sender_Wr <= Sender_Wr_Reg;

END bhv_SEND_CTRL;