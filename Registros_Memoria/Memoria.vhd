library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Memoria is
    port (
        clk      : in  std_logic;                                 -- Reloj para la escritura síncrona
		  RST      : in  std_logic;                                 -- Reloj para la escritura síncrona
        we       : in  std_logic;                                 -- Write Enable (Habilitación de escritura)
		  UP		  : in  std_logic;											--	Incrementa registro
		  DN		  : in  std_logic;											--	Decrementa registro
        data_in  : in  std_logic_vector(7 downto 0); 					-- Dato de entrada
        data_out : out std_logic_vector(7 downto 0);  					-- Dato de salida (lectura)
		  numdisp: out std_logic_vector(3 downto 0)					--Numero de display

    );
end entity Memoria;

architecture Behavioral of Memoria is
--Variables para la memoria
	signal addr     : unsigned(7 downto 0) := (others => '0'); -- Dirección del registro a escribir/leer
	signal conteo : unsigned(7 downto 0);
	-- N_REGS = Número de registros (16 posiciones)
	constant N_REGS : integer := 255;
	
--Variables para las frecuencias
	 signal contador_60Hz   : unsigned(18 downto 0) := (others => '0'); -- Contador para 60 Hz
	 signal clk_60Hz   : std_logic := '0'; 

--Variables para display
	signal num0 : std_logic_vector(3 downto 0);--Numero de cada display
	--signal frec2,frec : std_logic;
	signal disp : unsigned(1 downto 0);
	signal dis : unsigned(7 downto 0);
	signal dato : std_LOGIC_VECTOR(7 downto 0);
	
    -- Definición del TIPO DE MEMORIA (el array de N registros)
    -- Es un array de N_REGS posiciones, donde cada posición guarda un STD_LOGIC_VECTOR de DATA_WIDTH bits.
    type Register_Array is array (0 to N_REGS - 1) of std_logic_vector(7 downto 0);

    -- Declaración de la SEÑAL DE MEMORIA
    signal mem : Register_Array := (others => (others => '0')); -- Inicializado a cero

	 --VARIABLES PARA ANTIREBOTE
SIGNAL T_ESTABLE	:	INTEGER RANGE 0 TO 500_000;
SIGNAL UP_AN	:	STD_LOGIC;
SIGNAL UP_OK	:	STD_LOGIC;
SIGNAL UP_ONAN	:	STD_LOGIC;

--VARIABLES PARA ANTIREBOTE
SIGNAL T_ESTABLE1	:	INTEGER RANGE 0 TO 500_000;
SIGNAL DN_AN	:	STD_LOGIC;
SIGNAL DN_OK	:	STD_LOGIC;
SIGNAL DN_ONAN	:	STD_LOGIC;

begin

UP_AN <= UP WHEN RISING_EDGE(CLK);
T_ESTABLE <= 0 WHEN (UP_AN = '0' AND UP = '1') OR (UP_AN = '1' AND UP = '0') OR RST = '1' OR T_ESTABLE = 500_000
					ELSE T_ESTABLE +1 WHEN RISING_EDGE(CLK);
UP_OK <= UP WHEN T_ESTABLE = 499_999 AND RISING_EDGE(CLK);
UP_ONAN <= UP_OK WHEN RISING_EDGE(CLK);

DN_AN <= DN WHEN RISING_EDGE(CLK);
T_ESTABLE1 <= 0 WHEN (DN_AN = '0' AND DN = '1') OR (DN_AN = '1' AND DN = '0') OR RST = '1' OR T_ESTABLE1 = 500_000
					ELSE T_ESTABLE1 +1 WHEN RISING_EDGE(CLK);
DN_OK <= DN WHEN T_ESTABLE1 = 499_999 AND RISING_EDGE(CLK);
DN_ONAN <= DN_OK WHEN RISING_EDGE(CLK);

    -- **Proceso de ESCRITURA (Síncrono)**
    -- La escritura solo ocurre en el flanco de subida del reloj
    process (clk)
        -- Conversión del vector de dirección a un entero
        variable write_addr : integer range 0 to N_REGS - 1; 
    begin
        if rising_edge(clk) then
				--Divisor para 60 Hz
				if contador_60Hz = 208333 - 1 then
                contador_60Hz <= (others => '0'); 		-- Reinicia el contador
                clk_60Hz <= not clk_60Hz;     -- Cambia el estado de la señal de salida
            else
                contador_60Hz <= contador_60Hz + 1; 	-- Incrementa el contador
            end if;
				
            --ESCRITURA
				if we = '1' then
                -- Convierte el STD_LOGIC_VECTOR de addr a un índice (entero)
                write_addr := to_integer(unsigned(addr));
                
                -- **Guarda el valor en el registro de memoria N**
                -- La escritura se hace en la posición determinada por el índice.
                mem(write_addr) <= data_in;
				--INCREMENTO
				elsif UP_ONAN = '0' AND UP_OK =  '1' then
					addr <= addr + 1;
				--DECREMENTO
				elsif DN_ONAN = '0' AND DN_OK =  '1' then
					addr <= addr - 1;
				--LIMPIEZA
				elsif RST = '1' then
					mem(write_addr) <= X"00";
            end if;
        end if;
    end process;

    -- **Lógica de LECTURA (Asíncrona/Combinacional)**
    -- El dato de salida se actualiza inmediatamente cuando cambia la dirección (addr)
    -- Nota: En sistemas reales, la lectura puede ser síncrona, pero esta es la implementación más simple.
	 conteo <= unsigned(addr);
    dato <= mem(to_integer(unsigned(addr)));
	 
--Multiplexor
	process (clk_60Hz) 
	  begin
		if rising_edge(clk_60Hz) then
			disp <= disp + 1;
			if disp = "11" then
				disp <= "00";
			end if;
		end if;
	end process;

	--Seleccionar display
	process(disp,num0)
	begin
		if disp = "00" then
			num0 <= dato(3 downto 0);	--Numero de primer display a mostrar
			--num0 <= num1;
			numdisp <= "0001";
		elsif disp = "01" then
			num0 <= dato(7 downto 4);
			numdisp <= "0010";
		elsif disp = "10" then
			num0 <= std_logic_vector(conteo(3 downto 0));
			numdisp <= "0100";
		elsif disp = "11" then
			num0 <= std_logic_vector(conteo(7 downto 4));
			numdisp <= "1000";
		end if;
	end process;
	
--Display 7 segmentos
process (num0) 
  begin
		case num0 is
			when  X"0"  =>  dis  <=  X"3F";  --0111111  gfedcba
			when  X"1"  =>  dis  <=  X"06";  --0000110
			when  X"2"  =>  dis  <=  X"5B";
			when  X"3"  =>  dis  <=  X"4F";
			when  X"4"  =>  dis	<=  X"66";
			when  X"5"  =>  dis  <=  X"6D";
			when  X"6"  =>  dis  <=  X"7D";
			when  X"7"  =>  dis  <=  X"07";
			when  X"8"  =>  dis  <=  X"7F";
			when  X"9"  =>  dis  <=  X"6F";
			when  X"A"  =>  dis  <=  X"77";
			when  X"B"  =>  dis  <=  X"7C";
			when  X"C"  =>  dis  <=  X"39";
			when  X"D"  =>  dis  <=  X"5E";
			when  X"E"  =>  dis  <=  X"79";
			when  others  =>  dis  <=  X"71";
		end case;
end process;
		data_out <= std_logic_vector(dis);
end architecture Behavioral;