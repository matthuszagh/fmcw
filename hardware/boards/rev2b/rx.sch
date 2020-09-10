EESchema Schematic File Version 4
EELAYER 30 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 9 11
Title "FMCW"
Date ""
Rev "rev2"
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
Connection ~ 3850 3100
Connection ~ 2750 2700
Connection ~ 4700 2700
Connection ~ 4050 3100
Connection ~ 4350 2700
Connection ~ 6800 4200
Connection ~ 6800 3150
Connection ~ 6700 3150
Connection ~ 6700 3650
Connection ~ 6950 3150
Connection ~ 8050 2600
Connection ~ 3850 3950
Connection ~ 3850 2700
Connection ~ 7850 3950
Connection ~ 4700 2950
Wire Wire Line
	2450 2700 2750 2700
Wire Wire Line
	2750 2700 3000 2700
Wire Wire Line
	2750 2750 2750 2700
Wire Wire Line
	2750 3100 2750 3050
Wire Wire Line
	3300 2700 3850 2700
Wire Wire Line
	3300 3950 3150 3950
Wire Wire Line
	3600 3950 3850 3950
Wire Wire Line
	3850 2700 3850 3100
Wire Wire Line
	3850 3100 3850 3350
Wire Wire Line
	3850 3100 4050 3100
Wire Wire Line
	3850 3650 3850 3950
Wire Wire Line
	3850 3950 4250 3950
Wire Wire Line
	4050 3100 4300 3100
Wire Wire Line
	4350 2700 3850 2700
Wire Wire Line
	4550 2950 4550 3750
Wire Wire Line
	4550 2950 4700 2950
Wire Wire Line
	4550 4150 4550 4250
Wire Wire Line
	4650 3550 4650 3750
Wire Wire Line
	4700 2700 4350 2700
Wire Wire Line
	4700 2700 5150 2700
Wire Wire Line
	4700 2950 4700 2700
Wire Wire Line
	4850 3550 4650 3550
Wire Wire Line
	4850 3950 5400 3950
Wire Wire Line
	5150 2700 5150 2750
Wire Wire Line
	5150 3100 5150 3050
Wire Wire Line
	5700 3950 6400 3950
Wire Wire Line
	6250 3150 6250 3250
Wire Wire Line
	6250 3600 6250 3550
Wire Wire Line
	6700 3150 6250 3150
Wire Wire Line
	6700 3150 6700 3250
Wire Wire Line
	6700 3550 6700 3650
Wire Wire Line
	6700 4150 6700 4200
Wire Wire Line
	6700 4200 6800 4200
Wire Wire Line
	6800 3150 6700 3150
Wire Wire Line
	6800 3150 6950 3150
Wire Wire Line
	6800 3250 6800 3150
Wire Wire Line
	6800 3550 6800 3650
Wire Wire Line
	6800 4150 6800 4200
Wire Wire Line
	6800 4250 6800 4200
Wire Wire Line
	7000 3950 7850 3950
Wire Wire Line
	7200 2600 7200 3150
Wire Wire Line
	7200 2600 7550 2600
Wire Wire Line
	7200 3150 6950 3150
Wire Wire Line
	7850 2600 8050 2600
Wire Wire Line
	7850 3950 8950 3950
Wire Wire Line
	7850 4050 7850 3950
Wire Wire Line
	8050 2650 8050 2600
Wire Wire Line
	8050 3000 8050 2950
Wire Wire Line
	8300 2600 8050 2600
Wire Wire Line
	9150 4250 9150 4150
Text Notes 1550 2850 0    50   Italic 0
65 (55) mA
Text Notes 4900 4800 0    50   ~ 0
Gain: 11 dB\nNF: 5.5 dB\nIP1dB: -3.5 dBm
Text Notes 5700 2200 0    50   ~ 0
Gain: 24 dB\nIP1dB: -16.5 dBm
Text Notes 6500 4800 0    50   ~ 0
Gain: 13 dB\nNF: 1.0 dB\nIP1dB: -4 dBm
Text Notes 8700 2850 0    50   Italic 0
15 (10) mA
Text HLabel 2450 2700 0    60   Input ~ 0
3V0
Text HLabel 3150 3950 0    60   Output ~ 0
RF_OUT
Text HLabel 8300 2600 2    60   Input ~ 0
3V0
$Comp
L power:PWR_FLAG #FLG011
U 1 1 5CF2FC64
P 4350 2700
AR Path="/59396B97/5CF2FC64" Ref="#FLG011"  Part="1" 
AR Path="/593D90BA/5CF2FC64" Ref="#FLG014"  Part="1" 
F 0 "#FLG014" H 4350 2775 50  0001 C CNN
F 1 "PWR_FLAG" H 4350 2874 50  0000 C CNN
F 2 "" H 4350 2700 50  0001 C CNN
F 3 "~" H 4350 2700 50  0001 C CNN
	1    4350 2700
	1    0    0    -1  
