`default_nettype none

`include "fft_r22sdf_bf.v"
`include "fft_r22sdf_wm.v"
`include "ram_single_18k.v"

/** Radix-2^2 SDF FFT implementation.
 *
 * N must be a power of 4. Currently, any power of 4 <= 1024 is
 * supported, but this could easily be extended to greater lengths.
 */

module fft_r22sdf #(
   parameter N              = 1024, /* FFT length */
   parameter INPUT_WIDTH    = 14,
   parameter TWIDDLE_WIDTH  = 10,
   // +1 comes from complex multiply, which is really 2 multiplies.
   parameter OUTPUT_WIDTH   = 25   /* ceil(log_2(N)) + INPUT_WIDTH + 1 */
) (
   input wire                           clk_i,
   input wire                           clk_3x_i,
   input wire                           rst_n,
   output reg                           sync_o, // output data ready
   // freq bin index of output data. only valid if `sync_o == 1'b1'
   output wire [N_LOG2-1:0]             data_ctr_o,
   input wire signed [INPUT_WIDTH-1:0]  data_re_i,
   input wire signed [INPUT_WIDTH-1:0]  data_im_i,
   output reg signed [OUTPUT_WIDTH-1:0] data_re_o,
   output reg signed [OUTPUT_WIDTH-1:0] data_im_o
);

   localparam N_LOG2 = $clog2(N);
   localparam N_STAGES = N_LOG2/2;

   // non bit-reversed output data count
   reg [N_LOG2-1:0]                     data_ctr_bit_nrml;

   // twiddle factors
   wire signed [TWIDDLE_WIDTH-1:0]      w_s0_re;
   ram_single_18k #(
      .INIT_00(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_01(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_02(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_03(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_04(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_05(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_06(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_07(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_08(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_09(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_0A(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_0B(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_0C(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_0D(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_0E(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_0F(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_10(256'h01F601F701F801F901FA01FB01FB01FC01FD01FD01FE01FE01FE01FE01FE01FF),
      .INIT_11(256'h01DA01DC01DE01E101E301E501E701E801EA01EC01EE01EF01F101F201F301F5),
      .INIT_12(256'h01AC01AF01B301B601B901BC01BF01C201C501C801CB01CD01D001D301D501D8),
      .INIT_13(256'h016D01720176017A017E01820187018B018E01920196019A019E01A101A501A8),
      .INIT_14(256'h01210126012B01300135013A013F01440148014D01520157015B016001640169),
      .INIT_15(256'h00C900CF00D400DA00E000E500EB00F000F600FB01010106010C01110116011B),
      .INIT_16(256'h0069006F0076007C00820088008E0094009A00A000A600AC00B200B700BD00C3),
      .INIT_17(256'h0006000C00120019001F0025002B00320038003E0044004A00510057005D0063),
      .INIT_18(256'h03A203A803AE03B403BB03C103C703CD03D403DA03E003E603ED03F303F90000),
      .INIT_19(256'h03410347034D03530359035F0365036B03710377037D03830389038F0395039C),
      .INIT_1A(256'h02E802EE02F302F802FE03030309030E03140319031F0325032A03300336033C),
      .INIT_1B(256'h029A029E02A302A802AC02B102B602BB02C002C502C902CF02D402D902DE02E3),
      .INIT_1C(256'h0259025D026102640268026C027002740278027C028002840288028D02910295),
      .INIT_1D(256'h0229022B022E0231023302360239023C023F024202450248024C024F02520256),
      .INIT_1E(256'h020B020C020D020F021002120214021602170219021B021D0220022202240226),
      .INIT_1F(256'h0200020002000200020002010201020202030203020402050206020702080209),
      .INIT_20(256'h01FC01FD01FD01FD01FD01FE01FE01FE01FE01FE01FE01FE01FE01FE01FE01FF),
      .INIT_21(256'h01F501F601F601F701F801F801F801F901F901FA01FA01FB01FB01FB01FC01FC),
      .INIT_22(256'h01E901EA01EB01EC01ED01EE01EE01EF01F001F101F101F201F301F301F401F5),
      .INIT_23(256'h01D901DA01DB01DC01DD01DE01E001E101E201E301E401E501E601E701E801E8),
      .INIT_24(256'h01C401C501C701C801C901CB01CC01CD01CF01D001D101D301D401D501D601D8),
      .INIT_25(256'h01AA01AC01AE01AF01B101B301B401B601B701B901BB01BC01BE01BF01C101C2),
      .INIT_26(256'h018C018E01900192019401960198019A019C019E019F01A101A301A501A701A8),
      .INIT_27(256'h016B016D016F0172017401760178017A017C017E01800182018401870189018B),
      .INIT_28(256'h01460148014B014D01500152015401570159015B015E01600162016401670169),
      .INIT_29(256'h011E0121012301260128012B012D0130013201350137013A013C013F01410144),
      .INIT_2A(256'h00F300F600F900FB00FE0101010401060109010C010E0111011401160119011B),
      .INIT_2B(256'h00C600C900CC00CF00D100D400D700DA00DD00E000E200E500E800EB00EE00F0),
      .INIT_2C(256'h0097009A009D00A000A300A600A900AC00AF00B200B400B700BA00BD00C000C3),
      .INIT_2D(256'h00660069006C006F007300760079007C007F008200850088008B008E00910094),
      .INIT_2E(256'h00350038003B003E004100440047004A004E005100540057005A005D00600063),
      .INIT_2F(256'h000300060009000C000F001200150019001C001F002200250028002B002E0032),
      .INIT_30(256'h01EB01EE01F001F201F401F601F801F901FA01FB01FC01FD01FE01FE01FE01FF),
      .INIT_31(256'h01AE01B301B701BC01C101C501C901CD01D101D501D901DC01E001E301E601E8),
      .INIT_32(256'h014B0152015901600167016D0174017A01800187018C01920198019E01A301A8),
      .INIT_33(256'h00CC00D400DD00E500EE00F600FE0106010E0116011E0126012D0135013C0144),
      .INIT_34(256'h003B0044004E0057006000690073007C0085008E009700A000A900B200BA00C3),
      .INIT_35(256'h03A503AE03B703C103CA03D403DD03E603F003F90003000C0015001F00280032),
      .INIT_36(256'h0316031F0327033003390341034A0353035C0365036E0377038003890392039C),
      .INIT_37(256'h029C02A302AA02B102B802C002C702CF02D602DE02E602EE02F602FE0306030E),
      .INIT_38(256'h02400245024A024F02540259025F0264026A02700276027C02820288028F0295),
      .INIT_39(256'h020B020D0210021202150217021A021D022102240228022B022F02330238023C),
      .INIT_3A(256'h0201020002000200020002000200020002010201020202030205020602080209),
      .INIT_3B(256'h02230220021C0219021602140211020F020D020B020902070206020402030202),
      .INIT_3C(256'h026E02680262025D02580252024D02480244023F023A02360232022E022A0226),
      .INIT_3D(256'h02DB02D402CC02C502BD02B602AF02A802A1029A0293028D02860280027A0274),
      .INIT_3E(256'h0362035903500347033E0336032D0325031C0314030B030302FB02F302EB02E3),
      .INIT_3F(256'h03F603ED03E303DA03D003C703BE03B403AB03A20399038F0386037D0374036B),
      // .INITFILE      ("roms/fft_r22sdf_rom_s0_re.hex"),
      .ADDRESS_WIDTH (N_LOG2),
      .DATA_WIDTH    (TWIDDLE_WIDTH)
   ) rom_w_s0_re (
      .clk    (clk_i),
      .en     (1'b1),
      .we     (1'b0),
      .addr   (stage1_ctr_wm),
      .data_o (w_s0_re)
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s0_im;
   ram_single_18k #(
      .INIT_00(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_01(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_02(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_03(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_04(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_05(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_06(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_07(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_08(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_09(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0A(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0B(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0C(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0D(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0E(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0F(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_10(256'h03A203A803AE03B403BB03C103C703CD03D403DA03E003E603ED03F303F90000),
      .INIT_11(256'h03410347034D03530359035F0365036B03710377037D03830389038F0395039C),
      .INIT_12(256'h02E802EE02F302F802FE03030309030E03140319031F0325032A03300336033C),
      .INIT_13(256'h029A029E02A302A802AC02B102B602BB02C002C502C902CF02D402D902DE02E3),
      .INIT_14(256'h0259025D026102640268026C027002740278027C028002840288028D02910295),
      .INIT_15(256'h0229022B022E0231023302360239023C023F024202450248024C024F02520256),
      .INIT_16(256'h020B020C020D020F021002120214021602170219021B021D0220022202240226),
      .INIT_17(256'h0200020002000200020002010201020202030203020402050206020702080209),
      .INIT_18(256'h0208020702060205020402030203020202010201020002000200020002000200),
      .INIT_19(256'h022402220220021D021B021902170216021402120210020F020D020C020B0209),
      .INIT_1A(256'h0252024F024C024802450242023F023C0239023602330231022E022B02290226),
      .INIT_1B(256'h0291028D028802840280027C027802740270026C026802640261025D02590256),
      .INIT_1C(256'h02DE02D902D402CF02C902C502C002BB02B602B102AC02A802A3029E029A0295),
      .INIT_1D(256'h03360330032A0325031F03190314030E0309030302FE02F802F302EE02E802E3),
      .INIT_1E(256'h0395038F03890383037D03770371036B0365035F03590353034D03470341033C),
      .INIT_1F(256'h03F903F303ED03E603E003DA03D403CD03C703C103BB03B403AE03A803A2039C),
      .INIT_20(256'h03D003D403D703DA03DD03E003E303E603EA03ED03F003F303F603F903FC0000),
      .INIT_21(256'h039F03A203A503A803AB03AE03B103B403B703BB03BE03C103C403C703CA03CD),
      .INIT_22(256'h036E037103740377037A037D0380038303860389038C038F039203950399039C),
      .INIT_23(256'h033E034103440347034A034D0350035303560359035C035F036203650368036B),
      .INIT_24(256'h0311031403160319031C031F032203250327032A032D0330033303360339033C),
      .INIT_25(256'h02E602E802EB02EE02F002F302F602F802FB02FE0300030303060309030B030E),
      .INIT_26(256'h02BD02C002C202C502C702C902CC02CF02D102D402D602D902DB02DE02E002E3),
      .INIT_27(256'h0298029A029C029E02A102A302A502A802AA02AC02AF02B102B302B602B802BB),
      .INIT_28(256'h02760278027A027C027E02800282028402860288028B028D028F029102930295),
      .INIT_29(256'h02580259025B025D025F02610262026402660268026A026C026E027002720274),
      .INIT_2A(256'h023D023F024002420244024502470248024A024C024D024F0251025202540256),
      .INIT_2B(256'h02280229022A022B022D022E022F0231023202330235023602380239023A023C),
      .INIT_2C(256'h0216021702180219021A021B021C021D021E0220022102220223022402250226),
      .INIT_2D(256'h020A020B020B020C020D020D020E020F02100210021102120213021402150216),
      .INIT_2E(256'h0202020302030203020402040205020502060206020702070208020802090209),
      .INIT_2F(256'h0200020002000200020002000200020002000200020102010201020102020202),
      .INIT_30(256'h0374037D0386038F039903A203AB03B403BE03C703D003DA03E303ED03F60000),
      .INIT_31(256'h02EB02F302FB0303030B0314031C0325032D0336033E0347035003590362036B),
      .INIT_32(256'h027A02800286028D0293029A02A102A802AF02B602BD02C502CC02D402DB02E3),
      .INIT_33(256'h022A022E02320236023A023F02440248024D02520258025D02620268026E0274),
      .INIT_34(256'h02030204020602070209020B020D020F0211021402160219021C022002230226),
      .INIT_35(256'h0208020602050203020202010201020002000200020002000200020002010202),
      .INIT_36(256'h02380233022F022B022802240221021D021A0217021502120210020D020B0209),
      .INIT_37(256'h028F02880282027C02760270026A0264025F02590254024F024A02450240023C),
      .INIT_38(256'h030602FE02F602EE02E602DE02D602CF02C702C002B802B102AA02A3029C0295),
      .INIT_39(256'h0392038903800377036E0365035C0353034A0341033903300327031F0316030E),
      .INIT_3A(256'h0028001F0015000C000303F903F003E603DD03D403CA03C103B703AE03A5039C),
      .INIT_3B(256'h00BA00B200A900A00097008E0085007C0073006900600057004E0044003B0032),
      .INIT_3C(256'h013C0135012D0126011E0116010E010600FE00F600EE00E500DD00D400CC00C3),
      .INIT_3D(256'h01A3019E01980192018C01870180017A0174016D0167016001590152014B0144),
      .INIT_3E(256'h01E601E301E001DC01D901D501D101CD01C901C501C101BC01B701B301AE01A8),
      .INIT_3F(256'h01FE01FE01FE01FD01FC01FB01FA01F901F801F601F401F201F001EE01EB01E8),
      // .INITFILE      ("roms/fft_r22sdf_rom_s0_im.hex"),
      .ADDRESS_WIDTH (N_LOG2),
      .DATA_WIDTH    (TWIDDLE_WIDTH)
   ) rom_w_s0_im (
      .clk    (clk_i),
      .en     (1'b1),
      .we     (1'b0),
      .addr   (stage1_ctr_wm),
      .data_o (w_s0_im)
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s1_re;
   ram_single_18k #(
      .INIT_00(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_01(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_02(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_03(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_04(256'h017A018B019A01A801B601C201CD01D801E101E801EF01F501F901FC01FE01FF),
      .INIT_05(256'h00190032004A0063007C009400AC00C300DA00F00106011B0130014401570169),
      .INIT_06(256'h02A802BB02CF02E302F8030E0325033C0353036B0383039C03B403CD03E60000),
      .INIT_07(256'h0200020202050209020F0216021D02260231023C024802560264027402840295),
      .INIT_08(256'h01DC01E101E501E801EC01EF01F201F501F701F901FB01FC01FD01FE01FE01FF),
      .INIT_09(256'h0172017A0182018B0192019A01A101A801AF01B601BC01C201C801CD01D301D8),
      .INIT_0A(256'h00CF00DA00E500F000FB01060111011B01260130013A0144014D015701600169),
      .INIT_0B(256'h000C001900250032003E004A00570063006F007C0088009400A000AC00B700C3),
      .INIT_0C(256'h00E50106012601440160017A019201A801BC01CD01DC01E801F201F901FD01FF),
      .INIT_0D(256'h02B102CF02EE030E033003530377039C03C103E6000C00320057007C00A000C3),
      .INIT_0E(256'h0219020F0207020202000200020302090212021D022B023C024F0264027C0295),
      .INIT_0F(256'h03DA03B4038F036B03470325030302E302C502A8028D0274025D024802360226),
      // .INITFILE      ("roms/fft_r22sdf_rom_s1_re.hex"),
      .ADDRESS_WIDTH (N_LOG2-1),
      .DATA_WIDTH    (TWIDDLE_WIDTH)
   ) rom_w_s1_re (
      .clk    (clk_i),
      .en     (1'b1),
      .we     (1'b0),
      .addr   (stage2_ctr_wm[N_LOG2-3:0]),
      .data_o (w_s1_re)
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s1_im;
   ram_single_18k #(
      .INIT_00(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_01(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_02(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_03(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_04(256'h02A802BB02CF02E302F8030E0325033C0353036B0383039C03B403CD03E60000),
      .INIT_05(256'h0200020202050209020F0216021D02260231023C024802560264027402840295),
      .INIT_06(256'h02840274026402560248023C02310226021D0216020F02090205020202000200),
      .INIT_07(256'h03E603CD03B4039C0383036B0353033C0325030E02F802E302CF02BB02A80295),
      .INIT_08(256'h03470353035F036B03770383038F039C03A803B403C103CD03DA03E603F30000),
      .INIT_09(256'h029E02A802B102BB02C502CF02D902E302EE02F80303030E031903250330033C),
      .INIT_0A(256'h022B02310236023C02420248024F0256025D0264026C0274027C0284028D0295),
      .INIT_0B(256'h02000200020102020203020502070209020C020F021202160219021D02220226),
      .INIT_0C(256'h02360248025D0274028D02A802C502E3030303250347036B038F03B403DA0000),
      .INIT_0D(256'h027C0264024F023C022B021D0212020902030200020002020207020F02190226),
      .INIT_0E(256'h00A0007C00570032000C03E603C1039C037703530330030E02EE02CF02B10295),
      .INIT_0F(256'h01FD01F901F201E801DC01CD01BC01A80192017A016001440126010600E500C3),
      // .INITFILE      ("roms/fft_r22sdf_rom_s1_im.hex"),
      .ADDRESS_WIDTH (N_LOG2-1),
      .DATA_WIDTH    (TWIDDLE_WIDTH)
   ) rom_w_s1_im (
      .clk    (clk_i),
      .en     (1'b1),
      .we     (1'b0),
      .addr   (stage2_ctr_wm[N_LOG2-3:0]),
      .data_o (w_s1_im)
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s2_re;
   ram_single_18k #(
      .INIT_00(256'h01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF01FF),
      .INIT_01(256'h020902260256029502E3033C039C0000006300C3011B016901A801D801F501FF),
      .INIT_02(256'h00320063009400C300F0011B01440169018B01A801C201D801E801F501FC01FF),
      .INIT_03(256'h036B02E30274022602020209023C0295030E039C003200C3014401A801E801FF),
      // .INITFILE      ("roms/fft_r22sdf_rom_s2_re.hex"),
      .ADDRESS_WIDTH (N_LOG2-2),
      .DATA_WIDTH    (TWIDDLE_WIDTH)
   ) rom_w_s2_re (
      .clk    (clk_i),
      .en     (1'b1),
      .we     (1'b0),
      .addr   (stage3_ctr_wm[N_LOG2-5:0]),
      .data_o (w_s2_re)
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s2_im;
   ram_single_18k #(
      .INIT_00(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_01(256'h039C033C02E302950256022602090200020902260256029502E3033C039C0000),
      .INIT_02(256'h0202020902160226023C02560274029502BB02E3030E033C036B039C03CD0000),
      .INIT_03(256'h01E801A8014400C30032039C030E0295023C020902020226027402E3036B0000),
      // .INITFILE      ("roms/fft_r22sdf_rom_s2_im.hex"),
      .ADDRESS_WIDTH (N_LOG2-2),
      .DATA_WIDTH    (TWIDDLE_WIDTH)
   ) rom_w_s2_im (
      .clk    (clk_i),
      .en     (1'b1),
      .we     (1'b0),
      .addr   (stage3_ctr_wm[N_LOG2-5:0]),
      .data_o (w_s2_im)
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s3_re;
   ram_single_18k #(
      .INIT_00(256'h0226029500C301FF00C3016901D801FF02950000016901FF01FF01FF01FF01FF),
      // .INITFILE      ("roms/fft_r22sdf_rom_s3_re.hex"),
      .ADDRESS_WIDTH (N_LOG2-3),
      .DATA_WIDTH    (TWIDDLE_WIDTH)
   ) rom_w_s3_re (
      .clk    (clk_i),
      .en     (1'b1),
      .we     (1'b0),
      .addr   (stage4_ctr_wm[N_LOG2-7:0]),
      .data_o (w_s3_re)
   );

   wire signed [TWIDDLE_WIDTH-1:0]      w_s3_im;
   ram_single_18k #(
      .INIT_00(256'h00C302950226000002260295033C000002950200029500000000000000000000),
      // .INITFILE      ("roms/fft_r22sdf_rom_s3_im.hex"),
      .ADDRESS_WIDTH (N_LOG2-3),
      .DATA_WIDTH    (TWIDDLE_WIDTH)
   ) rom_w_s3_im (
      .clk    (clk_i),
      .en     (1'b1),
      .we     (1'b0),
      .addr   (stage4_ctr_wm[N_LOG2-7:0]),
      .data_o (w_s3_im)
   );

   // stage counters
   // provide control logic to each stage
   reg [N_LOG2-1:0]                     stage0_ctr;
   wire [N_LOG2-1:0]                    stage1_ctr_wm;
   wire [N_LOG2-1:0]                    stage1_ctr;
   wire [N_LOG2-1:0]                    stage2_ctr_wm;
   wire [N_LOG2-1:0]                    stage2_ctr;
   wire [N_LOG2-1:0]                    stage3_ctr_wm;
   wire [N_LOG2-1:0]                    stage3_ctr;
   wire [N_LOG2-1:0]                    stage4_ctr_wm;
   wire [N_LOG2-1:0]                    stage4_ctr;

   // output data comes out in bit-reversed order
   genvar k;
   generate
      for (k=0; k<N_LOG2; k=k+1) begin
         assign data_ctr_o[k] = data_ctr_bit_nrml[N_LOG2-1-k];
      end
   endgenerate

   function [OUTPUT_WIDTH-1:0] sign_extend_input(input [INPUT_WIDTH-1:0] expr);
      sign_extend_input = (expr[INPUT_WIDTH-1] == 1'b1) ? {{OUTPUT_WIDTH-INPUT_WIDTH{1'b1}}, expr}
                      : {{OUTPUT_WIDTH-INPUT_WIDTH{1'b0}}, expr};
   endfunction

   // stage 0
   wire signed [OUTPUT_WIDTH-1:0] bf0_re;
   wire signed [OUTPUT_WIDTH-1:0] bf0_im;
   wire signed [OUTPUT_WIDTH-1:0] w0_re;
   wire signed [OUTPUT_WIDTH-1:0] w0_im;

   fft_r22sdf_bf #(
      .DATA_WIDTH (OUTPUT_WIDTH),
      .FFT_N      (N),
      .FFT_NLOG2  (N_LOG2),
      .STAGE      (0),
      .STAGES     (N_STAGES)
   ) stage0_bf (
      .clk_i  (clk_i),
      .rst_n  (rst_n),
      .cnt_i  (stage0_ctr),
      .cnt_o  (stage1_ctr_wm),
      .x_re_i (sign_extend_input(data_re_i)),
      .x_im_i (sign_extend_input(data_im_i)),
      .z_re_o (bf0_re),
      .z_im_o (bf0_im)
   );

   // stage 1
   wire signed [OUTPUT_WIDTH-1:0] bf1_re;
   wire signed [OUTPUT_WIDTH-1:0] bf1_im;
   wire signed [OUTPUT_WIDTH-1:0] w1_re;
   wire signed [OUTPUT_WIDTH-1:0] w1_im;

   generate
      if (N_STAGES > 1) begin
         fft_r22sdf_wm #(
            .DATA_WIDTH    (OUTPUT_WIDTH),
            .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
            .FFT_N         (N),
            .NLOG2         (N_LOG2)
         ) stage0_wm (
            .clk_i    (clk_i),
            .clk_3x_i (clk_3x_i),
            .ctr_i    (stage1_ctr_wm),
            .ctr_o    (stage1_ctr),
            .rst_n    (rst_n),
            .x_re_i   (bf0_re),
            .x_im_i   (bf0_im),
            .w_re_i   (w_s0_re),
            .w_im_i   (w_s0_im),
            .z_re_o   (w0_re),
            .z_im_o   (w0_im)
         );

         fft_r22sdf_bf #(
            .DATA_WIDTH (OUTPUT_WIDTH),
            .FFT_N      (N),
            .FFT_NLOG2  (N_LOG2),
            .STAGE      (1),
            .STAGES     (N_STAGES)
         ) stage1_bf (
            .clk_i  (clk_i),
            .rst_n  (rst_n),
            .cnt_i  (stage1_ctr),
            .cnt_o  (stage2_ctr_wm),
            .x_re_i (w0_re),
            .x_im_i (w0_im),
            .z_re_o (bf1_re),
            .z_im_o (bf1_im)
         );
      end // if (N > 1)
   endgenerate

   // stage 2
   wire signed [OUTPUT_WIDTH-1:0] bf2_re;
   wire signed [OUTPUT_WIDTH-1:0] bf2_im;
   wire signed [OUTPUT_WIDTH-1:0] w2_re;
   wire signed [OUTPUT_WIDTH-1:0] w2_im;

   generate
      if (N_STAGES > 2) begin
         fft_r22sdf_wm #(
            .DATA_WIDTH    (OUTPUT_WIDTH),
            .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
            .FFT_N         (N),
            .NLOG2         (N_LOG2)
         ) stage1_wm (
            .clk_i    (clk_i),
            .clk_3x_i (clk_3x_i),
            .ctr_i    (stage2_ctr_wm),
            .ctr_o    (stage2_ctr),
            .rst_n    (rst_n),
            .x_re_i   (bf1_re),
            .x_im_i   (bf1_im),
            .w_re_i   (w_s1_re),
            .w_im_i   (w_s1_im),
            .z_re_o   (w1_re),
            .z_im_o   (w1_im)
         );

         fft_r22sdf_bf #(
            .DATA_WIDTH (OUTPUT_WIDTH),
            .FFT_N      (N),
            .FFT_NLOG2  (N_LOG2),
            .STAGE      (2),
            .STAGES     (N_STAGES)
         ) stage2_bf (
            .clk_i  (clk_i),
            .rst_n  (rst_n),
            .cnt_i  (stage2_ctr),
            .cnt_o  (stage3_ctr_wm),
            .x_re_i (w1_re),
            .x_im_i (w1_im),
            .z_re_o (bf2_re),
            .z_im_o (bf2_im)
         );
      end // if (N > 2)
   endgenerate

   // stage 3
   wire signed [OUTPUT_WIDTH-1:0] bf3_re;
   wire signed [OUTPUT_WIDTH-1:0] bf3_im;
   wire signed [OUTPUT_WIDTH-1:0] w3_re;
   wire signed [OUTPUT_WIDTH-1:0] w3_im;

   generate
      if (N_STAGES > 3) begin
         fft_r22sdf_wm #(
            .DATA_WIDTH    (OUTPUT_WIDTH),
            .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
            .FFT_N         (N),
            .NLOG2         (N_LOG2)
         ) stage2_wm (
            .clk_i    (clk_i),
            .clk_3x_i (clk_3x_i),
            .ctr_i    (stage3_ctr_wm),
            .ctr_o    (stage3_ctr),
            .rst_n    (rst_n),
            .x_re_i   (bf2_re),
            .x_im_i   (bf2_im),
            .w_re_i   (w_s2_re),
            .w_im_i   (w_s2_im),
            .z_re_o   (w2_re),
            .z_im_o   (w2_im)
         );

         fft_r22sdf_bf #(
            .DATA_WIDTH (OUTPUT_WIDTH),
            .FFT_N      (N),
            .FFT_NLOG2  (N_LOG2),
            .STAGE      (3),
            .STAGES     (N_STAGES)
         ) stage3_bf (
            .clk_i  (clk_i),
            .rst_n  (rst_n),
            .cnt_i  (stage3_ctr),
            .cnt_o  (stage4_ctr_wm),
            .x_re_i (w2_re),
            .x_im_i (w2_im),
            .z_re_o (bf3_re),
            .z_im_o (bf3_im)
         );
      end // if (N > 3)
   endgenerate

   // stage 4
   wire signed [OUTPUT_WIDTH-1:0] bf4_re;
   wire signed [OUTPUT_WIDTH-1:0] bf4_im;

   generate
      if (N_STAGES > 4) begin
         fft_r22sdf_wm #(
            .DATA_WIDTH    (OUTPUT_WIDTH),
            .TWIDDLE_WIDTH (TWIDDLE_WIDTH),
            .FFT_N         (N),
            .NLOG2         (N_LOG2)
         ) stage3_wm (
            .clk_i    (clk_i),
            .clk_3x_i (clk_3x_i),
            .ctr_i    (stage4_ctr_wm),
            .ctr_o    (stage4_ctr),
            .rst_n    (rst_n),
            .x_re_i   (bf3_re),
            .x_im_i   (bf3_im),
            .w_re_i   (w_s3_re),
            .w_im_i   (w_s3_im),
            .z_re_o   (w3_re),
            .z_im_o   (w3_im)
         );

         fft_r22sdf_bf #(
            .DATA_WIDTH (OUTPUT_WIDTH),
            .FFT_N      (N),
            .FFT_NLOG2  (N_LOG2),
            .STAGE      (4),
            .STAGES     (N_STAGES)
         ) stage4_bf (
            .clk_i  (clk_i),
            .rst_n  (rst_n),
            .cnt_i  (stage4_ctr),
            .x_re_i (w3_re),
            .x_im_i (w3_im),
            .z_re_o (bf4_re),
            .z_im_o (bf4_im)
         );
      end // if (N > 4)
   endgenerate

   wire signed [OUTPUT_WIDTH-1:0] data_bf_last_re;
   wire signed [OUTPUT_WIDTH-1:0] data_bf_last_im;

   generate
      case (N_STAGES)
      5:
        begin
           assign data_bf_last_re = bf4_re;
           assign data_bf_last_im = bf4_im;
        end
      4:
        begin
           assign data_bf_last_re = bf3_re;
           assign data_bf_last_im = bf3_im;
        end
      3:
        begin
           assign data_bf_last_re = bf2_re;
           assign data_bf_last_im = bf2_im;
        end
      2:
        begin
           assign data_bf_last_re = bf1_re;
           assign data_bf_last_im = bf1_im;
        end
      1:
        begin
           assign data_bf_last_re = bf0_re;
           assign data_bf_last_im = bf0_im;
        end
      endcase
   endgenerate

   always @(posedge clk_i) begin
      if (!rst_n) begin
         sync_o            <= 1'b0;
         data_ctr_bit_nrml <= {N_LOG2{1'b0}};
         stage0_ctr        <= {N_LOG2{1'b0}};
      end else begin
         data_re_o  <= data_bf_last_re;
         data_im_o  <= data_bf_last_im;
         stage0_ctr <= stage0_ctr + 1'b1;

         if (sync_o == 1'b1) begin
            data_ctr_bit_nrml <= data_ctr_bit_nrml + 1'b1;
         end else begin
            data_ctr_bit_nrml <= {N_LOG2{1'b0}};
         end

         if (stage4_ctr == N_STAGES-2 || sync_o == 1'b1) begin
            sync_o <= 1'b1;
         end else begin
            sync_o <= 1'b0;
         end
      end
   end

endmodule // fft_r22sdf

`ifdef FFT_SIMULATE

`include "fft_r22sdf_defines.vh"
`include "PLLE2_BASE.v"
`include "PLLE2_ADV.v"
`include "BRAM_SINGLE_MACRO.v"
`include "BRAM_SDP_MACRO.v"
`include "RAMB18E1.v"
`include "DSP48E1.v"
`include "glbl.v"

`timescale 1ns/1ps
module fft_r22sdf_tb #( `FFT_PARAMS );

   reg                             clk = 0;
   reg [INPUT_WIDTH-1:0]           samples [0:N-1];
   wire [INPUT_WIDTH-1:0]          data_i;
   wire                            sync;
   wire [N_LOG2-1:0]               data_cnt;
   wire [OUTPUT_WIDTH-1:0]         data_re_o;
   wire [OUTPUT_WIDTH-1:0]         data_im_o;
   reg [N_LOG2-1:0]                cnt;

   assign data_i = samples[cnt];

   integer                         idx;
   initial begin
      $dumpfile("tb/fft_r22sdf_tb.vcd");
      $dumpvars(0, fft_r22sdf_tb);

      $readmemh("tb/fft_samples_1024.hex", samples);
      cnt = 0;

      #120000 $finish;
   end

   always #12.5 clk = !clk;

   always @(posedge clk) begin
      if (pll_lock) begin
         if (cnt == N) begin
            cnt <= cnt;
         end
         else begin
            cnt <= cnt + 1;
         end
      end else begin
         cnt <= 0;
      end
   end

   wire clk_120mhz;
   wire pll_lock;
   wire clk_fb;

   PLLE2_BASE #(
      .CLKFBOUT_MULT  (24),
      .DIVCLK_DIVIDE  (1),
      .CLKOUT0_DIVIDE (8),
      .CLKIN1_PERIOD  (25)
   ) PLLE2_BASE_120mhz (
      .CLKOUT0  (clk_120mhz),
      .LOCKED   (pll_lock),
      .CLKIN1   (clk),
      .RST      (1'b0),
      .CLKFBOUT (clk_fb),
      .CLKFBIN  (clk_fb)
   );


   fft_r22sdf #(
      .N              (N),
      .INPUT_WIDTH    (INPUT_WIDTH),
      .TWIDDLE_WIDTH  (TWIDDLE_WIDTH),
      .OUTPUT_WIDTH   (OUTPUT_WIDTH)
   ) dut (
      .clk_i      (clk),
      .clk_3x_i   (clk_120mhz),
      .rst_n      (pll_lock),
      .sync_o     (sync),
      .data_ctr_o (data_cnt),
      .data_re_i  ($signed(data_i)),
      .data_im_i  ({INPUT_WIDTH{1'b0}}),
      .data_re_o  (data_re_o),
      .data_im_o  (data_im_o)
   );

endmodule

`endif
// Local Variables:
// flycheck-verilator-include-path:("/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unimacro/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/"
//                                  "/home/matt/.nix-profile/opt/Vivado/2017.2/data/verilog/src/unisims/"
//                                  "/home/matt/src/libdigital/libdigital/hdl/memory/ram/"
//                                  "/home/matt/src/libdigital/libdigital/hdl/memory/shift_reg/"
//                                  "/home/matt/src/libdigital/libdigital/hdl/dsp/multiply_add/")
// End:
