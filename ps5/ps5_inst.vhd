	component ps5 is
		port (
			clk_clk         : in  std_logic                    := 'X'; -- clk
			reset_reset_n   : in  std_logic                    := 'X'; -- reset_n
			ps5_data_export : out std_logic_vector(7 downto 0)         -- export
		);
	end component ps5;

	u0 : component ps5
		port map (
			clk_clk         => CONNECTED_TO_clk_clk,         --      clk.clk
			reset_reset_n   => CONNECTED_TO_reset_reset_n,   --    reset.reset_n
			ps5_data_export => CONNECTED_TO_ps5_data_export  -- ps5_data.export
		);