$EndComp
$Comp
L power:PWR_FLAG #FLG012
U 1 1 5CF3D956
P 6700 3650
AR Path="/59396B97/5CF3D956" Ref="#FLG012"  Part="1" 
AR Path="/593D90BA/5CF3D956" Ref="#FLG015"  Part="1" 
F 0 "#FLG015" H 6700 3725 50  0001 C CNN
F 1 "PWR_FLAG" V 6800 3700 50  0000 L CNN
F 2 "" H 6700 3650 50  0001 C CNN
F 3 "~" H 6700 3650 50  0001 C CNN
	1    6700 3650
	0    -1   -1   0   
$EndComp
$Comp
L power:PWR_FLAG #FLG013
U 1 1 5CF2FCC1
P 6950 3150
AR Path="/59396B97/5CF2FCC1" Ref="#FLG013"  Part="1" 
AR Path="/593D90BA/5CF2FCC1" Ref="#FLG016"  Part="1" 
F 0 "#FLG016" H 6950 3225 50  0001 C CNN
F 1 "PWR_FLAG" H 6950 3324 50  0000 C CNN
F 2 "" H 6950 3150 50  0001 C CNN
F 3 "~" H 6950 3150 50  0001 C CNN
	1    6950 3150
	1    0    0    -1  
$EndComp
$Comp
L Device:L L1
U 1 1 593BD8E8
P 3850 3500
AR Path="/59396B97/593BD8E8" Ref="L1"  Part="1" 
AR Path="/593D90BA/593BD8E8" Ref="L3"  Part="1" 
F 0 "L3" H 3928 3454 50  0000 L CNN
F 1 "LQW15AN9N9J80D" H 3928 3545 50  0000 L CNN
F 2 "fmcw_v5:RF_Bypass_C_0402_1005Metric" H 3850 3500 60  0001 C CNN
F 3 "https://www.mouser.com/datasheet/2/281/JELF243A-0100-1380931.pdf" H 3850 3500 60  0001 C CNN
F 4 "LQW15AN9N9J80D" H 0   -250 50  0001 C CNN "MFN"
	1    3850 3500
	-1   0    0    1   
$EndComp
$Comp
L Device:L L2
U 1 1 593BC695
P 6700 3400
AR Path="/59396B97/593BC695" Ref="L2"  Part="1" 
AR Path="/593D90BA/593BC695" Ref="L4"  Part="1" 
F 0 "L4" H 6753 3354 50  0000 L CNN
F 1 "0.6n" H 6753 3445 50  0000 L CNN
F 2 "Inductor_SMD:L_0402_1005Metric" H 6700 3400 60  0001 C CNN
F 3 "" H 6700 3400 60  0000 C CNN
F 4 "MLG1005S0N6CT000" H -1450 100 50  0001 C CNN "MFN"
	1    6700 3400
	-1   0    0    1   
