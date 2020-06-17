write_cfgmem \
    -force \
    -format bin \
    -size 4 \
    -interface SPIx1 \
    -loadbit "up 0x0 top.bit" \
    flash.bin
