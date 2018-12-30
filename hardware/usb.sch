EESchema Schematic File Version 4
LIBS:fmcw-cache
EELAYER 26 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 3 10
Title ""
Date ""
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L Device:R R80
U 1 1 583B312F
P 4400 3350
F 0 "R80" V 4300 3350 50  0000 C CNN
F 1 "0" V 4400 3350 50  0000 C CNN
F 2 "fmcw:R_0402b" V 4330 3350 30  0001 C CNN
F 3 "" H 4400 3350 30  0000 C CNN
	1    4400 3350
	0    1    1    0   
$EndComp
$Comp
L Device:R R81
U 1 1 583B315C
P 4400 3450
F 0 "R81" V 4480 3450 50  0000 C CNN
F 1 "0" V 4400 3450 50  0000 C CNN
F 2 "fmcw:R_0402b" V 4330 3450 30  0001 C CNN
F 3 "" H 4400 3450 30  0000 C CNN
	1    4400 3450
	0    1    1    0   
$EndComp
Text Label 4100 3450 2    60   ~ 0
USBDP
Text Label 4100 3350 2    60   ~ 0
USBDM
$Comp
L Device:C C210
U 1 1 583B35D4
P 4550 2500
F 0 "C210" H 4575 2600 50  0000 L CNN
F 1 "100n" H 4575 2400 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 4588 2350 30  0001 C CNN
F 3 "" H 4550 2500 60  0000 C CNN
	1    4550 2500
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR040
U 1 1 583B35F7
P 4550 2750
F 0 "#PWR040" H 4550 2500 50  0001 C CNN
F 1 "GND" H 4550 2600 50  0000 C CNN
F 2 "" H 4550 2750 60  0000 C CNN
F 3 "" H 4550 2750 60  0000 C CNN
	1    4550 2750
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR041
U 1 1 583B4921
P 6250 6600
F 0 "#PWR041" H 6250 6350 50  0001 C CNN
F 1 "GND" H 6250 6450 50  0000 C CNN
F 2 "" H 6250 6600 60  0000 C CNN
F 3 "" H 6250 6600 60  0000 C CNN
	1    6250 6600
	1    0    0    -1  
$EndComp
$Comp
L Device:C C212
U 1 1 583B55E3
P 6200 1250
F 0 "C212" H 6225 1350 50  0000 L CNN
F 1 "100n" H 6225 1150 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 6238 1100 30  0001 C CNN
F 3 "" H 6200 1250 60  0000 C CNN
	1    6200 1250
	1    0    0    -1  
$EndComp
$Comp
L Device:C C211
U 1 1 583B5665
P 5600 1600
F 0 "C211" H 5625 1700 50  0000 L CNN
F 1 "100n" H 5625 1500 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 5638 1450 30  0001 C CNN
F 3 "" H 5600 1600 60  0000 C CNN
	1    5600 1600
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR042
U 1 1 583B5768
P 6200 1400
F 0 "#PWR042" H 6200 1150 50  0001 C CNN
F 1 "GND" H 6200 1250 50  0000 C CNN
F 2 "" H 6200 1400 60  0000 C CNN
F 3 "" H 6200 1400 60  0000 C CNN
	1    6200 1400
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR043
U 1 1 583B5791
P 5600 1750
F 0 "#PWR043" H 5600 1500 50  0001 C CNN
F 1 "GND" H 5600 1600 50  0000 C CNN
F 2 "" H 5600 1750 60  0000 C CNN
F 3 "" H 5600 1750 60  0000 C CNN
	1    5600 1750
	1    0    0    -1  
$EndComp
$Comp
L Device:R R84
U 1 1 583B5C84
P 8000 4150
F 0 "R84" V 8080 4150 50  0000 C CNN
F 1 "33" V 8000 4150 50  0000 C CNN
F 2 "fmcw:R_0402b" V 7930 4150 30  0001 C CNN
F 3 "" H 8000 4150 30  0000 C CNN
	1    8000 4150
	0    1    1    0   
