# PlonkFS (PFS) Documentation
PFS is the primary filesystem for the Plonk operating system. It is designed to be performant, even with large volumes, while avoiding some of the problems common to other openly-available file systems.

Additionally, PFS should be fast on traditional hard drives as well as solid-state storage, without causing unnecessary wear for flash memory.

## Feature Overview
### Forks
A common task for filesystems is storing some kind of metadata along with files—metadata which does not follow a well-defined structure. Instead of having the filesystem try to account for every metadata field possible, it supports the concept of forks.

Forks are different 'streams' of a file, and are stored alongside it. Accessing a fork by name is as easy as appending the fork name to the file's name, separated by a colon. Each file can (theoretically) have an infinite number of forks.

## Structure
Various data is stored in different kinds of structures and allocation units, each with their own unique characteristics.

### Blocks
At the core, the drive is divided into individual blocks, made up of several sectors. These blocks serve as the smallest, most basic allocation unit in PFS. Their size depends on the underlying media's sector size, as well as the partition's size. Blocks sizes are always powers of two, up to 128 sectors.

By default, PFS is created with eight sector blocks on filesystems over 2GB, and four sector blocks on filesystems smaller than 2GB. This balances efficient space usage with performance of the filesystem.

### Block Groups
Certain numbers of blocks are bonded together to form block groups. They serve as the basic unit of management for the filesystem. At a maximum, the number of blocks is equal to the block size multiplied by eight. This limit exists so that block allocation bitmaps themselves fit into a single block.

#### Group Descriptors
Group descriptors describe the group, including the block index of the inode and block bitmaps, in addition to keeping track of the number of free inodes and blocks in the group. 

```c
struct pfs_group_descriptor {
	unsigned int block_bitmap;
	unsigned int inode_bitmap;
	
	unsigned int inode_table;
	
	unsigned int free_blocks;
	unsigned int free_inodes;
	
	unsigned int directories;
}
```

#### Data Allocation
All data should be located in the same block as the data it is related to. For example, when creating a new inode for a file, this inode should be located in the same block as the rest of the directory. Data for a file is attempted to be located in the same block group as the directory.

Keeping all this data in the same block group enhances locality of reference, thus requiring less head movement on traditional hard drives. Keeping data together additionally allows for faster reads. Such optimizations, along with block allocation schemes, can reduce fragmentation and overall improve performance.

##### Block Allocation
When allocating blocks, the filesystem can reserve adjacent blocks to use later. By keeping these blocks reserved, directories can be extended quickly and efficiently, and new files can often be contiguous.

### inodes
An inode is a structure representing a certain file, and is the primary resource in PFS. When a filesystem is created, each block group has a certain number of inodes allocated for it. Usually, for every data block, a single inode is allocated. The inodes hold attributes such as the file's size, permissions, owner, and group, various timestamps, file versions, and other metadata about compression or encryption of the file's data. It also serves to document the type of the file—be it a directory, a device, or something else.

Additionally, an inode references a certain amount of blocks taken up by a file's data, and if the file is larger, can point to a block containing a list of blocks containing the file's data. Additional blocks can be added, up until a hierarchy of three lists is established.

### Directories
Instead of giving directories special treatment, they are stored in the same manner as a file with a predefined structure that the filesystem can interpret.

These 'directory records' contain a variable-length zero-terminated filename, encoded using UTF-8, an inode number, and the total length of the record. Records are padded to be multiples of four bytes in size to ensure alignment on architectures that enforce it more strictly than x86.

```c
struct pfs_dirent {
	unsigned int inode;
	
	unsigned short name_length;
	char name[];
}
```

### Superblock
The most important part of PFS is the superblock, which contains many important parameters that allow the rest of the filesystem to be read, interpreted, and correctly parsed. It is located at 512 bytes into the partition, which allows the entirety of the first 512 bytes to be used for a legacy x86 bootloader.

For the most part, there are three types of information in the superblock:

- Configuration variables: These were decided upon when the filesystem was created. These include block sizes, sector sizes, block group sizes, and so forth.
- Tunable configuration: Various options that govern how the filesystem operates. For example, what the driver should do in case of a filesystem error.
- Filesystem state: State that is updated every time the filesystem is mounted and manipulated. This can be used to determine the health of the filesystem, and provides useful statistics like mount and error counts.

Additionally, the superblock provides the location of the root directory, which allows the filesystem to be traversed.