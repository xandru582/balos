---
name: Bug report
about: Something is broken
title: "[bug] "
labels: bug
---

**Hardware**
- Vendor/model:
- CPU:
- GPU:
- RAM:

**BalOS**
- ISO filename / version:
- Kernel: `uname -r` →
- Booted from:  [ ] USB   [ ] VM   [ ] Installed to disk

**Describe the bug**
A clear and concise description of what's broken.

**To reproduce**
Steps:
1.
2.
3.

**Expected**

**Actual**

**Logs**
```
# attach relevant lines of:
journalctl -b -p err
dmesg --level=err,warn
```

**Additional context**