$EndComp
$Comp
L Device:R R88
U 1 1 583B5CC5
P 8400 4250
F 0 "R88" V 8480 4250 50  0000 C CNN
F 1 "33" V 8400 4250 50  0000 C CNN
F 2 "fmcw:R_0402b" V 8330 4250 30  0001 C CNN
F 3 "" H 8400 4250 30  0000 C CNN
	1    8400 4250
	0    1    1    0   
$EndComp
$Comp
L Device:R R85
U 1 1 583B63A8
P 8000 4450
F 0 "R85" V 8080 4450 50  0000 C CNN
F 1 "33" V 8000 4450 50  0000 C CNN
F 2 "fmcw:R_0402b" V 7930 4450 30  0001 C CNN
F 3 "" H 8000 4450 30  0000 C CNN
	1    8000 4450
	0    1    1    0   
$EndComp
Text HLabel 8800 4150 2    60   Output ~ 0
TCK
Text HLabel 8800 4250 2    60   Output ~ 0
TDI
Text HLabel 8800 4350 2    60   Input ~ 0
TDO
Text HLabel 8800 4450 2    60   Output ~ 0
TMS
Text HLabel 8150 2350 2    60   BiDi ~ 0
D0
Text HLabel 8150 2450 2    60   BiDi ~ 0
D1
Text HLabel 8150 2550 2    60   BiDi ~ 0
D2
Text HLabel 8150 2650 2    60   BiDi ~ 0
D3
Text HLabel 8150 2750 2    60   BiDi ~ 0
D4
Text HLabel 8150 2850 2    60   BiDi ~ 0
D5
Text HLabel 8150 2950 2    60   BiDi ~ 0
D6
Text HLabel 8150 3050 2    60   BiDi ~ 0
D7
Text HLabel 8150 3250 2    60   Output ~ 0
RXF#
Text HLabel 8150 3350 2    60   Output ~ 0
TXE#
Text HLabel 8150 3450 2    60   Input ~ 0
RD#
Text HLabel 8150 3550 2    60   Input ~ 0
WR
Text HLabel 8150 3650 2    60   Input ~ 0
SIWUA
$Comp
L Device:Crystal Y1
U 1 1 583C5AF8
P 3800 5650
F 0 "Y1" H 3800 5800 50  0000 C CNN
F 1 "ABM10-167-12.000MHZ-T3" V 3800 6400 50  0000 C CNN
F 2 "Crystal:Crystal_SMD_Abracon_ABM10-4Pin_2.5x2.0mm" H 3800 5650 60  0001 C CNN
F 3 "https://abracon.com/Resonators/ABM10-166-12.000MHz.pdf" H 3800 5650 60  0001 C CNN
	1    3800 5650
	0    1    1    0   
$EndComp
$Comp
L Device:C C209
U 1 1 583C5B9D
P 3650 5950
F 0 "C209" V 3810 5950 50  0000 C CNN
F 1 "15p" V 3901 5950 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3688 5800 30  0001 C CNN
F 3 "" H 3650 5950 60  0000 C CNN
	1    3650 5950
	0    1    1    0   
$EndComp
$Comp
L Device:C C208
U 1 1 583C5BF7
P 3650 5300
F 0 "C208" V 3398 5300 50  0000 C CNN
F 1 "15p" V 3489 5300 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3688 5150 30  0001 C CNN
F 3 "" H 3650 5300 60  0000 C CNN
	1    3650 5300
	0    1    1    0   
$EndComp
$Comp
L power:GND #PWR045
U 1 1 583C6491
P 3300 5300
F 0 "#PWR045" H 3300 5050 50  0001 C CNN
F 1 "GND" H 3300 5150 50  0000 C CNN
F 2 "" H 3300 5300 60  0000 C CNN
F 3 "" H 3300 5300 60  0000 C CNN
	1    3300 5300
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR046
U 1 1 583C64DF
P 3300 5950
F 0 "#PWR046" H 3300 5700 50  0001 C CNN
F 1 "GND" H 3300 5800 50  0000 C CNN
F 2 "" H 3300 5950 60  0000 C CNN
F 3 "" H 3300 5950 60  0000 C CNN
	1    3300 5950
	1    0    0    -1  
