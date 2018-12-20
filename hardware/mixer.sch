EESchema Schematic File Version 4
LIBS:fmcw-cache
EELAYER 26 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 9 10
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
L power:GND #PWR?
U 1 1 593ACD1C
P 6050 5400
AR Path="/59396B97/593ABC4F/593ACD1C" Ref="#PWR?"  Part="1" 
AR Path="/59434BD2/593ACD1C" Ref="#PWR0223"  Part="1" 
F 0 "#PWR0223" H 6050 5150 50  0001 C CNN
F 1 "GND" H 6050 5250 50  0000 C CNN
F 2 "" H 6050 5400 60  0000 C CNN
F 3 "" H 6050 5400 60  0000 C CNN
	1    6050 5400
	1    0    0    -1  
$EndComp
$Comp
L fmcw-rescue:5400BL15B050E-fmcw3-rescue U?
U 1 1 593ACD34
P 2650 4550
AR Path="/59396B97/593ABC4F/593ACD34" Ref="U?"  Part="1" 
AR Path="/59434BD2/593ACD34" Ref="U26"  Part="1" 
AR Path="/593ACD34" Ref="U26"  Part="1" 
F 0 "U26" H 2900 4800 60  0000 C CNN
F 1 "5400BL15B050E" H 2750 5250 60  0000 C CNN
F 2 "fmcw:5400BL15B050E" H 2650 4550 60  0001 C CNN
F 3 "https://www.johansontechnology.com/datasheets/5400BL15B050/5400BL15B050.pdf" H 2650 4550 60  0001 C CNN
	1    2650 4550
	1    0    0    -1  
$EndComp
$Comp
L Device:C C?
U 1 1 593ACD56
P 3550 3950
AR Path="/59396B97/593ABC4F/593ACD56" Ref="C?"  Part="1" 
AR Path="/59434BD2/593ACD56" Ref="C109"  Part="1" 
F 0 "C109" V 3298 3950 50  0000 C CNN
F 1 "3p" V 3389 3950 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3588 3800 30  0001 C CNN
F 3 "" H 3550 3950 60  0000 C CNN
	1    3550 3950
	0    1    1    0   
$EndComp
$Comp
L Device:C C?
U 1 1 593ACD5D
P 3550 4150
AR Path="/59396B97/593ABC4F/593ACD5D" Ref="C?"  Part="1" 
AR Path="/59434BD2/593ACD5D" Ref="C110"  Part="1" 
F 0 "C110" V 3710 4150 50  0000 C CNN
F 1 "3p" V 3801 4150 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3588 4000 30  0001 C CNN
F 3 "" H 3550 4150 60  0000 C CNN
	1    3550 4150
	0    1    1    0   
$EndComp
$Comp
L power:GND #PWR?
U 1 1 593ACD64
P 2600 4550
AR Path="/59396B97/593ABC4F/593ACD64" Ref="#PWR?"  Part="1" 
AR Path="/59434BD2/593ACD64" Ref="#PWR0224"  Part="1" 
F 0 "#PWR0224" H 2600 4300 50  0001 C CNN
F 1 "GND" H 2600 4400 50  0000 C CNN
F 2 "" H 2600 4550 60  0000 C CNN
F 3 "" H 2600 4550 60  0000 C CNN
	1    2600 4550
	1    0    0    -1  
$EndComp
$Comp
L Device:C C?
U 1 1 593ACD6A
P 4450 2600
AR Path="/59396B97/593ABC4F/593ACD6A" Ref="C?"  Part="1" 
AR Path="/59434BD2/593ACD6A" Ref="C117"  Part="1" 
F 0 "C117" H 4475 2700 50  0000 L CNN
F 1 "100p" H 4475 2500 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 4488 2450 30  0001 C CNN
F 3 "" H 4450 2600 60  0000 C CNN
	1    4450 2600
	-1   0    0    1   
$EndComp
$Comp
L Device:C C?
U 1 1 593ACD71
P 4150 2600
AR Path="/59396B97/593ABC4F/593ACD71" Ref="C?"  Part="1" 
AR Path="/59434BD2/593ACD71" Ref="C116"  Part="1" 
F 0 "C116" H 4175 2700 50  0000 L CNN
F 1 "100n" H 4175 2500 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 4188 2450 30  0001 C CNN
F 3 "" H 4150 2600 60  0000 C CNN
	1    4150 2600
	-1   0    0    1   
