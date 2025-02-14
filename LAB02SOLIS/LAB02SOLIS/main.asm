//*********************************************************************
// Universidad del Valle de Guatemala
// IE2023: Programación de Microcontroladores
// Author : Thomas Solis
// Proyecto: LAB02
// Descripción:Timer0 y Botones, comparacion del contador con el Display de 7 segmentos.  
// Hardware: ATmega328p
// Created: 12/02/2025 22:45:54
//*********************************************************************
// Encabezado
//*********************************************************************


.include "M328PDEF.inc"
.cseg
.org 0x0000

//Configuración de la pila
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17

//CONFIGURACIÓN DEL MCU Y TIMER0

SETUP:
    LDI R16, (1 << CLKPCE)     ; Configurar prescaler 
    STS CLKPR, R16            
    LDI R16, 0b0000_0100      ; Prescaler = 16 a F_CPU = 1MHz
    STS CLKPR, R16            

    CALL INIT_TMR0             ; Configurar Timer0
    
    ; Configurar PC3 - PC0 como salidas para el contador binario
    LDI     R16, 0b00001111  
    OUT     DDRC, R16        

    ; Configurar PB3 y PB4 como entrada con pull-up (botones)
    LDI R16, 0b0001_1000      
    OUT PORTB, R16            

    ; Configurar PB5 como salida (LED de estado)
    LDI R16, 0b00100000        ; PB5 como salida
    OUT DDRB, R16

    ;Configurar PD0-PD6 como salida display de 7 segmentos
    LDI R16, 0x7F            
    OUT DDRD, R16            

    ; Inicializar variables
    CLR     R21                ; Contador de 4 bits (segundos)
    CLR     R20                ; Contador de 100ms
    CLR     R22                ; Contador de segundos
    CLR     R23                ; Estado de la LED (PB5)
    
    LDI R18, 0                ; Inicializar el contador del display
    LDI R19, 0                ; Valor inicial del display
    CALL DISPLAY   
	     
// LOOP PRINCIPAL
MAIN_LOOP:
    IN      R16, TIFR0           ; Verificar si Timer0 generó una comparación
    SBRS    R16, OCF0A          
    RJMP    ESTADO_BOTONES       
    
    SBI     TIFR0, OCF0A        ; Limpiar bandera de comparación OCF0A
    
    INC     R20                 ; Incrementar contador de tiempo (100ms)
    CPI     R20, 10             ; Esperar 10 ciclos de 100ms (1s)
    BRNE    ESTADO_BOTONES       
    
    CLR     R20                 ; Reiniciar contador de 100ms
    
    INC     R21                 ; Incrementar contador binario de 4 bits
    ANDI    R21, 0x0F           ; Mantener solo los 4 bits bajos (0-15)
    OUT     PORTC, R21          ; Mostrar en los LEDs PC0-PC3

	// verificar comparacion 
    CP R21, R19    ; Si el contador de segundos es igual al valor del display, reiniciar y alternar LED
    BRNE ESTADO_BOTONES           ;Si no son iguales, seguir normal BRNE verifica si el bit Z esta en cero 

    CLR R21                     ; Reiniciar contador binario de 4 bits
    OUT PORTC, R21              ; Actualizar LEDs
    
    IN R16, PORTB
    LDI R17, 0b00100000         ; Máscara para PB5 solo afecta el PB5 
    EOR R16, R17                ; Alternar estado de PB5, si PB5 estaba en cero, se cambia a 1 sino lo contrario, EOR realiza la operacion XOR entre R16 puerto B y R17 la masacaa PB5 
    OUT PORTB, R16              ; Actualizar PB5

ESTADO_BOTONES:
    IN R16, PINB				; 
    SBRS R16, PB3               ; si el boton No esta presionado (PB3=1), se salta a la siguiente instruccion, si el boton esta presionado PB3=0 se ejecuta la siguente osea el RJMP
    RJMP DB_1                    

    IN R17, PINB
    SBRS R17, PB4               ; Si PB4 está en 0, llamar a DECREMENTAR
    RJMP DB_2

    RJMP MAIN_LOOP