$EndComp
Text Label 2950 6950 2    60   ~ 0
EECS
Text Label 4000 6950 0    60   ~ 0
EECLK
$Comp
L Device:R R73
U 1 1 583C7CCB
P 1300 4200
F 0 "R73" V 1380 4200 50  0000 C CNN
F 1 "10k" V 1300 4200 50  0000 C CNN
F 2 "fmcw:R_0402b" V 1230 4200 30  0001 C CNN
F 3 "" H 1300 4200 30  0000 C CNN
	1    1300 4200
	1    0    0    -1  
$EndComp
$Comp
L Device:R R79
U 1 1 583C7D2C
P 1300 4600
F 0 "R79" V 1380 4600 50  0000 C CNN
F 1 "2.2k" V 1300 4600 50  0000 C CNN
F 2 "fmcw:R_0402b" V 1230 4600 30  0001 C CNN
F 3 "" H 1300 4600 30  0000 C CNN
	1    1300 4600
	1    0    0    -1  
$EndComp
Text Label 1400 4400 0    60   ~ 0
DO
Text Label 1350 4900 0    60   ~ 0
EEDATA
Text Label 4000 7150 0    60   ~ 0
DO
$Comp
L Device:C C207
U 1 1 583C8C2A
P 2450 6700
F 0 "C207" H 2475 6800 50  0000 L CNN
F 1 "100n" H 2475 6600 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 2488 6550 30  0001 C CNN
F 3 "" H 2450 6700 60  0000 C CNN
	1    2450 6700
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR048
U 1 1 583C8C93
P 2450 6900
F 0 "#PWR048" H 2450 6650 50  0001 C CNN
F 1 "GND" H 2450 6750 50  0000 C CNN
F 2 "" H 2450 6900 60  0000 C CNN
F 3 "" H 2450 6900 60  0000 C CNN
	1    2450 6900
	1    0    0    -1  
$EndComp
Text Label 1300 4000 0    60   ~ 0
3V3D
Text Label 4000 7050 0    60   ~ 0
EEDATA
$Comp
L Device:Ferrite_Bead FB12
U 1 1 5865C0D7
P 4550 1300
F 0 "FB12" V 4500 1500 50  0000 C CNN
F 1 "BLM18PG181SN1D" V 4400 1300 50  0000 C CNN
F 2 "fmcw:C_0603b" H 4550 1300 60  0001 C CNN
F 3 "" H 4550 1300 60  0000 C CNN
	1    4550 1300
	0    -1   -1   0   
$EndComp
$Comp
L Device:Ferrite_Bead FB14
U 1 1 596BB650
P 4550 1050
F 0 "FB14" V 4500 900 50  0000 C CNN
F 1 "BLM18PG181SN1D" V 4400 1050 50  0000 C CNN
F 2 "fmcw:C_0603b" H 4550 1050 60  0001 C CNN
F 3 "" H 4550 1050 60  0000 C CNN
	1    4550 1050
	0    1    1    0   
$EndComp
$Comp
L Device:C C158
U 1 1 596BBF3A
P 7150 1250
F 0 "C158" H 7175 1350 50  0000 L CNN
F 1 "100n" H 7175 1150 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 7188 1100 30  0001 C CNN
F 3 "" H 7150 1250 60  0000 C CNN
	1    7150 1250
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR049
U 1 1 596BBF40
P 7150 1400
F 0 "#PWR049" H 7150 1150 50  0001 C CNN
F 1 "GND" H 7150 1250 50  0000 C CNN
F 2 "" H 7150 1400 60  0000 C CNN
F 3 "" H 7150 1400 60  0000 C CNN
	1    7150 1400
	1    0    0    -1  
$EndComp
$Comp
L Device:C C159
U 1 1 596BC02C
P 7400 1250
F 0 "C159" H 7425 1350 50  0000 L CNN
F 1 "100n" H 7425 1150 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 7438 1100 30  0001 C CNN
F 3 "" H 7400 1250 60  0000 C CNN
	1    7400 1250
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR050
U 1 1 596BC033
P 7400 1400
F 0 "#PWR050" H 7400 1150 50  0001 C CNN
F 1 "GND" H 7400 1250 50  0000 C CNN
F 2 "" H 7400 1400 60  0000 C CNN
F 3 "" H 7400 1400 60  0000 C CNN
	1    7400 1400
	1    0    0    -1  