$EndComp
$Comp
L power:GND #PWR?
U 1 1 593ACD78
P 4450 2750
AR Path="/59396B97/593ABC4F/593ACD78" Ref="#PWR?"  Part="1" 
AR Path="/59434BD2/593ACD78" Ref="#PWR0225"  Part="1" 
F 0 "#PWR0225" H 4450 2500 50  0001 C CNN
F 1 "GND" H 4450 2600 50  0000 C CNN
F 2 "" H 4450 2750 60  0000 C CNN
F 3 "" H 4450 2750 60  0000 C CNN
	1    4450 2750
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR?
U 1 1 593ACD7E
P 4150 2750
AR Path="/59396B97/593ABC4F/593ACD7E" Ref="#PWR?"  Part="1" 
AR Path="/59434BD2/593ACD7E" Ref="#PWR0226"  Part="1" 
F 0 "#PWR0226" H 4150 2500 50  0001 C CNN
F 1 "GND" H 4150 2600 50  0000 C CNN
F 2 "" H 4150 2750 60  0000 C CNN
F 3 "" H 4150 2750 60  0000 C CNN
	1    4150 2750
	1    0    0    -1  
$EndComp
$Comp
L Device:R R?
U 1 1 593ACD85
P 8400 3300
AR Path="/59396B97/593ABC4F/593ACD85" Ref="R?"  Part="1" 
AR Path="/59434BD2/593ACD85" Ref="R51"  Part="1" 
F 0 "R51" H 8330 3254 50  0000 R CNN
F 1 "49.9" H 8330 3345 50  0000 R CNN
F 2 "fmcw:R_0402b" V 8330 3300 30  0001 C CNN
F 3 "" H 8400 3300 30  0000 C CNN
	1    8400 3300
	-1   0    0    1   
$EndComp
$Comp
L Device:R R?
U 1 1 593ACD8C
P 8400 3700
AR Path="/59396B97/593ABC4F/593ACD8C" Ref="R?"  Part="1" 
AR Path="/59434BD2/593ACD8C" Ref="R52"  Part="1" 
F 0 "R52" H 8330 3654 50  0000 R CNN
F 1 "49.9" H 8330 3745 50  0000 R CNN
F 2 "fmcw:R_0402b" V 8330 3700 30  0001 C CNN
F 3 "" H 8400 3700 30  0000 C CNN
	1    8400 3700
	-1   0    0    1   
$EndComp
$Comp
L Device:C C?
U 1 1 593ACD93
P 8250 3050
AR Path="/59396B97/593ABC4F/593ACD93" Ref="C?"  Part="1" 
AR Path="/59434BD2/593ACD93" Ref="C120"  Part="1" 
F 0 "C120" V 8502 3050 50  0000 C CNN
F 1 "100n" V 8411 3050 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 8288 2900 30  0001 C CNN
F 3 "" H 8250 3050 60  0000 C CNN
	1    8250 3050
	0    -1   -1   0   
$EndComp
$Comp
L power:GND #PWR?
U 1 1 593ACD9A
P 8100 3050
AR Path="/59396B97/593ABC4F/593ACD9A" Ref="#PWR?"  Part="1" 
AR Path="/59434BD2/593ACD9A" Ref="#PWR0227"  Part="1" 
F 0 "#PWR0227" H 8100 2800 50  0001 C CNN
F 1 "GND" H 8100 2900 50  0000 C CNN
F 2 "" H 8100 3050 60  0000 C CNN
F 3 "" H 8100 3050 60  0000 C CNN
	1    8100 3050
	0    1    1    0   
$EndComp
$Comp
L Device:C C?
U 1 1 593ACDA0
P 8250 4000
AR Path="/59396B97/593ABC4F/593ACDA0" Ref="C?"  Part="1" 
AR Path="/59434BD2/593ACDA0" Ref="C121"  Part="1" 
F 0 "C121" V 8502 4000 50  0000 C CNN
F 1 "100n" V 8411 4000 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 8288 3850 30  0001 C CNN
F 3 "" H 8250 4000 60  0000 C CNN
	1    8250 4000
	0    -1   -1   0   
