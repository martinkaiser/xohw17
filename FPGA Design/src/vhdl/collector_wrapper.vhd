-- Copyright (c) 2017 Martin Kaiser and Sarah Pilz
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--------------------------------------------------------------------------------
-- CITEC - Center of Excellence Cognitive Interaction Technology
-- Bielefeld University
-- Cognitronics & Sensor Systems
--
-- File Name   : collector_wrapper.vhd
-- Author      : Martin Kaiser and Sarah Pilz
-- Description : Wrapper for the collector unit. The first stage of fifos is generated
--               and the next stage instantiated.
--
-- Revision History:
--------------------------------------------------------------------------------
--
-- Version | Author                        | Date       | Changes
-----------+-------------------------------+------------+----------------------------
-- 1.0     | Martin Kaiser and Sarah Pilz  | 2017-06-30 | - initial release
-----------+-------------------------------+------------+----------------------------

-----------------
--  LIBRARIES  --                                                
-----------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;


library hamming_dist;
use hamming_dist.collector_pkg.all;
use hamming_dist.hamming_dist_element_wrapper_pkg.all;

--------------
--  ENTITY  --                                                
--------------

entity collector_wrapper is
  generic(
    NUMBER_OF_HAMMING_ELEMENTS : in integer;
    COLLECTOR_STAGES : in integer;
    PORTS_PER_ARBITER : in integer;
    HPE_CNT_IN_EACH_STATE : in HPE_STAGE_COUNTING
  );
  port(
    CLK_IN               : in  std_logic;
    RESET_N_IN           : in  std_logic;
    HPE_RESULTS_IN          : in  array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS-1); 
    HPE_RESULTS_WR_REQ_IN   : in  unsigned(NUMBER_OF_HAMMING_ELEMENTS-1 downto 0);
    --get colltected results
    READ_COL_FIFO_RESULTS               : in  std_logic;
    COL_RESULTS_FIFO_DATA_OUT           : out  std_logic_vector(127 downto 0); 
    COL_RESULTS_FIFO_EMPTY_OUT          : out  std_logic; 
    COL_RESULTS_FIFO_ALMOSTEMPTY_OUT    : out  std_logic; 
    ENABLE_HPE_OUT                        : out std_logic -- = almostfull to stop hpe in time to not loose any results
  );
end collector_wrapper;

--------------------
--  ARCHITECTURE  --
--------------------

architecture RTL of collector_wrapper is

  ------------------------------
  --  COMPONENT DECLARATIONS  --
  ------------------------------

  --fifos for the first collector stage
COMPONENT fifo_cmnclkbram_fwft_wwr64_d32_wrd64_almostfull_almostempty
  PORT (
    clk : IN STD_LOGIC;
    srst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    full : OUT STD_LOGIC;
    almost_full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    almost_empty : OUT STD_LOGIC
  );
END COMPONENT;
  
  
  
--Collector tree  
COMPONENT collector_elem 
  generic(
    COLLECTOR_STAGES          : in integer;
    HPE_CNT_IN_EACH_STATE     : in HPE_STAGE_COUNTING;
    CURRENT_COLLECTOR_STAGE   : in integer;
    PORTS_PER_ARBITER         : in integer;
    AGGREGATE                 : in std_logic
  );
  port(
        CLK_IN                              : in  std_logic;
    RESET_N_IN                          : in  std_logic;
    --communication to last/next rekursion stage
    ARBITER_REQ_FIFO_DATA_IN            : in array_col_fifo_64(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE-1)-1); 
    ARBITER_REQ_FIFO_EMPTY_IN           : in array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE-1)-1); 
    ARBITER_REQ_FIFO_ALMOSTEMPTY_IN     : in array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE-1)-1); 
    ARBITER_REQ_FIFO_ALMOSTFULL_IN      : in array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE-1)-1); 
    ARBITER_GNT_RD_EN_OUT               : out array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE-1)-1); 
    --results output from last stage to collector output
    COL_RES_REQ_FIFO_DATA_OUT           : out std_logic_vector(127 downto 0); 
    COL_RES_REQ_FIFO_EMPTY_OUT          : out std_logic; 
    COL_RES_REQ_FIFO_ALMOSTEMPTY_OUT    : out std_logic; 
    COL_RES_REQ_FIFO_ALMOSTFULL_OUT     : out std_logic; 
    COL_RES_RD_EN_IN                    : in std_logic
    );