$EndComp
$Comp
L Device:C C160
U 1 1 596BC066
P 7650 1250
F 0 "C160" H 7675 1350 50  0000 L CNN
F 1 "100n" H 7675 1150 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 7688 1100 30  0001 C CNN
F 3 "" H 7650 1250 60  0000 C CNN
	1    7650 1250
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR051
U 1 1 596BC06D
P 7650 1400
F 0 "#PWR051" H 7650 1150 50  0001 C CNN
F 1 "GND" H 7650 1250 50  0000 C CNN
F 2 "" H 7650 1400 60  0000 C CNN
F 3 "" H 7650 1400 60  0000 C CNN
	1    7650 1400
	1    0    0    -1  
$EndComp
$Comp
L Device:C C161
U 1 1 596BC0A3
P 7900 1250
F 0 "C161" H 7925 1350 50  0000 L CNN
F 1 "100n" H 7925 1150 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 7938 1100 30  0001 C CNN
F 3 "" H 7900 1250 60  0000 C CNN
	1    7900 1250
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR052
U 1 1 596BC0AA
P 7900 1400
F 0 "#PWR052" H 7900 1150 50  0001 C CNN
F 1 "GND" H 7900 1250 50  0000 C CNN
F 2 "" H 7900 1400 60  0000 C CNN
F 3 "" H 7900 1400 60  0000 C CNN
	1    7900 1400
	1    0    0    -1  
$EndComp
Text HLabel 8050 1050 2    60   Input ~ 0
3V3D
$Comp
L Device:C C155
U 1 1 596BD0A1
P 4950 1650
F 0 "C155" H 4975 1750 50  0000 L CNN
F 1 "4.7u" H 4975 1550 50  0000 L CNN
F 2 "Capacitor_SMD:C_0603_1608Metric" H 4988 1500 30  0001 C CNN
F 3 "" H 4950 1650 60  0000 C CNN
	1    4950 1650
	1    0    0    -1  
$EndComp
$Comp
L Device:C C157
U 1 1 596BD0F6
P 5200 1650
F 0 "C157" H 5225 1750 50  0000 L CNN
F 1 "4.7u" H 5225 1550 50  0000 L CNN
F 2 "Capacitor_SMD:C_0603_1608Metric" H 5238 1500 30  0001 C CNN
F 3 "" H 5200 1650 60  0000 C CNN
	1    5200 1650
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR053
U 1 1 596BD1A8
P 4950 1800
F 0 "#PWR053" H 4950 1550 50  0001 C CNN
F 1 "GND" H 4950 1650 50  0000 C CNN
F 2 "" H 4950 1800 60  0000 C CNN
F 3 "" H 4950 1800 60  0000 C CNN
	1    4950 1800
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR054
U 1 1 596BD1F2
P 5200 1800
F 0 "#PWR054" H 5200 1550 50  0001 C CNN
F 1 "GND" H 5200 1650 50  0000 C CNN
F 2 "" H 5200 1800 60  0000 C CNN
F 3 "" H 5200 1800 60  0000 C CNN
	1    5200 1800
	1    0    0    -1  
$EndComp
Wire Wire Line
	4550 3350 5150 3350
Wire Wire Line
	4550 3450 5150 3450
Wire Wire Line
	4100 3350 4250 3350
Wire Wire Line
	4250 3450 4100 3450
Wire Wire Line
	4550 2350 5150 2350
Wire Wire Line
	6250 6450 6250 6550
Wire Wire Line
	6350 6550 6350 6450
Connection ~ 6250 6550
Wire Wire Line
	6450 6550 6450 6450
Connection ~ 6350 6550
Wire Wire Line
	6550 6550 6550 6450
Connection ~ 6450 6550
Wire Wire Line
	6650 6550 6650 6450
Connection ~ 6550 6550
Wire Wire Line
	7850 4150 7550 4150
Wire Wire Line
	7550 4250 8250 4250
Wire Wire Line
	7550 4350 8800 4350
Wire Wire Line
	8150 4150 8800 4150
Wire Wire Line
	8550 4250 8800 4250
Wire Wire Line
	7550 4450 7850 4450
