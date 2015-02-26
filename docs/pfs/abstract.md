# PlonkFS (PFS) Documentation
PFS is the primary filesystem for the Plonk operating system. It is designed to be performant, even with large volumes, while avoiding some of the problems common to other openly-available file systems.

## Structure
Various data is stored in different kinds of structures and allocation units, each with their own unique characteristics.

### Blocks
At the core, the drive is divided into individual blocks, made up of several sectors. These blocks serve as the smallest, most basic allocation unit in PFS. Their size depends on the underlying media's sector size, as well as the partition's size. Blocks sizes are always powers of two, up to 128 sectors.

By default, PFS is created with eight sector blocks on filesystems over 2GB, and four sector blocks on filesystems smaller than 2GB. This balances efficient space usage with performance.