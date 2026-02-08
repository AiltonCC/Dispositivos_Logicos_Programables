library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RXTXNextion is
    Port ( 
        clk : in STD_LOGIC;
		  modo: in std_LOGIC;	
        rst : in STD_LOGIC;
        up : in STD_LOGIC;
        dn : in STD_LOGIC;
		  wr : in STD_LOGIC;
		  send_btn : in STD_LOGIC;  -- Botón para enviar datos (J3)
        switches : in STD_LOGIC_VECTOR(7 downto 0);
        display_segments : out STD_LOGIC_VECTOR(7 downto 0);
        display_anodes : out STD_LOGIC_VECTOR(3 downto 0);
        RXn : in STD_LOGIC;
		  TXn : out STD_LOGIC
    );
end RXTXNextion;

architecture Behavioral of RXTXNextion is
    type registro_array is array (0 to 15) of STD_LOGIC_VECTOR(7 downto 0);
    signal registros : registro_array := (others => (others => '0'));
    signal current_reg : unsigned(3 downto 0) := (others => '0');
    
    signal display_value : STD_LOGIC_VECTOR(15 downto 0);
    signal digit_select : unsigned(1 downto 0) := "00";
    signal counter : unsigned(15 downto 0) := (others => '0');
    signal segment_data : STD_LOGIC_VECTOR(7 downto 0);
    
    type debounce_state is (IDLE, WAIT_STABLE, CONFIRM_PRESS, WAIT_RELEASE, WAIT_PRESS, PRESSED, RELEASED);
	 --type debounce_state2 is (WAIT_PRESS, PRESSED, WAIT_RELEASE, RELEASED);
    signal up_state, dn_state, wr_state, rst_state, send_state : debounce_state := WAIT_PRESS;
    signal up_db, dn_db, wr_db, rst_db, send_db : STD_LOGIC := '0';
    signal up_counter, dn_counter, wr_counter, rst_counter, send_counter_db : unsigned(19 downto 0) := (others => '0');
    
	 --VARIABLES RX
    signal rx_state : unsigned(2 downto 0) := "000";
    signal rx_bit_counter : unsigned(3 downto 0) := (others => '0');
    signal rx_baud_counter : unsigned(15 downto 0) := (others => '0');
    signal rx_byte : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal rx_data_ready : STD_LOGIC := '0';
    signal rx_data : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    
    signal write_pointer : unsigned(3 downto 0) := (others => '0');
    
	 --VARIABLES TX
    signal tx_state : unsigned(2 downto 0) := "000";
    signal tx_bit_counter : unsigned(3 downto 0) := (others => '0');
    signal tx_baud_counter : unsigned(15 downto 0) := (others => '0');
    constant BAUD_DIVIDER : unsigned(15 downto 0) := to_unsigned(5208, 16); -- 9600 baudios para 50MHz
    
    signal send_counter : unsigned(3 downto 0) := (others => '0');
    signal send_max_reg : unsigned(3 downto 0) := (others => '0');
    signal send_active : STD_LOGIC := '0';
    signal tx_byte : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal start_sending : STD_LOGIC := '0';
    signal all_bytes_sent : STD_LOGIC := '0';
	 
