Some CP-SAT models used in the CI, plus basic performance statistics. May be useful to detect performance regressions,
e.g. when updating OR-Tools.

Command lines:
```
slothy/paper/scripts> SLOTHY_FLAGS="-c log_model=slothy_ci_fft" ./slothy_fft.sh
slothy/paper/scripts> SLOTHY_FLAGS="-c log_model=slothy_ci_sqmag" ./slothy_sqmag.sh
slothy> python3 example.py --examples ntt_kyber_123_4567_a55,ntt_dilithium_123_45678_a55 --timeout=300 --log-model --log-model-dir="paper/scripts/models"
```