$EndComp
$Comp
L power:GND #PWR0149
U 1 1 5C430750
P 2750 3100
AR Path="/59396B97/5C430750" Ref="#PWR0149"  Part="1" 
AR Path="/593D90BA/5C430750" Ref="#PWR0163"  Part="1" 
F 0 "#PWR0163" H 2750 2850 50  0001 C CNN
F 1 "GND" H 2755 2927 50  0000 C CNN
F 2 "" H 2750 3100 50  0001 C CNN
F 3 "" H 2750 3100 50  0001 C CNN
	1    2750 3100
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0151
U 1 1 593BDABD
P 4050 3400
AR Path="/59396B97/593BDABD" Ref="#PWR0151"  Part="1" 
AR Path="/593D90BA/593BDABD" Ref="#PWR0165"  Part="1" 
F 0 "#PWR0165" H 4050 3150 50  0001 C CNN
F 1 "GND" H 4050 3250 50  0000 C CNN
F 2 "" H 4050 3400 60  0000 C CNN
F 3 "" H 4050 3400 60  0000 C CNN
	1    4050 3400
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0152
U 1 1 5976305E
P 4300 3400
AR Path="/59396B97/5976305E" Ref="#PWR0152"  Part="1" 
AR Path="/593D90BA/5976305E" Ref="#PWR0166"  Part="1" 
F 0 "#PWR0166" H 4300 3150 50  0001 C CNN
F 1 "GND" H 4300 3250 50  0000 C CNN
F 2 "" H 4300 3400 60  0000 C CNN
F 3 "" H 4300 3400 60  0000 C CNN
	1    4300 3400
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0153
U 1 1 593BD727
P 4550 4300
AR Path="/59396B97/593BD727" Ref="#PWR0153"  Part="1" 
AR Path="/593D90BA/593BD727" Ref="#PWR0167"  Part="1" 
F 0 "#PWR0167" H 4550 4050 50  0001 C CNN
F 1 "GND" H 4550 4150 50  0000 C CNN
F 2 "" H 4550 4300 60  0000 C CNN
F 3 "" H 4550 4300 60  0000 C CNN
	1    4550 4300
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0154
U 1 1 59761E7D
P 4700 3250
AR Path="/59396B97/59761E7D" Ref="#PWR0154"  Part="1" 
AR Path="/593D90BA/59761E7D" Ref="#PWR0168"  Part="1" 
F 0 "#PWR0168" H 4700 3000 50  0001 C CNN
F 1 "GND" H 4700 3100 50  0000 C CNN
F 2 "" H 4700 3250 60  0000 C CNN
F 3 "" H 4700 3250 60  0000 C CNN
	1    4700 3250
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0155
U 1 1 5C429467
P 4850 3550
AR Path="/59396B97/5C429467" Ref="#PWR0155"  Part="1" 
AR Path="/593D90BA/5C429467" Ref="#PWR0169"  Part="1" 
F 0 "#PWR0169" H 4850 3300 50  0001 C CNN
F 1 "GND" H 4850 3400 50  0000 C CNN
F 2 "" H 4850 3550 60  0000 C CNN
F 3 "" H 4850 3550 60  0000 C CNN
	1    4850 3550
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0170
U 1 1 59751D9B
P 5150 3100
AR Path="/593D90BA/59751D9B" Ref="#PWR0170"  Part="1" 
AR Path="/59396B97/59751D9B" Ref="#PWR0156"  Part="1" 
F 0 "#PWR0170" H 5150 2850 50  0001 C CNN
F 1 "GND" H 5150 2950 50  0000 C CNN
F 2 "" H 5150 3100 60  0000 C CNN
F 3 "" H 5150 3100 60  0000 C CNN
	1    5150 3100
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0157
U 1 1 593BC7DB
P 6250 3600
AR Path="/59396B97/593BC7DB" Ref="#PWR0157"  Part="1" 
AR Path="/593D90BA/593BC7DB" Ref="#PWR0171"  Part="1" 
F 0 "#PWR0171" H 6250 3350 50  0001 C CNN
F 1 "GND" H 6250 3450 50  0000 C CNN
F 2 "" H 6250 3600 60  0000 C CNN
F 3 "" H 6250 3600 60  0000 C CNN
	1    6250 3600
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0158
U 1 1 593BC25F
P 6800 4250
AR Path="/59396B97/593BC25F" Ref="#PWR0158"  Part="1" 
AR Path="/593D90BA/593BC25F" Ref="#PWR0172"  Part="1" 
F 0 "#PWR0172" H 6800 4000 50  0001 C CNN
F 1 "GND" H 6800 4100 50  0000 C CNN
F 2 "" H 6800 4250 60  0000 C CNN
F 3 "" H 6800 4250 60  0000 C CNN
	1    6800 4250
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0159
U 1 1 593BCF37
P 7850 4350
AR Path="/59396B97/593BCF37" Ref="#PWR0159"  Part="1" 
AR Path="/593D90BA/593BCF37" Ref="#PWR0173"  Part="1" 
F 0 "#PWR0173" H 7850 4100 50  0001 C CNN
F 1 "GND" H 7850 4200 50  0000 C CNN
F 2 "" H 7850 4350 60  0000 C CNN
F 3 "" H 7850 4350 60  0000 C CNN
	1    7850 4350
	1    0    0    -1  