Wire Wire Line
	8150 4450 8800 4450
Wire Wire Line
	7550 2350 8150 2350
Wire Wire Line
	7550 2450 8150 2450
Wire Wire Line
	7550 2550 8150 2550
Wire Wire Line
	7550 2650 8150 2650
Wire Wire Line
	7550 2750 8150 2750
Wire Wire Line
	7550 2850 8150 2850
Wire Wire Line
	7550 2950 8150 2950
Wire Wire Line
	7550 3050 8150 3050
Wire Wire Line
	7550 3250 8150 3250
Wire Wire Line
	7550 3350 8150 3350
Wire Wire Line
	7550 3450 8150 3450
Wire Wire Line
	7550 3550 8150 3550
Wire Wire Line
	7550 3650 8150 3650
Wire Wire Line
	3800 5300 3800 5450
Wire Wire Line
	3800 5800 3800 5850
Wire Wire Line
	3800 5450 5150 5450
Connection ~ 3800 5450
Connection ~ 3800 5850
Wire Wire Line
	3300 5950 3500 5950
Wire Wire Line
	3300 5300 3500 5300
Wire Wire Line
	1300 4350 1300 4400
Wire Wire Line
	2950 6950 3100 6950
Wire Wire Line
	4000 6950 3900 6950
Wire Wire Line
	4000 7050 3900 7050
Wire Wire Line
	3900 7150 4000 7150
Wire Wire Line
	1300 4050 1300 4000
Wire Wire Line
	1300 4750 1300 4900
Wire Wire Line
	1300 4900 1350 4900
Wire Wire Line
	1400 4400 1300 4400
Connection ~ 1300 4400
Wire Wire Line
	6150 6450 6150 6550
Wire Wire Line
	6050 6450 6050 6550
Connection ~ 6150 6550
Wire Wire Line
	5950 6450 5950 6550
Connection ~ 6050 6550
Connection ~ 5950 6550
Wire Wire Line
	4550 2750 4550 2650
Wire Wire Line
	5850 1300 5850 2050
Wire Wire Line
	5950 1050 5950 2050
Connection ~ 5950 1050
Wire Wire Line
	6200 1050 6200 1100
Wire Wire Line
	5600 1450 5600 1300
Connection ~ 5600 1300
Wire Wire Line
	7150 1050 7150 1100
Wire Wire Line
	7400 1050 7400 1100
Wire Wire Line
	7650 1050 7650 1100
Wire Wire Line
	7900 1050 7900 1100
Wire Wire Line
	6650 1050 6650 1900
Connection ~ 7150 1050
Wire Wire Line
	6550 2050 6550 1900
Wire Wire Line
	6550 1900 6650 1900
Connection ~ 6650 1900
Wire Wire Line
	6750 1900 6750 2050
Wire Wire Line
	6850 1900 6850 2050
Connection ~ 6750 1900
Connection ~ 7400 1050
Connection ~ 7650 1050
Connection ~ 7900 1050
Wire Wire Line
	4950 1500 4950 1300
Connection ~ 4950 1300
Wire Wire Line
	5200 1500 5200 1050
Connection ~ 5200 1050
Text Label 4600 2350 0    60   ~ 0
3V3D
Wire Wire Line
	5150 2550 4950 2550
Text Label 4950 2550 0    60   ~ 0
1V8
$Comp
L Device:C C156
U 1 1 596BE99F
P 4950 2700
F 0 "C156" H 4975 2800 50  0000 L CNN
F 1 "4.7u" H 4975 2600 50  0000 L CNN
F 2 "Capacitor_SMD:C_0603_1608Metric" H 4988 2550 30  0001 C CNN
F 3 "" H 4950 2700 60  0000 C CNN
	1    4950 2700
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR055
U 1 1 596BEA28
P 4950 2850
F 0 "#PWR055" H 4950 2600 50  0001 C CNN
F 1 "GND" H 4950 2700 50  0000 C CNN
F 2 "" H 4950 2850 60  0000 C CNN
F 3 "" H 4950 2850 60  0000 C CNN
	1    4950 2850
	1    0    0    -1  