// ANTI-REBOTE PARA PB3 (AUMENTAR)

DB_1: // si PB3=0 se ejecuta DB_1 donde maneja el antirebote y luego incrementa el contador AUMENTAR 
    LDI R16, 100          ; cargo el valor de 100 en r16         
    DELAY1:
        DEC R16   ; decremento r16 en 1 
        BRNE DELAY1 ; si r16 no es iguakl a cero vuelve a delay1, cuando lla a 0 el bucle se detiene

    SBIS PINB, PB3       ; si pb3 =1 no presionado sigue la siguente intruccion de lo contario  se ejecuta RJMP        
    RJMP DB_1                    
    CALL AUMENTAR                
    RJMP MAIN_LOOP


// ANTI-REBOTE PARA PB4 (DECREMENTAR)
DB_2:
    LDI R17, 100                
    DELAY2:
        DEC R17
        BRNE DELAY2

    SBIS PINB, PB4              
    RJMP DB_2                    
    CALL DECREMENTAR                
    RJMP MAIN_LOOP

// FUNCIÓN PARA DECREMENTAR EL CONTADOR DEL DISPLAY
DECREMENTAR:
    DEC R19  ; almacena el valor del display              
    BRPL RESET_DEC        ; si r19 sigue siendo positivo se salta la intrucciion, si es negativo No salta y ejecuta LDI r19 para correguir 
    LDI R19, 15                 ; Si es menor que 0, regresa a F practicamente si es negativo se carga 15 
RESET_DEC:
    MOV R18, R19  ; copia el valor de r19 en r18 y lo muestra en el display 
    CALL DISPLAY ; llama display para que muestre r18 el nuevo valor 
    RET

// FUNCIÓN PARA AUMENTAR EL CONTADOR DEL DISPLAY
AUMENTAR:
    INC R19                     ; Incrementar valor del display
    CPI R19, 16                 ; Si llega a 16, volver a 0 practicamente compara r19 con 16 
    BRNE RESET_INC       ; si r19 no es igual a 16 entonces se salta intruccion y va a RESET_INC, de lo contrario significa que se ha excedido el valor F y se reinica 
    LDI R19, 0                  ; Reiniciar a 0
RESET_INC:
    MOV R18, R19   ; si r19 no es 16 no se modifica r19 entonces copia r18 que es la variable que se usa para mostrar el display 
    CALL DISPLAY ; llama display para que se actualize el display de 7 segmentos con el nuevo valor de r18 
	RET
// FUNCIÓN PARA MOSTRAR EL NÚMERO EN EL DISPLAY
DISPLAY:
    LDI ZH, HIGH(Tabla * 2)
    LDI ZL, LOW(Tabla * 2)
    ADD ZL, R18
    LPM R16, Z
    OUT PORTD, R16  ; Mostrar número en el display
    RET

// CONFIGURACIÓN DEL TIMER0

INIT_TMR0:
    LDI     R16, 0               ; Reiniciar Timer0
    OUT     TCNT0, R16
    LDI     R16, 98              ; Valor para alcanzar 10ms con F_CPU=1MHz y prescaler 1024
    OUT     OCR0A, R16      ; OCR0A establece el limite al cual el contador timer0 antes de reiniciarse
    LDI     R16, (1 << WGM01)    ; Modo CTC (Clear Timer on Compare Match) activa el modo CTC en este modo el timer0 cuenta hasta OCR0A y se reinicia automaticamente
    OUT     TCCR0A, R16 
    LDI     R16, (1 << CS02) | (1 << CS00)  ; Configurar prescaler a 1024
    OUT     TCCR0B, R16
    RET

// TABLA DE VALORES PARA CÁTODO COMÚN
Tabla: 
.DB 0x7E, 0x30, 0x6D, 0x79, 0x33, 0x5B, 0x5F, 0x70, 0x7F, 0x7B, 0x77, 0x1F, 0x4E, 0x3D, 0x4F, 0x47  
; 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B,  C, D, E, F



