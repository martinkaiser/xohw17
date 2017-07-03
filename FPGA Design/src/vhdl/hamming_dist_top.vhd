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
-- File Name   : hamming_dist_top.vhd
-- Author      : Martin Kaiser and Sarah Pilz
-- Description : Top entity for hamming distance calculation. All necessary 
--               componants and signals are instantiated.
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

library raptor_basetypes;
use raptor_basetypes.pkg_ub_if_types.all;

Library UNISIM;
use UNISIM.vcomponents.all;

library hamming_dist;
use hamming_dist.collector_pkg.all;
use hamming_dist.hamming_dist_element_wrapper_pkg.all;

--------------
--  ENTITY  --                                                
--------------

entity hamming_dist_top is
  generic(
    SIGNATURE_LENGTH  : in integer;          --Given signature length
    NUMBER_OF_HAMMING_ELEMENTS : in integer; --Number of used HPE
    PIPELINE_STAGES   : in integer;          --Number of Pipeline Stages for the collector unit
    THRESHOLD         : in integer;          --Only results below this threshold value will be stored in the result fifo
    PORTS_PER_ARBITER : in integer range 2 to 20 ; ---number of ports for each fifo arbiter of the collector unit
    -- AXI Full Slave	
		C_S_AXI_ID_WIDTH	  : integer	:= 1; -- Width of ID for for write address, write data, read address and read data
		C_S_AXI_DATA_WIDTH	: integer	:= 32; -- Width of S_AXI data bus
		C_S_AXI_ADDR_WIDTH	: integer	:= 6; -- Width of S_AXI address bus
		C_S_AXI_AWUSER_WIDTH	: integer	:= 0; -- Width of optional user defined signal in write address channel
		C_S_AXI_ARUSER_WIDTH	: integer	:= 0; -- Width of optional user defined signal in read address channel
		C_S_AXI_WUSER_WIDTH	: integer	:= 0; -- Width of optional user defined signal in write data channel
		C_S_AXI_RUSER_WIDTH	: integer	:= 0; -- Width of optional user defined signal in read data channel
		C_S_AXI_BUSER_WIDTH	: integer	:= 0 -- Width of optional user defined signal in write response channel
  );
  port(
  	-- AXI Full Slave
		S_AXI_ACLK_IBUF_IN	: in std_logic;
		S_AXI_ACLK	: in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWID	: in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    -- Write address
		S_AXI_AWADDR	  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWLEN	    : in std_logic_vector(7 downto 0);
		S_AXI_AWSIZE	  : in std_logic_vector(2 downto 0);
		S_AXI_AWBURST	  : in std_logic_vector(1 downto 0);
		S_AXI_AWLOCK	  : in std_logic;
		S_AXI_AWCACHE	  : in std_logic_vector(3 downto 0);
		S_AXI_AWPROT	  : in std_logic_vector(2 downto 0);
		S_AXI_AWQOS	    : in std_logic_vector(3 downto 0);
		S_AXI_AWREGION	: in std_logic_vector(3 downto 0);
		S_AXI_AWUSER	  : in std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0);
		S_AXI_AWVALID	  : in std_logic;
		S_AXI_AWREADY	  : out std_logic;
		-- Write Data
		S_AXI_WDATA	  : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	  : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WLAST	  : in std_logic;
		S_AXI_WUSER	  : in std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
    -- write response.
		S_AXI_BID	    : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
		S_AXI_BRESP	  : out std_logic_vector(1 downto 0);
		S_AXI_BUSER	  : out std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		-- Read address 
		S_AXI_ARID	    : in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
		S_AXI_ARADDR	  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARLEN	    : in std_logic_vector(7 downto 0);
		S_AXI_ARSIZE	  : in std_logic_vector(2 downto 0);
		S_AXI_ARBURST	  : in std_logic_vector(1 downto 0);
		S_AXI_ARLOCK	  : in std_logic;
		S_AXI_ARCACHE	  : in std_logic_vector(3 downto 0);
		S_AXI_ARPROT	  : in std_logic_vector(2 downto 0);
		S_AXI_ARQOS	    : in std_logic_vector(3 downto 0);
		S_AXI_ARREGION	: in std_logic_vector(3 downto 0);
		S_AXI_ARUSER	  : in std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0);
		S_AXI_ARVALID	  : in std_logic;
		S_AXI_ARREADY	  : out std_logic;
		S_AXI_RID	      : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
		-- Read Data
		S_AXI_RDATA	  : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	  : out std_logic_vector(1 downto 0);
		S_AXI_RLAST	  : out std_logic;
		S_AXI_RUSER	  : out std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
  );
end hamming_dist_top;


--------------------
--  ARCHITECTURE  --
--------------------