$EndComp
Text Label 4100 1050 2    60   ~ 0
3V3D
Text Label 4100 1300 2    60   ~ 0
3V3D
$Comp
L Device:R R72
U 1 1 596BF8E7
P 4850 3850
F 0 "R72" V 4930 3850 50  0000 C CNN
F 1 "1k" V 4850 3850 50  0000 C CNN
F 2 "fmcw:R_0402b" V 4780 3850 30  0001 C CNN
F 3 "" H 4850 3850 30  0000 C CNN
	1    4850 3850
	0    1    1    0   
$EndComp
Wire Wire Line
	5000 3850 5150 3850
Wire Wire Line
	4700 3850 4600 3850
Text Label 4600 3850 2    60   ~ 0
3V3D
Wire Wire Line
	5150 3650 4250 3650
Wire Wire Line
	4250 3650 4250 3750
$Comp
L Device:R R71
U 1 1 596C00A3
P 4250 3900
F 0 "R71" V 4330 3900 50  0000 C CNN
F 1 "12k" V 4250 3900 50  0000 C CNN
F 2 "fmcw:R_0402b" V 4180 3900 30  0001 C CNN
F 3 "" H 4250 3900 30  0000 C CNN
	1    4250 3900
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR056
U 1 1 596C016D
P 4250 4050
F 0 "#PWR056" H 4250 3800 50  0001 C CNN
F 1 "GND" H 4250 3900 50  0000 C CNN
F 2 "" H 4250 4050 60  0000 C CNN
F 3 "" H 4250 4050 60  0000 C CNN
	1    4250 4050
	1    0    0    -1  
$EndComp
Wire Wire Line
	5100 6050 5100 6550
Wire Wire Line
	5150 4950 5050 4950
Wire Wire Line
	5150 5050 5050 5050
Wire Wire Line
	5150 5150 5050 5150
Text Label 5050 4950 2    60   ~ 0
EECS
Text Label 5050 5050 2    60   ~ 0
EECLK
Text Label 5050 5150 2    60   ~ 0
EEDATA
$Comp
L Device:R R82
U 1 1 596C316E
P 8600 5600
F 0 "R82" V 8680 5600 50  0000 C CNN
F 1 "4.7k" V 8600 5600 50  0000 C CNN
F 2 "fmcw:R_0402b" V 8530 5600 30  0001 C CNN
F 3 "" H 8600 5600 30  0000 C CNN
	1    8600 5600
	1    0    0    -1  
$EndComp
$Comp
L Device:R R83
U 1 1 596C31BB
P 8600 5950
F 0 "R83" V 8680 5950 50  0000 C CNN
F 1 "10k" V 8600 5950 50  0000 C CNN
F 2 "fmcw:R_0402b" V 8530 5950 30  0001 C CNN
F 3 "" H 8600 5950 30  0000 C CNN
	1    8600 5950
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR057
U 1 1 596C327E
P 8600 6100
F 0 "#PWR057" H 8600 5850 50  0001 C CNN
F 1 "GND" H 8600 5950 50  0000 C CNN
F 2 "" H 8600 6100 60  0000 C CNN
F 3 "" H 8600 6100 60  0000 C CNN
	1    8600 6100
	1    0    0    -1  
$EndComp
Wire Wire Line
	8600 5750 8600 5800
Text Label 8600 5350 0    60   ~ 0
USB_5V
Wire Wire Line
	6350 1950 6350 2050
Wire Wire Line
	6150 1950 6250 1950
Wire Wire Line
	6250 1950 6250 2050
Wire Wire Line
	6150 1950 6150 2050
Connection ~ 6250 1950
Text Label 6150 1950 0    60   ~ 0
1V8
$Comp
L Device:C C152
U 1 1 596C4A23
P 3750 1900
F 0 "C152" H 3636 1946 50  0000 R CNN
F 1 "100n" H 3636 1855 50  0000 R CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3788 1750 30  0001 C CNN
F 3 "" H 3750 1900 60  0000 C CNN
	1    3750 1900
	1    0    0    -1  
$EndComp
$Comp
L Device:C C153
U 1 1 596C4AA8
P 3950 1900
F 0 "C153" H 3975 2000 50  0000 L CNN
F 1 "100n" H 3975 1800 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3988 1750 30  0001 C CNN
F 3 "" H 3950 1900 60  0000 C CNN
	1    3950 1900
	1    0    0    -1  
