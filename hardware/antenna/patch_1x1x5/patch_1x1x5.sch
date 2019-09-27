EESchema Schematic File Version 5
LIBS:patch_1x1x5-cache
EELAYER 29 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 1 1
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
L power:GND #PWR0101
U 1 1 5CB14A11
P 5650 4400
F 0 "#PWR0101" H 5650 4150 50  0001 C CNN
F 1 "GND" H 5655 4227 50  0000 C CNN
F 2 "" H 5650 4400 50  0001 C CNN
F 3 "" H 5650 4400 50  0001 C CNN
	1    5650 4400
	1    0    0    -1  
$EndComp
Wire Wire Line
	5650 4400 5650 4300
$Comp
L Device:Antenna_Chip AE1
U 1 1 5CB15CD2
P 5550 4200
F 0 "AE1" H 5730 4327 50  0000 L CNN
F 1 "Antenna_Chip" H 5730 4236 50  0000 L CNN
F 2 "antennas:patch_1x5" H 5450 4375 50  0001 C CNN
F 3 "~" H 5450 4375 50  0001 C CNN
	1    5550 4200
	1    0    0    -1  
$EndComp
$Comp
L power:LINE #PWR0102
U 1 1 5CB17720
P 5250 4300
F 0 "#PWR0102" H 5250 4150 50  0001 C CNN
F 1 "LINE" H 5267 4473 50  0000 C CNN
F 2 "" H 5250 4300 50  0001 C CNN
F 3 "" H 5250 4300 50  0001 C CNN
	1    5250 4300
	1    0    0    -1  
$EndComp
Wire Wire Line
	5250 4300 5450 4300
$EndSCHEMATC