$EndComp
$Comp
L power:GND #PWR?
U 1 1 593ACDA7
P 8100 4000
AR Path="/59396B97/593ABC4F/593ACDA7" Ref="#PWR?"  Part="1" 
AR Path="/59434BD2/593ACDA7" Ref="#PWR0228"  Part="1" 
F 0 "#PWR0228" H 8100 3750 50  0001 C CNN
F 1 "GND" H 8100 3850 50  0000 C CNN
F 2 "" H 8100 4000 60  0000 C CNN
F 3 "" H 8100 4000 60  0000 C CNN
	1    8100 4000
	0    1    1    0   
$EndComp
Text Label 8400 2850 0    60   ~ 0
5VF
Text Label 8400 4100 0    60   ~ 0
5VF
Text HLabel 4650 3850 0    60   Input ~ 0
MIX_ENBL
Text HLabel 950  4050 0    60   Input ~ 0
LO_IN
Text HLabel 8600 3550 2    60   Output ~ 0
IF1+
Text HLabel 8600 3450 2    60   Output ~ 0
IF1-
Text HLabel 3100 2200 0    60   Input ~ 0
5V
$Comp
L fmcw-rescue:ADL5802-fmcw3-rescue U?
U 1 1 5942E974
P 4650 4150
AR Path="/59396B97/593ABC4F/5942E974" Ref="U?"  Part="1" 
AR Path="/59434BD2/5942E974" Ref="U29"  Part="1" 
F 0 "U29" H 6100 4700 60  0000 C CNN
F 1 "ADL5802" H 5600 3950 60  0000 C CNN
F 2 "Package_DFN_QFN:QFN-24-1EP_4x4mm_P0.5mm_EP2.6x2.6mm" H 4650 4150 60  0001 C CNN
F 3 "http://www.analog.com/media/en/technical-documentation/data-sheets/ADL5802.pdf" H 4650 4150 60  0001 C CNN
F 4 "" H 4650 4150 50  0001 C CNN "manf#"
F 5 "ADL5802ACPZ-R7" H 0   0   50  0001 C CNN "MFN"
	1    4650 4150
	1    0    0    -1  
$EndComp
$Comp
L fmcw-rescue:5400BL15B050E-fmcw3-rescue U27
U 1 1 5942FD33
P 2650 5500
AR Path="/5942FD33" Ref="U27"  Part="1" 
AR Path="/59434BD2/5942FD33" Ref="U27"  Part="1" 
F 0 "U27" H 2900 5750 60  0000 C CNN
F 1 "5400BL15B050E" H 2750 6200 60  0000 C CNN
F 2 "fmcw:5400BL15B050E" H 2650 5500 60  0001 C CNN
F 3 "" H 2650 5500 60  0000 C CNN
	1    2650 5500
	1    0    0    -1  
$EndComp
$Comp
L Device:C C111
U 1 1 5942FD39
P 3550 4900
F 0 "C111" V 3298 4900 50  0000 C CNN
F 1 "3p" V 3389 4900 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3588 4750 30  0001 C CNN
F 3 "" H 3550 4900 60  0000 C CNN
	1    3550 4900
	0    1    1    0   
$EndComp
$Comp
L Device:C C112
U 1 1 5942FD3F
P 3550 5100
F 0 "C112" V 3710 5100 50  0000 C CNN
F 1 "3p" V 3801 5100 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3588 4950 30  0001 C CNN
F 3 "" H 3550 5100 60  0000 C CNN
	1    3550 5100
	0    1    1    0   
$EndComp
$Comp
L power:GND #PWR0229
U 1 1 5942FD45
P 2600 5500
F 0 "#PWR0229" H 2600 5250 50  0001 C CNN
F 1 "GND" H 2600 5350 50  0000 C CNN
F 2 "" H 2600 5500 60  0000 C CNN
F 3 "" H 2600 5500 60  0000 C CNN
	1    2600 5500
	1    0    0    -1  
$EndComp
Text HLabel 2100 5000 0    60   Input ~ 0
RF1
$Comp
L fmcw-rescue:5400BL15B050E-fmcw3-rescue U28
U 1 1 59430048
P 2650 6500
AR Path="/59430048" Ref="U28"  Part="1" 
AR Path="/59434BD2/59430048" Ref="U28"  Part="1" 
F 0 "U28" H 2900 6750 60  0000 C CNN
F 1 "5400BL15B050E" H 2750 7200 60  0000 C CNN
F 2 "fmcw:5400BL15B050E" H 2650 6500 60  0001 C CNN
F 3 "" H 2650 6500 60  0000 C CNN
	1    2650 6500
	1    0    0    -1  
