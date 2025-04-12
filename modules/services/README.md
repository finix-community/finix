NOTES
- at one point or another most of these services worked, though a number of them haven't been tested in some time - so they may not anymore, given other changes in `finix`
- my current `finix` desktop is running `seatd` instead of `logind` and `wayland` instead of `xserver` - services focused around my usage likely work

QUESTIONS
- how should `finix` [decouple services](https://discourse.nixos.org/t/pre-rfc-decouple-services-using-structured-typing/58257)?
  - `providers.*` is useful but solves a slightly different problem