begin
    up_debounce_fsm: process(clk)
    begin
        if rising_edge(clk) then
            up_db <= '0'; 
            
            case up_state is
                when IDLE =>
                    if up = '1' then
                        up_state <= WAIT_STABLE;
                        up_counter <= to_unsigned(100000, 20); 
                    end if;
                    
                when WAIT_STABLE =>
                    if up_counter > 0 then
                        up_counter <= up_counter - 1;
                    else
                        if up = '1' then
                            up_state <= CONFIRM_PRESS;
                        else
                            up_state <= IDLE; 
                        end if;
                    end if;
                    
                when CONFIRM_PRESS =>
                    if up = '0' then
                        up_state <= WAIT_RELEASE;
                        up_counter <= to_unsigned(50000, 20); 
                    end if;
                    
                when WAIT_RELEASE =>
                    if up_counter > 0 then
                        up_counter <= up_counter - 1;
                    else
                        up_db <= '1';
                        up_state <= IDLE;
                    end if;
                    
                when others =>
                    up_state <= IDLE;
            end case;
            
            if rst_db = '1' then
                up_state <= IDLE;
                up_counter <= (others => '0');
            end if;
        end if;
    end process;

  
    dn_debounce_fsm: process(clk)
    begin
        if rising_edge(clk) then
            dn_db <= '0';  
            
            case dn_state is
                when IDLE =>
                    if dn = '1' then
                        dn_state <= WAIT_STABLE;
                        dn_counter <= to_unsigned(100000, 20); 
                    end if;
                    
                when WAIT_STABLE =>
                    if dn_counter > 0 then
                        dn_counter <= dn_counter - 1;
                    else
                        if dn = '1' then
                            dn_state <= CONFIRM_PRESS;
                        else
                            dn_state <= IDLE; 
                        end if;
                    end if;
                    
                when CONFIRM_PRESS =>
                    if dn = '0' then
                        dn_state <= WAIT_RELEASE;
                        dn_counter <= to_unsigned(50000, 20);
                    end if;
                    
                when WAIT_RELEASE =>
                    if dn_counter > 0 then
                        dn_counter <= dn_counter - 1;
                    else
                        dn_db <= '1';
                        dn_state <= IDLE;
                    end if;
                    
                when others =>
                    dn_state <= IDLE;
            end case;
            
            if rst_db = '1' then
                dn_state <= IDLE;
                dn_counter <= (others => '0');
            end if;
        end if;
    end process;

    rst_debounce_fsm: process(clk)
    begin
        if rising_edge(clk) then
            rst_db <= '0'; 
            
            case rst_state is
                when IDLE =>
                    if rst = '1' then
                        rst_state <= WAIT_STABLE;
                        rst_counter <= to_unsigned(100000, 20);
                    end if;
                    
                when WAIT_STABLE =>
                    if rst_counter > 0 then
                        rst_counter <= rst_counter - 1;
                    else
             
                        if rst = '1' then
                            rst_state <= CONFIRM_PRESS;
                        else
                            rst_state <= IDLE; 
                        end if;
                    end if;
                    
                when CONFIRM_PRESS =>
     
                    if rst = '0' then
                        rst_state <= WAIT_RELEASE;
                        rst_counter <= to_unsigned(50000, 20); 
                    end if;
                    
                when WAIT_RELEASE =>
                    if rst_counter > 0 then
                        rst_counter <= rst_counter - 1;
                    else
               
                        rst_db <= '1';
                        rst_state <= IDLE;
                    end if;
                    
                when others =>
                    rst_state <= IDLE;
            end case;
        end if;
    end process;