$EndComp
$Comp
L power:GND #PWR0161
U 1 1 59752CE4
P 8050 3000
AR Path="/59396B97/59752CE4" Ref="#PWR0161"  Part="1" 
AR Path="/593D90BA/59752CE4" Ref="#PWR0175"  Part="1" 
F 0 "#PWR0175" H 8050 2750 50  0001 C CNN
F 1 "GND" H 8050 2850 50  0000 C CNN
F 2 "" H 8050 3000 60  0000 C CNN
F 3 "" H 8050 3000 60  0000 C CNN
	1    8050 3000
	-1   0    0    -1  
$EndComp
$Comp
L power:GND #PWR0162
U 1 1 593BCD59
P 9150 4250
AR Path="/59396B97/593BCD59" Ref="#PWR0162"  Part="1" 
AR Path="/593D90BA/593BCD59" Ref="#PWR0176"  Part="1" 
F 0 "#PWR0176" H 9150 4000 50  0001 C CNN
F 1 "GND" H 9150 4100 50  0000 C CNN
F 2 "" H 9150 4250 60  0000 C CNN
F 3 "" H 9150 4250 60  0000 C CNN
	1    9150 4250
	1    0    0    -1  
$EndComp
$Comp
L Device:R R49
U 1 1 593BC396
P 6800 3400
AR Path="/59396B97/593BC396" Ref="R49"  Part="1" 
AR Path="/593D90BA/593BC396" Ref="R50"  Part="1" 
F 0 "R50" H 6730 3354 50  0000 R CNN
F 1 "100" H 6730 3445 50  0000 R CNN
F 2 "Resistor_SMD:R_0402_1005Metric" V 6730 3400 30  0001 C CNN
F 3 "" H 6800 3400 30  0000 C CNN
F 4 "" H 1050 -250 50  0001 C CNN "MFN"
	1    6800 3400
	-1   0    0    1   
$EndComp
$Comp
L Device:C C145
U 1 1 5C42DC20
P 2750 2900
AR Path="/59396B97/5C42DC20" Ref="C145"  Part="1" 
AR Path="/593D90BA/5C42DC20" Ref="C157"  Part="1" 
F 0 "C157" H 2865 2946 50  0000 L CNN
F 1 "DNP" H 2865 2855 50  0000 L CNN
F 2 "Capacitor_SMD:C_0805_2012Metric" H 2788 2750 30  0001 C CNN
F 3 "" H 2750 2900 60  0000 C CNN
F 4 "" H -5850 -550 50  0001 C CNN "MFN"
	1    2750 2900
	1    0    0    -1  
$EndComp
$Comp
L Device:C C147
U 1 1 593BDF98
P 3450 3950
AR Path="/59396B97/593BDF98" Ref="C147"  Part="1" 
AR Path="/593D90BA/593BDF98" Ref="C159"  Part="1" 
F 0 "C159" V 3198 3950 50  0000 C CNN
F 1 "18p" V 3289 3950 50  0000 C CNN
F 2 "fmcw_v5:RF_C_0201_0603Metric" H 3488 3800 30  0001 C CNN
F 3 "" H 3450 3950 60  0000 C CNN
F 4 "GJM0335C1E180GB01D" H 0   -100 50  0001 C CNN "MFN"
	1    3450 3950
	0    1    1    0   
$EndComp
$Comp
L Device:C C148
U 1 1 593BDA25
P 4050 3250
AR Path="/59396B97/593BDA25" Ref="C148"  Part="1" 
AR Path="/593D90BA/593BDA25" Ref="C160"  Part="1" 
F 0 "C160" H 4075 3350 50  0000 L CNN
F 1 "10p" H 4075 3150 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 4088 3100 30  0001 C CNN
F 3 "" H 4050 3250 60  0000 C CNN
F 4 "" H 0   0   50  0001 C CNN "MFN"
	1    4050 3250
	1    0    0    -1  