$EndComp
$Comp
L Device:C C154
U 1 1 596C4AFE
P 4150 1900
F 0 "C154" H 4265 1946 50  0000 L CNN
F 1 "100n" H 4265 1855 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 4188 1750 30  0001 C CNN
F 3 "" H 4150 1900 60  0000 C CNN
	1    4150 1900
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR058
U 1 1 596C4CA2
P 4150 2050
F 0 "#PWR058" H 4150 1800 50  0001 C CNN
F 1 "GND" H 4150 1900 50  0000 C CNN
F 2 "" H 4150 2050 60  0000 C CNN
F 3 "" H 4150 2050 60  0000 C CNN
	1    4150 2050
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR059
U 1 1 596C4CF6
P 3950 2050
F 0 "#PWR059" H 3950 1800 50  0001 C CNN
F 1 "GND" H 3950 1900 50  0000 C CNN
F 2 "" H 3950 2050 60  0000 C CNN
F 3 "" H 3950 2050 60  0000 C CNN
	1    3950 2050
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR060
U 1 1 596C4D43
P 3750 2050
F 0 "#PWR060" H 3750 1800 50  0001 C CNN
F 1 "GND" H 3750 1900 50  0000 C CNN
F 2 "" H 3750 2050 60  0000 C CNN
F 3 "" H 3750 2050 60  0000 C CNN
	1    3750 2050
	1    0    0    -1  
$EndComp
Wire Wire Line
	3750 1750 3750 1700
Wire Wire Line
	3750 1700 3950 1700
Wire Wire Line
	3950 1700 3950 1750
Wire Wire Line
	4150 1700 4150 1750
Connection ~ 3950 1700
Text Label 3800 1700 0    60   ~ 0
1V8
Wire Wire Line
	7550 3750 8150 3750
Text HLabel 8150 3750 2    60   Output ~ 0
CLKOUT
Wire Wire Line
	7550 3850 8150 3850
Text HLabel 8150 3850 2    60   Input ~ 0
OE#
NoConn ~ 3650 5600
NoConn ~ 3650 5700
Wire Wire Line
	7550 6050 7600 6050
Text HLabel 7600 6050 2    60   Output ~ 0
SUSPEND
Wire Wire Line
	6250 6550 6250 6600
Wire Wire Line
	6250 6550 6350 6550
Wire Wire Line
	6350 6550 6450 6550
Wire Wire Line
	6450 6550 6550 6550
Wire Wire Line
	6550 6550 6650 6550
Wire Wire Line
	3800 5450 3800 5500
Wire Wire Line
	3800 5850 3800 5950
Wire Wire Line
	1300 4400 1300 4450
Wire Wire Line
	6150 6550 6250 6550
Wire Wire Line
	6050 6550 6150 6550
Wire Wire Line
	5950 6550 6050 6550
Wire Wire Line
	5950 1050 6200 1050
Wire Wire Line
	5600 1300 5850 1300
Wire Wire Line
	7150 1050 7400 1050
Wire Wire Line
	6650 1900 6650 2050
Wire Wire Line
	6650 1900 6750 1900
Wire Wire Line
	6750 1900 6850 1900
Wire Wire Line
	7400 1050 7650 1050
Wire Wire Line
	7650 1050 7900 1050
Wire Wire Line
	7900 1050 8050 1050
Wire Wire Line
	4950 1300 5600 1300
Wire Wire Line
	5200 1050 5950 1050
Wire Wire Line
	6250 1950 6350 1950
Wire Wire Line
	3950 1700 4150 1700
$Comp
L Interface_USB:FT2232H U14
U 1 1 5B4D30D0
P 6350 4250
F 0 "U14" H 6350 4150 50  0000 C CNN
F 1 "FT2232H" H 6350 4250 50  0000 C CNN
F 2 "Package_QFP:LQFP-64_10x10mm_P0.5mm" H 6350 4250 50  0001 C CNN
F 3 "http://www.ftdichip.com/Products/ICs/FT2232H.html" H 6350 4250 50  0001 C CNN
	1    6350 4250
	1    0    0    -1  
