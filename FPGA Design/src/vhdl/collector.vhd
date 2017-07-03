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
-- File Name   : collector.vhd
-- Author      : Martin Kaiser and Sarah Pilz
-- Description : Collector unit with generic generation of fifos and arbiters 
--               for the current stage. Next stage of the collector unit is 
--               called recursivly until the last stage with only one fifo is reached.
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


--------------
--  ENTITY  --                                                
--------------

entity collector_elem is
  generic(
    COLLECTOR_STAGES          : in integer; 
    HPE_CNT_IN_EACH_STATE     : in HPE_STAGE_COUNTING;
    CURRENT_COLLECTOR_STAGE   : in integer;
    PORTS_PER_ARBITER         : in integer;       --the chosen number of input ports for every arbiter
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
end collector_elem;
 
 
--------------------
--  ARCHITECTURE  --
--------------------

architecture RTL of collector_elem is

  ------------------------------
  --  COMPONENT DECLARATIONS  --
  ------------------------------
	
	-- component declaration is necessary here, because the component is recursively instantiated
  COMPONENT collector_elem
  generic(
    COLLECTOR_STAGES          : in integer;
    HPE_CNT_IN_EACH_STATE     : in HPE_STAGE_COUNTING;
    CURRENT_COLLECTOR_STAGE   : in integer;
    PORTS_PER_ARBITER         : in integer;
    AGGREGATE                 : in std_logic := '0'
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
  
  
  --Collect
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

  --Collect and Aggregate
COMPONENT fifo_cmnclkbram_fwft_wwr64_d64_wrd128_almostfull_almostempty --64 to 128 fifo
  PORT (
    srst : IN STD_LOGIC;
    clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    full : OUT STD_LOGIC;
    almost_full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    almost_empty : OUT STD_LOGIC
  );
END COMPONENT;

component arbiterRR is
    Generic ( nports : integer := 4 );
    Port ( reset_n_in         : in STD_LOGIC;
           clk_in             : in STD_LOGIC;
           request_in         : in STD_LOGIC_VECTOR(nports-1 downto 0);
           urgent_request_in  : in STD_LOGIC_VECTOR(nports-1 downto 0);
           grant_out          : out STD_LOGIC_VECTOR(nports-1 downto 0);
           enbale_in          : in STD_LOGIC
         );
end component arbiterRR;


  ---------------------------
  --  SIGNAL DECLARATIONS  --
  ---------------------------
  
  --collector fifo
  signal collector_fifo_din : array_col_fifo_64(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE) - 1) := (others => (others => '0'));
  signal collector_fifo_dout_64 : array_col_fifo_64(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE) - 1);
  signal collector_fifo_dout_128 : array_col_fifo_128(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE) - 1);
  signal collector_fifo_wr_en : array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE)-1) := (others => '0');
  signal collector_fifo_rd_en : array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE)-1) := (others => '0');
  signal collector_fifo_full : array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE)-1);
  signal collector_fifo_empty : array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE)-1);
  signal collector_fifo_almostfull : array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE)-1);
  signal collector_fifo_almostempty : array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE)-1); 
 
   --helper signals
  signal next_fifo_lock_rd     : std_logic_vector(HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE-1)-1 downto 0);
  signal current_fifo_lock_rd  : std_logic_vector(HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE-1)-1 downto 0) := (others => '0');
  
   --arbiter instance
  type arbiter_request_signals is array (0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE) - 1) of std_logic_vector(PORTS_PER_ARBITER-1 downto 0);
  signal arbiter_tree_grant_out : arbiter_request_signals;
  signal arbiter_tree_enable : array_ctrlsignals(0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE)-1) := (others => '0');
  signal arbiter_tree_request : arbiter_request_signals := (others => (others => '0'));
  signal arbiter_tree_urgent_request : arbiter_request_signals := (others => (others => '0'));
  
 signal reset : std_logic := '0';
 ---------
begin                                   --
---------

  -------------------------------
  --  COMPONENT INSTANTIAIONS  --
  -------------------------------     

  --The number of needed fifos and arbiters are generated for the current stage
