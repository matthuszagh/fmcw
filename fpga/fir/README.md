#### fir.m

Octave file that computes the impulse response for a digital filter with the specified number of
taps, passband and stopband regions, etc. It then saves the filter taps to `fir_coeffs.dbl` and the
frequency response plot to `fir.svg`.

#### dbl_to_hex.py

Quantizes the FIR impulse response double coefficients to integral values for a specified bit
width. The default value is 16 bits. The quantization error for a range of bit widths can be
computed with `quantization_cost.py`. The quantized filter coefficients are saved to `taps.hex`.

#### Makefile

Run `make` to create the FIR filter with default settings.