END COMPONENT;

  
  
  ---------------------------
  --  SIGNAL DECLARATIONS  --
  ---------------------------


  --HPE direct collector fifo
  type array_pefifo_fixed_fifo_length is array (0 to NUMBER_OF_HAMMING_ELEMENTS - 1) of std_logic_vector(63 downto 0);
  signal pefifo_outputs : array_col_fifo_64(0 to NUMBER_OF_HAMMING_ELEMENTS-1); 
  type array_pefifo_ctrlsignals is array (0 to NUMBER_OF_HAMMING_ELEMENTS - 1) of std_logic;
  
  -- fifo signals
  signal pefifo_rd_en : array_ctrlsignals(0 to NUMBER_OF_HAMMING_ELEMENTS-1);
  signal pefifo_full : array_ctrlsignals(0 to NUMBER_OF_HAMMING_ELEMENTS-1);
  signal pefifo_empty : array_ctrlsignals(0 to NUMBER_OF_HAMMING_ELEMENTS-1);
  signal pefifo_almostfull : array_ctrlsignals(0 to NUMBER_OF_HAMMING_ELEMENTS-1);
  signal pefifo_almostempty : array_ctrlsignals(0 to NUMBER_OF_HAMMING_ELEMENTS-1);
  
  signal fifo_reset : std_logic;

---------
begin  --
---------
   ENABLE_HPE_OUT <= '1' when unsigned(pefifo_almostfull) = to_unsigned(0, pefifo_almostfull'length) else '0'; 
   fifo_reset <= not RESET_N_IN;
   
  -------------------------------
  --  COMPONENT INSTANTIAIONS  --
  -------------------------------  

gen_collector_stage0 : for i in 0 to NUMBER_OF_HAMMING_ELEMENTS-1 generate
  begin  
  pe_fifo : fifo_cmnclkbram_fwft_wwr64_d32_wrd64_almostfull_almostempty
   PORT MAP (
     clk => CLK_IN,
     srst => fifo_reset,
     din => HPE_RESULTS_IN(i),
     wr_en => HPE_RESULTS_WR_REQ_IN(i),
     rd_en => pefifo_rd_en(i),
     dout => pefifo_outputs(i),
     full => pefifo_full(i),
     almost_full => pefifo_almostfull(i),
     empty => pefifo_empty(i),
     almost_empty => pefifo_almostempty(i)
   );  
end generate gen_collector_stage0;
 

collector_stage1 : collector_elem 
  generic map(
    COLLECTOR_STAGES          => COLLECTOR_STAGES,
    HPE_CNT_IN_EACH_STATE     => HPE_CNT_IN_EACH_STATE,
    CURRENT_COLLECTOR_STAGE   => 1,
    PORTS_PER_ARBITER         => PORTS_PER_ARBITER,
    AGGREGATE                 => '0'
  )
  port map(
    CLK_IN                   => CLK_IN, 
    RESET_N_IN               => RESET_N_IN, 
    --communication to last stage
    ARBITER_REQ_FIFO_DATA_IN            => pefifo_outputs, 
    ARBITER_REQ_FIFO_EMPTY_IN           => pefifo_empty,
    ARBITER_REQ_FIFO_ALMOSTEMPTY_IN     => pefifo_almostempty,
    ARBITER_REQ_FIFO_ALMOSTFULL_IN      => pefifo_almostfull,
    ARBITER_GNT_RD_EN_OUT               => pefifo_rd_en, 
    --communication to next stage
    COL_RES_REQ_FIFO_DATA_OUT           => COL_RESULTS_FIFO_DATA_OUT,
    COL_RES_REQ_FIFO_EMPTY_OUT          => COL_RESULTS_FIFO_EMPTY_OUT,
    COL_RES_REQ_FIFO_ALMOSTEMPTY_OUT    => COL_RESULTS_FIFO_ALMOSTEMPTY_OUT,
    COL_RES_REQ_FIFO_ALMOSTFULL_OUT     => open, 
    COL_RES_RD_EN_IN                    => READ_COL_FIFO_RESULTS
    );
end RTL;     