$EndComp
$Comp
L Device:C C149
U 1 1 59762FC5
P 4300 3250
AR Path="/59396B97/59762FC5" Ref="C149"  Part="1" 
AR Path="/593D90BA/59762FC5" Ref="C161"  Part="1" 
F 0 "C161" H 4325 3350 50  0000 L CNN
F 1 "10n" H 4325 3150 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 4338 3100 30  0001 C CNN
F 3 "" H 4300 3250 60  0000 C CNN
F 4 "" H 0   0   50  0001 C CNN "MFN"
	1    4300 3250
	1    0    0    -1  
$EndComp
$Comp
L Device:C C150
U 1 1 59761DBE
P 4700 3100
AR Path="/59396B97/59761DBE" Ref="C150"  Part="1" 
AR Path="/593D90BA/59761DBE" Ref="C162"  Part="1" 
F 0 "C162" H 4725 3200 50  0000 L CNN
F 1 "100p" H 4725 3000 50  0000 L CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 4738 2950 30  0001 C CNN
F 3 "" H 4700 3100 60  0000 C CNN
F 4 "" H 0   0   50  0001 C CNN "MFN"
	1    4700 3100
	1    0    0    -1  
$EndComp
$Comp
L Device:C C163
U 1 1 59751D28
P 5150 2900
AR Path="/593D90BA/59751D28" Ref="C163"  Part="1" 
AR Path="/59396B97/59751D28" Ref="C151"  Part="1" 
F 0 "C163" H 5175 3000 50  0000 L CNN
F 1 "DNP" H 5175 2800 50  0000 L CNN
F 2 "Capacitor_SMD:C_0603_1608Metric" H 5188 2750 30  0001 C CNN
F 3 "" H 5150 2900 60  0000 C CNN
	1    5150 2900
	1    0    0    -1  
$EndComp
$Comp
L Device:C C152
U 1 1 593BD4EF
P 5550 3950
AR Path="/59396B97/593BD4EF" Ref="C152"  Part="1" 
AR Path="/593D90BA/593BD4EF" Ref="C164"  Part="1" 
F 0 "C164" V 5298 3950 50  0000 C CNN
F 1 "18p" V 5389 3950 50  0000 C CNN
F 2 "fmcw_v5:RF_C_0201_0603Metric" H 5588 3800 30  0001 C CNN
F 3 "" H 5550 3950 60  0000 C CNN
F 4 "GJM0335C1E180GB01D" H 0   0   50  0001 C CNN "MFN"
	1    5550 3950
	0    1    1    0   
$EndComp
$Comp
L Device:C C153
U 1 1 593BC767
P 6250 3400
AR Path="/59396B97/593BC767" Ref="C153"  Part="1" 
AR Path="/593D90BA/593BC767" Ref="C165"  Part="1" 
F 0 "C165" H 6135 3446 50  0000 R CNN
F 1 "100n" H 6135 3355 50  0000 R CNN
F 2 "Capacitor_SMD:C_0402_1005Metric" H 6288 3250 30  0001 C CNN
F 3 "" H 6250 3400 60  0000 C CNN
F 4 "" H -2350 -50 50  0001 C CNN "MFN"
	1    6250 3400
	1    0    0    -1  
$EndComp
$Comp
L Device:C C154
U 1 1 593BCEBC
P 7850 4200
AR Path="/59396B97/593BCEBC" Ref="C154"  Part="1" 
AR Path="/593D90BA/593BCEBC" Ref="C166"  Part="1" 
F 0 "C166" H 7875 4300 50  0000 L CNN
F 1 "0.5p" H 7875 4100 50  0000 L CNN
F 2 "fmcw_v5:RF_C_0201_0603Metric" H 7888 4050 30  0001 C CNN
F 3 "" H 7850 4200 60  0000 C CNN
F 4 "GJM0335C1ER50BB01D" H -600 0   50  0001 C CNN "MFN"
	1    7850 4200
	1    0    0    -1  
$EndComp
$Comp
L Device:C C156
U 1 1 5C42C3BD
P 8050 2800
AR Path="/59396B97/5C42C3BD" Ref="C156"  Part="1" 
AR Path="/593D90BA/5C42C3BD" Ref="C168"  Part="1" 
F 0 "C168" H 8165 2846 50  0000 L CNN
F 1 "DNP" H 8165 2755 50  0000 L CNN
F 2 "Capacitor_SMD:C_0805_2012Metric" H 8088 2650 30  0001 C CNN
F 3 "" H 8050 2800 60  0000 C CNN
F 4 "" H -550 -650 50  0001 C CNN "MFN"
	1    8050 2800
	1    0    0    -1  
