# quicopt wire — a program's bytes

[`encode()`](https://quicopt.github.io/quicopt-r/reference/encode.md)
turns a
[`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
into the bytes the service reads. Encoding is deterministic: the same
model always produces the same bytes, and they are the bytes the service
produces for that model too — checked byte for byte against committed
goldens in `tests/`.