architecture RTL of hamming_dist_top is

  ------------------------------
  --  COMPONENT DECLARATIONS  --
  ------------------------------
   --Wrapper unit for HPE
   component hamming_dist_element_wrapper is
   generic(
     SIGNATURE_LENGTH : in integer;
     NUMBER_OF_HAMMING_ELEMENTS : in integer;
     PIPELINE_STAGES : in integer;
     HAMMING_DIST_LENGTH : in integer
   );
   port(
     CLK_HPE_GATED_IN            : in  std_logic;
     CLK_IN                      : in  std_logic;
     RESET_N_IN                  : in  std_logic;
     PE_RESULTS_OUT              : out  array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS-1);
     PE_RESULTS_VALID_OUT        : out unsigned(NUMBER_OF_HAMMING_ELEMENTS-1 downto 0);
     SIGNATURE_A_IN              : in unsigned(SIGNATURE_LENGTH-1 downto 0);
     SIGNATURE_A_VALID_IN        : in std_logic;
     SIGNATURE_A_IDX_IN          : in unsigned (26 downto 0);
     SIGNATURE_B_IN              : in unsigned(SIGNATURE_LENGTH-1 downto 0);
     SIGNATURE_B_VALID_IN        : in std_logic;
     SIGNATURE_B_IDX_IN          : in unsigned (26 downto 0);
     GLOBAL_ENABLE               : in std_logic
    
   );
 end component hamming_dist_element_wrapper;
  
  --Wrapper unit for collector
  component collector_wrapper is
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
      ENABLE_HPE_OUT                        : out std_logic -- = almostfull
    );
  end component;

  --Result threshold checker
 component threshold_checker is
   generic(  
     NUMBER_OF_HAMMING_ELEMENTS : in integer;
     THRESHOLD : in integer    
   );
   port(
     CLK_IN               : in  std_logic;
     RESET_N_IN           : in  std_logic;
     HPE_RESULTS_IN          : in  array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS-1); 
     HPE_RESULTS_WR_REQ_IN   : in  unsigned(NUMBER_OF_HAMMING_ELEMENTS-1 downto 0);
     HPE_RESULTS_OUT         : out  array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS-1); 
     HPE_RESULTS_WR_REQ_OUT  : out  unsigned(NUMBER_OF_HAMMING_ELEMENTS-1 downto 0)
   );
 end component threshold_checker;
  
  
  ---------------------------
  --  SIGNAL DECLARATIONS  --
  ---------------------------
  --fixed values that depend on the generic inputs. Computed at synthesis time
  constant HAMMING_DIST_LENGTH : integer range 0 to SIGNATURE_LENGTH-1 := integer(ceil(log2(real(SIGNATURE_LENGTH))));
  constant SIGNATURE_INDEX_LENGTH : integer range 0 to 64 := (64-HAMMING_DIST_LENGTH) / 2;
  constant COLLECTOR_STAGES : integer range 1 to NUMBER_OF_HAMMING_ELEMENTS := integer(ceil(log2(real(NUMBER_OF_HAMMING_ELEMENTS)) / (log2(real(PORTS_PER_ARBITER))))) +1;

  --clalculate the number of fifos that has to be used in each stage, depending on the number of used pe and input ports per arbiter
  function CALC_FIFO_PER_STAGE (PE_CNT : integer; STAGES : integer; CNT_PORTS : integer) return HPE_STAGE_COUNTING is
  variable TMP : HPE_STAGE_COUNTING(0 to COLLECTOR_STAGES-1);
  begin
  TMP(0) := PE_CNT;
    for i in 1 to STAGES-1 loop
    TMP(i) := integer(ceil(real(TMP(i-1))/real(CNT_PORTS)));
    end loop;
  return TMP;
  end CALC_FIFO_PER_STAGE;
  
  --Number of HPE/Collector fifos in each stage
  constant HPE_CNT_IN_EACH_STATE : HPE_STAGE_COUNTING(0 to COLLECTOR_STAGES-1) := CALC_FIFO_PER_STAGE(NUMBER_OF_HAMMING_ELEMENTS, COLLECTOR_STAGES, PORTS_PER_ARBITER);
  signal hpe_cnt_debug_signal : HPE_STAGE_COUNTING(0 to COLLECTOR_STAGES-1) := HPE_CNT_IN_EACH_STATE; --Debug Signal!!
 
  --Softwear controll states
  type SW_CTRL_STATE is (IDLE, RESET, WRITE_SIG_A, WRITE_SIG_B, READ_FIFO_OUTPUT, READ_FIFO_OUTPUT_ALL_DDR_BYPASS_0,
                         READ_FIFO_OUTPUT_ALL_DDR_BYPASS_1, READ_FIFO_OUTPUT_ALL_DDR_BYPASS_2, READ_FIFO_OUTPUT_ALL_DDR_BYPASS_3);
  signal current_sw_state : SW_CTRL_STATE;
  signal next_sw_state    : SW_CTRL_STATE;
  
  --Signatures
  signal current_signature_A : unsigned(SIGNATURE_LENGTH-1 downto 0) := (others => '0');
  signal next_signature_A : unsigned(SIGNATURE_LENGTH-1 downto 0);
  signal current_signature_B : unsigned(SIGNATURE_LENGTH-1 downto 0) := (others => '0');
  signal next_signature_B : unsigned(SIGNATURE_LENGTH-1 downto 0);
  
	attribute shreg_extract : string;
  attribute shreg_extract of current_signature_A : signal is "yes";
  attribute shreg_extract of current_signature_B : signal is "yes";
	
	attribute srl_style : string;
  attribute srl_style of current_signature_A : signal is "reg_srl_reg";
  attribute srl_style of current_signature_B : signal is "reg_srl_reg";
	
  --Signature valid
  signal current_sig_A_valids : std_logic := '0'; 
  signal next_sig_A_valids : std_logic; 
  signal current_sig_B_valids : std_logic := '0'; 
  signal next_sig_B_valids : std_logic; 

  constant SIG_B_WR_CNT_MAX : integer := SIGNATURE_LENGTH / 32;
  
  --Signature counter
  signal current_sigA_cnt : integer range 0 to SIG_B_WR_CNT_MAX := 0;
  signal next_sigA_cnt    : integer range 0 to SIG_B_WR_CNT_MAX; 
  signal current_sigB_cnt : integer range 0 to SIG_B_WR_CNT_MAX := 0;
  signal next_sigB_cnt    : integer range 0 to SIG_B_WR_CNT_MAX;

  --Result fifo output signals to split 128bit into 32bit readable output
  signal n_resultfifo_cnt : integer range 0 to 4;
  signal c_resultfifo_cnt : integer range 0 to 4 := 0;
  signal n_store_128bit_resultfifo : std_logic_vector(127 downto 0);
  signal c_store_128bit_resultfifo : std_logic_vector(127 downto 0) := (others => '0');
  

  ----------------------
  ---stuff for collector-
  ----------------------- 
  ---idx for signatures
  type idx_signal is array (0 to NUMBER_OF_HAMMING_ELEMENTS-1) of unsigned (26 downto 0);
  signal current_signature_1_idx : unsigned (26 downto 0) := (others => '0');
  signal next_signature_1_idx    : unsigned (26 downto 0);
  signal current_signature_2_idx : unsigned (26 downto 0) := (others => '1');
  signal next_signature_2_idx    : unsigned (26 downto 0);
  
  ---------------
  --hpe wrapper
  -------------------
  signal hpe_result_array : array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS-1);  
  signal hpe_result_array_t : array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS-1);  
  signal hpe_result_valid : unsigned(NUMBER_OF_HAMMING_ELEMENTS-1 downto 0);
  signal hpe_result_valid_t : unsigned(NUMBER_OF_HAMMING_ELEMENTS-1 downto 0);
  
  -------------------
  --collector wrapper
  -------------------
  signal read_results_fifo_data            : std_logic_vector(127 downto 0); 
  signal read_results_fifo_empty           : std_logic; 
  signal read_results_fifo_almostempty     : std_logic; 
  signal enable_hpe_d0      : std_logic; 
  signal enable_hpe_d1      : std_logic; 
  signal enable_hpe_d2      : std_logic; 
  signal read_results_fifo_rd_en           : std_logic; 
    