process(clk)	
begin 
if modo = '1' and rising_edge(clk) then		--MODO COMUNICACION RX

     --process(clk)--main_control:
    --begin
        if rising_edge(clk) then
            if rst_db = '1' then
            
                for i in 0 to 15 loop
                    registros(i) <= (others => '0');
                end loop;
                current_reg <= (others => '0');
                write_pointer <= (others => '0');
            else
             
                if up_db = '1' then
                    if current_reg < 15 then
                        current_reg <= current_reg + 1;
                    end if;
                    
                elsif dn_db = '1' then
                    if current_reg > 0 then
                        current_reg <= current_reg - 1;
                    end if;
                end if;
                
         
                if rx_data_ready = '1' then
                    registros(to_integer(write_pointer)) <= rx_data;
                  
                    if write_pointer = 15 then
                        write_pointer <= (others => '0');
                    else
                        write_pointer <= write_pointer + 1;
                    end if;
                end if;
            end if;
        end if;
    --end process;

    --process(clk)--uart_rx_process:
    --begin
        if rising_edge(clk) then
            if rst_db = '1' then
                rx_state <= "000";
                rx_bit_counter <= (others => '0');
                rx_baud_counter <= (others => '0');
                rx_byte <= (others => '0');
                rx_data_ready <= '0';
                rx_data <= (others => '0');
            else
                rx_data_ready <= '0';  
                
                case rx_state is
                    when "000" => 
                        if RXn = '0' then  
                            rx_state <= "001";
                            rx_bit_counter <= (others => '0');
                            rx_baud_counter <= to_unsigned(2604, 16); 
                        end if;
                        
                    when "001" => 
                        if rx_baud_counter = 0 then
                            if RXn = '0' then  
                                rx_state <= "010";
                                rx_baud_counter <= to_unsigned(5208, 16);
                            else
                                rx_state <= "000";  
                            end if;
                        else
                            rx_baud_counter <= rx_baud_counter - 1;
                        end if;
                        
                    when "010" => 
                        if rx_baud_counter = 0 then
                            rx_baud_counter <= to_unsigned(5208, 16); 
                            rx_byte(to_integer(rx_bit_counter)) <= RXn;
                            if rx_bit_counter = 7 then
                                rx_state <= "011";
                            else
                                rx_bit_counter <= rx_bit_counter + 1;
                            end if;
                        else
                            rx_baud_counter <= rx_baud_counter - 1;
                        end if;
                        
                    when "011" => -- Stop bit
                        if rx_baud_counter = 0 then
                            if RXn = '1' then  -- Stop bit válido
                                rx_data <= rx_byte;
                                rx_data_ready <= '1';
                            end if;
                            rx_state <= "000";
                        else
                            rx_baud_counter <= rx_baud_counter - 1;
                        end if;
                        
                    when others =>
                        rx_state <= "000";
                end case;
            end if;
        end if;
    --end process;
	 
