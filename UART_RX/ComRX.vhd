library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY ComRX IS
	PORT(	CLK	:	IN STD_LOGIC;
			RST	:	IN	STD_LOGIC;
			RX		:	IN STD_LOGIC;
			LEDS	:	OUT STD_LOGIC_VECTOR(7 DOWNTO 0));
END ComRX;

ARCHITECTURE BEHAVIORAL OF ComRX IS

--VARIABLES PARA LA COMINICACION
CONSTANT BAUD_RATE_MAX 	: INTEGER := 5207; -- 5207 si cuentas de 0 a 5207 (5208 ciclos).
SIGNAL BITRATE_RX	:	INTEGER RANGE 0 TO 5207 := 0;
SIGNAL NBIT	:	INTEGER :=0;
SIGNAL INI_RX	:	STD_LOGIC := '0';

--VARIABLES PARA INICIAR RX
SIGNAL RX_D1,RX_D2	:	STD_LOGIC;
SIGNAL DATO		: 	STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
BEGIN

--DETECCIÓN DE FLANCO (START BIT)
PROCESS (CLK)
BEGIN
    IF RISING_EDGE(CLK) THEN
        RX_D1 <= RX;
        RX_D2 <= RX_D1;
    END IF;
END PROCESS;

--COMUNICACION
PROCESS (CLK, RST)
BEGIN
    IF RST = '1' THEN
        INI_RX <= '0';
        BITRATE_RX <= 0;
        NBIT <= 0;
        DATO <= (OTHERS => '0');
        LEDS <= (OTHERS => '0');

    ELSIF RISING_EDGE(CLK) THEN

        IF INI_RX = '0' AND RX_D2 = '1' AND RX_D1 = '0' THEN
            INI_RX <= '1';
            BITRATE_RX <= BAUD_RATE_MAX / 2; -- Iniciamos en la mitad del ciclo para muestrear en el centro del Start Bit.
            NBIT <= 0; 								-- Contador de bits a 0 (el primer bit es el Start Bit)
        
        -- Lógica de Recepción (cuando INI_RX_FLAG = '1')
        ELSIF INI_RX = '1' THEN
            
            -- Contador de Baud Rate
            IF BITRATE_RX = BAUD_RATE_MAX THEN
                BITRATE_RX <= 0; 	-- Reinicia el contador de Baud Rate
                NBIT <= NBIT + 1; 	-- Avanza al siguiente bit
					 
                IF NBIT = 0 THEN
                    NULL;
						  
                ELSIF NBIT >= 1 AND NBIT <= 8 THEN
                    DATO(NBIT - 1) <= RX; -- Bit 1 va a DATO(0), Bit 2 va a DATO(1), etc.

                -- Muestreo de Stop Bit (NBIT_CNT = 9)
                ELSIF NBIT = 9 THEN
                    LEDS <= DATO; -- Transfiere el dato completo a la salida LEDS
                    
                    -- Finaliza la recepción
                    INI_RX <= '0';
                    NBIT <= 0;
                    
                END IF;
                
            ELSE
                BITRATE_RX <= BITRATE_RX + 1; -- Incrementa el contador de Baud Rate
            END IF;
        END IF;
    END IF;
	 
END PROCESS;
			
END BEHAVIORAL;