$EndComp
$Comp
L Device:C C113
U 1 1 5943004E
P 3550 5900
F 0 "C113" V 3298 5900 50  0000 C CNN
F 1 "3p" V 3389 5900 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3588 5750 30  0001 C CNN
F 3 "" H 3550 5900 60  0000 C CNN
	1    3550 5900
	0    1    1    0   
$EndComp
$Comp
L Device:C C114
U 1 1 59430054
P 3550 6100
F 0 "C114" V 3710 6100 50  0000 C CNN
F 1 "3p" V 3801 6100 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3588 5950 30  0001 C CNN
F 3 "" H 3550 6100 60  0000 C CNN
	1    3550 6100
	0    1    1    0   
$EndComp
$Comp
L power:GND #PWR0230
U 1 1 5943005A
P 2600 6500
F 0 "#PWR0230" H 2600 6250 50  0001 C CNN
F 1 "GND" H 2600 6350 50  0000 C CNN
F 2 "" H 2600 6500 60  0000 C CNN
F 3 "" H 2600 6500 60  0000 C CNN
	1    2600 6500
	1    0    0    -1  
$EndComp
Text HLabel 2100 6000 0    60   Input ~ 0
RF2
$Comp
L Device:R R53
U 1 1 59431056
P 8400 4900
F 0 "R53" H 8330 4854 50  0000 R CNN
F 1 "49.9" H 8330 4945 50  0000 R CNN
F 2 "fmcw:R_0402b" V 8330 4900 30  0001 C CNN
F 3 "" H 8400 4900 30  0000 C CNN
	1    8400 4900
	-1   0    0    1   
$EndComp
$Comp
L Device:R R54
U 1 1 5943105C
P 8400 5300
F 0 "R54" H 8330 5254 50  0000 R CNN
F 1 "49.9" H 8330 5345 50  0000 R CNN
F 2 "fmcw:R_0402b" V 8330 5300 30  0001 C CNN
F 3 "" H 8400 5300 30  0000 C CNN
	1    8400 5300
	-1   0    0    1   
$EndComp
$Comp
L Device:C C?
U 1 1 59431062
P 8250 4650
AR Path="/59396B97/593ABC4F/59431062" Ref="C?"  Part="1" 
AR Path="/59434BD2/59431062" Ref="C122"  Part="1" 
F 0 "C122" V 8090 4650 50  0000 C CNN
F 1 "100n" V 7999 4650 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 8288 4500 30  0001 C CNN
F 3 "" H 8250 4650 60  0000 C CNN
	1    8250 4650
	0    -1   -1   0   
$EndComp
$Comp
L power:GND #PWR0231
U 1 1 59431068
P 8100 4650
F 0 "#PWR0231" H 8100 4400 50  0001 C CNN
F 1 "GND" H 8100 4500 50  0000 C CNN
F 2 "" H 8100 4650 60  0000 C CNN
F 3 "" H 8100 4650 60  0000 C CNN
	1    8100 4650
	0    1    1    0   
$EndComp
$Comp
L Device:C C?
U 1 1 5943106E
P 8250 5600
AR Path="/59396B97/593ABC4F/5943106E" Ref="C?"  Part="1" 
AR Path="/59434BD2/5943106E" Ref="C123"  Part="1" 
F 0 "C123" V 8502 5600 50  0000 C CNN
F 1 "100n" V 8411 5600 50  0000 C CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 8288 5450 30  0001 C CNN
F 3 "" H 8250 5600 60  0000 C CNN
	1    8250 5600
	0    -1   -1   0   
$EndComp
$Comp
L power:GND #PWR0232
U 1 1 59431074
P 8100 5600
F 0 "#PWR0232" H 8100 5350 50  0001 C CNN
F 1 "GND" H 8100 5450 50  0000 C CNN
F 2 "" H 8100 5600 60  0000 C CNN
F 3 "" H 8100 5600 60  0000 C CNN
	1    8100 5600
	0    1    1    0   