-- HPE control signals 
  signal clk_200_hpe      : std_logic;   -- gated clock from bufg 
  signal current_hpe_reset_n      : std_logic := '0'; 
  signal next_hpe_reset_n      : std_logic; 
	
  attribute MAX_FANOUT : integer;
  attribute MAX_FANOUT of current_hpe_reset_n : signal is 50;
    
    
  ---------------------------------
  -- axi full signals and helper --
  ---------------------------------
  	-- AXI4FULL signals
	signal axi_awaddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_buser	: std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rdata	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rlast	: std_logic;
	signal axi_ruser	: std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
	signal axi_rvalid	: std_logic;
	signal w_accepted	: std_logic := '0';
	
	signal aw_wrap_en : std_logic;  -- aw_wrap_en determines wrap boundary and enables wrapping
	signal ar_wrap_en : std_logic; -- ar_wrap_en determines wrap boundary and enables wrapping
	signal aw_wrap_size : integer; -- aw_wrap_size is the size of the write transfer, the write address wraps to a lower address if upper address limit is reached
	signal ar_wrap_size : integer; -- ar_wrap_size is the size of the read transfer, the read address wraps to a lower address if upper address limit is reached
	signal axi_awv_awr_flag    : std_logic; -- The axi_awv_awr_flag flag marks the presence of write address valid
	signal axi_arv_arr_flag    : std_logic; --The axi_arv_arr_flag flag marks the presence of read address valid
	signal axi_awlen_cntr      : std_logic_vector(7 downto 0); 	-- The axi_awlen_cntr internal write address counter to keep track of beats in a burst transaction
	signal axi_arlen_cntr      : std_logic_vector(7 downto 0); --The axi_arlen_cntr internal read address counter to keep track of beats in a burst transaction
	signal axi_arburst      : std_logic_vector(2-1 downto 0);
	signal axi_awburst      : std_logic_vector(2-1 downto 0);
	signal axi_arlen      : std_logic_vector(8-1 downto 0);
	signal axi_awlen      : std_logic_vector(8-1 downto 0);
  
	signal w_finished      : std_logic;
  
	constant ADDR_LSB  : integer := (C_S_AXI_DATA_WIDTH/32)+ 1;
	constant OPT_MEM_ADDR_BITS : integer := 3;
	constant USER_NUM_MEM: integer := 1;
	constant low : std_logic_vector (C_S_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
  
  
  
  -------------------
  -----Functions-----
  -------------------




---------
begin  --
-- ---------

  -------------------------------
  --  COMPONENT INSTANTIAIONS  --
  -------------------------------   
	
	-- create 
	 BUFGCE_inst : BUFGCE
   port map (
      O => clk_200_hpe,   -- 1-bit output: Clock output
      CE => enable_hpe_d2, -- 1-bit input: Clock enable input for I0
      I => S_AXI_ACLK_IBUF_IN    -- 1-bit input: Primary clock
   );
	
	


collector_wrapper_inst : collector_wrapper 
  generic map (
    NUMBER_OF_HAMMING_ELEMENTS  => NUMBER_OF_HAMMING_ELEMENTS,
    COLLECTOR_STAGES            => COLLECTOR_STAGES,
    PORTS_PER_ARBITER           => PORTS_PER_ARBITER,
    HPE_CNT_IN_EACH_STATE       => HPE_CNT_IN_EACH_STATE
  )
  port map(
    CLK_IN               =>  S_AXI_ACLK,
    RESET_N_IN           =>  S_AXI_ARESETN,
    HPE_RESULTS_IN          =>  hpe_result_array_t,
    HPE_RESULTS_WR_REQ_IN   => hpe_result_valid_t, --not ?
    --get colltected results
    READ_COL_FIFO_RESULTS               => read_results_fifo_rd_en,
    COL_RESULTS_FIFO_DATA_OUT           => read_results_fifo_data,
    COL_RESULTS_FIFO_EMPTY_OUT          => read_results_fifo_empty,
    COL_RESULTS_FIFO_ALMOSTEMPTY_OUT    => read_results_fifo_almostempty,
    ENABLE_HPE_OUT                        => enable_hpe_d0
  );


  threshold_checker_inst : threshold_checker 
  generic map(
    NUMBER_OF_HAMMING_ELEMENTS => NUMBER_OF_HAMMING_ELEMENTS,
    THRESHOLD => THRESHOLD
  )
  port map(
    CLK_IN                  =>  S_AXI_ACLK,
    RESET_N_IN              =>  S_AXI_ARESETN,
    HPE_RESULTS_IN          =>  hpe_result_array,
    HPE_RESULTS_WR_REQ_IN   =>  hpe_result_valid,
    HPE_RESULTS_OUT         =>  hpe_result_array_t, 
    HPE_RESULTS_WR_REQ_OUT  =>  hpe_result_valid_t
  );
  
  
  
  hamming_element_wrapper : hamming_dist_element_wrapper 
  generic map(
    SIGNATURE_LENGTH              => SIGNATURE_LENGTH,
    NUMBER_OF_HAMMING_ELEMENTS    => NUMBER_OF_HAMMING_ELEMENTS,
    PIPELINE_STAGES               => PIPELINE_STAGES,
    HAMMING_DIST_LENGTH           => HAMMING_DIST_LENGTH
  )
  port map(
    CLK_IN                   => S_AXI_ACLK,
    CLK_HPE_GATED_IN            => clk_200_hpe,
    RESET_N_IN               => current_hpe_reset_n,
    PE_RESULTS_OUT              => hpe_result_array,
    PE_RESULTS_VALID_OUT        => hpe_result_valid,
    SIGNATURE_A_IN              => current_signature_A,
    SIGNATURE_A_VALID_IN        => current_sig_A_valids,
    SIGNATURE_A_IDX_IN          => current_signature_1_idx,
    SIGNATURE_B_IN              => current_signature_B,
    SIGNATURE_B_VALID_IN        => current_sig_B_valids,
    SIGNATURE_B_IDX_IN          => current_signature_2_idx,
    GLOBAL_ENABLE               => enable_hpe_d2
  );
  
  --------------------------------
  --  INPUT/OUTPUT ASSIGNMENTS  --
  --------------------------------
  S_AXI_AWREADY	<= axi_awready;
	S_AXI_WREADY	<= axi_wready;
	S_AXI_BRESP	<= axi_bresp;
	S_AXI_BUSER	<= (others => '0');
	S_AXI_BVALID	<= axi_bvalid;
	S_AXI_ARREADY	<= axi_arready;
	S_AXI_RDATA	<= axi_rdata;
	S_AXI_RRESP	<= axi_rresp;
	S_AXI_RLAST	<= axi_rlast;
	S_AXI_RUSER	<= (others => '0');
	S_AXI_RVALID	<= axi_rvalid;
	S_AXI_BID <= S_AXI_AWID;
	S_AXI_RID <= S_AXI_ARID;
	aw_wrap_size <= ((C_S_AXI_DATA_WIDTH)/8 * to_integer(unsigned(axi_awlen))); 
	ar_wrap_size <= ((C_S_AXI_DATA_WIDTH)/8 * to_integer(unsigned(axi_arlen))); 
	aw_wrap_en <= '1' when (((axi_awaddr AND std_logic_vector(to_unsigned(aw_wrap_size,C_S_AXI_ADDR_WIDTH))) XOR std_logic_vector(to_unsigned(aw_wrap_size,C_S_AXI_ADDR_WIDTH))) = low) else '0';
	ar_wrap_en <= '1' when (((axi_araddr AND std_logic_vector(to_unsigned(ar_wrap_size,C_S_AXI_ADDR_WIDTH))) XOR std_logic_vector(to_unsigned(ar_wrap_size,C_S_AXI_ADDR_WIDTH))) = low) else '0';
    
  -----------------------------
  --  CONCURRENT STATEMENTS  --
  -----------------------------
    
  -----------------
  --  PROCESSES  --
  -----------------

	-- Implement axi_awready generation

	-- axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	-- de-asserted when reset is low.

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_awready <= '0';
	      axi_awv_awr_flag <= '0';
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and axi_awv_awr_flag = '0' and axi_arv_arr_flag = '0') then
	        -- slave is ready to accept an address and
	        -- associated control signals
	        axi_awv_awr_flag  <= '1'; -- used for generation of bresp() and bvalid
	        axi_awready <= '1';
	      elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then 
	      -- preparing to accept next address after current write burst tx completion
	        axi_awv_awr_flag  <= '0';
	      else
	        axi_awready <= '0';
	      end if;
	    end if;
	  end if;         
	end process; 
	-- Implement axi_awaddr latching

	-- This process is used to latch the address when both 
	-- S_AXI_AWVALID and S_AXI_WVALID are valid. 

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_awaddr <= (others => '0');
	      axi_awburst <= (others => '0'); 
	      axi_awlen <= (others => '0'); 
	      axi_awlen_cntr <= (others => '0');
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and axi_awv_awr_flag = '0') then
	      -- address latching 
	        axi_awaddr <= S_AXI_AWADDR(C_S_AXI_ADDR_WIDTH - 1 downto 0);  ---- start address of transfer
	        axi_awlen_cntr <= (others => '0');
	        axi_awburst <= S_AXI_AWBURST;
	        axi_awlen <= S_AXI_AWLEN;
	      elsif((axi_awlen_cntr <= axi_awlen) and axi_wready = '1' and S_AXI_WVALID = '1') then     
	        axi_awlen_cntr <= std_logic_vector (unsigned(axi_awlen_cntr) + 1);

	        case (axi_awburst) is
	          when "00" => -- fixed burst
	            -- The write address for all the beats in the transaction are fixed
	            axi_awaddr     <= axi_awaddr;       ----for awsize = 4 bytes (010)
	          when "01" => --incremental burst
	            -- The write address for all the beats in the transaction are increments by awsize
	            axi_awaddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB) <= std_logic_vector (unsigned(axi_awaddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB)) + 1);--awaddr aligned to 4 byte boundary
	            axi_awaddr(ADDR_LSB-1 downto 0)  <= (others => '0');  ----for awsize = 4 bytes (010)
	          when "10" => --Wrapping burst
	            -- The write address wraps when the address reaches wrap boundary 
	            if (aw_wrap_en = '1') then
	              axi_awaddr <= std_logic_vector (unsigned(axi_awaddr) - (to_unsigned(aw_wrap_size,C_S_AXI_ADDR_WIDTH)));                
	            else 
	              axi_awaddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB) <= std_logic_vector (unsigned(axi_awaddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB)) + 1);--awaddr aligned to 4 byte boundary
	              axi_awaddr(ADDR_LSB-1 downto 0)  <= (others => '0');  ----for awsize = 4 bytes (010)
	            end if;
	          when others => --reserved (incremental burst for example)
	            axi_awaddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB) <= std_logic_vector (unsigned(axi_awaddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB)) + 1);--for awsize = 4 bytes (010)
	            axi_awaddr(ADDR_LSB-1 downto 0)  <= (others => '0');
	        end case;        
	      end if;
	    end if;
	  end if;
	end process;
  
  
  --for fast answering: write finished before state was reached
 process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
          w_finished <= '0';
	    else
	      if (axi_wready = '1' and S_AXI_WVALID = '1' and S_AXI_WLAST = '1' and S_AXI_AWVALID = '1' and axi_awready = '1' ) then
	        w_finished <= '1';
	      elsif (S_AXI_BREADY = '1' ) then 
	        w_finished <= '0';

	      end if;
	    end if;
	  end if;         
	end process; 
  
  
  
	-- Implement axi_wready generation

	-- axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	-- de-asserted when reset is low. 

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_wready <= '0';
          w_accepted <= '0';
	    else
	      if (axi_wready = '0' and S_AXI_WVALID = '1' ) then
	        axi_wready <= '1';
          w_accepted <= '1';
	      elsif (S_AXI_WLAST = '1' and axi_wready = '1') then 

	        axi_wready <= '0';
	      end if;
        
        if(S_AXI_BREADY = '1') then
          w_accepted <= '0';
        end if;
	    end if;
	  end if;         
	end process; 
	-- Implement write response logic generation

	-- The write response and response valid signals are asserted by the slave 
	-- when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	-- This marks the acceptance of address and indicates the status of 
	-- write transaction.

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_bvalid  <= '0';
	      axi_bresp  <= "00"; --need to work more on the responses
	      axi_buser <= (others => '0');
	    else
	      if (axi_awv_awr_flag = '1' and (axi_wready = '1' or S_AXI_WVALID = '1' or w_accepted = '1') and axi_bvalid = '0' and S_AXI_WLAST = '1' ) then
	        axi_bvalid <= '1';
	        axi_bresp  <= "00"; 
	      elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then  
	      --check if bready is asserted while bvalid is high)
	        axi_bvalid <= '0';                      
	      end if;
	    end if;
	  end if;         
	end process; 
	-- Implement axi_arready generation

	-- axi_arready is asserted for one S_AXI_ACLK clock cycle when
	-- S_AXI_ARVALID is asserted. axi_awready is 
	-- de-asserted when reset (active low) is asserted. 
	-- The read address is also latched when S_AXI_ARVALID is 
	-- asserted. axi_araddr is reset to zero on reset assertion.

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_arready <= '0';
	      axi_arv_arr_flag <= '0';
	    else
	      if (axi_arready = '0' and S_AXI_ARVALID = '1' and axi_awv_awr_flag = '0' and axi_arv_arr_flag = '0') then
	        axi_arready <= '1';
	        axi_arv_arr_flag <= '1';
	      elsif (axi_rvalid = '1' and S_AXI_RREADY = '1' and (axi_arlen_cntr = axi_arlen)) then 
	      -- preparing to accept next address after current read completion
	        axi_arv_arr_flag <= '0';
	      else
	        axi_arready <= '0';
	      end if;
	    end if;
	  end if;         
	end process; 
	-- Implement axi_araddr latching

	--This process is used to latch the address when both 
	--S_AXI_ARVALID and S_AXI_RVALID are valid. 
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_araddr <= (others => '0');
	      axi_arburst <= (others => '0');
	      axi_arlen <= (others => '0'); 
	      axi_arlen_cntr <= (others => '0');
	      axi_rlast <= '0';
	      axi_ruser <= (others => '0');
	    else
	      if (axi_arready = '0' and S_AXI_ARVALID = '1' and axi_arv_arr_flag = '0') then
	        -- address latching 
	        axi_araddr <= S_AXI_ARADDR(C_S_AXI_ADDR_WIDTH - 1 downto 0); ---- start address of transfer
	        axi_arlen_cntr <= (others => '0');
	        axi_rlast <= '0';
	        axi_arburst <= S_AXI_ARBURST;
	        axi_arlen <= S_AXI_ARLEN;
	      elsif((axi_arlen_cntr <= axi_arlen) and axi_rvalid = '1' and S_AXI_RREADY = '1') then     
	        axi_arlen_cntr <= std_logic_vector (unsigned(axi_arlen_cntr) + 1);
	        axi_rlast <= '0';      
	     
	        case (axi_arburst) is
	          when "00" =>  -- fixed burst
	            -- The read address for all the beats in the transaction are fixed
	            axi_araddr     <= axi_araddr;      ----for arsize = 4 bytes (010)
	          when "01" =>  --incremental burst
	            -- The read address for all the beats in the transaction are increments by awsize
	            axi_araddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB) <= std_logic_vector (unsigned(axi_araddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB)) + 1); --araddr aligned to 4 byte boundary
	            axi_araddr(ADDR_LSB-1 downto 0)  <= (others => '0');  ----for awsize = 4 bytes (010)
	          when "10" =>  --Wrapping burst
	            -- The read address wraps when the address reaches wrap boundary 
	            if (ar_wrap_en = '1') then   
	              axi_araddr <= std_logic_vector (unsigned(axi_araddr) - (to_unsigned(ar_wrap_size,C_S_AXI_ADDR_WIDTH)));
	            else 
	              axi_araddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB) <= std_logic_vector (unsigned(axi_araddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB)) + 1); --araddr aligned to 4 byte boundary
	              axi_araddr(ADDR_LSB-1 downto 0)  <= (others => '0');  ----for awsize = 4 bytes (010)
	            end if;
	          when others => --reserved (incremental burst for example)
	            axi_araddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB) <= std_logic_vector (unsigned(axi_araddr(C_S_AXI_ADDR_WIDTH - 1 downto ADDR_LSB)) + 1);--for arsize = 4 bytes (010)
			  axi_araddr(ADDR_LSB-1 downto 0)  <= (others => '0');
	        end case;         
	      elsif((axi_arlen_cntr = axi_arlen) and axi_rlast = '0' and axi_arv_arr_flag = '1') then  
	        axi_rlast <= '1';
	      elsif (S_AXI_RREADY = '1') then  
	        axi_rlast <= '0';
	      end if;
	    end if;
	  end if;
	end  process;  
	-- Implement axi_arvalid generation

	-- axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	-- S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	-- data are available on the axi_rdata bus at this instance. The 
	-- assertion of axi_rvalid marks the validity of read data on the 
	-- bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	-- is deasserted on reset (active low). axi_rresp and axi_rdata are 
	-- cleared to zero on reset (active low).  

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_rvalid <= '0';
	      axi_rresp  <= "00";
	    else
	      if (axi_arv_arr_flag = '1' and axi_rvalid = '0') then
	        axi_rvalid <= '1';
	        axi_rresp  <= "00"; -- 'OKAY' response
	      elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
	        axi_rvalid <= '0';
	      end  if;      
	    end if;
	  end if;
	end  process;
  
  
  
  
  
 software_ctrl_p : process(axi_rlast, S_AXI_WVALID, S_AXI_WDATA, axi_awv_awr_flag, axi_arv_arr_flag, axi_awaddr, axi_araddr, S_AXI_BREADY,
                           current_sw_state , current_sigB_cnt, current_sigA_cnt,
                           current_signature_A,current_signature_B,
                           read_results_fifo_data, read_results_fifo_empty, c_store_128bit_resultfifo, c_resultfifo_cnt,
                           current_signature_2_idx, current_signature_1_idx, w_accepted, w_finished, S_AXI_RREADY, 
                           axi_rvalid, current_sig_B_valids)
  begin
    next_sw_state             <= current_sw_state ;
    axi_rdata                 <= c_store_128bit_resultfifo(31 downto 0);
    next_sigA_cnt             <= current_sigA_cnt;
    next_sigB_cnt             <= current_sigB_cnt;
    next_signature_A          <= current_signature_A;
    next_signature_B          <= current_signature_B;
    next_sig_B_valids         <=  '0'; 
    n_resultfifo_cnt          <= c_resultfifo_cnt;
    n_store_128bit_resultfifo <= c_store_128bit_resultfifo; 
    next_signature_1_idx      <= current_signature_1_idx;
    next_signature_2_idx      <= current_signature_2_idx;
    read_results_fifo_rd_en   <= '0';
    next_sig_A_valids         <= '0';			
		next_hpe_reset_n          <= '1';
 
    case current_sw_state is
	when RESET =>
        next_sigA_cnt <= 0;
        next_sigB_cnt <= 0;
        next_signature_A <= (others => '0');
        next_signature_B <= (others => '0');
        next_sig_A_valids <= '0';
        next_sig_B_valids <= '0';
        n_resultfifo_cnt <= 0;
        n_store_128bit_resultfifo <= (others => '0');
        next_signature_1_idx <= (others => '0');
        next_signature_2_idx <= (others => '1');
				next_hpe_reset_n <= '0';
				next_sw_state <= IDLE;
				
      when IDLE =>
      
      if(axi_awv_awr_flag = '1') then -- valid write address
        if(axi_awaddr(11) = '1') then 
              next_sw_state <= WRITE_SIG_A;
        elsif (axi_awaddr(6) = '1') then 
              next_sw_state  <= WRITE_SIG_B ;
        end if;
      elsif(axi_arv_arr_flag = '1') then --valid read address
        if  (axi_araddr(8) = '1') then
               next_sw_state <= READ_FIFO_OUTPUT;
         end if;
      end if;
      
			
		
			
        if (S_AXI_BREADY = '1' ) then 
          next_sw_state <= IDLE;
        end if;

       when WRITE_SIG_A =>        
        if (S_AXI_BREADY = '1' ) then 
          next_sw_state <= IDLE;
        end if;
        
        if (S_AXI_WVALID = '1' or w_accepted = '1' or w_finished = '1') then
          next_signature_A(SIGNATURE_LENGTH-1 downto 32) <= current_signature_A(SIGNATURE_LENGTH-33 downto 0);
          next_signature_A(31 downto 0) <= unsigned(S_AXI_WDATA);
          next_sigA_cnt <= current_sigA_cnt +1;
      
        if (current_sigA_cnt = SIG_B_WR_CNT_MAX-1) then
          next_sig_A_valids <= '1';
          next_signature_1_idx <= current_signature_1_idx +1;
          next_sigA_cnt <= 0;
        else 
          next_sig_A_valids <= '0';
        end if;

        end if;
        
        
      when WRITE_SIG_B =>
        if (S_AXI_BREADY = '1') then
          next_sw_state <= IDLE;
            next_signature_2_idx <= current_signature_2_idx +1;
        end if;
        
       if (S_AXI_WVALID = '1' or w_accepted = '1' or w_finished = '1') then
          next_signature_B(SIGNATURE_LENGTH-1 downto 32) <= current_signature_B(SIGNATURE_LENGTH-33 downto 0);
          next_signature_B(31 downto 0) <= unsigned(S_AXI_WDATA);   
          next_sigB_cnt <= current_sigB_cnt +1;
          
          if ((current_sigB_cnt = SIG_B_WR_CNT_MAX-1) and (current_sig_B_valids = '0')) then
            next_sig_B_valids <= '1';
            next_sigB_cnt <= 0;
          elsif (current_sigB_cnt = SIG_B_WR_CNT_MAX-1) then
            next_sigB_cnt <= 0;
            next_sig_B_valids <= '0';
          else 
            next_sig_B_valids <= '0';
          end if;
        end if;
 

    when READ_FIFO_OUTPUT =>    -- fifo output is valid here
        if (read_results_fifo_empty = '1') then
          next_sw_state <= IDLE;
        else
          read_results_fifo_rd_en <= '1';
          n_store_128bit_resultfifo <= read_results_fifo_data;
          next_sw_state <= READ_FIFO_OUTPUT_ALL_DDR_BYPASS_0;
        end if;
        
      when READ_FIFO_OUTPUT_ALL_DDR_BYPASS_0 => 
          if (S_AXI_RREADY = '1' and axi_rvalid = '1') then   
            n_resultfifo_cnt <= c_resultfifo_cnt +1; --only for debug purposes at the moment
            next_sw_state <= READ_FIFO_OUTPUT_ALL_DDR_BYPASS_1;        
            n_store_128bit_resultfifo((127-32) downto 0) <= c_store_128bit_resultfifo(127 downto 32);
          end if;     
          
      when READ_FIFO_OUTPUT_ALL_DDR_BYPASS_1 =>
          if (S_AXI_RREADY = '1' and axi_rvalid = '1') then   -- was last access
           n_resultfifo_cnt <= c_resultfifo_cnt +1;
           next_sw_state <= READ_FIFO_OUTPUT_ALL_DDR_BYPASS_2;        
           n_store_128bit_resultfifo((127-32) downto 0) <= c_store_128bit_resultfifo(127 downto 32);
          end if;   

      when READ_FIFO_OUTPUT_ALL_DDR_BYPASS_2 =>
          if (S_AXI_RREADY = '1' and axi_rvalid = '1') then   -- was last access
           n_resultfifo_cnt <= c_resultfifo_cnt +1;
           next_sw_state <= READ_FIFO_OUTPUT_ALL_DDR_BYPASS_3;        
           n_store_128bit_resultfifo((127-32) downto 0) <= c_store_128bit_resultfifo(127 downto 32);
          end if;   

      when READ_FIFO_OUTPUT_ALL_DDR_BYPASS_3 =>
          if (S_AXI_RREADY = '1' and axi_rvalid = '1') then   -- was last access
           n_resultfifo_cnt <= 0;
           if(axi_rlast = '1') then 
           next_sw_state <= IDLE; 
           else
           next_sw_state <= READ_FIFO_OUTPUT; 
           end if;
          end if;       
    

    end case;

  end process software_ctrl_p;
  
  

 sw_reg_p : process(S_AXI_ACLK)
  begin
    if (rising_edge(S_AXI_ACLK)) then
        enable_hpe_d1 <= enable_hpe_d0;
        enable_hpe_d2 <= enable_hpe_d1;
				
				current_hpe_reset_n <= next_hpe_reset_n;
				
        current_sigA_cnt <= next_sigA_cnt;
        current_sigB_cnt <= next_sigB_cnt;
        current_signature_A <= next_signature_A;
        current_signature_B <= next_signature_B;
        current_signature_1_idx <= next_signature_1_idx;
        current_signature_2_idx <= next_signature_2_idx;
        current_sig_A_valids <= next_sig_A_valids;
        current_sig_B_valids <= next_sig_B_valids;
        c_resultfifo_cnt <= n_resultfifo_cnt;
        c_store_128bit_resultfifo <= n_store_128bit_resultfifo;
				
      if (S_AXI_ARESETN = '0') then
        current_sw_state <= RESET;
			else
        current_sw_state <= next_sw_state;
      end if;
    end if;
  end process sw_reg_p;

end RTL;      

  