$EndComp
$Comp
L Device:Ferrite_Bead FB13
U 1 1 59751767
P 3150 2700
AR Path="/593D90BA/59751767" Ref="FB13"  Part="1" 
AR Path="/59396B97/59751767" Ref="FB11"  Part="1" 
F 0 "FB13" V 2876 2700 50  0000 C CNN
F 1 "BLM18PG181SH1D" V 2967 2700 50  0000 C CNN
F 2 "Inductor_SMD:L_0603_1608Metric" H 3150 2700 60  0001 C CNN
F 3 "" H 3150 2700 60  0000 C CNN
F 4 "BLM18PG181SH1D" H -150 -50 50  0001 C CNN "MFN"
	1    3150 2700
	0    1    1    0   
$EndComp
$Comp
L Device:Ferrite_Bead FB14
U 1 1 597527FA
P 7700 2600
AR Path="/593D90BA/597527FA" Ref="FB14"  Part="1" 
AR Path="/59396B97/597527FA" Ref="FB12"  Part="1" 
F 0 "FB14" V 7426 2600 50  0000 C CNN
F 1 "BLM18PG181SH1D" V 7517 2600 50  0000 C CNN
F 2 "Inductor_SMD:L_0603_1608Metric" H 7700 2600 60  0001 C CNN
F 3 "" H 7700 2600 60  0000 C CNN
F 4 "BLM18PG181SH1D" H -450 0   50  0001 C CNN "MFN"
	1    7700 2600
	0    -1   1    0   
$EndComp
$Comp
L Connector:Conn_Coaxial J4
U 1 1 593BCCCA
P 9150 3950
AR Path="/59396B97/593BCCCA" Ref="J4"  Part="1" 
AR Path="/593D90BA/593BCCCA" Ref="J5"  Part="1" 
F 0 "J5" H 9300 3950 60  0000 C CNN
F 1 "SMA" H 9150 4100 60  0000 C CNN
F 2 "fmcw_v5:BU-1420701851_SMA" H 9150 3950 60  0001 C CNN
F 3 "" H 9150 3950 60  0000 C CNN
F 4 "901-10512-3" H 9150 3950 50  0001 C CNN "MFN"
	1    9150 3950
	1    0    0    -1  
$EndComp
$Comp
L RF_Amplifier:SKY65404 U23
U 1 1 593BC199
P 6800 3950
AR Path="/59396B97/593BC199" Ref="U23"  Part="1" 
AR Path="/593D90BA/593BC199" Ref="U25"  Part="1" 
F 0 "U25" H 6650 4250 60  0000 R CNN
F 1 "SKY65404" H 6650 4150 60  0000 R CNN
F 2 "RF:Skyworks_SKY65404-31" H 6750 3950 60  0001 C CNN
F 3 "" H 6750 3950 60  0001 C CNN
F 4 "SKY65404-31" H 0   150 50  0001 C CNN "MFN"
	1    6800 3950
	-1   0    0    -1  
$EndComp
$Comp
L fmcw:TRF37A73 U22
U 1 1 597605DF
P 4650 3950
AR Path="/59396B97/597605DF" Ref="U22"  Part="1" 
AR Path="/593D90BA/597605DF" Ref="U24"  Part="1" 
AR Path="/597605DF" Ref="U?"  Part="1" 
F 0 "U24" H 4950 3800 60  0000 L CNN
F 1 "TRF37A73" H 4950 3700 60  0000 L CNN
F 2 "Package_SON:WSON-8-1EP_2x2mm_P0.5mm_EP0.9x1.6mm_ThermalVias" H 4450 3900 60  0001 C CNN
F 3 "" H 4450 3900 60  0000 C CNN
F 4 "TRF37A73IDSGR" H 100 -150 50  0001 C CNN "MFN"
	1    4650 3950
	-1   0    0    -1  
$EndComp
Wire Wire Line
	4850 4050 4850 4250
Wire Wire Line
	4850 4250 4550 4250
Connection ~ 4550 4250
Wire Wire Line
	4550 4250 4550 4300
$EndSCHEMATC