$EndComp
Text Label 8400 4450 2    60   ~ 0
5VF
Text Label 8400 5700 0    60   ~ 0
5VF
Text HLabel 8600 5150 2    60   Output ~ 0
IF2+
Text HLabel 8600 5050 2    60   Output ~ 0
IF2-
$Comp
L Device:C C?
U 1 1 594316B6
P 4750 2600
AR Path="/59396B97/593ABC4F/594316B6" Ref="C?"  Part="1" 
AR Path="/59434BD2/594316B6" Ref="C118"  Part="1" 
F 0 "C118" H 4775 2700 50  0000 L CNN
F 1 "100p" H 4775 2500 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 4788 2450 30  0001 C CNN
F 3 "" H 4750 2600 60  0000 C CNN
	1    4750 2600
	-1   0    0    1   
$EndComp
$Comp
L Device:C C119
U 1 1 594316FC
P 5050 2600
F 0 "C119" H 5075 2700 50  0000 L CNN
F 1 "100p" H 5075 2500 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 5088 2450 30  0001 C CNN
F 3 "" H 5050 2600 60  0000 C CNN
	1    5050 2600
	-1   0    0    1   
$EndComp
$Comp
L power:GND #PWR?
U 1 1 594317B9
P 4750 2750
AR Path="/59396B97/593ABC4F/594317B9" Ref="#PWR?"  Part="1" 
AR Path="/59434BD2/594317B9" Ref="#PWR0233"  Part="1" 
F 0 "#PWR0233" H 4750 2500 50  0001 C CNN
F 1 "GND" H 4750 2600 50  0000 C CNN
F 2 "" H 4750 2750 60  0000 C CNN
F 3 "" H 4750 2750 60  0000 C CNN
	1    4750 2750
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0234
U 1 1 594317F0
P 5050 2750
F 0 "#PWR0234" H 5050 2500 50  0001 C CNN
F 1 "GND" H 5050 2600 50  0000 C CNN
F 2 "" H 5050 2750 60  0000 C CNN
F 3 "" H 5050 2750 60  0000 C CNN
	1    5050 2750
	1    0    0    -1  
$EndComp
$Comp
L Device:C C?
U 1 1 5943199B
P 3800 2600
AR Path="/59396B97/593ABC4F/5943199B" Ref="C?"  Part="1" 
AR Path="/59434BD2/5943199B" Ref="C115"  Part="1" 
F 0 "C115" H 3825 2700 50  0000 L CNN
F 1 "100n" H 3825 2500 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3838 2450 30  0001 C CNN
F 3 "" H 3800 2600 60  0000 C CNN
	1    3800 2600
	-1   0    0    1   
$EndComp
$Comp
L Device:C C108
U 1 1 594319E3
P 3450 2600
F 0 "C108" H 3475 2700 50  0000 L CNN
F 1 "100n" H 3475 2500 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 3488 2450 30  0001 C CNN
F 3 "" H 3450 2600 60  0000 C CNN
	1    3450 2600
	-1   0    0    1   
$EndComp
Wire Wire Line
	6050 5200 6050 5300
Wire Wire Line
	3850 3950 3700 3950
Wire Wire Line
	3400 3950 3300 3950
Wire Wire Line
	3300 3950 3300 4000
Wire Wire Line
	3300 4000 3200 4000
Wire Wire Line
	3200 4100 3300 4100
Wire Wire Line
	3300 4100 3300 4150
Wire Wire Line
	3300 4150 3400 4150
Wire Wire Line
	2600 4450 2600 4500
Wire Wire Line
	2700 4450 2700 4500
Wire Wire Line
	2700 4500 2600 4500
Connection ~ 2600 4500
Wire Wire Line
	3450 2450 3800 2450
Connection ~ 4450 2450
Wire Wire Line
	6950 3550 8400 3550
Wire Wire Line
	6850 3450 8400 3450
Wire Wire Line
	8400 3850 8400 4000
Wire Wire Line
	8400 2850 8400 3050
Connection ~ 8400 4000
Connection ~ 8400 3050
Connection ~ 8400 3450
Connection ~ 8400 3550
Wire Wire Line
	950  4050 2100 4050
Wire Wire Line
	4150 2200 4150 2450
Wire Wire Line
	5950 5300 5950 5200
Wire Wire Line
	5150 5300 5250 5300
Connection ~ 6050 5300
Wire Wire Line
	5850 5200 5850 5300
Connection ~ 5950 5300
Wire Wire Line
	5750 5200 5750 5300