$EndComp
Wire Wire Line
	3800 5850 5150 5850
Wire Wire Line
	5100 6550 5750 6550
Wire Wire Line
	5750 6550 5750 6450
Connection ~ 5750 6550
Wire Wire Line
	5750 6550 5950 6550
Wire Wire Line
	5100 6050 5150 6050
Connection ~ 8600 5750
NoConn ~ 7550 3950
NoConn ~ 7550 4550
NoConn ~ 7550 4650
NoConn ~ 7550 4750
NoConn ~ 7550 4850
NoConn ~ 7550 5050
NoConn ~ 7550 5150
NoConn ~ 7550 5250
NoConn ~ 7550 5350
NoConn ~ 7550 5450
NoConn ~ 7550 5550
NoConn ~ 7550 5650
NoConn ~ 7550 5950
Wire Wire Line
	6650 1050 7150 1050
Wire Wire Line
	7550 5750 8600 5750
$Comp
L Memory_EEPROM:93LCxxB U31
U 1 1 6321F24D
P 3500 7050
F 0 "U31" H 3750 6800 50  0000 C CNN
F 1 "93LCxxB" H 3700 7300 50  0000 C CNN
F 2 "Package_TO_SOT_SMD:SOT-23-6" H 3500 7050 50  0001 C CNN
F 3 "http://ww1.microchip.com/downloads/en/DeviceDoc/20001749K.pdf" H 3500 7050 50  0001 C CNN
	1    3500 7050
	1    0    0    -1  
$EndComp
Wire Wire Line
	3500 6750 3500 6450
Wire Wire Line
	2450 6450 2450 6550
Wire Wire Line
	2450 6850 2450 6900
Wire Wire Line
	2450 6450 3500 6450
Wire Wire Line
	3500 7350 3500 7450
$Comp
L power:GND #PWR044
U 1 1 6327E0E5
P 3500 7450
F 0 "#PWR044" H 3500 7200 50  0001 C CNN
F 1 "GND" H 3505 7277 50  0000 C CNN
F 2 "" H 3500 7450 50  0001 C CNN
F 3 "" H 3500 7450 50  0001 C CNN
	1    3500 7450
	1    0    0    -1  
$EndComp
Text Label 2900 6450 0    60   ~ 0
3V3D
$Comp
L Connector:USB_B_Micro J2
U 1 1 63293618
P 1250 2950
F 0 "J2" H 1305 3417 50  0000 C CNN
F 1 "USB_B_Micro" H 1305 3326 50  0000 C CNN
F 2 "Connector_USB:USB_Micro-B_Amphenol_10103594-0001LF_Horizontal" H 1400 2900 50  0001 C CNN
F 3 "~" H 1400 2900 50  0001 C CNN
	1    1250 2950
	1    0    0    -1  
$EndComp
Wire Wire Line
	1550 2750 1850 2750
Text Label 1850 2750 0    60   ~ 0
USB_5V
Wire Wire Line
	1550 2950 1850 2950
Text Label 1850 2950 0    60   ~ 0
USBDP
Wire Wire Line
	1550 3050 1850 3050
Text Label 1850 3050 0    60   ~ 0
USBDM
NoConn ~ 1550 3150
Wire Wire Line
	1250 3350 1250 3400
$Comp
L power:GND #PWR0255
U 1 1 632B9897
P 1250 3450
F 0 "#PWR0255" H 1250 3200 50  0001 C CNN
F 1 "GND" H 1255 3277 50  0000 C CNN
F 2 "" H 1250 3450 50  0001 C CNN
F 3 "" H 1250 3450 50  0001 C CNN
	1    1250 3450
	1    0    0    -1  
$EndComp
Wire Wire Line
	4700 1300 4950 1300
Wire Wire Line
	4100 1300 4400 1300
Wire Wire Line
	4100 1050 4400 1050
Wire Wire Line
	4700 1050 5200 1050
Wire Wire Line
	8600 5350 8600 5450
Wire Wire Line
	1150 3350 1150 3400
Wire Wire Line
	1150 3400 1250 3400
Connection ~ 1250 3400
Wire Wire Line
	1250 3400 1250 3450
$EndSCHEMATC