FIFO_AND_ARBITER_GENERATE: for i in 0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE)-1 generate  
  begin
  --Collector fifos
  GEN_FIFOS_64 : if(CURRENT_COLLECTOR_STAGE < COLLECTOR_STAGES-1) generate
    collect_64_to_64_bit_fifo : fifo_cmnclkbram_fwft_wwr64_d32_wrd64_almostfull_almostempty
    PORT MAP (
      clk => CLK_IN,
      srst => reset,
      din => collector_fifo_din(i),
      wr_en => collector_fifo_wr_en(i),
      rd_en => collector_fifo_rd_en(i),
      dout => collector_fifo_dout_64(i),
      full => collector_fifo_full(i),
      almost_full => collector_fifo_almostfull(i),
      empty => collector_fifo_empty(i),
      almost_empty => collector_fifo_almostempty(i)
    );
  end generate GEN_FIFOS_64;
  
  --In the last stage a single fifo with 128 bit output port is generated to collect and aggregate results until 
  --they are read out by the host
   GEN_FIFO_64_TO_128 : if(CURRENT_COLLECTOR_STAGE = COLLECTOR_STAGES-1) generate 
    collect_64_to_128_bit_fifo : fifo_cmnclkbram_fwft_wwr64_d64_wrd128_almostfull_almostempty
    PORT MAP (
      clk => CLK_IN,
      srst => reset,
      din => collector_fifo_din(i),
      wr_en => collector_fifo_wr_en(i),
      rd_en => collector_fifo_rd_en(i),
      dout => collector_fifo_dout_128(i),
      full => collector_fifo_full(i),
      almost_full => collector_fifo_almostfull(i),
      empty => collector_fifo_empty(i),
      almost_empty => collector_fifo_almostempty(i)
    );
  end generate GEN_FIFO_64_TO_128;
  
  
  --arbiter instance
  arbiter_further_instance: arbiterRR 
    generic map ( 
        nports => PORTS_PER_ARBITER )
    port map ( 
           reset_n_in         => RESET_N_IN,
           clk_in             => CLK_IN,
           request_in         => arbiter_tree_request(i),
           urgent_request_in  => arbiter_tree_urgent_request(i),
           grant_out          => arbiter_tree_grant_out(i),
           enbale_in          => arbiter_tree_enable(i)
         );
  
   
 end generate FIFO_AND_ARBITER_GENERATE;
 


 --Recursive new collector instances until the last stage with only one fifo was reached
  CX : if(CURRENT_COLLECTOR_STAGE < COLLECTOR_STAGES-1) generate
begin
  collector_stageX : collector_elem 
  generic map(
    COLLECTOR_STAGES          => COLLECTOR_STAGES,
    HPE_CNT_IN_EACH_STATE     => HPE_CNT_IN_EACH_STATE,
    CURRENT_COLLECTOR_STAGE   => CURRENT_COLLECTOR_STAGE +1,
    PORTS_PER_ARBITER         => PORTS_PER_ARBITER,
    AGGREGATE                 => '0'
  )
  port map(
    CLK_IN                   => CLK_IN, 
    RESET_N_IN               => RESET_N_IN, 
    --communication to previous stage
    ARBITER_REQ_FIFO_DATA_IN            => collector_fifo_dout_64,
    ARBITER_REQ_FIFO_EMPTY_IN           => collector_fifo_empty,
    ARBITER_REQ_FIFO_ALMOSTEMPTY_IN     => collector_fifo_almostempty,
    ARBITER_REQ_FIFO_ALMOSTFULL_IN      => collector_fifo_almostfull,
    ARBITER_GNT_RD_EN_OUT               => collector_fifo_rd_en,
    --communication to next stage
    COL_RES_REQ_FIFO_DATA_OUT           => COL_RES_REQ_FIFO_DATA_OUT, 
    COL_RES_REQ_FIFO_EMPTY_OUT          => COL_RES_REQ_FIFO_EMPTY_OUT,
    COL_RES_REQ_FIFO_ALMOSTEMPTY_OUT    => COL_RES_REQ_FIFO_ALMOSTEMPTY_OUT,
    COL_RES_REQ_FIFO_ALMOSTFULL_OUT     => COL_RES_REQ_FIFO_ALMOSTFULL_OUT,
    COL_RES_RD_EN_IN                    => COL_RES_RD_EN_IN
    );
  end generate CX;

  --------------------------------
  --  INPUT/OUTPUT ASSIGNMENTS  --
  --------------------------------
  
  --read back results from the last stage fifo
  C_LAST : if(CURRENT_COLLECTOR_STAGE = COLLECTOR_STAGES-1) generate 
   begin 
    COL_RES_REQ_FIFO_DATA_OUT <= collector_fifo_dout_128(0);
    COL_RES_REQ_FIFO_EMPTY_OUT <= collector_fifo_empty(0);
    COL_RES_REQ_FIFO_ALMOSTEMPTY_OUT <= collector_fifo_almostempty(0);
    COL_RES_REQ_FIFO_ALMOSTFULL_OUT <= collector_fifo_almostfull(0);
    collector_fifo_rd_en(0) <= COL_RES_RD_EN_IN;
  end generate C_LAST;
  
  reset <= not RESET_N_IN;
  -----------------------------
  --  CONCURRENT STATEMENTS  --
  -----------------------------

  -----------------
  --  PROCESSES  --
  -----------------
 ARBITER_MUX_P : process(collector_fifo_full, current_fifo_lock_rd, ARBITER_REQ_FIFO_DATA_IN, ARBITER_REQ_FIFO_EMPTY_IN, ARBITER_REQ_FIFO_ALMOSTEMPTY_IN, ARBITER_REQ_FIFO_ALMOSTFULL_IN, arbiter_tree_grant_out)
