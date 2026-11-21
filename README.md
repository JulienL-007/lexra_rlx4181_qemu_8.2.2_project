# lexra_rlx4181_qemu_8.2.2_project

A QEMU 8.2.2 fork that adds the machine the Sengled Element Hub
(Z02-HUB) needs to boot unmodified: the `rtl8196e` machine
(Realtek RTL8196E SoC) with the `rlx4181` CPU model (the Lexra
RLX4181 core). The vendor bootcode and the vendor Linux 2.6.30
kernel run on it as-is, from a raw 8 MB flash image.

This repository is the fork in patch form - the same principle
as a source package: pristine QEMU is fetched, one patch is
applied, and a script proves the patch reproduces the working
tree exactly.

## The patch

`patches/001-rtl8196e-fork.patch` - 20 files, 2,608 lines against
pristine QEMU 8.2.2:

- the `rtl8196e` machine: SoC register blocks modelled from the
  vendor kernel source (memory controller, UARTs, timers, the
  flash window the bootcode probes),
- the `rlx4181` CPU definition (MIPS I / mips1, soft-float,
  legacy NaN),
- LOPI interrupt handling for the Lexra core.

Known limit, stated plainly: the translator executes the
`lwl`/`lwr`/`swl`/`swr` instructions natively - the RLX4181 core
omits them, but this fork does not gate them to a reserved-
instruction exception. Binaries for the hub are kept clean of
them at build time by the toolchain (see the companion project
lexra_rlx4181_mips1_gcc_14.4.0_project) and verified by an opcode
scan; QEMU here is a boot/function bench, not the legality proof.

## Build

```
./build-qemu.sh
```

The script fetches `qemu-8.2.2.tar.xz` from download.qemu.org,
extracts it, applies the fork patch, configures for mips-softmmu
only, and builds with ninja. The binary lands at
`build/qemu-system-mips`. Safe to re-run: each step skips work
already done.

Host needs: a C toolchain, pkg-config, glib and pixman
development files, ninja, python3, curl, xz, patch.

## Proof

```
./make-patch.sh check
```

Regenerates the patch from a pristine extract and diffs it
against the working tree: PATCH = STATE means the shipped patch
reproduces the fork exactly.

## Run

```
build/qemu-system-mips -machine rtl8196e,flash=<8mb-fullflash.bin> \
  -display none -monitor none \
  -serial unix:/tmp/uart0.sock,server,nowait \
  -serial file:/tmp/uart1.log
```

## License

GPL-2.0 - QEMU's license; the fork patch is a derivative work
of QEMU 8.2.2 and is distributed under the same terms. See
LICENSE.