Connection ~ 5850 5300
Wire Wire Line
	5650 5200 5650 5300
Connection ~ 5750 5300
Wire Wire Line
	5550 5200 5550 5300
Connection ~ 5650 5300
Wire Wire Line
	5450 5300 5450 5200
Connection ~ 5550 5300
Wire Wire Line
	5350 5200 5350 5300
Connection ~ 5450 5300
Wire Wire Line
	5250 5200 5250 5300
Connection ~ 5350 5300
Wire Wire Line
	4650 3850 4800 3850
Wire Wire Line
	4800 4000 3850 4000
Wire Wire Line
	3850 4000 3850 3950
Wire Wire Line
	4800 4100 3850 4100
Wire Wire Line
	3850 4100 3850 4150
Wire Wire Line
	3850 4150 3700 4150
Wire Wire Line
	3400 4900 3300 4900
Wire Wire Line
	3300 4900 3300 4950
Wire Wire Line
	3300 4950 3200 4950
Wire Wire Line
	3200 5050 3300 5050
Wire Wire Line
	3300 5050 3300 5100
Wire Wire Line
	3300 5100 3400 5100
Wire Wire Line
	2600 5400 2600 5450
Wire Wire Line
	2700 5400 2700 5450
Wire Wire Line
	2700 5450 2600 5450
Connection ~ 2600 5450
Wire Wire Line
	2200 5000 2100 5000
Wire Wire Line
	3400 5900 3300 5900
Wire Wire Line
	3300 5900 3300 5950
Wire Wire Line
	3300 5950 3200 5950
Wire Wire Line
	3200 6050 3300 6050
Wire Wire Line
	3300 6050 3300 6100
Wire Wire Line
	3300 6100 3400 6100
Wire Wire Line
	2600 6400 2600 6450
Wire Wire Line
	2700 6400 2700 6450
Wire Wire Line
	2700 6450 2600 6450
Connection ~ 2600 6450
Wire Wire Line
	2200 6000 2100 6000
Wire Wire Line
	4800 4300 3700 4300
Wire Wire Line
	3700 4300 3700 4900
Wire Wire Line
	4800 4400 3850 4400
Wire Wire Line
	3850 4400 3850 5100
Wire Wire Line
	3850 5100 3700 5100
Wire Wire Line
	4800 4600 4050 4600
Wire Wire Line
	4050 4600 4050 5900
Wire Wire Line
	4050 5900 3700 5900
Wire Wire Line
	3700 6100 4150 6100
Wire Wire Line
	4150 6100 4150 4700
Wire Wire Line
	4150 4700 4800 4700
Wire Wire Line
	7350 5150 8400 5150
Wire Wire Line
	7500 5050 8400 5050
Wire Wire Line
	8400 5450 8400 5600
Wire Wire Line
	8400 4450 8400 4650
Connection ~ 8400 5600
Connection ~ 8400 4650
Connection ~ 8400 5050
Connection ~ 8400 5150
Wire Wire Line
	6850 3450 6850 4000
Wire Wire Line
	6850 4000 6400 4000
Wire Wire Line
	6400 4100 6950 4100
Wire Wire Line
	6950 4100 6950 3550
Wire Wire Line
	6400 4300 7500 4300
Wire Wire Line
	7500 4300 7500 5050
Wire Wire Line
	7350 5150 7350 4400
Wire Wire Line
	7350 4400 6400 4400
Wire Wire Line
	5700 2450 5700 3500
Connection ~ 5050 2450
Wire Wire Line
	5600 3500 5600 2450
Connection ~ 5600 2450
Wire Wire Line
	5500 3500 5500 2450
Connection ~ 5500 2450
$Comp
L power:GND #PWR?
U 1 1 59431C33
P 3800 2750
AR Path="/59396B97/593ABC4F/59431C33" Ref="#PWR?"  Part="1" 
AR Path="/59434BD2/59431C33" Ref="#PWR0235"  Part="1" 
F 0 "#PWR0235" H 3800 2500 50  0001 C CNN
F 1 "GND" H 3800 2600 50  0000 C CNN
F 2 "" H 3800 2750 60  0000 C CNN
F 3 "" H 3800 2750 60  0000 C CNN
	1    3800 2750
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0236
U 1 1 59431C75
P 3450 2750
F 0 "#PWR0236" H 3450 2500 50  0001 C CNN
F 1 "GND" H 3450 2600 50  0000 C CNN
F 2 "" H 3450 2750 60  0000 C CNN
F 3 "" H 3450 2750 60  0000 C CNN
	1    3450 2750
	1    0    0    -1  