begin 
    collector_fifo_wr_en <= (others => '0');
    arbiter_tree_request <= (others => (others => '0'));
    arbiter_tree_urgent_request <= (others => (others => '0'));
    ARBITER_GNT_RD_EN_OUT <= (others => '0'); 
    next_fifo_lock_rd <= (others => '0');
        
   for i in 0 to HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE)-1 loop
      collector_fifo_din(i) <= (others => '0');
   ---ARBITER INPUT MUX
   for k in 0 to PORTS_PER_ARBITER-1 loop
    if(i*PORTS_PER_ARBITER+k) < HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE-1)  then 
        arbiter_tree_request(i)(k) <= not ARBITER_REQ_FIFO_EMPTY_IN(i*PORTS_PER_ARBITER+k);
        arbiter_tree_urgent_request(i)(k) <= ARBITER_REQ_FIFO_ALMOSTFULL_IN(i*PORTS_PER_ARBITER+k);
      end if;
   end loop;
    arbiter_tree_enable(i) <= not collector_fifo_full(i); 
   
    if (collector_fifo_full(i) = '0') then
    ---ARBITER OUT/ FIFO INPUT MUX  
      for k in 0 to PORTS_PER_ARBITER-1 loop  
        if ((arbiter_tree_grant_out(i)(k) = '1') and ((i*PORTS_PER_ARBITER+k) < HPE_CNT_IN_EACH_STATE(CURRENT_COLLECTOR_STAGE-1))) then
            if (current_fifo_lock_rd (i*PORTS_PER_ARBITER+k) = '0') then
                  if(ARBITER_REQ_FIFO_ALMOSTEMPTY_IN(i*PORTS_PER_ARBITER+k) = '1') then 
                    next_fifo_lock_rd(i*PORTS_PER_ARBITER+k) <= '1';
                  end if;       
              collector_fifo_din(i) <= ARBITER_REQ_FIFO_DATA_IN((i*PORTS_PER_ARBITER+k));
              ARBITER_GNT_RD_EN_OUT(i*PORTS_PER_ARBITER+k) <= '1'; 
              collector_fifo_wr_en(i) <= arbiter_tree_grant_out(i)(k);
            else
               next_fifo_lock_rd(i*PORTS_PER_ARBITER+k) <= '0';
            end if;
        end if;
      end loop;
    end if;   
  end loop;
  
end process;


sw_reg_p : process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_N_IN = '0') then
        current_fifo_lock_rd <= (others => '0');
      else
        current_fifo_lock_rd <= next_fifo_lock_rd;
      end if;
    end if;
  end process sw_reg_p;

end RTL;