ELSE	--MODO COMUNICACION TX
	--process(clk)--wr_debounce_fsm: 
    --begin
        if rising_edge(clk) then
            wr_db <= '0';  -- Pulso de un solo ciclo
            
            case wr_state is
                when WAIT_PRESS =>
                    if wr = '1' then
                        wr_state <= PRESSED;
                        wr_counter <= to_unsigned(100000, 20); -- 2ms
                    end if;
                    
                when PRESSED =>
                    if wr_counter > 0 then
                        wr_counter <= wr_counter - 1;
                    else
                        wr_state <= WAIT_RELEASE;
                    end if;
                    
                when WAIT_RELEASE =>
                    if wr = '0' then
                        wr_state <= RELEASED;
                        wr_counter <= to_unsigned(50000, 20); -- 1ms
                    end if;
                    
                when RELEASED =>
                    if wr_counter > 0 then
                        wr_counter <= wr_counter - 1;
                    else
                        wr_db <= '1';
                        wr_state <= WAIT_PRESS;
                    end if;
                    
                when others =>
                    wr_state <= WAIT_PRESS;
            end case;
            
            if rst_db = '1' then
                wr_state <= WAIT_PRESS;
                wr_counter <= (others => '0');
            end if;
        end if;
    --end process;

    -- Debounce con MÁQUINA DE ESTADOS para SEND_BTN
    --process(clk)--send_debounce_fsm:
    --begin
        if rising_edge(clk) then
            send_db <= '0';  -- Pulso de un solo ciclo
            
            case send_state is
                when WAIT_PRESS =>
                    if send_btn = '1' then
                        send_state <= PRESSED;
                        send_counter_db <= to_unsigned(100000, 20); -- 2ms
                    end if;
                    
                when PRESSED =>
                    if send_counter_db > 0 then
                        send_counter_db <= send_counter_db - 1;
                    else
                        send_state <= WAIT_RELEASE;
                    end if;
                    
                when WAIT_RELEASE =>
                    if send_btn = '0' then
                        send_state <= RELEASED;
                        send_counter_db <= to_unsigned(50000, 20); -- 1ms
                    end if;
                    
                when RELEASED =>
                    if send_counter_db > 0 then
                        send_counter_db <= send_counter_db - 1;
                    else
                        send_db <= '1';
                        send_state <= WAIT_PRESS;
                    end if;
                    
                when others =>
                    send_state <= WAIT_PRESS;
            end case;
            
            if rst_db = '1' then
                send_state <= WAIT_PRESS;
                send_counter_db <= (others => '0');
            end if;
        end if;
    --end process;

    -- Control principal
    --process(clk)--main_control: 
    --begin
        if rising_edge(clk) then
            if rst_db = '1' then
                -- Reset
                for i in 0 to 15 loop
                    registros(i) <= (others => '0');
                end loop;
                current_reg <= (others => '0');
                start_sending <= '0';
            else
                start_sending <= '0';
                
                -- Control de registro
                if up_db = '1' then
                    if current_reg < 15 then
                        current_reg <= current_reg + 1;
                    end if;
                    
                elsif dn_db = '1' then
                    if current_reg > 0 then
                        current_reg <= current_reg - 1;
                    end if;
                end if;
                
                -- Escritura en registro
                if wr_db = '1' then
                    registros(to_integer(current_reg)) <= switches;
                end if;
                
                -- Envío de datos (solo si no está enviando actualmente)
                if send_db = '1' and send_active = '0' then
                    start_sending <= '1';
                    send_max_reg <= current_reg;
                end if;
            end if;
        end if;
    --end process;

    -- Transmisor UART CORREGIDO - Sin loop infinito
    --process(clk)--uart_tx_process: 
    --begin
        if rising_edge(clk) then
            if rst_db = '1' then
                tx_state <= "000";
                tx_bit_counter <= (others => '0');
                tx_baud_counter <= (others => '0');
                TXn <= '1';
                send_counter <= (others => '0');
                tx_byte <= (others => '0');
                send_active <= '0';
                all_bytes_sent <= '0';
            else
                -- Iniciar envío
                if start_sending = '1' and send_active = '0' then
                    send_active <= '1';
                    send_counter <= (others => '0');
                    all_bytes_sent <= '0';
                end if;
                
                case tx_state is
                    when "000" => -- Estado idle
                        TXn <= '1';
                        if send_active = '1' then
                            if send_counter <= send_max_reg and all_bytes_sent = '0' then
                                -- Enviar siguiente byte
                                tx_byte <= registros(to_integer(send_counter));
                                tx_state <= "001";
                                tx_bit_counter <= (others => '0');
                                tx_baud_counter <= BAUD_DIVIDER;
                            else
                                -- Todos los bytes han sido enviados
                                send_active <= '0';
                                send_counter <= (others => '0');
                            end if;
                        end if;
                        
                    when "001" => -- Start bit
                        TXn <= '0';
                        if tx_baud_counter = 0 then
                            tx_baud_counter <= BAUD_DIVIDER;
                            tx_state <= "010";
                        else
                            tx_baud_counter <= tx_baud_counter - 1;
                        end if;
                        
                    when "010" => -- Transmitiendo datos
                        TXn <= tx_byte(to_integer(tx_bit_counter));
                        if tx_baud_counter = 0 then
                            tx_baud_counter <= BAUD_DIVIDER;
                            if tx_bit_counter = 7 then
                                tx_state <= "011";
                            else
                                tx_bit_counter <= tx_bit_counter + 1;
                            end if;
                        else
                            tx_baud_counter <= tx_baud_counter - 1;
                        end if;
                        
                    when "011" => -- Stop bit
                        TXn <= '1';
                        if tx_baud_counter = 0 then
                            tx_baud_counter <= BAUD_DIVIDER;
                            tx_state <= "100";
                        else
                            tx_baud_counter <= tx_baud_counter - 1;
                        end if;
                        
                    when "100" => -- Entre bytes
                        TXn <= '1';
                        if tx_baud_counter = 0 then
                            -- Verificar si es el último byte
                            if send_counter = send_max_reg then
                                all_bytes_sent <= '1';  -- Marcar que todos los bytes fueron enviados
                            else
                                send_counter <= send_counter + 1;  -- Siguiente byte
                            end if;
                            tx_state <= "000";  -- Volver a idle
                        else
                            tx_baud_counter <= tx_baud_counter - 1;
                        end if;
                        
                    when others =>
                        tx_state <= "000";
                        TXn <= '1';
                end case;
            end if;
        end if;
    --end process;