$EndComp
Connection ~ 4150 2450
Connection ~ 3800 2450
$Comp
L Device:R R?
U 1 1 594321EF
P 6950 5350
AR Path="/59396B97/593ABC4F/594321EF" Ref="R?"  Part="1" 
AR Path="/59434BD2/594321EF" Ref="R50"  Part="1" 
F 0 "R50" V 7030 5350 50  0000 C CNN
F 1 "DNP" V 6950 5350 50  0000 C CNN
F 2 "fmcw:R_0402b" V 6880 5350 30  0001 C CNN
F 3 "" H 6950 5350 30  0000 C CNN
	1    6950 5350
	1    0    0    -1  
$EndComp
Wire Wire Line
	6400 4650 6750 4650
Wire Wire Line
	6750 4650 6750 5150
$Comp
L Device:R R49
U 1 1 594327C4
P 6950 4950
F 0 "R49" V 7030 4950 50  0000 C CNN
F 1 "2k" V 6950 4950 50  0000 C CNN
F 2 "fmcw:R_0402b" V 6880 4950 30  0001 C CNN
F 3 "" H 6950 4950 30  0000 C CNN
	1    6950 4950
	1    0    0    -1  
$EndComp
Wire Wire Line
	6750 5150 6950 5150
Wire Wire Line
	6950 5100 6950 5150
Connection ~ 6950 5150
$Comp
L power:GND #PWR0237
U 1 1 5943298A
P 6950 5500
F 0 "#PWR0237" H 6950 5250 50  0001 C CNN
F 1 "GND" H 6950 5350 50  0000 C CNN
F 2 "" H 6950 5500 60  0000 C CNN
F 3 "" H 6950 5500 60  0000 C CNN
	1    6950 5500
	1    0    0    -1  
$EndComp
Wire Wire Line
	6950 4800 6950 4750
Text Label 6950 4750 0    60   ~ 0
5VF
Text Notes 4300 2350 0    50   ~ 0
I_max: 300mA\nI_typ: 220mA
$Comp
L Device:Ferrite_Bead FB13
U 1 1 59754A66
P 3650 2200
F 0 "FB13" V 3600 2050 50  0000 C CNN
F 1 "BLM18PG181SN1D" V 3500 2200 50  0000 C CNN
F 2 "fmcw:C_0603b" H 3650 2200 60  0001 C CNN
F 3 "" H 3650 2200 60  0000 C CNN
	1    3650 2200
	0    1    1    0   
$EndComp
$Comp
L Device:C C107
U 1 1 59754CBB
P 3000 2650
F 0 "C107" H 3025 2750 50  0000 L CNN
F 1 "DNP" H 3025 2550 50  0000 L CNN
F 2 "Capacitor_SMD:C_0805_2012Metric" H 3038 2500 30  0001 C CNN
F 3 "" H 3000 2650 60  0000 C CNN
	1    3000 2650
	-1   0    0    1   
$EndComp
$Comp
L power:GND #PWR0238
U 1 1 59754CC1
P 3000 2800
F 0 "#PWR0238" H 3000 2550 50  0001 C CNN
F 1 "GND" H 3000 2650 50  0000 C CNN
F 2 "" H 3000 2800 60  0000 C CNN
F 3 "" H 3000 2800 60  0000 C CNN
	1    3000 2800
	1    0    0    -1  
$EndComp
Wire Wire Line
	3000 2500 3000 2300
Wire Wire Line
	3000 2300 3150 2300
Wire Wire Line
	3150 2300 3150 2200
Wire Wire Line
	3100 2200 3150 2200
Connection ~ 3150 2200
Connection ~ 4750 2450
Text Label 5200 2450 0    60   ~ 0
5VF
$Comp
L Device:C C162
U 1 1 596ED50B
P 6250 2800
F 0 "C162" H 6275 2900 50  0000 L CNN
F 1 "10u" H 6275 2700 50  0000 L CNN
F 2 "Capacitor_SMD:C_0805_2012Metric" H 6288 2650 30  0001 C CNN
F 3 "" H 6250 2800 60  0000 C CNN
F 4 "885012107014" H 0   0   50  0001 C CNN "MFN"
	1    6250 2800
	-1   0    0    1   
