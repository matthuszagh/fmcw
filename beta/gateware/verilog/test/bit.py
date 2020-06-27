"""
A collection of useful functions for converting between decimal
and binary numbers.
"""


def sub_integral_to_sint(real_val, prec):
    """
    Map a floating point number between the values of -1 and 1 to a
    signed integral value in the range [-2^(@prec-1)-1,
    2^(@prec-1)-1]. This does not permit the value -2^(@prec-1) even
    though it is in the valid two's complement range in order to
    simplify the computation somewhat.
    """
    int_val = int(round(real_val * (2 ** (prec - 1))))
    if int_val == 2 ** (prec - 1):
        int_val -= 1
    return int_val


def sub_integral_to_uint(real_val, prec):
    """
    Like `sub_integral_to_sint' but for unsigned values.
    """
    int_val = int(round(real_val * (2 ** prec)))
    if int_val == 2 ** prec:
        int_val = 2 ** prec - 1
    return int_val


def quantized_real(orig_val, prec):
    """
    Returns a floating-point number quantized for @prec bits of
    precision. Unlike `sub_integral_to_sint', this does not return a
    mapped integer value. Instead, it returns a floating point number
    mimicking the quantization effects of mapping a floating point
    number to an integral value with @prec bits, as is done in
    `sub_integral_to_sint'.
    """
    int_val = sub_integral_to_sint(orig_val, prec)
    return int_val / (2 ** (prec - 1))


def int_to_hex(i, prec):
    """
    Return the two's complement hexadecimal representation of an
    integer.
    """
    if i > 2 ** (prec - 1) - 1 or i < -2 ** (prec - 1):
        raise ValueError("""Value must be in the range given by @prec.""")
    if i < 0:
        i = 2 ** prec + i

    hex_str = format(i, "x")
    return hex_str


def hex_to_sint(s, prec):
    """
    Return the signed integer value of a hexadecimal string with bit
    precision @prec.
    """
    int_val = int(s, 16)
    min_val = -2 ** (prec - 1)
    max_val = 2 ** (prec - 1) - 1
    if int_val > max_val:
        int_val = -2 ** (prec) + int_val
        if int_val > 0:
            raise ValueError(
                """Value is outside the range supported by"""
                """ specified precision."""
            )

    return int_val