end if;
end process;

    display_value(15 downto 12) <= "0000";
    display_value(11 downto 8) <= std_logic_vector(current_reg);
    display_value(7 downto 0) <= registros(to_integer(current_reg));

    display_mux: process(clk)
    begin
        if rising_edge(clk) then
            counter <= counter + 1;
            if counter = 0 then
                digit_select <= digit_select + 1;
            end if;
            
            case digit_select is
                when "00" => 
                    display_anodes <= "1110";
                    case display_value(3 downto 0) is
                        when "0000" => segment_data <= "11000000";
                        when "0001" => segment_data <= "11111001";
                        when "0010" => segment_data <= "10100100";
                        when "0011" => segment_data <= "10110000";
                        when "0100" => segment_data <= "10011001";
                        when "0101" => segment_data <= "10010010";
                        when "0110" => segment_data <= "10000010";
                        when "0111" => segment_data <= "11111000";
                        when "1000" => segment_data <= "10000000";
                        when "1001" => segment_data <= "10010000";
                        when "1010" => segment_data <= "10001000";
                        when "1011" => segment_data <= "10000011";
                        when "1100" => segment_data <= "11000110";
                        when "1101" => segment_data <= "10100001";
                        when "1110" => segment_data <= "10000110";
                        when "1111" => segment_data <= "10001110";
                        when others => segment_data <= "11111111";
                    end case;
                    
                when "01" =>
                    display_anodes <= "1101";
                    case display_value(7 downto 4) is
                        when "0000" => segment_data <= "11000000";
                        when "0001" => segment_data <= "11111001";
                        when "0010" => segment_data <= "10100100";
                        when "0011" => segment_data <= "10110000";
                        when "0100" => segment_data <= "10011001";
                        when "0101" => segment_data <= "10010010";
                        when "0110" => segment_data <= "10000010";
                        when "0111" => segment_data <= "11111000";
                        when "1000" => segment_data <= "10000000";
                        when "1001" => segment_data <= "10010000";
                        when "1010" => segment_data <= "10001000";
                        when "1011" => segment_data <= "10000011";
                        when "1100" => segment_data <= "11000110";
                        when "1101" => segment_data <= "10100001";
                        when "1110" => segment_data <= "10000110";
                        when "1111" => segment_data <= "10001110";
                        when others => segment_data <= "11111111";
                    end case;
                    
                when "10" =>
                    display_anodes <= "1011";
                    case display_value(11 downto 8) is
                        when "0000" => segment_data <= "11000000";
                        when "0001" => segment_data <= "11111001";
                        when "0010" => segment_data <= "10100100";
                        when "0011" => segment_data <= "10110000";
                        when "0100" => segment_data <= "10011001";
                        when "0101" => segment_data <= "10010010";
                        when "0110" => segment_data <= "10000010";
                        when "0111" => segment_data <= "11111000";
                        when "1000" => segment_data <= "10000000";
                        when "1001" => segment_data <= "10010000";
                        when "1010" => segment_data <= "10001000";
                        when "1011" => segment_data <= "10000011";
                        when "1100" => segment_data <= "11000110";
                        when "1101" => segment_data <= "10100001";
                        when "1110" => segment_data <= "10000110";
                        when "1111" => segment_data <= "10001110";
                        when others => segment_data <= "11111111";
                    end case;
                    
                when "11" =>
                    display_anodes <= "0111";
                    case display_value(15 downto 12) is
                        when "0000" => segment_data <= "11000000";
                        when others => segment_data <= "11000000";
                    end case;
                    
                when others =>
                    display_anodes <= "1111";
                    segment_data <= "11111111";
            end case;
        end if;
    end process;

    display_segments <= segment_data;

end Behavioral;