$EndComp
$Comp
L power:GND #PWR0239
U 1 1 596ED512
P 6250 2950
F 0 "#PWR0239" H 6250 2700 50  0001 C CNN
F 1 "GND" H 6250 2800 50  0000 C CNN
F 2 "" H 6250 2950 60  0000 C CNN
F 3 "" H 6250 2950 60  0000 C CNN
	1    6250 2950
	1    0    0    -1  
$EndComp
Wire Wire Line
	6250 2450 6250 2650
Connection ~ 5700 2450
$Comp
L fmcw-rescue:Via-fmcw3-rescue F1
U 1 1 597038AD
P 1150 4050
F 0 "F1" H 1068 4297 60  0000 C CNN
F 1 "Via" H 1068 4191 60  0000 C CNN
F 2 "fmcw:RF_via" H 1150 4050 60  0001 C CNN
F 3 "" H 1150 4050 60  0001 C CNN
	1    1150 4050
	1    0    0    -1  
$EndComp
$Comp
L fmcw-rescue:Via-fmcw3-rescue F2
U 1 1 5970394E
P 1900 4050
F 0 "F2" H 1819 4297 60  0000 C CNN
F 1 "Via" H 1819 4191 60  0000 C CNN
F 2 "fmcw:RF_via" H 1900 4050 60  0001 C CNN
F 3 "" H 1900 4050 60  0001 C CNN
	1    1900 4050
	-1   0    0    -1  
$EndComp
$Comp
L power:GND #PWR0240
U 1 1 59703BAC
P 2100 4250
F 0 "#PWR0240" H 2100 4000 50  0001 C CNN
F 1 "GND" H 2100 4100 50  0000 C CNN
F 2 "" H 2100 4250 60  0000 C CNN
F 3 "" H 2100 4250 60  0000 C CNN
	1    2100 4250
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0241
U 1 1 59703C1B
P 950 4250
F 0 "#PWR0241" H 950 4000 50  0001 C CNN
F 1 "GND" H 950 4100 50  0000 C CNN
F 2 "" H 950 4250 60  0000 C CNN
F 3 "" H 950 4250 60  0000 C CNN
	1    950  4250
	1    0    0    -1  
$EndComp
Wire Wire Line
	5150 5200 5150 5300
Connection ~ 5250 5300
Wire Wire Line
	2600 4500 2600 4550
Wire Wire Line
	4450 2450 4750 2450
Wire Wire Line
	8400 4000 8400 4100
Wire Wire Line
	8400 3050 8400 3150
Wire Wire Line
	8400 3450 8600 3450
Wire Wire Line
	8400 3550 8600 3550
Wire Wire Line
	6050 5300 6050 5400
Wire Wire Line
	5950 5300 6050 5300
Wire Wire Line
	5850 5300 5950 5300
Wire Wire Line
	5750 5300 5850 5300
Wire Wire Line
	5650 5300 5750 5300
Wire Wire Line
	5550 5300 5650 5300
Wire Wire Line
	5450 5300 5550 5300
Wire Wire Line
	5350 5300 5450 5300
Wire Wire Line
	2600 5450 2600 5500
Wire Wire Line
	2600 6450 2600 6500
Wire Wire Line
	8400 5600 8400 5700
Wire Wire Line
	8400 4650 8400 4750
Wire Wire Line
	8400 5050 8600 5050
Wire Wire Line
	8400 5150 8600 5150
Wire Wire Line
	5050 2450 5500 2450
Wire Wire Line
	5600 2450 5700 2450
Wire Wire Line
	5500 2450 5600 2450
Wire Wire Line
	4150 2450 4450 2450
Wire Wire Line
	3800 2450 4150 2450
Wire Wire Line
	6950 5150 6950 5200
Wire Wire Line
	4750 2450 5050 2450
Wire Wire Line
	5700 2450 6250 2450
Wire Wire Line
	5250 5300 5350 5300
Wire Wire Line
	3150 2200 3500 2200
Wire Wire Line
	3800 2200 4150 2200
Wire Wire Line
	2200 4050 2100 4050
Connection ~ 2100 4050
$EndSCHEMATC
