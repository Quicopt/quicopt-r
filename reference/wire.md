# The bytes sent to the service

[`solve()`](https://rdrr.io/r/base/solve.html) sends a model to the
service as a sequence of bytes, in a format defined by the service.
[`encode()`](https://quicopt.github.io/quicopt-r/reference/encode.md)
produces these bytes from a model or a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md),
and
[`encode_params()`](https://quicopt.github.io/quicopt-r/reference/encode_params.md)
the bytes for parameter tables on their own. Encoding gives the same
bytes for the same model every time.

## Details

You need these functions only to store the bytes, compare them, or send
them yourself; [`solve()`](https://rdrr.io/r/base/solve.html) encodes a
model for you.
